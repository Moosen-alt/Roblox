#!/usr/bin/env python3
"""Verify every remote is consumed as the class it is registered as.

Remotes are looked up by name and cast with `::`, which is compile-time fiction —
so a name listed in FUNCTIONS but used via Remotes.Event() type-checks perfectly
and then dies at runtime on `.OnServerEvent`, aborting the whole server script.
That is exactly how Reel a Relic shipped dead on arrival: MineNode sat in
FUNCTIONS while MiningService and MiningInput both treated it as an event.

luau-lsp cannot see this. This can.

Usage: python3 tests/check-remotes.py [game-dir ...]
"""

import pathlib
import re
import sys

USE = re.compile(r'Remotes\.(Event|Function)\(\s*"([^"]+)"\s*\)')


def strip_comments(source: str) -> str:
    """Drop -- comments. The registry tables document each name inline, and those
    comments contain quotes (`(trailName | "")`) that otherwise get read as
    entries."""
    return re.sub(r"--[^\n]*", "", source)


def registry(path: pathlib.Path) -> tuple[set[str], set[str]]:
    """Pull the EVENTS and FUNCTIONS name lists out of a Remotes.luau."""
    source = strip_comments(path.read_text())
    tables = {}
    for name in ("EVENTS", "FUNCTIONS"):
        match = re.search(rf"local {name} = {{(.*?)^}}", source, re.S | re.M)
        if not match:
            raise SystemExit(f"{path}: could not find the {name} table")
        tables[name] = set(re.findall(r'"([^"]+)"', match.group(1)))
    return tables["EVENTS"], tables["FUNCTIONS"]


def check(game: pathlib.Path) -> list[str]:
    remotes = game / "src" / "shared" / "Remotes.luau"
    if not remotes.exists():
        return []  # game has no remote registry
    events, functions = registry(remotes)
    problems = []
    used = set()

    for source in sorted((game / "src").rglob("*.luau")):
        if source == remotes or "Packages" in source.parts:
            continue
        text = strip_comments(source.read_text())
        for kind, name in USE.findall(text):
            used.add(name)
            expected = events if kind == "Event" else functions
            other = functions if kind == "Event" else events
            if name in expected:
                continue
            where = source.relative_to(game)
            if name in other:
                problems.append(
                    f"{where}: Remotes.{kind}(\"{name}\") but {name!r} is registered as a "
                    f"{'RemoteFunction' if kind == 'Event' else 'RemoteEvent'} "
                    f"— move it to the {'EVENTS' if kind == 'Event' else 'FUNCTIONS'} table"
                )
            else:
                problems.append(f"{where}: Remotes.{kind}(\"{name}\") is not registered at all")

    for name in sorted((events | functions) - used):
        print(f"  note: {game}/src/shared/Remotes.luau registers {name!r} but nothing uses it")

    return problems


def main() -> int:
    games = [pathlib.Path(a) for a in sys.argv[1:]] or [pathlib.Path(".")]
    failures = []
    for game in games:
        print(f"=== checking remotes in {game} ===")
        failures += check(game)
    if failures:
        print("\nFAIL: remote registry mismatches\n")
        for problem in failures:
            print("  " + problem)
        return 1
    print("\nALL REMOTES CONSISTENT")
    return 0


if __name__ == "__main__":
    sys.exit(main())
