#!/usr/bin/env python3
"""Upload the mesh pack to Roblox via Open Cloud, and record the asset ids.

Runs in GitHub Actions, not locally: this container cannot reach any Roblox
domain (403 at the egress gateway), while the runners can — that is already how
CI publishes the place files.

WHAT IT DOES

    for each manifest row with no MeshId yet:
        assets/mesh-source/<file>.obj  --assimp-->  .fbx
        POST /assets/v1/assets  (multipart: request JSON + fileContent)
        poll the returned operation until it yields an assetId
        write that id back into asset_manifest.csv

Then tools/build-meshes.py turns the filled manifest into the Meshes.luau
tables, and the workflow commits both.

IDEMPOTENT BY DESIGN. A row that already has a MeshId is skipped, so re-running
after a partial failure resumes rather than creating duplicate assets. That
matters more than it sounds: a re-run that uploaded everything again would leave
69 orphans on the account with no way to tell them apart.

--limit exists so the first run can be a single file. Prove the pipeline end to
end on one Anchovy before spending moderation queue on 69.
"""
import argparse
import csv
import json
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "assets/mesh-source/asset_manifest.csv"
SOURCE = ROOT / "assets/mesh-source"

API = "https://apis.roblox.com/assets/v1"
# Moderation is asynchronous. Most models clear in seconds; give up after this
# and leave the row blank so the next run retries it rather than recording junk.
POLL_ATTEMPTS = 30
POLL_SECONDS = 2


def convert_to_fbx(obj: Path, out_dir: Path) -> Path:
    """Open Cloud takes FBX for Model assets; the pack ships OBJ."""
    fbx = out_dir / (obj.stem + ".fbx")
    result = subprocess.run(
        ["assimp", "export", str(obj), str(fbx)],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0 or not fbx.exists():
        raise RuntimeError(f"assimp failed for {obj.name}: {result.stderr.strip()[:300]}")
    return fbx


# PER-GAME CREATORS. The two games live in two different groups, so a single
# creator id would file every fish under whichever group happened to be set —
# and an asset created under the wrong group is not usable by the other game's
# experience without moving it, which Open Cloud cannot do.
#
# Group ids are public (they are the number in the community URL), exactly like
# the universe and place ids already in ci.yml, so they are defaults here rather
# than secrets. An env var still overrides, for a group that changes later.
GROUPS = {
    # https://www.roblox.com/communities/346261815/Crack-a-Geode
    "Crack a Geode": "346261815",
    # https://www.roblox.com/communities/238904293/Reel-a-Relic-Fishing-Simulator
    "Reel a Relic": "238904293",
}
ENV_OVERRIDE = {
    "Crack a Geode": "GEODE_GROUP_ID",
    "Reel a Relic": "REEL_GROUP_ID",
}


def creation_context(game: str) -> dict:
    """Who the asset is created under, for this row's game.

    ROBLOX_USER_ID overrides everything, for the case where the games are on a
    personal account instead of in groups.
    """
    user = os.environ.get("ROBLOX_USER_ID", "").strip()
    if user:
        return {"creator": {"userId": user}}
    group = os.environ.get(ENV_OVERRIDE.get(game, ""), "").strip() or GROUPS.get(game, "")
    if group:
        return {"creator": {"groupId": group}}
    raise SystemExit(
        f"No creator for {game!r}. Add it to GROUPS, set {ENV_OVERRIDE.get(game, 'a group env var')}, "
        f"or set ROBLOX_USER_ID for a personal account."
    )


def upload(session, key: str, fbx: Path, display_name: str, game: str) -> str:
    request = {
        "assetType": "Model",
        "displayName": display_name,
        "description": f"Model for {game}.",
        **creation_context(game),
    }
    with fbx.open("rb") as handle:
        response = session.post(
            f"{API}/assets",
            headers={"x-api-key": key},
            data={"request": json.dumps(request)},
            files={"fileContent": (fbx.name, handle, "model/fbx")},
            timeout=120,
        )
    if response.status_code >= 300:
        raise RuntimeError(f"upload HTTP {response.status_code}: {response.text[:400]}")

    body = response.json()
    # Some responses hand back the asset directly; most hand back an operation.
    if body.get("assetId"):
        return str(body["assetId"])
    path = body.get("path") or body.get("operationId")
    if not path:
        raise RuntimeError(f"no operation in response: {json.dumps(body)[:400]}")
    operation = path.rsplit("/", 1)[-1]

    for _ in range(POLL_ATTEMPTS):
        time.sleep(POLL_SECONDS)
        poll = session.get(
            f"{API}/operations/{operation}", headers={"x-api-key": key}, timeout=60
        )
        if poll.status_code >= 300:
            raise RuntimeError(f"poll HTTP {poll.status_code}: {poll.text[:300]}")
        data = poll.json()
        if data.get("done"):
            asset_id = (data.get("response") or {}).get("assetId")
            if not asset_id:
                raise RuntimeError(f"operation finished with no assetId: {json.dumps(data)[:400]}")
            return str(asset_id)
    raise TimeoutError("operation still pending after polling; will retry next run")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=0, help="stop after N uploads (0 = all)")
    parser.add_argument("--only", default="", help="substring filter on ExactName")
    args = parser.parse_args()

    key = os.environ.get("ROBLOX_API_KEY", "").strip()
    if not key:
        raise SystemExit("ROBLOX_API_KEY is not set")

    import requests  # installed by the workflow

    rows = list(csv.DictReader(MANIFEST.open(newline="", encoding="utf-8")))
    fields = list(rows[0].keys())
    work = [
        r
        for r in rows
        if not (r["MeshId"] or "").strip()
        and (not args.only or args.only.lower() in r["ExactName"].lower())
    ]
    if args.limit:
        work = work[: args.limit]

    for game in sorted({r["Game"] for r in work}):
        context = creation_context(game)["creator"]
        who = f"group {context['groupId']}" if "groupId" in context else f"user {context['userId']}"
        print(f"  {game} -> {who}")
    print(f"{len(rows)} rows, {len(work)} to upload this run")
    if not work:
        print("nothing to do — every targeted row already has a MeshId")
        return 0

    tmp = Path("/tmp/fbx")
    tmp.mkdir(exist_ok=True)
    session = requests.Session()

    uploaded, failed = 0, []
    for row in work:
        name = row["ExactName"]
        obj = SOURCE / row["LocalFile"]
        try:
            fbx = convert_to_fbx(obj, tmp)
            asset_id = upload(session, key, fbx, name, row["Game"])
        except Exception as error:  # noqa: BLE001 — one bad model must not stop the rest
            print(f"  FAIL {name}: {error}")
            failed.append(name)
            continue
        row["MeshId"] = asset_id
        uploaded += 1
        print(f"  ok   {name:24} -> {asset_id}")
        # Write after every success. A run that dies halfway must not lose the
        # ids it already paid for.
        writer = csv.DictWriter(MANIFEST.open("w", newline="", encoding="utf-8"), fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)

    print(f"\nuploaded {uploaded}, failed {len(failed)}")
    if failed:
        print("failed rows keep a blank MeshId and will be retried on the next run:")
        for name in failed:
            print(f"  - {name}")
    # A partial run is a success: the next run resumes. Only a run that achieved
    # nothing at all is worth failing the job over.
    return 0 if uploaded or not work else 1


if __name__ == "__main__":
    sys.exit(main())
