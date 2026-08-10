--!nocheck
-- Runs inside the published place via tools/luau-exec.py, and answers the
-- question the library diagnostic cannot: does the LIVE boot path actually put
-- decoration in the world, and does what it places end up somewhere a player
-- can see?
--
-- diagnose-library.luau proved every asset LOADS by calling InsertService
-- directly — its own calls, not the game's. Between "the asset loads" and "a
-- player sees a prop" sits the entire real pipeline: AssetPreload's worker
-- pool, the Loaded flip, every OnReady deferral, WorldBuild's grounding
-- arithmetic and the placement plans. Any link can fail silently, because by
-- design every failure falls back to bare procedural terrain. So this runs the
-- server's actual boot sequence — the same requires init.server.luau makes —
-- and then measures the world it produced.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local report = { placeId = game.PlaceId, steps = {} }
local function step(message)
	table.insert(report.steps, message)
end

local ok, err = pcall(function()
	local server = ServerScriptService:WaitForChild("Server", 10)
	local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
	local MeshAssets = require(Shared.MeshAssets)
	local Meshes = require(Shared.Config.Meshes)

	-- FIRST RUN'S LESSON: game scripts DO execute in a Luau task — the server
	-- boots exactly as it does for a player, so by the time this script runs
	-- the world is usually already built. Running the boot sequence again on
	-- top of that produced a perfect 2x of every count, identical positions and
	-- all, because the map rng is deterministic. So: only boot what the game
	-- demonstrably has not booted, and otherwise audit what is already there —
	-- which is the more honest measurement anyway, being the game's own work
	-- rather than this script's.
	if not Workspace:FindFirstChild("GeneratedMap") and not ReplicatedStorage:FindFirstChild(MeshAssets.FOLDER) then
		local AssetPreload = require(server.AssetPreload)
		local Remotes = require(Shared.Remotes)
		pcall(function()
			Remotes.Init()
		end)
		AssetPreload.Start()
		local MapBuilder = require(server.MapBuilder)
		MapBuilder.Build()
		step("game had not booted; ran the boot sequence here")
	else
		step("auditing the world the game itself built")
	end
	step("ENABLED = " .. tostring(MeshAssets.ENABLED))

	-- Wait for the library the way clients do, then give the deferred OnReady
	-- builds a moment to actually parent their models.
	local holder = ReplicatedStorage:WaitForChild(MeshAssets.FOLDER, 30)
	local deadline = os.clock() + 150
	while holder and not holder:GetAttribute("Loaded") and os.clock() < deadline do
		task.wait(1)
	end
	task.wait(3)
	report.libraryLoaded = holder and holder:GetAttribute("Loaded") or false
	report.libraryCount = holder and #holder:GetChildren() or 0
	step(("library: Loaded=%s, %d templates"):format(tostring(report.libraryLoaded), report.libraryCount))

	-- Every name the config could place, so placed models can be recognised
	-- wherever they were parented.
	local worldNames = {}
	for name in Meshes.World do
		worldNames[name] = true
	end

	-- What is actually IN the world now?
	local placed = {}
	local total = 0
	local aboveWater, buried = 0, 0
	local biggest = {}
	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("Model") and worldNames[descendant.Name] then
			total += 1
			placed[descendant.Name] = (placed[descendant.Name] or 0) + 1
			local box, size = descendant:GetBoundingBox()
			local top = box.Position.Y + size.Y / 2
			local bottom = box.Position.Y - size.Y / 2
			-- Water surface sits at about -0.2 in reel; the geode floor at 0.
			if top > 0.3 then
				aboveWater += 1
			end
			if top < -1 then
				buried += 1
			end
			table.insert(biggest, {
				name = descendant.Name,
				size = math.floor(math.max(size.X, size.Y, size.Z) * 10) / 10,
				at = ("%.0f, %.0f, %.0f"):format(box.Position.X, box.Position.Y, box.Position.Z),
				top = math.floor(top * 10) / 10,
				bottom = math.floor(bottom * 10) / 10,
			})
		end
	end
	table.sort(biggest, function(a, b)
		return a.size > b.size
	end)
	report.placedTotal = total
	report.placedByName = placed
	report.visiblyAboveWaterline = aboveWater
	report.entirelyBelowMinusOne = buried
	report.largestTen = { table.unpack(biggest, 1, math.min(10, #biggest)) }

	-- Near-spawn visibility: how much decoration is within sight of where a
	-- player actually stands when they join?
	local spawnAt = Vector3.new(0, 2, -40)
	local spawnLocation = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawnLocation then
		spawnAt = spawnLocation.Position
	end
	local near = 0
	for _, entry in biggest do
		local parts = string.split(entry.at, ",")
		local at = Vector3.new(tonumber(parts[1]) or 0, 0, tonumber(parts[3]) or 0)
		if (Vector3.new(spawnAt.X, 0, spawnAt.Z) - at).Magnitude < 90 then
			near += 1
		end
	end
	report.within90StudsOfSpawn = near
	step(("placed %d world props; %d near spawn"):format(total, near))
end)

if not ok then
	report.fatal = tostring(err)
end

local blob = HttpService:JSONEncode(report)
local SLICE = 6000
local totalSlices = math.ceil(#blob / SLICE)
for index = 1, totalSlices do
	print(("JSON[%d/%d]%s"):format(index, totalSlices, blob:sub((index - 1) * SLICE + 1, index * SLICE)))
end
