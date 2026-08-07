# Model shopping list

Everything in this game is built from Roblox primitives in code, which needs no
asset pipeline and has a hard ceiling: primitives read as *stylised*, never as
*sculpted*. This is the list for lifting that ceiling.

**Start in Studio → View → Toolbox → Creator Store.** Not the external model
sites. Two reasons, and both are practical rather than pedantic:

- **Licensing is already handled.** Creator Store assets are licensed for Roblox
  use by construction. Uploading a model from Sketchfab or CGTrader is
  *redistribution*, most free-tier licences there don't permit it, and a takedown
  strike lands on the account — which would take all three games down, not one.
- **There's no upload step.** Insert it and it's in your place with an asset ID
  already minted. No 3D Importer, no moderation wait.

Poly Haven (CC0) and NASA (public domain) are the safe external options if you
want something the Creator Store doesn't have. Everything else on the list you
sent needs its licence checked per model.

---

## The big shortcut: one mesh serves a whole family

**Don't buy 33 fish.** `Config/Meshes.luau` lets several species point at the
same asset ID with different `Scale` — and each species already carries its own
colour from `Crystals.luau`, so one shark mesh becomes five recognisably
different sharks for free.

That takes the job from 33 models to about **15**, and the first six are 80% of
what a player actually sees.

### Tier 1 — do these six first

These cover every species in the first two areas plus both landmark fish, which
is what a new player looks at for their entire first session.

| Search the Creator Store for | Covers | How |
| --- | --- | --- |
| `fish low poly` / `bass fish` | Sea Bass, Kelp Bass, Red Snapper, Giant Sea Bass, Sheephead | one bass body, 5 scales/colours |
| `small fish` / `sardine` | Anchovy, Mackerel, Lanternfish | scale 0.6–1.0 |
| `shark low poly` | Leopard Shark, Reef Shark, Goblin Shark, Megalodon | Megalodon at ~2× the rest |
| `tropical fish` / `clownfish` | Clownfish, Blue Tang, Garibaldi, Parrotfish | disc-shaped reef body |
| `eel` / `sea serpent` | Moray Eel, Gulper Eel, Oarfish, Frilled Shark | Oarfish long and thin |
| `seahorse` | Seahorse | — |

### Tier 2 — the ones that need their own shape

Each of these is a silhouette no other mesh can stand in for. Worth doing, but
after Tier 1.

| Search for | Covers |
| --- | --- |
| `hammerhead shark` | Hammerhead |
| `manta ray` / `stingray` | Manta Ray |
| `anglerfish` | Anglerfish |
| `squid` / `kraken` | Colossal Squid |
| `octopus` | Dumbo Octopus |
| `flounder` / `flatfish` | Flounder |
| `sailfish` / `marlin` / `swordfish` | Sailfish |
| `isopod` / `woodlouse` / `trilobite` | Giant Isopod |
| `deep sea fish` | Hatchetfish, Viperfish, Barreleye |

### Relics: mostly leave them

The 28 relics are already the strongest models in the game — a bottle looks like
a bottle, a diving helmet looks like a diving helmet. Only replace one if it
specifically bothers you. If you do want a few, these gain the most from a real
mesh: `treasure chest`, `anchor`, `crown`, `trident`, `katana` (Oni Mask),
`temple bell`.

---

## Wiring them in

1. Insert everything from the Creator Store in one go. They land in Workspace.
2. **Rename each one to the exact species name** from `Config/Crystals.luau` —
   `Leopard Shark`, `Manta Ray`, `Anchovy`. Exact, including apostrophes.
3. Select them all in the Explorer.
4. **View → Command Bar**, paste [`tools/studio-mesh-ids.luau`](../../tools/studio-mesh-ids.luau),
   press Enter.

It prints ready-to-paste config rows with the asset ID and a scale derived from
each model's actual size:

```lua
	["Leopard Shark"] = { Mesh = 1234567890, Scale = 0.42 },
	["Reef Shark"]    = { Mesh = 1234567890, Scale = 0.40 },
	["Megalodon"]     = { Mesh = 1234567890, Scale = 0.95 },
```

Paste into `src/shared/Config/Meshes.luau` and push. CI republishes
automatically. Anything without an entry keeps its primitive model, so you can
do this six fish at a time and never have a broken build in between.

## Tuning

- **Wrong size** → adjust `Scale`. The script's number is a starting point taken
  from the model's own bounding box.
- **Facing the wrong way** → add `Rotation` (degrees, X then Y then Z). The game
  builds fish nose-along-**+X**, upright. Blender exports are usually Z-up:
  `Rotation = Vector3.new(-90, 0, 0)`. Facing backwards: `Vector3.new(0, 180, 0)`.
- **Sitting too high or low in the tank** → `Offset`.
- **Wrong colour** → leave `Texture` out and the mesh is tinted with the species
  colour, so auras still work. Set `Texture` only if the model's own texture is
  better than the tint.

## What CI checks

`tests/check-models.py` fails the build if a mesh entry names a species that
doesn't exist, or has an asset ID of 0. Both failures are otherwise **silent in
game** — a typo'd name means the override never applies and the primitive keeps
rendering, which looks exactly like a failed upload rather than a typo.

## Picking well

- **Low-poly beats realistic.** It matches the rest of the game, loads faster on
  phones, and a photoreal trout next to a blocky dock looks worse than a stylised
  one, not better.
- **Check the Explorer before inserting.** A model built from plain Parts has no
  mesh in it and can't be used here — the script will tell you, but it's faster
  to spot up front.
- **Under ~2k triangles each.** A tank holds eight at once and the Index can draw
  hundreds.
- **One style across the set.** Six fish from one creator's pack will always look
  better together than twelve from twelve creators.
