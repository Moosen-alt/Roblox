# Roblox mesh pack: Crack a Geode + Reel a Relic

This pack is aligned to the exact collectible names currently in the GitHub configuration.

Included:
- 33 Reel a Relic fish OBJ files
- 28 Reel a Relic relic OBJ files
- 8 Crack a Geode crystal OBJ files
- asset_manifest.csv for tracking Roblox MeshIds
- Meshes.template.luau with every exact Reel collectible name
- tools/build_meshes_luau.py to generate paste-ready Lua rows after upload
- verified source and license notes for CC0 replacement packs

## Reel a Relic import flow

1. Open Roblox Studio.
2. Use 3D Importer and select an OBJ from reel-a-relic/fish or reel-a-relic/relics.
3. Save the imported MeshPart to Roblox.
4. Copy the numeric MeshId.
5. Put that number in the matching row of asset_manifest.csv.
6. Run: python tools/build_meshes_luau.py
7. Copy the generated Fish and Relic tables into:
   games/reel-a-relic/src/shared/Config/Meshes.luau
8. Push and let CI validate/publish.

The included meshes are centered, normalized to a 1-unit maximum dimension, Y-up, and fish are
authored nose-along +X. Start at Scale = 1.0 and Rotation = Vector3.zero.

Leave a collectible absent from Meshes.luau until its real Roblox MeshId exists. The primitive
fallback continues to work, and check-models.py correctly rejects zero IDs.

## Crack a Geode

The root Geode game currently builds crystal visuals procedurally and does not yet have the same
per-collectible Meshes.luau override seam. The eight OBJ crystal files here are ready for 3D
Importer, but using them in-game requires adding a mesh override path similar to Reel a Relic.

## Included geometry

The OBJ files in this ZIP were procedurally authored for this project and contain no third-party
model geometry. The verified-sources folder includes license notes and direct options for
higher-detail replacements.

Current asset count: 69 OBJ files.
