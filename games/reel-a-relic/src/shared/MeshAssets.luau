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

function MeshAssets.Has(kind: string, name: string): boolean
	local holder = folder()
	return holder ~= nil and holder:FindFirstChild(MeshAssets.Key(kind, name)) ~= nil
end

-- Clients need to know when the library exists before they draw anything from
-- it. The server sets Loaded once, after the whole batch has been attempted.
function MeshAssets.WaitForLibrary(timeout: number): Folder?
	local holder = ReplicatedStorage:WaitForChild(MeshAssets.FOLDER, timeout) :: Folder?
	if not holder then
		return nil
	end
	local deadline = os.clock() + timeout
	while not holder:GetAttribute("Loaded") and os.clock() < deadline do
		task.wait(0.1)
	end
	return holder
end

return MeshAssets
