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


def check(game: Path) -> list[str]:
    config = game / "src/shared/Config/Crystals.luau"
    shapes = game / "src/shared/RelicShape.luau"
    if not config.exists() or not shapes.exists():
        return []  # this game has no relic pool; nothing to check

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
