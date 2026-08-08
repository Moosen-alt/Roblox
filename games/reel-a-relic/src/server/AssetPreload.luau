--!strict
-- Loads every uploaded model into ReplicatedStorage, in the background, from
-- server start.
--
-- These are Model assets (see Shared/MeshAssets for why that is not a choice),
-- so `InsertService:LoadAsset` is the only way in. It is server-only, it yields,
-- and it hits the network per asset — none of which can happen at draw time on a
-- client. So it starts here, and everything downstream clones from the folder
-- this leaves behind.
--
-- NOTHING HERE MAY BLOCK THE CALLER. The first cut ran the whole batch before
-- MapBuilder, on the theory that building the map first would bake in primitive
-- fallbacks. What it actually did was hold the ground itself hostage: the map —
-- floor, spawn, everything — waited on 138 network round trips, and a player
-- joining a cold server fell through a world that did not exist yet. Falling
-- forever is worse than any fallback. The map goes up immediately; everything
-- that wants a mesh either defers on MeshAssets.OnReady or redraws when it
-- fires.
--
-- FAILURE IS LOUD. The whole reason this module exists is that a broken asset
-- pipeline looked identical to a working one for hours: every builder falls back
-- to a primitive, so the game keeps running and looking finished. If loading
-- fails now, the fallbacks still work — but the log says so plainly, with the
-- most likely cause, instead of leaving it to be discovered by eye.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MeshAssets = require(Shared.MeshAssets)
local Meshes = require(Shared.Config.Meshes)

local AssetPreload = {}

-- LoadAsset is a network round trip each. Serial would take minutes for a
-- hundred-plus assets; unbounded would have Roblox throttle us and fail some.
local CONCURRENCY = 8

type Entry = { Kind: string, Name: string, Id: number }

local function collect(): { Entry }
	local entries: { Entry } = {}
	local tables: { [string]: { [string]: Meshes.MeshDef } } = {
		Fish = Meshes.Fish,
		Relic = Meshes.Relic,
		Prop = Meshes.Prop,
		World = Meshes.World,
	}
	for kind, group in tables do
		for name, def in group do
			if def.Mesh and def.Mesh > 0 then
				table.insert(entries, { Kind = kind, Name = name, Id = def.Mesh })
			end
		end
	end
	return entries
end

-- What comes back from LoadAsset is a container holding the imported thing,
-- which may be a lone MeshPart or a Model of several. Normalise it to one
-- contract every builder can rely on — a Model centred on the world origin,
-- pivot at the origin with identity orientation — and strip anything that could
-- act on the world: decoration must never collide, block a raycast, or run a
-- script.
local function normalise(loaded: Model, key: string): Model?
	local model = Instance.new("Model")
	model.Name = key
	for _, child in loaded:GetChildren() do
		child.Parent = model
	end
	local parts = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
			parts += 1
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end
	if parts == 0 then
		model:Destroy()
		return nil
	end
	-- NO PrimaryPart, ever. A pivot that rides on a part sits wherever that
	-- part's author left it, and GetBoundingBox aligns itself to that part —
	-- which is how the first cut of this file buried every placed prop by its
	-- authored centre height. An explicit identity pivot, with the parts moved
	-- so their bounding box is centred on it, gives every clone the guarantee
	-- the primitive builders already provide: PivotTo(x) puts the middle of the
	-- visible thing at x, and GetBoundingBox stays axis-aligned.
	model.WorldPivot = CFrame.identity
	local box = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(box.Position)
	model:PivotTo(CFrame.identity)
	return model
end

-- Fire-and-forget. Creates the library folder NOW — synchronously, so OnReady
-- consumers and clients have something to wait on — and fills it from worker
-- threads. Returns immediately; Loaded flips on the folder when the batch is
-- done, and that flip is the one signal everything mesh-shaped listens for.
function AssetPreload.Start(): Folder
	local holder = Instance.new("Folder")
	holder.Name = MeshAssets.FOLDER
	holder.Parent = ReplicatedStorage

	local entries = collect()
	if #entries == 0 then
		holder:SetAttribute("Loaded", true)
		return holder
	end

	local next_ = 1
	local loaded, failed = 0, {}
	local firstError: string? = nil
	local active = 0
	local announced = false

	-- Loaded flips exactly once, whether the batch finishes or the watchdog
	-- gives up waiting for it. Announcing twice would be harmless for the
	-- attribute but would double every log line.
	local function announce(timedOut: boolean)
		if announced then
			return
		end
		announced = true
		if timedOut then
			warn(
				("[AssetPreload] Still loading after 120s; proceeding with %d/%d models. Stragglers keep filling the library."):format(
					loaded,
					#entries
				)
			)
		end
		holder:SetAttribute("Loaded", true)
		print(("[AssetPreload] %d/%d models loaded"):format(loaded, #entries))
		if #failed > 0 then
			warn(
				("[AssetPreload] %d model(s) failed to load; those fall back to primitives. First error: %s"):format(
					#failed,
					firstError or "?"
				)
			)
			if loaded == 0 then
				-- Every single one failing is not bad luck, it is a permission
				-- problem. LoadAsset can only reach assets the EXPERIENCE's owner
				-- owns, so group-owned models in a personally-owned place fail
				-- exactly like this, uniformly and silently.
				warn(
					"[AssetPreload] NOTHING loaded. LoadAsset can only fetch assets owned by the "
						.. "experience's owner — check the experience is owned by the same group the "
						.. "models were uploaded under, or re-upload them under the owning account."
				)
			end
		end
	end

	-- The WHOLE entry sits inside pcall — LoadAsset, normalise, parenting — so
	-- one malformed asset is one line in `failed`, never a dead worker whose
	-- missing `active -= 1` would leave Loaded unset forever.
	local function handle(entry: Entry): boolean
		local result = InsertService:LoadAsset(entry.Id)
		local model = normalise(result, MeshAssets.Key(entry.Kind, entry.Name))
		result:Destroy()
		if not model then
			return false
		end
		model.Parent = holder
		return true
	end

	local function worker()
		while true do
			local index = next_
			next_ += 1
			local entry = entries[index]
			if not entry then
				break
			end
			local ok, result = pcall(handle, entry)
			if ok and result == true then
				loaded += 1
			elseif ok then
				table.insert(failed, entry.Name .. " (no parts)")
			else
				table.insert(failed, entry.Name)
				if not firstError then
					firstError = tostring(result)
				end
			end
		end
	end

	for _ = 1, math.min(CONCURRENCY, #entries) do
		active += 1
		task.spawn(function()
			pcall(worker)
			active -= 1
			if active == 0 then
				announce(false)
			end
		end)
	end
	-- A hung LoadAsset must not leave Loaded unset forever — every deferred
	-- redraw in both games waits on that flip. Two minutes is far past any
	-- healthy batch.
	task.delay(120, function()
		if not announced then
			announce(true)
		end
	end)
	return holder
end

return AssetPreload
