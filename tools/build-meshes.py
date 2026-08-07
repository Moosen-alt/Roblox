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
SOURCE = ROOT / "assets/mesh-source"

# Which manifest Game/Kind lands in which file and table.
TARGETS = {
    ("Reel a Relic", "Fish"): ("games/reel-a-relic/src/shared/Config/Meshes.luau", "Fish"),
    ("Reel a Relic", "Relic"): ("games/reel-a-relic/src/shared/Config/Meshes.luau", "Relic"),
    ("Crack a Geode", "Crystal"): ("src/shared/Config/Meshes.luau", "Crystal"),
    ("Reel a Relic", "Prop"): ("games/reel-a-relic/src/shared/Config/Meshes.luau", "Prop"),
    ("Crack a Geode", "Prop"): ("src/shared/Config/Meshes.luau", "Prop"),
    ("Reel a Relic", "World"): ("games/reel-a-relic/src/shared/Config/Meshes.luau", "World"),
    ("Crack a Geode", "World"): ("src/shared/Config/Meshes.luau", "World"),
}

# Collectibles are drawn centred in a viewport at a fixed size, so their extents
# do not matter. World decoration is placed ON terrain at a chosen height, and a
# SpecialMesh keeps its Part 1x1x1 however large the mesh draws — so at runtime
# there is no way to ask how tall a prop is. Measure it here instead.
MEASURED_KINDS = {"World"}

# The world pack ships its own material and colour per model. Copying 69 of
# those by hand is exactly the kind of transcription nobody proofreads, so read
# them from the pack's manifest and generate them too.
PACK_MANIFEST = ROOT / "assets/mesh-source/world/pack-manifest.csv"

# Roblox material names, for the few the pack writes differently. Anything not
# listed is passed through and validated below — a bad name would otherwise
# reach Luau as Enum.Material.Nonsense.
MATERIAL_ALIASES = {
    "Grass/Wood": "Grass",  # trees: fronds/needles are the mass, the trunk is a sliver
    "Bone": "Sand",  # Roblox has no Bone; Sand is the closest pale, matte surface
    "DiamondPlate": "DiamondPlate",
}
ROBLOX_MATERIALS = {
    "Plastic", "SmoothPlastic", "Neon", "Wood", "WoodPlanks", "Marble", "Slate",
    "Concrete", "Granite", "Brick", "Pebble", "Cobblestone", "Rock", "Sandstone",
    "Basalt", "CrackedLava", "Limestone", "Asphalt", "Ground", "Mud", "Sand",
    "Snow", "Ice", "Glacier", "Grass", "LeafyGrass", "Metal", "DiamondPlate",
    "CorrodedMetal", "Foil", "Glass", "ForceField", "Fabric", "Salt",
}


def pack_styles() -> dict[tuple[str, str], tuple[str, str]]:
    """(Game, Asset) -> (Roblox material, "r, g, b") from the world pack."""
    if not PACK_MANIFEST.exists():
        return {}
    styles = {}
    for row in csv.DictReader(PACK_MANIFEST.open(newline="", encoding="utf-8")):
        raw = row["SuggestedMaterial"].strip()
        material = MATERIAL_ALIASES.get(raw, raw)
        if material not in ROBLOX_MATERIALS:
            raise SystemExit(
                f"{row['Asset']}: {raw!r} is not a Roblox material. "
                f"Add it to MATERIAL_ALIASES in tools/build-meshes.py."
            )
        rgb = ", ".join(part.strip() for part in row["SuggestedColorRGB"].split(","))
        styles[(row["Game"], row["Asset"])] = (material, rgb)
    return styles


STYLES = pack_styles()


def measure(obj: Path) -> dict[str, tuple[float, float, float]] | None:
    """Native extents, centre and lowest point of an OBJ, in mesh units."""
    if not obj.exists():
        return None
    lo = [float("inf")] * 3
    hi = [float("-inf")] * 3
    with obj.open(encoding="utf-8", errors="ignore") as handle:
        for line in handle:
            if not line.startswith("v "):
                continue
            parts = line.split()
            for axis in range(3):
                value = float(parts[axis + 1])
                lo[axis] = min(lo[axis], value)
                hi[axis] = max(hi[axis], value)
    if lo[0] == float("inf"):
        return None
    return {
        "size": tuple(hi[a] - lo[a] for a in range(3)),
        "middle": tuple((hi[a] + lo[a]) / 2 for a in range(3)),
        "floor": lo[1],
    }


def row_to_lua(row: dict) -> str:
    mesh = int(row["MeshId"])
    scale = float(row["Scale"] or 1)
    rx, ry, rz = (float(row[f"Rotation{a}"] or 0) for a in "XYZ")
    extra = f", Rotation = Vector3.new({rx:g}, {ry:g}, {rz:g})" if any((rx, ry, rz)) else ""
    if row["Kind"] in MEASURED_KINDS:
        bounds = measure(SOURCE / row["LocalFile"])
        if bounds is None:
            raise SystemExit(
                f"cannot measure {row['ExactName']}: no source OBJ at {row['LocalFile']}. "
                f"World props are placed from their real extents, so this is not optional."
            )
        w, h, d = bounds["size"]
        mx, my, mz = bounds["middle"]
        extra += f", Size = Vector3.new({w:.4g}, {h:.4g}, {d:.4g})"
        extra += f", Floor = {bounds['floor']:.4g}"
        if any(abs(v) > 1e-4 for v in (mx, my, mz)):
            extra += f", Middle = Vector3.new({mx:.4g}, {my:.4g}, {mz:.4g})"
        style = STYLES.get((row["Game"], row["ExactName"]))
        if style:
            material, rgb = style
            extra += f", Material = Enum.Material.{material}, Tint = Color3.fromRGB({rgb})"
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
    filled = pendingCount = deliberate = 0
    for row in csv.DictReader(MANIFEST.open(newline="", encoding="utf-8")):
        key = (row["Game"], row["Kind"])
        target = TARGETS.get(key)
        if target is None:
            print(f"  ! unknown Game/Kind {key}, skipping {row['ExactName']}")
            continue
        raw = (row["MeshId"] or "").strip()
        if raw.lower() == "skip":
            # Deliberately not uploaded: the hand-built primitive is better.
            # Generating no override is the whole point.
            deliberate += 1
            continue
        if not raw:
            pendingCount += 1
            continue
        try:
            if int(raw) <= 0:
                raise ValueError
        except ValueError:
            print(f"  ! {row['ExactName']}: MeshId {raw!r} is not a positive number", file=sys.stderr)
            return 1
        pending.setdefault(target, []).append(row_to_lua(row))
        filled += 1

    # "Awaiting" and "skipped" must not be reported as the same thing: one is
    # work left to do, the other is a decision already made.
    print(f"{filled} uploaded, {pendingCount} awaiting a MeshId, {deliberate} deliberately skipped")
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
