#!/usr/bin/env python3
"""Every collectible must have its own model, not a generic fallback.

This exists because the failure it catches is invisible. Adding a row to
Crystals.luau ships immediately and works — it just renders as a nondescript
hoard of coins, and nobody finds out until a player happens to pull that one
relic and screenshots it looking like every other relic.

It lives in Python rather than tests/invariants.luau because RelicShape calls
Instance.new, so it cannot load in the Luau stub harness. A test that silently
skips is worse than no test at all.
"""
import re
import sys
from pathlib import Path


def check_relics(config: Path, shapes: Path) -> list[str]:
    declared = re.findall(r'\{\s*Name\s*=\s*"([^"]+)",\s*Kind\s*=\s*"Relic"', config.read_text())
    built = set(re.findall(r'BUILDERS\[\s*"([^"]+)"\s*\]\s*=', shapes.read_text()))

    problems = []
    for name in declared:
        if name not in built:
            problems.append(f"  relic {name!r} has no model in RelicShape.luau (would render as the generic hoard)")
    # And the other way: a builder for something that is not in the table is
    # dead weight, and usually means a name was renamed in one file only.
    for name in sorted(built - set(declared)):
        problems.append(f"  RelicShape builds {name!r}, which is not a relic in Crystals.luau (renamed?)")
    if not problems:
        print(f"  {len(declared)}/{len(declared)} relics have their own model")
    return problems


def check_fish(config: Path, shapes: Path) -> list[str]:
    """Same failure, other half of the collection.

    Fish are worse than relics here, because the fallback is a perfectly
    good-looking fish. A missing relic renders as an obviously generic hoard; a
    missing fish renders as a fish, and the only tell is that the Anchovy and
    the Megalodon are the same animal in different colours. That is exactly the
    bug this whole species table exists to avoid, and it would ship silently.
    """
    declared = re.findall(r'\{\s*Name\s*=\s*"([^"]+)",\s*Kind\s*=\s*"Fish"', config.read_text())
    text = shapes.read_text()
    # Profile keys are written either bare (Anchovy = {...}) or bracketed when
    # they contain a space (["Sea Bass"] = {...}).
    body = text[text.index("local PROFILES"):]
    body = body[: body.index("\n}\n")]
    built = set(re.findall(r'^\t\["([^"]+)"\]\s*=', body, re.M))
    built |= set(re.findall(r"^\t(\w+)\s*=", body, re.M))

    problems = []
    for name in declared:
        if name not in built:
            problems.append(
                f"  fish {name!r} has no profile in FishShape.luau "
                f"(would silently render as the generic fish)"
            )
    for name in sorted(built - set(declared)):
        problems.append(f"  FishShape profiles {name!r}, which is not a fish in Crystals.luau (renamed?)")
    if not problems:
        print(f"  {len(declared)}/{len(declared)} fish have their own silhouette")
    return problems


def check_meshes(config: Path, meshes: Path) -> list[str]:
    """Mesh overrides must name something that exists.

    Config/Meshes.luau is hand-edited while working through an upload list, and
    a typo'd species name is silent: the override simply never applies and the
    primitive model keeps rendering, so it looks like the upload failed. An
    asset id of 0 is worse - it renders an untextured blank where a fish was.
    """
    text = meshes.read_text()
    # Reel rows carry Kind; the geode game's crystal rows do not. Match the
    # leading `{ Name = "..."` common to both rather than one game's shape.
    names = set(re.findall(r'^\t\{ Name = "([^"]+)"', config.read_text(), re.M))
    problems = []
    total = 0
    # Props are scenery, not collectibles: their names are chosen by the code
    # (ChestBase, ChestLid), so only their asset ids are worth checking.
    for table, kind in (("Fish", "fish"), ("Relic", "relic"), ("Crystal", "crystal"), ("Prop", "prop")):
        try:
            body = text[text.index(f"Meshes.{table} = {{"):]
            body = body[: body.index("\n") if body.startswith(f"Meshes.{table} = {{}}") else body.index("\n}")]
        except ValueError:
            continue
        for name, rest in re.findall(r'\["([^"]+)"\]\s*=\s*\{([^}]*)\}', body):
            total += 1
            if kind != "prop" and name not in names:
                problems.append(
                    f"  mesh override for {kind} {name!r} names nothing in Crystals.luau "
                    f"(the override would silently never apply)"
                )
            asset = re.search(r"Mesh\s*=\s*(\d+)", rest)
            if not asset or int(asset.group(1)) <= 0:
                problems.append(f"  mesh override for {name!r} has no valid Mesh asset id")
    if total:
        print(f"  {total} mesh overrides, all naming real collectibles")
    return problems


# Where each game asks for world decoration by name. These are placement plans,
# not collectibles, so the coverage question is different: does the prop exist in
# the pack at all?
DECOR_SOURCES = ["src/server/MapBuilder.luau", "src/client/CaveDecor.luau"]
MANIFEST = Path(__file__).resolve().parent.parent / "assets/mesh-source/asset_manifest.csv"

# Game directory -> the Game column in the manifest.
GAME_NAMES = {".": "Crack a Geode", "games/reel-a-relic": "Reel a Relic"}

# A placement plan asks for a size in studs along ONE axis. Scale is uniform, so
# the other two are a consequence nobody wrote down and nobody looks at — which
# is how a bridge asked to stand 11 studs tall came out 210 studs long, in a
# cavern 220 studs wide. Past this, a prop is not decoration any more.
MAX_FOOTPRINT = 60


