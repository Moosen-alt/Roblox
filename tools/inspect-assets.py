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
    creators = set()
    print(f"{'name':22} {'kind':8} {'id':17} -> assetType / state / creator")
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
        creator = (body.get("creationContext") or {}).get("creator") or {}
        owner = (
            f"group {creator['groupId']}" if creator.get("groupId")
            else f"user {creator.get('userId', '?')}"
        )
        creators.add(owner)
        print(f"{row['ExactName']:22} {row['Kind']:8} {row['MeshId']:17} -> {kind} / {state} / {owner}")

    # THE OWNERSHIP QUESTION. InsertService:LoadAsset only loads assets owned by
    # the EXPERIENCE's owner. The mining game demonstrably loads these models and
    # the fishing game demonstrably does not, and the one difference that can do
    # that silently is the two universes having different owners. games.roblox.com
    # is public and needs no key.
    print()
    print("universe owners (must match the asset creator above for LoadAsset to work):")
    for label, env in (("Crack a Geode", "GEODE_UNIVERSE_ID"), ("Reel a Relic", "REEL_UNIVERSE_ID")):
        universe = os.environ.get(env, "").strip()
        if not universe:
            print(f"  {label:14} -> {env} not provided; skipped")
            continue
        response = session.get(
            "https://games.roblox.com/v1/games", params={"universeIds": universe}, timeout=60
        )
        data = (response.json().get("data") or [None])[0] if response.status_code < 300 else None
        if not data:
            print(f"  {label:14} -> lookup failed: HTTP {response.status_code} {response.text[:120]}")
            continue
        creator = data.get("creator") or {}
        owner = f"{str(creator.get('type', '?')).lower()} {creator.get('id', '?')} ({creator.get('name', '?')})"
        verdict = (
            "MATCHES asset creator"
            if any(owner.startswith(o + " ") for o in creators)
            else "DOES NOT MATCH -> LoadAsset returns nothing in this game"
        )
        print(f"  {label:14} -> {owner}  [{verdict}]")
    return 0


if __name__ == "__main__":
    sys.exit(main())
