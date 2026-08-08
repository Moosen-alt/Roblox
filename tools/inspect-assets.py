#!/usr/bin/env python3
"""Ask Roblox what our uploaded asset ids actually ARE.

Everything downstream of the upload assumed these ids are meshes, because that
is what SpecialMesh.MeshId needs. Nothing ever checked. The uploader asks for
`assetType: "Model"`, and a Model is a container — an .rbxm holding MeshParts —
whose id is not interchangeable with a mesh id. If that is what came back, then
every override in Meshes.luau points at something SpecialMesh cannot render, the
game falls back to primitives, and the result looks exactly like a pipeline that
never ran. Which is what it looks like.

This does not fix anything. It answers the one question that decides which fix
is the right one, using the only authority on it.

Runs in CI, not here: this container cannot reach apis.roblox.com.
"""
import csv
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "assets/mesh-source/asset_manifest.csv"
API = "https://apis.roblox.com/assets/v1/assets"


def main() -> int:
    key = os.environ.get("ROBLOX_API_KEY", "").strip()
    if not key:
        raise SystemExit("ROBLOX_API_KEY is not set")
    import requests

    rows = [
        row
        for row in csv.DictReader(MANIFEST.open(newline="", encoding="utf-8"))
        if (row["MeshId"] or "").strip().isdigit()
    ]
    # A spread across kinds and both games — enough to tell a systematic problem
    # from a one-off, without asking about all 138.
    wanted = ["Anchovy", "Megalodon", "Amethyst", "ChestBase", "GeodeHalfA", "Palm Tree", "Hero Crystal Cluster"]
    sample = [r for r in rows if r["ExactName"] in wanted]

    session = requests.Session()
    print(f"{'name':22} {'kind':8} {'id':17} -> assetType / state")
    for row in sample:
        response = session.get(
            f"{API}/{row['MeshId']}", headers={"x-api-key": key}, timeout=60
        )
        if response.status_code >= 300:
            print(f"{row['ExactName']:22} {row['Kind']:8} {row['MeshId']:17} -> HTTP {response.status_code}: {response.text[:160]}")
            continue
        body = response.json()
        kind = body.get("assetType", "?")
        state = (body.get("moderationResult") or {}).get("moderationState", "?")
        print(f"{row['ExactName']:22} {row['Kind']:8} {row['MeshId']:17} -> {kind} / {state}")
        if row["ExactName"] == wanted[0]:
            print("  full record for reference:")
            print("  " + json.dumps(body, indent=2)[:1200].replace("\n", "\n  "))
    return 0


if __name__ == "__main__":
    sys.exit(main())