def obj_extents(path: Path) -> tuple[float, float, float] | None:
    lo = [float("inf")] * 3
    hi = [float("-inf")] * 3
    if not path.exists():
        return None
    with path.open(encoding="utf-8", errors="ignore") as handle:
        for line in handle:
            if line.startswith("v "):
                parts = line.split()
                for axis in range(3):
                    value = float(parts[axis + 1])
                    lo[axis] = min(lo[axis], value)
                    hi[axis] = max(hi[axis], value)
    if lo[0] == float("inf"):
        return None
    return tuple(hi[a] - lo[a] for a in range(3))


def check_footprints(game: Path, rows: list[dict]) -> list[str]:
    """What a placement plan actually renders, not what it asks for.

    The plan says "eleven studs". For a boulder that is the whole story; for
    anything long and low it is one third of it, and the other two thirds is
    where the model ends up wider than the room. This measures the source OBJ
    and works the rendered footprint out, which is the only way to see it — the
    numbers in the plan look completely reasonable either way.
    """
    source = Path("assets/mesh-source")
    by_name = {row["ExactName"]: row for row in rows}
    problems = []
    for relative in DECOR_SOURCES:
        plan_file = game / relative
        if not plan_file.exists():
            continue
        # The tail is matched loosely and Fit searched within it, so a row that
        # writes Tint or Material between Zone and Fit still measures as a Span
        # row instead of silently falling back to height-sizing.
        pattern = (
            r'\{\s*Name = "([^"]+)", Count = \d+, Min = ([\d.]+), Max = ([\d.]+), '
            r'Zone = "\w+"([^}]*)\}'
        )
        for name, _, biggest, tail in re.findall(pattern, plan_file.read_text()):
            by_span = 'Fit = "Span"' in tail
            row = by_name.get(name)
            if row is None:
                continue  # the name check above already reports this
            extents = obj_extents(source / row["LocalFile"])
            if extents is None:
                continue
            width, height, depth = extents
            longest = max(width, depth)
            # Span sizes the longest horizontal axis; otherwise height does, and
            # the horizontal size falls out of the model's own proportions.
            scale = float(biggest) / (longest if by_span else height)
            footprint = longest * scale
            if footprint > MAX_FOOTPRINT:
                problems.append(
                    f"  {relative} places {name!r} at {footprint:.0f} studs across "
                    f"(asked for {biggest} {'span' if by_span else 'tall'}; the model is "
                    f"{longest / height:.0f}x wider than it is tall). "
                    f"Size it with Fit = \"Span\" instead."
                )
    return problems


def check_decor(game: Path) -> list[str]:
    """A world prop named in a placement plan must exist in the pack.

    Same silent failure as a missing collectible model, one step further out.
    WorldBuild returns nil for a name it does not know — which is exactly what
    it should do for a mesh awaiting upload — so a typo is indistinguishable
    from "not uploaded yet" and simply renders nothing, forever. Nobody notices
    one absent boulder among forty.
    """
    import csv

    key = GAME_NAMES.get(game.as_posix())
    if key is None or not MANIFEST.exists():
        return []
    rows = [
        row
        for row in csv.DictReader(MANIFEST.open(newline="", encoding="utf-8"))
        if row["Game"] == key and row["Kind"] == "World"
    ]
    known = {row["ExactName"] for row in rows}
    if not known:
        return []

    problems, used = check_footprints(game, rows), set()
    for relative in DECOR_SOURCES:
        source = game / relative
        if not source.exists():
            continue
        # Only rows that are placement plans: `{ Name = "x", Count = n, ... }`.
        for name in re.findall(r'\{\s*Name\s*=\s*"([^"]+)",\s*Count\s*=', source.read_text()):
            used.add(name)
            if name not in known:
                problems.append(
                    f"  {relative} places world prop {name!r}, which is not in the mesh pack "
                    f"(it would silently render nothing)"
                )
    unused = sorted(known - used)
    if unused:
        # Not a failure. An uploaded prop nobody places is wasted, but shipping
        # is never the moment to argue about it.
        print(f"  ! {len(unused)} world prop(s) in the pack are never placed: {', '.join(unused)}")
    if not problems:
        print(f"  {len(used)} world props placed, all present in the pack")
    return problems


def check(game: Path) -> list[str]:
    config = game / "src/shared/Config/Crystals.luau"
    problems = check_decor(game)
    relics = game / "src/shared/RelicShape.luau"
    fish = game / "src/shared/FishShape.luau"
    if not config.exists():
        return []  # this game has no collectible pools; nothing to check
    if relics.exists():
        problems += check_relics(config, relics)
    if fish.exists():
        problems += check_fish(config, fish)
    meshes = game / "src/shared/Config/Meshes.luau"
    if meshes.exists():
        problems += check_meshes(config, meshes)
    return problems


def main() -> int:
    games = [Path(a) for a in sys.argv[1:]] or [Path(".")]
    failures = []
    for game in games:
        print(f"=== checking models in {game} ===")
        failures += check(game)
    if failures:
        print("\nMODEL COVERAGE FAILED")
        print("\n".join(failures))
        return 1
    print("\nALL COLLECTIBLES HAVE MODELS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
