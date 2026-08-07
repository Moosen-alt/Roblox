#!/usr/bin/env python3
"""Turn asset_manifest.csv into the Meshes.luau tables, for both games.

Workflow:
    1. Import an OBJ from assets/mesh-source/ in Studio's 3D Importer.
    2. Save the MeshPart to Roblox, copy its numeric MeshId.
    3. Paste that number into the MeshId column of the manifest row.
    4. Run this. It rewrites the override tables in place.
    5. Push. CI validates the names and republishes.

Rows with a blank MeshId are skipped, so this is safe to run at any point — you
can upload six fish, run it, and ship with the other twenty-seven still using
their primitive models.

Rewrites only the table bodies. Everything else in Meshes.luau — the type, the
lookup functions, and the long comment about licensing — is left alone.
"""
import argparse
import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "assets/mesh-source/asset_manifest.csv"

# Which manifest Game/Kind lands in which file and table.
TARGETS = {
    ("Reel a Relic", "Fish"): ("games/reel-a-relic/src/shared/Config/Meshes.luau", "Fish"),
    ("Reel a Relic", "Relic"): ("games/reel-a-relic/src/shared/Config/Meshes.luau", "Relic"),
    ("Crack a Geode", "Crystal"): ("src/shared/Config/Meshes.luau", "Crystal"),
    ("Reel a Relic", "Prop"): ("games/reel-a-relic/src/shared/Config/Meshes.luau", "Prop"),
    ("Crack a Geode", "Prop"): ("src/shared/Config/Meshes.luau", "Prop"),
}


def row_to_lua(row: dict) -> str:
    mesh = int(row["MeshId"])
    scale = float(row["Scale"] or 1)
    rx, ry, rz = (float(row[f"Rotation{a}"] or 0) for a in "XYZ")
    extra = f", Rotation = Vector3.new({rx:g}, {ry:g}, {rz:g})" if any((rx, ry, rz)) else ""
    return f'\t["{row["ExactName"]}"] = {{ Mesh = {mesh}, Scale = {scale:g}{extra} }},'


def replace_table(text: str, table: str, rows: list[str]) -> str:
    """Swap the body of `Meshes.<table> = { ... } :: { [string]: MeshDef }`."""
    pattern = re.compile(
        rf"(Meshes\.{table} = \{{)(.*?)(\}} :: \{{ \[string\]: MeshDef \}})",
        re.S,
    )
    if not pattern.search(text):
        raise SystemExit(f"could not find Meshes.{table} table to rewrite")
    body = "\n" + "\n".join(rows) + "\n" if rows else ""
    return pattern.sub(lambda m: m.group(1) + body + m.group(3), text, count=1)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="report only; do not write")
    args = parser.parse_args()

    if not MANIFEST.exists():
        print(f"no manifest at {MANIFEST}", file=sys.stderr)
        return 1

    pending: dict[tuple[str, str], list[str]] = {}
    filled = skipped = 0
    for row in csv.DictReader(MANIFEST.open(newline="", encoding="utf-8")):
        key = (row["Game"], row["Kind"])
        target = TARGETS.get(key)
        if target is None:
            print(f"  ! unknown Game/Kind {key}, skipping {row['ExactName']}")
            continue
        raw = (row["MeshId"] or "").strip()
        if not raw:
            skipped += 1
            continue
        try:
            if int(raw) <= 0:
                raise ValueError
        except ValueError:
            print(f"  ! {row['ExactName']}: MeshId {raw!r} is not a positive number", file=sys.stderr)
            return 1
        pending.setdefault(target, []).append(row_to_lua(row))
        filled += 1

    print(f"{filled} uploaded, {skipped} still awaiting a MeshId")
    if args.check:
        return 0

    # Group by file so a file holding two tables is written once.
    by_file: dict[str, list[tuple[str, list[str]]]] = {}
    for (path, table), rows in pending.items():
        by_file.setdefault(path, []).append((table, rows))
    # Tables with nothing uploaded still need emptying, in case a row was removed.
    for path, table in TARGETS.values():
        by_file.setdefault(path, [])
        if table not in [t for t, _ in by_file[path]]:
            by_file[path].append((table, []))

    for path, tables in by_file.items():
        full = ROOT / path
        text = full.read_text()
        for table, rows in tables:
            text = replace_table(text, table, sorted(rows))
        full.write_text(text)
        names = ", ".join(f"{t} x{len(r)}" for t, r in tables)
        print(f"  wrote {path}  ({names})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
