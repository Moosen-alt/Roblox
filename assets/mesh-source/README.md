# Mesh pack: Crack a Geode + Reel a Relic

OBJ source for every model that overrides a hand-built primitive, plus the
manifest that maps each one to its Roblox asset id.

- 33 Reel a Relic fish
- 28 Reel a Relic relics (6 deliberately unused — see below)
- 8 Crack a Geode crystals
- 2 Crack a Geode geode halves
- `asset_manifest.csv` — the source of truth for every uploaded asset id

Everything here was authored for this project. No third-party model geometry is
redistributed, so there is nothing to attribute; the one asset that does carry a
licence condition (a CC-BY geode) is credited in `src/shared/Config/Credits.luau`
and shown in-game.

Meshes are centred, normalised to a 1-unit maximum dimension and Y-up, with fish
authored nose-along +X. Start at `Scale = 1.0`, `Rotation = Vector3.zero`.

## Uploading

Run the **Upload meshes to Roblox** workflow from the Actions tab. It is manual
only — on every push it would fill the account with duplicates, and there is no
bulk delete.

    for each manifest row with a blank MeshId:
        OBJ --assimp--> FBX --Open Cloud--> asset id --> asset_manifest.csv
    tools/build-meshes.py  -->  the Meshes.luau override tables
    commit both

Start with `limit: 1` on a new batch to prove the pipeline before spending
moderation queue on seventy models. Re-running is safe: a row that already has an
id is skipped, so a failed run resumes instead of re-uploading.

Three states in the `MeshId` column, and they mean different things:

| value | meaning |
| --- | --- |
| blank | not uploaded yet; the primitive fallback is in use |
| `skip` | decided against — the hand-built primitive is better than the mesh |
| a number | uploaded; the mesh renders instead of the primitive |

`skip` is not a to-do. Six relics ship this way because their source meshes are
literal cubes and cylinders of 12–76 faces, which is worse than what the code
already draws.

## Why the manifest is guarded

An asset id is the only handle on an uploaded model. Uploading is **not
repeatable** — running the uploader again creates a *second* asset rather than
recovering the first — and Roblox offers no bulk delete and no search-by-name.
An id that falls out of this file is a model stranded on the account forever.

It is also damage that does not look like damage: a manifest with every `MeshId`
blank is a perfectly well-formed CSV. That combination nearly cost 67 ids once.
The upload workflow commits from CI, so a local `git pull --rebase` replays local
commits over it and the manifest conflicts on almost every row — and in a rebase
`--theirs` means *the commit being replayed*, which is the local, blank side. One
habitual command.

Three layers now stand between that and a loss, so no single one has to be
remembered:

1. **`tools/manifest-merge.py`** — a row-wise merge driver keyed on
   `(Game, Kind, ExactName)`. `blank < skip < a real id`, and a merge may only
   move a row up that ladder, whichever side the id is on and whichever
   direction the merge runs. Registered by `.gitattributes` + `tools/setup-git.sh`.
2. **`.githooks/pre-push`** — refuses a push that drops an id, while the fix is
   still local.
3. **`tests/check-manifest.py`** — in CI, and the reason the other two are
   conveniences rather than load-bearing. It compares the manifest against every
   id it has ever held in any commit on any branch, so it catches the loss
   however it happened.

Recovery is one command, not archaeology:

    python3 tests/check-manifest.py --repair

It recovers every id from git history and regenerates the Meshes.luau tables.

Run `sh tools/setup-git.sh` once per clone to install layers 1 and 2. Git will
not let a repository configure its own merge drivers or hooks — that would let a
clone run code on checkout — so that step cannot be automatic.
