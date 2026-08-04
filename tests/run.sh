#!/bin/sh
# Runs math tests under the standalone Luau CLI (no Studio needed).
# The shared modules are pure Luau except Color3/Random, which
# tests/randstub.luau provides.
#
# Usage:
#   sh tests/run.sh                                       # root game, full math tests
#   sh tests/run.sh games/reel-a-relic tests/invariants.luau   # a re-theme, generic invariants
#   [LUAU=/path/to/luau] to point at a specific Luau binary.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$DIR/.."
GAME="${1:-.}"
TESTFILE="${2:-$DIR/mathtest.luau}"
LUAU="${LUAU:-luau}"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

SRC="$ROOT/$GAME/src/shared"

strip_module() {
	# Drop strict pragma, module returns, and cross-module requires — the files
	# are concatenated in dependency order so the tables resolve as upvalues.
	grep -v '^--!strict$' "$1" | grep -v '^return ' | grep -v 'require(script'
}

{
	cat "$DIR/randstub.luau"
	strip_module "$SRC/Config/Crystals.luau"
	strip_module "$SRC/Config/Balance.luau"
	strip_module "$SRC/RarityMath.luau"
	strip_module "$SRC/Format.luau"
	cat "$TESTFILE"
} > "$OUT/combined.luau"

"$LUAU" "$OUT/combined.luau"
