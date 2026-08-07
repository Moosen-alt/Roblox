#!/usr/bin/env python3
"""Redeem codes must be well-formed.

This exists because Config/Codes.luau is the one file meant to be edited by
whoever is running the game, live, in a hurry, on the day of an update — and
every failure mode is silent. A duplicate code means the second row never fires
and nobody finds out until players say a code "doesn't work". A code with no
reward redeems successfully and pays nothing, which is worse than a dead code
because it also burns the player's one redemption.

Python rather than the Luau harness for the same reason as check-models.py: this
runs in CI on a plain checkout with no Roblox globals to stand up.
"""
import re
import sys
from pathlib import Path


def check(game: Path) -> list[str]:
    config = game / "src/shared/Config/Codes.luau"
    if not config.exists():
        return []  # this game has no codes; nothing to check

    text = config.read_text()
    try:
        body = text[text.index("Codes.List = {"):]
        body = body[: body.index("\n} ::")]
    except ValueError:
        return ["  Codes.List is missing or its closing `} ::` annotation changed"]

    rows = re.findall(r'\{\s*Code\s*=\s*"([^"]*)"(.*?)\},', body, re.S)
    problems: list[str] = []
    if not rows:
        problems.append("  Codes.List has no entries — the redeem box would reject everything")

    seen: dict[str, int] = {}
    for index, (code, rest) in enumerate(rows, start=1):
        canonical = code.strip().upper()
        if not canonical:
            problems.append(f"  entry {index} has an empty code")
            continue
        if canonical in seen:
            problems.append(
                f"  code {code!r} is defined twice (rows {seen[canonical]} and {index}); "
                f"the second one can never fire, because Codes.Find returns the first match"
            )
        seen[canonical] = index

        # Codes are matched case-insensitively, so a lowercase row still works —
        # but the table is also the operator's reference sheet, and mixed casing
        # there is how a wrong code ends up copied into a video description.
        if code != canonical:
            problems.append(f"  code {code!r} should be written upper-case and untrimmed as {canonical!r}")

        coins = re.search(r"Coins\s*=\s*([\d.]+)", rest)
        chests = re.search(r"Chests\s*=\s*(\d+)", rest)
        pays = (coins and float(coins.group(1)) > 0) or (chests and int(chests.group(1)) > 0)
        if not pays:
            problems.append(
                f"  code {code!r} pays nothing — it would consume the player's "
                f"one redemption and hand back an empty reward"
            )
        if not re.search(r'Note\s*=\s*"[^"]+"', rest):
            problems.append(f"  code {code!r} has no Note; the success message would be blank")

    if not problems:
        print(f"  {len(rows)} codes, all unique and all paying something")
    return problems


def main() -> int:
    games = [Path(a) for a in sys.argv[1:]] or [Path(".")]
    failures = []
    for game in games:
        print(f"=== checking codes in {game} ===")
        failures += check(game)
    if failures:
        print("\nCODE TABLE FAILED")
        print("\n".join(failures))
        return 1
    print("\nALL CODE TABLES VALID")
    return 0


if __name__ == "__main__":
    sys.exit(main())
