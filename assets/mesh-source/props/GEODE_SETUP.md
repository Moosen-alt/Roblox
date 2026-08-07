# Blue Agate Geode: Roblox crack-animation version

I inspected the uploaded model before modifying it.

## What the original actually is
The downloaded asset is already ONE OPEN GEODE HALF, not a complete closed rock.
That is ideal for this animation. Instead of cutting through the crystal geometry, this pack
uses that detailed half twice:

- `Geode_Half_A.obj` keeps the original open-face orientation.
- `Geode_Half_B.obj` is a 180-degree opposing half.
- Put them face-to-face to make the closed geode.
- During the crack animation, separate/rotate them to reveal the crystal surfaces.

This avoids ugly cut faces and preserves all the authored crystal detail and UV mapping.

## Files

### Import these for the actual game
- `Geode_Half_A.obj`
- `Geode_Half_B.obj`
- `geode_materials.mtl`
- `textures/`

### Reference poses
- `Geode_Closed_Assembly.obj`
- `Geode_Open_Assembly.obj`

The assembly files are previews/reference models. Whether Roblox Studio preserves both OBJ objects
as separate MeshParts depends on the importer path/version. The safest animation workflow is to
import A and B individually.

### Animation helper
- `GeodeCrackAnimation.luau`

## Roblox Studio setup

1. Import `Geode_Half_A.obj`.
2. Import `Geode_Half_B.obj`.
3. Name the imported objects/models:
   - `LeftHalf`
   - `RightHalf`
4. Put both under a Model named `GeodeModel`.
5. Arrange them face-to-face like `Geode_Closed_Assembly.obj`.
6. Anchor every MeshPart.
7. Put `GeodeCrackAnimation.luau` in ReplicatedStorage or your shared modules.
8. Call:
   `require(path.To.GeodeCrackAnimation).Crack(GeodeModel)`

The converted halves are scaled to about 4.45 units across so they are easier to work with in
a Roblox-sized reveal scene. Adjust final Studio scale to taste.

## PBR maps

Outer stone:
- ColorMap: `textures/Outer_Color.png`
- NormalMap: `textures/Outer_Normal.png`
- RoughnessMap: `textures/Outer_Roughness.png`
- MetalnessMap: `textures/Stone_Metalness.png`

Inner crystal:
- ColorMap: `textures/Inner_Color.png`
- NormalMap: `textures/Inner_Normal.png`
- RoughnessMap: `textures/Inner_Roughness.png`
- MetalnessMap: `textures/Stone_Metalness.png`

`Inner_Emissive.png` is also included from the source material. Roblox SurfaceAppearance does not
provide a conventional emissive-map slot, so use it as reference for a glow treatment, or add a
PointLight/Highlight/particle flash during the crack.

## Good animation timing for Crack a Geode!

0.00s - 0.18s: shake
0.18s: crack flash / sound
0.18s - 0.70s: halves burst apart
0.35s: crystal light blooms
0.55s: rarity card begins appearing
0.70s+: collectible reveal settles

For a stronger "chest" feeling, keep Half A mostly facing the camera and make Half B do most of
the outward kick/rotation.
