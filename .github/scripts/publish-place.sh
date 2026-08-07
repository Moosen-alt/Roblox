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

# 401/403 means the key exists but is not authorised for THIS universe. Open
# Cloud keys are scoped per-experience, so a key that publishes one game returns
# this for every other game until that experience is added to its access list.
# That is a console setting nobody has made yet - not a broken build - and
# failing the job for it would leave CI permanently red while the code is fine,
# which is the fastest way to make a red X stop meaning anything.
#
# So: warn loudly (annotation + run summary, both visible without opening logs)
# and let the job pass. Every other status stays fatal, so a key that breaks
# AFTER being wired up still fails the build.
if [ "${HTTP_CODE}" = "401" ] || [ "${HTTP_CODE}" = "403" ]; then
	MSG="Not published: the Open Cloud key is not authorised for universe ${UNIVERSE_ID}. Add this experience in Creator Hub -> Open Cloud -> API Keys -> edit the key -> Experience Operations, with universe-places:write."
	echo "::warning title=Roblox publish skipped (${PLACE_FILE})::${MSG}"
	if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
		echo "⚠️ **${PLACE_FILE}** — ${MSG}" >>"$GITHUB_STEP_SUMMARY"
	fi
	exit 0
fi

if [ "${HTTP_CODE}" != "200" ]; then
	echo "Publish failed - check the API key scopes (universe-places: write, created under the GROUP), universe/place IDs, and that the key's IP restriction allows GitHub runners (use 0.0.0.0/0)."
	exit 1
fi
echo "Published ${PLACE_FILE} live to place ${PLACE_ID}."
