#!/bin/sh
# Runs the math tests under the standalone Luau CLI (no Studio needed).
# The shared modules are pure Luau except for Color3/Random, which
# tests/randstub.luau provides. Usage: [LUAU=/path/to/luau] sh tests/run.sh
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$DIR/.."
LUAU="${LUAU:-luau}"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

strip_module() {
	# Drop strict pragma, module returns, and cross-module requires — the files
	# are concatenated in dependency order so the tables resolve as upvalues.
	grep -v '^--!strict$' "$1" | grep -v '^return ' | grep -v 'require(script'
}

{
	cat "$DIR/randstub.luau"
	strip_module "$ROOT/src/shared/Config/Crystals.luau"
	strip_module "$ROOT/src/shared/Config/Balance.luau"
	strip_module "$ROOT/src/shared/RarityMath.luau"
	strip_module "$ROOT/src/shared/Format.luau"
	cat "$DIR/mathtest.luau"
} > "$OUT/combined.luau"

"$LUAU" "$OUT/combined.luau"
