# Models: the mesh pack and how it gets in

Everything in this game is built from Roblox primitives in code, which needs no
asset pipeline and has a hard ceiling: primitives read as *stylised*, never as
*sculpted*. This is the list for lifting that ceiling.

**A full pack of 69 original OBJ models already ships in
[`assets/mesh-source/`](../../assets/mesh-source/)** — 33 fish, 28 relics and the
geode game's 8 crystals, every name matching the configs exactly, normalised to a
1-unit maximum dimension, centred, Y-up, fish nose-along +X. Two ways to get them
into the game:

| | |
| --- | --- |
| **Automatic** | Run the **Upload meshes to Roblox** workflow (Actions tab). It converts, uploads via Open Cloud, records the asset ids and commits them. See below. |
| **By hand** | Studio → 3D Importer → save to Roblox → paste ids into the manifest → `python3 tools/build-meshes.py`. |

**Six relics are not worth uploading.** Spanish Emerald, Black Box and Tide Jewel
are 12 faces each — literally cubes — and Silver Doubloon, Cannery Token and Tiki
Idol are 64–76. The hand-built primitives they would replace have shaped, detailed
geometry, so swapping those is a downgrade. Leave their manifest rows blank.

The rest of this file is for sourcing *additional* models beyond the pack.

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


---

# Automatic upload (the Actions workflow)

## One-time setup

**Add `asset:write` to your Open Cloud key** — Creator Hub → Open Cloud → API
Keys → edit the key you already use for publishing → under **Asset Operations**,
add `write`, **for both groups**. Same key, one extra permission.

That is the only setup step. Each game already uploads under its own group:

| Game | Group |
| --- | --- |
| Crack a Geode | [346261815](https://www.roblox.com/communities/346261815/Crack-a-Geode) |
| Reel a Relic | [238904293](https://www.roblox.com/communities/238904293/Reel-a-Relic-Fishing-Simulator) |

Those are baked into `tools/upload-meshes.py` rather than kept as secrets,
because group ids are public — the number is in the community URL, exactly like
the universe and place ids already in `ci.yml`. Set `GEODE_GROUP_ID` /
`REEL_GROUP_ID` only to override, or `ROBLOX_USER_ID` if you ever move the games
to a personal account.

**The key must be authorised for both groups.** A key scoped to one will upload
that game's models and 403 on the other, which shows up as roughly half the run
failing — the fish going through and the crystals not, or vice versa.

## Running it

Actions tab → **Upload meshes to Roblox** → Run workflow.

- **`limit`** — how many to upload. **Leave it at `1` for the first run.** Prove
  the whole pipeline on one Anchovy before spending moderation queue on 69.
- **`only`** — optional name filter, e.g. `Anchovy`.

Once one works, re-run with `limit: 0` for everything remaining.

The workflow converts each OBJ to FBX with assimp, uploads it, polls until
Roblox returns an asset id, writes that id into the manifest, regenerates both
`Meshes.luau` files, validates them, and commits. The normal CI run then rebuilds
and republishes the places.

## Why it is safe to re-run

**Rows that already have a MeshId are skipped.** A run that dies halfway resumes
where it stopped rather than uploading everything a second time — which matters,
because there is no bulk delete and 69 orphaned duplicates would be
indistinguishable from the real ones. The manifest is written after *every*
success, not at the end, so a crash never loses ids you have already paid for.

Failed rows keep a blank MeshId and are simply retried next run.

## If it does not work first time

This is the one part of the pipeline built without being able to read Roblox's
documentation — every Roblox domain is blocked from the environment these tools
were written in, so the API contract is from memory and the workflow logs are the
only feedback loop. Expect it to need a round or two. The likely failure points,
in order:

1. **`asset:write` missing** → HTTP 401 or 403 on everything.
2. **Key not authorised for one group** → 403 on exactly that game's rows while
   the other game's succeed. Add the missing group to the key.
3. **FBX rejected** → assimp's output is not what Roblox wants. Fallback is
   Blender (`pip install bpy`) in place of assimp, which produces canonical FBX.
4. **Operation never completes** → moderation is slow; the row stays blank and
   the next run retries it. Not an error.

Paste the failing log and it can be fixed against real output rather than guessed
at twice.
