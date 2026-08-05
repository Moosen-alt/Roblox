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

USE = re.compile(r"""Remotes\.(Event|Function)\(\s*(['"])([^'"]+)\2\s*\)""")
# A call whose argument is not a plain literal — those are invisible to USE, so
# report them rather than pretending the file is fully covered.
DYNAMIC = re.compile(r"""Remotes\.(?:Event|Function)\(\s*(?!['"])""")


def strip_comments(source: str) -> str:
    """Drop -- comments without eating quoted text.

    Naive `--.*` stripping truncates any line where -- appears inside a string
    (`Text = "Restock in --:--"`), which would silently hide a Remotes call
    later on that line. Walk the line instead, tracking whether we are inside a
    quote.
    """
    out = []
    for line in source.split("\n"):
        quote = None
        cut = len(line)
        i = 0
        while i < len(line):
            ch = line[i]
            if quote:
                if ch == "\\":
                    i += 2
                    continue
                if ch == quote:
                    quote = None
            elif ch in "\"'":
                quote = ch
            elif ch == "-" and line.startswith("--", i):
                cut = i
                break
            i += 1
        out.append(line[:cut])
    return "\n".join(out)


def registry(path: pathlib.Path) -> tuple[set[str], set[str], list[str]]:
    """Pull the EVENTS and FUNCTIONS name lists out of a Remotes.luau."""
    source = strip_comments(path.read_text())
    tables = {}
    for name in ("EVENTS", "FUNCTIONS"):
        match = re.search(rf"local {name} = {{(.*?)^}}", source, re.S | re.M)
        if not match:
            raise SystemExit(f"{path}: could not find the {name} table")
        tables[name] = set(re.findall(r'"([^"]+)"', match.group(1)))

    # A name in BOTH tables is worse than it looks: Remotes.Init() creates the
    # RemoteEvent first, then the FUNCTIONS pass finds it, sees the wrong class,
    # and errors — inside Init, which is the first line of the server script.
    problems = [
        f"{path}: {name!r} is listed in EVENTS *and* FUNCTIONS — Remotes.Init() will error on it"
        for name in sorted(tables["EVENTS"] & tables["FUNCTIONS"])
    ]
    return tables["EVENTS"], tables["FUNCTIONS"], problems


def check(game: pathlib.Path) -> list[str]:
    remotes = game / "src" / "shared" / "Remotes.luau"
    if not remotes.exists():
        # Never pass silently on a path that does not exist: a typo in the CI
        # GAMES list would otherwise print a green header and check nothing.
        return [f"{game}: no src/shared/Remotes.luau (wrong path, or the file moved?)"]

    events, functions, problems = registry(remotes)
    used = set()
    scanned = 0

    for source in sorted((game / "src").rglob("*.luau")):
        if source == remotes or "Packages" in source.parts:
            continue
        scanned += 1
        text = strip_comments(source.read_text())
        where = source.relative_to(game)

        for kind, _quote, name in USE.findall(text):
            used.add(name)
            expected = events if kind == "Event" else functions
            other = functions if kind == "Event" else events
            if name in expected:
                continue
            if name in other:
                problems.append(
                    f'{where}: Remotes.{kind}("{name}") but {name!r} is registered as a '
                    f"{'RemoteFunction' if kind == 'Event' else 'RemoteEvent'} "
                    f"— move it to the {'EVENTS' if kind == 'Event' else 'FUNCTIONS'} table"
                )
            else:
                problems.append(f'{where}: Remotes.{kind}("{name}") is not registered at all')

        for _ in DYNAMIC.findall(text):
            print(f"  note: {where} looks up a remote by variable — not covered by this check")

    if scanned == 0:
        problems.append(f"{game}: no .luau sources found under src/ — nothing was checked")

    for name in sorted((events | functions) - used):
        print(f"  note: {remotes} registers {name!r} but no literal lookup uses it")

    return problems


def main() -> int:
    games = [pathlib.Path(a) for a in sys.argv[1:]] or [pathlib.Path(".")]
    failures = []
    for game in games:
        print(f"=== checking remotes in {game} ===")
        failures += check(game)
    if failures:
        print("\nFAIL: remote registry problems\n")
        for problem in failures:
            print("  " + problem)
        return 1
    print("\nALL REMOTES CONSISTENT")
    return 0


if __name__ == "__main__":
    sys.exit(main())
