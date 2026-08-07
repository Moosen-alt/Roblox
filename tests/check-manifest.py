#!/usr/bin/env python3
"""The mesh manifest must never lose an asset id.

A Roblox asset id is the only handle on an uploaded model. Uploading is not
repeatable — re-running the uploader creates a SECOND asset rather than
recovering the first — and there is no bulk delete and no search-by-name, so an
id that falls out of the manifest is a model that exists on the account forever
and can never be used again. That makes the manifest the single most fragile
file here, and the one whose damage is least visible: a manifest with every
MeshId blank is a perfectly well-formed CSV.

It has already come close once. The upload workflow commits ids from CI, so a
local `git pull --rebase` replays local commits over that commit and the manifest
conflicts on nearly every row — and during a rebase `--theirs` means the commit
being replayed, which is the local, blank side. One habitual command, 67 ids
gone, and nothing about the result looks wrong.

TWO INVARIANTS, checked against git history rather than against any one commit,
so it does not matter how the loss happened — rebase, bad manual resolution,
revert, stray edit:

  1. NO ROW GOES BACKWARDS. If a row ever carried a real asset id in any commit
     on any branch, it must still carry one. blank -> id is fine (an upload).
     id -> a different id is fine (a re-upload). id -> blank is never fine.

  2. THE GENERATED TABLES MATCH. Meshes.luau is derived from the manifest by
     tools/build-meshes.py, so a merge that mangles it is repairable but only if
     someone notices. Regenerating in memory and comparing is how we notice.

    python3 tests/check-manifest.py            # verify (CI, and the pre-push hook)
    python3 tests/check-manifest.py --repair    # put the lost ids back

--repair is why this can be an instruction rather than an incident: it recovers
every id from history and rewrites the generated tables, so the answer to "the
manifest looks wrong" is one command instead of archaeology.
"""
import argparse
import csv
import importlib.util
import io
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RELPATH = "assets/mesh-source/asset_manifest.csv"
MANIFEST = ROOT / RELPATH
KEY = ("Game", "Kind", "ExactName")


def git(*args: str) -> str:
    result = subprocess.run(
        ["git", *args], cwd=ROOT, capture_output=True, text=True
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"git {' '.join(args)} failed")
    return result.stdout


def rows_of(text: str) -> dict[tuple, dict]:
    if not text.strip():
        return {}
    reader = csv.DictReader(io.StringIO(text))
    return {
        tuple((row.get(f) or "").strip() for f in KEY): row
        for row in reader
    }


def is_id(value: str) -> bool:
    value = (value or "").strip()
    return value.isdigit() and int(value) > 0


def history_ids() -> tuple[dict[tuple, str], int]:
    """Every asset id this manifest has ever held, keyed by row identity.

    --all rather than HEAD's ancestry: after a bad rebase the commit that
    recorded the ids may no longer be an ancestor of anything, but it is still
    reachable from the remote-tracking branch, and that is enough to recover it.
    """
    try:
        shallow = git("rev-parse", "--is-shallow-repository").strip() == "true"
    except RuntimeError as error:
        print(f"  ! no git history available ({error}); invariant 1 not checked")
        return {}, 0
    if shallow:
        # A shallow clone would make this check pass by knowing nothing, which is
        # worse than not running it: it reports "safe" over an empty search.
        raise SystemExit(
            "  ! shallow clone — the history this check depends on is not here.\n"
            "    In CI: actions/checkout@v4 needs `with: {fetch-depth: 0}`.\n"
            "    Locally: git fetch --unshallow"
        )

    known: dict[tuple, str] = {}
    commits = git("log", "--all", "--format=%H", "--", RELPATH).split()
    for sha in commits:
        try:
            text = git("show", f"{sha}:{RELPATH}")
        except RuntimeError:
            continue  # the file did not exist in that commit
        for key, row in rows_of(text).items():
            value = (row.get("MeshId") or "").strip()
            if is_id(value):
                known.setdefault(key, value)  # newest commit first, so first wins
    return known, len(commits)


def generated_drift() -> list[str]:
    """Do the Meshes.luau tables still say what the manifest says?"""
    # Reuse the generator's own row formatter rather than reimplementing it —
    # a second copy of that logic would drift and this check would then be
    # comparing the manifest against the wrong expectation.
    sys.dont_write_bytecode = True  # no __pycache__ beside the tools
    spec = importlib.util.spec_from_file_location("build_meshes", ROOT / "tools/build-meshes.py")
    build = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(build)

    wanted: dict[tuple[str, str], list[str]] = {}
    for row in csv.DictReader(MANIFEST.open(newline="", encoding="utf-8")):
        target = build.TARGETS.get((row["Game"], row["Kind"]))
        if target is None or not is_id(row["MeshId"]):
            continue
        wanted.setdefault(target, []).append(build.row_to_lua(row))

    problems = []
    for path, table in set(build.TARGETS.values()):
        full = ROOT / path
        if not full.exists():
            problems.append(f"  {path} is missing, but the manifest targets it")
            continue
        text = full.read_text()
        expected = build.replace_table(text, table, sorted(wanted.get((path, table), [])))
        if expected != text:
            problems.append(
                f"  {path}: the {table} table does not match the manifest "
                f"(expected {len(wanted.get((path, table), []))} entries)"
            )
    return problems


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repair", action="store_true", help="restore lost ids and regenerate")
    args = parser.parse_args()

    if not MANIFEST.exists():
        print(f"no manifest at {RELPATH}; nothing to check")
        return 0

    current = rows_of(MANIFEST.read_text(encoding="utf-8"))
    known, commits = history_ids()

    lost = {
        key: was
        for key, was in known.items()
        if key not in current or not is_id(current[key].get("MeshId", ""))
    }
    live = sum(1 for row in current.values() if is_id(row.get("MeshId", "")))

    if lost and args.repair:
        print(f"restoring {len(lost)} asset id(s) from history:")
        fields = list(next(iter(current.values())).keys())
        for key, was in sorted(lost.items()):
            if key in current:
                current[key]["MeshId"] = was
                print(f"  {'/'.join(key)} -> {was}")
            else:
                print(f"  ! {'/'.join(key)} has no row to restore into (id {was} is orphaned)")
        out = io.StringIO()
        writer = csv.DictWriter(out, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(current.values())
        MANIFEST.write_text(out.getvalue(), encoding="utf-8")
        subprocess.run([sys.executable, str(ROOT / "tools/build-meshes.py")], cwd=ROOT, check=True)
        print("manifest repaired and tables regenerated — review the diff, then commit")
        return 0

    problems: list[str] = []
    if lost:
        problems.append(
            f"  {len(lost)} row(s) had a Roblox asset id in git history and no longer do.\n"
            f"  Those assets still exist on the account and cannot be recovered any other way."
        )
        for key, was in sorted(lost.items()):
            problems.append(f"    {'/'.join(key)}  had {was}, now {current.get(key, {}).get('MeshId', '<row deleted>')!r}")
        problems.append("\n  Fix it with:  python3 tests/check-manifest.py --repair")

    if args.repair:
        print("no lost ids to restore")

    drift = generated_drift()
    if drift:
        problems.append("  the generated mesh tables are out of step with the manifest:")
        problems += drift
        problems.append("\n  Fix it with:  python3 tools/build-meshes.py")

    if problems:
        print("\nMESH MANIFEST FAILED")
        print("\n".join(problems))
        return 1

    print(
        f"  {len(current)} rows, {live} asset ids, none lost "
        f"(checked against {commits} commit(s) of history); generated tables match"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
