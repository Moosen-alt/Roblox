--!strict
-- The uploaded models, loaded once and cloned from ReplicatedStorage.
--
-- WHY NOT SpecialMesh.MeshId, WHICH IS WHAT EVERY BUILDER USED TO DO.
--
-- Open Cloud has no "Mesh" asset type. Uploading a 3D file — OBJ, FBX, anything
-- — always produces a **Model**: a container holding MeshParts, with its own
-- asset id. `SpecialMesh.MeshId` needs a *mesh* id, and the two are not
-- interchangeable. Point it at a Model id and it renders nothing at all.
--
-- That was the state of this project for a while and it was invisible from the
-- outside. The uploads succeeded, the ids came back, moderation approved them,
-- the manifest filled in, the generated config referenced them, CI went green
-- and the published places contained every id — and both games quietly drew
-- primitives, because every builder here falls back to a primitive when the
-- mesh is unavailable. Every check ran upstream of the one thing that mattered.
--
-- A Model asset can only be brought in with `InsertService:LoadAsset`, which is
-- server-only and yields. Most of what needs these is on the client — viewport
-- previews, the reveal, the cavern dressing — so loading on demand is not an
-- option. Instead the server loads each asset ONCE into a folder under
-- ReplicatedStorage, and everything afterwards clones from that folder: server,
-- client, and inside a ViewportFrame, with no yielding and no per-use cost.
--
-- Absent entry = fall back to the primitive, exactly as before. A model still in
-- moderation, or one the game has no permission to load, must never take the
-- game down with it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeshAssets = {}

MeshAssets.FOLDER = "MeshAssets"

-- THE ROLLOUT SWITCH. false = the game renders entirely from its primitive
-- builders, exactly as it did before the mesh pack existed — that is the point
-- of every builder having a fallback. The first attempt at turning the pack on
-- shipped every defect at once — buried props, boulders on the shops, a chest
-- facing away from its own camera — because nothing could be seen in isolation
-- before it was live. Turn this back on deliberately: one kind at a time,
-- looked at in Studio or a test server first, not by pushing and hoping.
MeshAssets.ENABLED = true

-- Kind and name, flattened, because "Prop/ChestBase" and "World/ChestBase" are
-- allowed to be different things.
function MeshAssets.Key(kind: string, name: string): string
	return kind .. "/" .. name
end

local cached: Folder? = nil

local function folder(): Folder?
	if cached and cached.Parent then
		return cached
	end
	cached = ReplicatedStorage:FindFirstChild(MeshAssets.FOLDER) :: Folder?
	return cached
end

-- A fresh copy of the loaded model, or nil if it is not there.
--
-- Never returns the stored original: callers parent what they get into the
-- world, and handing out the template would empty the library on first use.
function MeshAssets.Clone(kind: string, name: string): Model?
	if not MeshAssets.ENABLED then
		return nil
	end
	local holder = folder()
	if not holder then
		return nil
	end
	local template = holder:FindFirstChild(MeshAssets.Key(kind, name))
	if not template or not template:IsA("Model") then
		return nil
	end
	return template:Clone()
end

-- Clients must not draw from the library before it is ready, and "ready" means
-- the server has finished its whole batch, not merely that the folder has
-- replicated. The server sets Loaded exactly once, after every load has been
-- attempted; this runs `callback` (on a fresh thread) at that moment, or
-- immediately if it has already passed. Event-driven on purpose — the previous
-- timed wait returned the folder on timeout exactly as it did on success, so a
-- server slower than the guess quietly froze every caller's fallback in place
-- for the session.
function MeshAssets.OnReady(callback: () -> ())
	task.spawn(function()
		local holder = ReplicatedStorage:WaitForChild(MeshAssets.FOLDER, math.huge) :: Folder
		while not holder:GetAttribute("Loaded") do
			holder:GetAttributeChangedSignal("Loaded"):Wait()
		end
		callback()
	end)
end

return MeshAssets
