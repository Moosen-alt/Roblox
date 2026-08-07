#!/usr/bin/env python3
"""Git merge driver for assets/mesh-source/asset_manifest.csv.

WHY THIS EXISTS

Uploading a mesh to Roblox is not reversible and not repeatable. The asset id
that comes back is the only handle on a model that now lives on Roblox's
servers; lose the id and the asset is still there, still counted against the
account, and completely unreachable — you cannot search it back out by name and
you cannot delete it to try again. The manifest is where those ids live.

The upload workflow commits ids from CI while there are usually unpushed commits
locally, so `git pull --rebase` replays local work over the upload commit and the
manifest conflicts on almost every row. That conflict is the dangerous one,
because BOTH SIDES LOOK PLAUSIBLE: the local side is a complete, well-formed
manifest whose MeshId column is simply blank. Nothing about it reads as damage.
Resolving it the wrong way — and during a rebase `--theirs` means the commit
being replayed, i.e. the local side, which is the reverse of what it reads like —
silently discards every id in one command.

    ours   (local, pre-upload):  Anchovy,...,          <- blank, looks fine
    theirs (the upload commit):  Anchovy,...,121171092141963
    a plain 3-way merge:         conflict, and a coin flip

WHAT IT DOES INSTEAD

Merges row-wise on (Game, Kind, ExactName) rather than line-wise, and gives the
MeshId column one asymmetric rule:

    blank  <  skip  <  a real asset id

A merge may only ever move a row UP that ladder. A real id can never be replaced
by a blank one, whichever side it came from and whichever direction the merge is
running. Every other column merges normally, three-way against the ancestor.

Registered by .gitattributes plus `sh tools/setup-git.sh` (git will not let a
repository configure its own merge drivers — that would let a clone run code —
so the one-line install is deliberate and has to be run once per checkout).
tests/check-manifest.py is the backstop for when it hasn't been.
"""
import csv
import io
import sys
from pathlib import Path

KEY = ("Game", "Kind", "ExactName")


def rank(value: str) -> int:
    """Where a MeshId sits on the ladder. Higher is more decided."""
    value = (value or "").strip()
    if not value:
        return 0  # not uploaded yet
    if value.lower() == "skip":
        return 1  # decided against: the hand-built primitive is better
    return 2  # a real asset id, paid for, unrecoverable if dropped


def read(path: str) -> tuple[list[str], dict[tuple, dict], list[tuple]]:
    """Rows keyed by identity, plus the field list and the original order."""
    text = Path(path).read_text(encoding="utf-8") if path else ""
    if not text.strip():
        return [], {}, []
    reader = csv.DictReader(io.StringIO(text))
    fields = list(reader.fieldnames or [])
    rows: dict[tuple, dict] = {}
    order: list[tuple] = []
    for row in reader:
        key = tuple((row.get(f) or "").strip() for f in KEY)
        rows[key] = row
        order.append(key)
    return fields, rows, order


def merge_field(field: str, base, ours, theirs, key, notes: list[str]):
    """Ordinary three-way resolve for one cell."""
    if ours == theirs:
        return ours, False
    if ours == base:
        return theirs, False
    if theirs == base:
        return ours, False
    notes.append(f"  {'/'.join(key)}: {field} differs on both sides ({ours!r} vs {theirs!r}); kept {ours!r}")
    return ours, True


def merge_row(key, base, ours, theirs, fields, notes) -> tuple[dict, bool]:
    source = ours or theirs or base or {}
    merged: dict[str, str] = {}
    conflicted = False
    for field in fields:
        b = (base or {}).get(field, "")
        o = (ours or {}).get(field, source.get(field, ""))
        t = (theirs or {}).get(field, source.get(field, ""))
        if field == "MeshId":
            # The whole point. Take whichever side is further up the ladder,
            # regardless of what the ancestor said and regardless of which side
            # is "ours" — a real id outranks a blank one, always.
            best = max((o, t, b), key=rank)
            if rank(o) == rank(t) == 2 and o.strip() != t.strip():
                # Two different real ids means the model was uploaded twice and
                # one of the two assets is now an orphan. Not data loss — but
                # somebody should know, so say it out loud instead of picking
                # quietly.
                notes.append(
                    f"  {'/'.join(key)}: two different asset ids ({o.strip()} and {t.strip()}); "
                    f"kept {o.strip()}, the other asset is orphaned on Roblox"
                )
                best = o
            merged[field] = best.strip()
            continue
        value, clash = merge_field(field, b, o, t, key, notes)
        merged[field] = value
        conflicted = conflicted or clash
    return merged, conflicted


def main() -> int:
    if len(sys.argv) < 4:
        print("usage: manifest-merge.py <ancestor> <ours> <theirs> [path]", file=sys.stderr)
        return 2
    ancestor, ours_path, theirs_path = sys.argv[1:4]
    label = sys.argv[4] if len(sys.argv) > 4 else "asset_manifest.csv"

    base_fields, base_rows, _ = read(ancestor)
    our_fields, our_rows, our_order = read(ours_path)
    their_fields, their_rows, their_order = read(theirs_path)

    # Column set: whichever side has more, so a newly added column survives.
    fields = max((our_fields, their_fields, base_fields), key=len)
    if not fields:
        print("manifest-merge: no columns on any side; leaving it to git", file=sys.stderr)
        return 1

    # Ours first, then anything only upstream has, each in its own order. Keeps
    # diffs readable instead of reshuffling seventy-five rows.
    order = list(our_order) + [k for k in their_order if k not in our_rows]

    notes: list[str] = []
    conflicted = False
    merged_rows = []
    for key in order:
        row, clash = merge_row(
            key, base_rows.get(key), our_rows.get(key), their_rows.get(key), fields, notes
        )
        conflicted = conflicted or clash
        merged_rows.append(row)

    # A row deleted on one side but carrying a real id on the other is kept.
    # Deleting a manifest row is how you forget an asset exists; it is never
    # urgent enough to do as a side effect of a merge.
    for key in list(base_rows) + list(their_rows):
        if key in our_rows or any(tuple(r[f] for f in KEY) == key for r in merged_rows):
            continue
        source = their_rows.get(key) or base_rows.get(key) or {}
        if rank(source.get("MeshId", "")) == 2:
            notes.append(f"  {'/'.join(key)}: row was deleted but has asset id {source['MeshId']}; kept it")
            merged_rows.append({f: source.get(f, "") for f in fields})

    out = io.StringIO()
    writer = csv.DictWriter(out, fieldnames=fields, lineterminator="\n")
    writer.writeheader()
    writer.writerows(merged_rows)
    Path(ours_path).write_text(out.getvalue(), encoding="utf-8")

    kept = sum(1 for r in merged_rows if rank(r.get("MeshId", "")) == 2)
    where = sys.stderr if conflicted else sys.stdout
    print(f"manifest-merge: {label} merged, {len(merged_rows)} rows, {kept} asset ids kept", file=where)
    if notes:
        print("\n".join(notes), file=where)
    # Exit 1 marks the file conflicted for the human to finish. The ids are
    # already safe in the file either way — that part is never left to a human.
    if conflicted:
        print("manifest-merge: asset ids are resolved; the fields above still need a decision", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
