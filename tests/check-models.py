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
    for table, kind in (("Fish", "fish"), ("Relic", "relic"), ("Crystal", "crystal")):
        try:
            body = text[text.index(f"Meshes.{table} = {{"):]
            body = body[: body.index("\n") if body.startswith(f"Meshes.{table} = {{}}") else body.index("\n}")]
        except ValueError:
            continue
        for name, rest in re.findall(r'\["([^"]+)"\]\s*=\s*\{([^}]*)\}', body):
            total += 1
            if name not in names:
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


def check(game: Path) -> list[str]:
    config = game / "src/shared/Config/Crystals.luau"
    problems = []
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
