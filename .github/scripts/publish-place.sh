#!/bin/bash
# Publish a built place file to Roblox via the Open Cloud Place Publishing API.
# Skips silently when the secrets for this game aren't configured yet.
# Usage: publish-place.sh <path/to/game.rbxlx>   (reads ROBLOX_API_KEY, UNIVERSE_ID, PLACE_ID)
set -euo pipefail

PLACE_FILE="$1"

if [ -z "${ROBLOX_API_KEY:-}" ] || [ -z "${UNIVERSE_ID:-}" ] || [ -z "${PLACE_ID:-}" ]; then
	echo "Roblox publish secrets not configured for this game - skipping auto-publish."
	exit 0
fi
if [ ! -f "$PLACE_FILE" ]; then
	echo "Place file not found: $PLACE_FILE"
	exit 1
fi

HTTP_CODE=$(curl -sS -o /tmp/publish-response.json -w "%{http_code}" -X POST \
	"https://apis.roblox.com/universes/v1/${UNIVERSE_ID}/places/${PLACE_ID}/versions?versionType=Published" \
	-H "x-api-key: ${ROBLOX_API_KEY}" \
	-H "Content-Type: application/xml" \
	--data-binary "@${PLACE_FILE}")

echo "HTTP ${HTTP_CODE}"
cat /tmp/publish-response.json
echo ""

if [ "${HTTP_CODE}" != "200" ]; then
	echo "Publish failed - check the API key scopes (universe-places: write, created under the GROUP), universe/place IDs, and that the key's IP restriction allows GitHub runners (use 0.0.0.0/0)."
	exit 1
fi
echo "Published ${PLACE_FILE} live to place ${PLACE_ID}."
