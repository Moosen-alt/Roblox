--!strict
-- The cavern re-dresses itself for the layer you are on.
--
-- WHY THIS IS ON THE CLIENT. Layer is per-player here — it is your rebirth
-- count, not a place you walk to — so two players standing next to each other
-- are legitimately on different layers. The room is shared and the progression
-- is not, and a server-built theme would have to pick one player to be right
-- for. Building the dressing locally lets everyone see their own depth in the
-- same cavern, costs the server nothing, and replicates nothing.
--
-- It also means this is decoration and only decoration. Nothing here collides,
-- nothing answers a raycast, nothing is a click target, and the geometry that
-- the game actually runs on — the wall, the nodes, the stations — is built by
-- the server and untouched. If every mesh in the pack were missing, the cavern
-- would look exactly as it did before, which is the point of doing it this way.
--
-- LAYOUT. Everything sits in the flanks, the back corners and the ceiling. The
-- middle of the room is the walk between the wall and the four stations, and
-- set dressing standing in a walkway reads as clutter even when you can pass
-- straight through it.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldBuild = require(Shared.WorldBuild)
local MeshAssets = require(Shared.MeshAssets)
local State = require(script.Parent.State)

local CaveDecor = {}

type PropPlan = {
	Name: string,
	Count: number,
	Min: number,
	Max: number,
	Zone: string, -- Flank | Back | Front | Ceiling | Float | Hero
	-- Min/Max mean HEIGHT unless this says "Span", in which case they mean the
	-- longest horizontal dimension. Bridges and ceiling strips are defined by
	-- how far they reach, not by how tall they are, and sizing them by height
	-- makes them hundreds of studs long — wider than the cavern they sit in.
	Fit: string?,
	Glow: number?,
}

-- The five authored layers, each dressed out of its own set. These are the same
-- names as Balance.LayerNames, in the same order, because that is what the
-- player sees on the rebirth screen when they arrive.
local LAYER_THEMES: { { PropPlan } } = {
	{ -- 1 Crystal Cavern — where everyone starts. Bright, and the only layer
		-- that gets a true hero piece, so the first room reads as the good one.
		{ Name = "Hero Crystal Cluster", Count = 1, Min = 24, Max = 24, Zone = "Hero", Glow = 40 },
		{ Name = "Crystal Arch", Count = 6, Min = 15, Max = 21, Zone = "Back" },
		{ Name = "Stalagmite Cluster", Count = 14, Min = 6, Max = 13, Zone = "Flank" },
		{ Name = "Cave Boulder A", Count = 12, Min = 5, Max = 10, Zone = "Flank" },
		{ Name = "Cave Boulder B", Count = 10, Min = 5, Max = 11, Zone = "Front" },
		{ Name = "Floating Crystal Ring", Count = 7, Min = 8, Max = 12, Zone = "Float", Glow = 26 },
	},
	{ -- 2 Amber Depths — a worked-out mine. Timber and warm stone.
		{ Name = "Amber Pillar", Count = 8, Min = 16, Max = 26, Zone = "Back" },
		{ Name = "Ruined Stone Arch", Count = 6, Min = 14, Max = 20, Zone = "Back" },
		{ Name = "Old Mine Support", Count = 14, Min = 10, Max = 15, Zone = "Flank" },
		{ Name = "Mine Boulder", Count = 13, Min = 4, Max = 9, Zone = "Flank" },
		{ Name = "Broken Plank Bridge", Count = 4, Min = 26, Max = 34, Zone = "Front", Fit = "Span" },
		{ Name = "Amber Cluster", Count = 10, Min = 5, Max = 9, Zone = "Float", Glow = 24 },
	},
	{ -- 3 Frost Hollow — the first layer that is actively hostile. Ice above.
		{ Name = "Frozen Pillar", Count = 8, Min = 18, Max = 28, Zone = "Back" },
		{ Name = "Frozen Arch", Count = 6, Min = 14, Max = 20, Zone = "Back" },
		{ Name = "Ice Spire Cluster", Count = 14, Min = 8, Max = 16, Zone = "Flank" },
		{ Name = "Frost Boulder", Count = 12, Min = 4, Max = 9, Zone = "Flank" },
		{ Name = "Icicle Ceiling Strip", Count = 16, Min = 14, Max = 24, Zone = "Ceiling", Fit = "Span" },
		{ Name = "Ice Crystal Cluster", Count = 10, Min = 5, Max = 9, Zone = "Float", Glow = 22 },
	},
	{ -- 4 Ember Rift — heat. Everything glows from below rather than above.
		{ Name = "Basalt Gate", Count = 4, Min = 18, Max = 24, Zone = "Back" },
		{ Name = "Basalt Spire Cluster", Count = 14, Min = 9, Max = 18, Zone = "Flank" },
		{ Name = "Lava Fissure Rock", Count = 13, Min = 4, Max = 9, Zone = "Flank", Glow = 18 },
		{ Name = "Hydrothermal Vent", Count = 9, Min = 7, Max = 12, Zone = "Front", Glow = 20 },
		{ Name = "Broken Rift Bridge", Count = 4, Min = 26, Max = 34, Zone = "Front", Fit = "Span" },
		{ Name = "Ember Crystal Cluster", Count = 10, Min = 5, Max = 9, Zone = "Float", Glow = 26 },
	},
	{ -- 5 Starfall Core — the end of the authored run, so it gets to be strange.
		{ Name = "Star Monolith", Count = 5, Min = 20, Max = 30, Zone = "Back", Glow = 24 },
		{ Name = "Star Pillar", Count = 8, Min = 16, Max = 26, Zone = "Back" },
		{ Name = "Meteor Chunk A", Count = 12, Min = 5, Max = 11, Zone = "Flank" },
		{ Name = "Meteor Chunk B", Count = 11, Min = 5, Max = 11, Zone = "Front" },
		{ Name = "Cosmic Ring", Count = 5, Min = 12, Max = 18, Zone = "Float", Glow = 30 },
		{ Name = "Prismatic Core Cluster", Count = 10, Min = 6, Max = 10, Zone = "Float", Glow = 30 },
	},
}

-- Layers 6 to 25 have generated names and no authored art, so they are dressed
-- from a shared remix set. Picking from it by layer number rather than at random
-- means layer 11 always looks like layer 11 — you can tell how deep you are by
-- looking, and rejoining does not reshuffle the room.
local REMIX: { PropPlan } = {
	{ Name = "Shattered Monolith", Count = 6, Min = 20, Max = 30, Zone = "Back" },
	{ Name = "Drowned Pillar", Count = 8, Min = 16, Max = 26, Zone = "Back" },
	{ Name = "Ashen Gate", Count = 4, Min = 18, Max = 24, Zone = "Back" },
	{ Name = "Cinder Spires", Count = 14, Min = 9, Max = 18, Zone = "Flank" },
	{ Name = "Glacier Shards", Count = 14, Min = 6, Max = 13, Zone = "Flank" },
	{ Name = "Obsidian Boulder", Count = 12, Min = 5, Max = 11, Zone = "Flank" },
	{ Name = "Gilded Ruin", Count = 8, Min = 8, Max = 14, Zone = "Front", Glow = 18 },
	{ Name = "Verdant Crystals", Count = 10, Min = 5, Max = 9, Zone = "Float", Glow = 24 },
	{ Name = "Radiant Cluster", Count = 10, Min = 6, Max = 10, Zone = "Float", Glow = 30 },
}

local FLOOR = 0
local CEILING = 51

local folder: Folder? = nil
local shown = -1

local function planFor(layer: number): { PropPlan }
	local authored = LAYER_THEMES[layer]
	if authored then
		return authored
	end
	-- Four of the nine each time, stepped by the layer so consecutive deep
	-- layers never come out identical and none of them is ever empty.
	local picked: { PropPlan } = {}
	for offset = 0, 3 do
		local index = ((layer * 3 + offset * 2) % #REMIX) + 1
		table.insert(picked, REMIX[index])
	end
	return picked
end

-- The four station pads and the walk between them. Decoration goes AROUND these,
-- never on them: a prop you can walk through still reads as being in the way.
local STATIONS = {
	Vector3.new(-34, 0, -20),
	Vector3.new(0, 0, -10),
	Vector3.new(34, 0, -20),
	Vector3.new(0, 0, 42),
}

local function clearOfStations(at: Vector3): boolean
	for _, pad in STATIONS do
		if (Vector3.new(at.X, 0, at.Z) - pad).Magnitude < 20 then
			return false
		end
	end
	return true
end

-- Somewhere in this zone, given a per-instance random source.
--
-- THESE BOUNDS ARE ABOUT BEING SEEN. The first version kept everything at
-- |x| >= 50 to stay out of the walkway, which also put all of it outside the
-- part of the room anyone looks at — a player works the wall between x = -45 and
-- 45, so forty props sat in the wings and the cavern looked untouched. Coming
-- inward is the whole fix; the station clearance above is what makes it safe.
local function placeIn(zone: string, rng: Random, height: number): (Vector3, number?)
	if zone == "Hero" then
		-- Off the left shoulder of the wall: the first thing you see on spawn,
		-- and never in front of a node.
		return Vector3.new(-56, FLOOR, -48), nil
	end

	local side = if rng:NextNumber() < 0.5 then -1 else 1
	for _ = 1, 12 do
		local at: Vector3
		local sink: number? = nil
		if zone == "Back" then
			-- Either side of the mine wall, close enough to frame it. Never in
			-- front of it: the wall is the game.
			at = Vector3.new(side * rng:NextNumber(30, 92), FLOOR, rng:NextNumber(-58, -40))
		elseif zone == "Flank" then
			-- In close along both sides of the working area, which is where a
			-- player spends the entire session looking.
			at = Vector3.new(side * rng:NextNumber(28, 96), FLOOR, rng:NextNumber(-34, 62))
		elseif zone == "Front" then
			at = Vector3.new(side * rng:NextNumber(24, 84), FLOOR, rng:NextNumber(38, 56))
		elseif zone == "Ceiling" then
			-- Sink by the model's own height hangs it from the ceiling rather
			-- than standing it on one: the base drops a full height below the
			-- anchor, so the top ends up flush with the rock.
			at = Vector3.new(rng:NextNumber(-88, 88), CEILING, rng:NextNumber(-54, 62))
			sink = height
		else -- Float: up in the air where it reads against the dark ceiling.
			at = Vector3.new(side * rng:NextNumber(26, 88), rng:NextNumber(10, 30), rng:NextNumber(-46, 58))
		end
		-- Overhead pieces are never in anybody's way, so they skip the check.
		if zone == "Ceiling" or clearOfStations(at) then
			return at, sink
		end
	end
	-- Every try landed on a station. Fall back to the wings rather than drop it.
	return Vector3.new(side * rng:NextNumber(64, 92), FLOOR, rng:NextNumber(-40, 50)), nil
end

local function build(layer: number)
	if folder then
		folder:Destroy()
		folder = nil
	end
	local holder = Instance.new("Folder")
	holder.Name = "CaveDecor"

	-- Seeded on the layer, so the room you rebirth into is the same room every
	-- time you come back to it. A cavern that rearranges itself on every join
	-- reads as broken rather than as varied.
	local rng = Random.new(4021 + layer * 977)

	for _, plan in planFor(layer) do
		for _ = 1, plan.Count do
			local height = rng:NextNumber(plan.Min, plan.Max)
			local at, sink = placeIn(plan.Zone, rng, height)
			local model = WorldBuild.Build(plan.Name, {
				Height = height,
				Span = if plan.Fit == "Span" then height else nil,
				Position = at,
				Yaw = rng:NextNumber(0, 360),
				Sink = sink,
				Glow = plan.Glow,
			})
			if model then
				model.Parent = holder
			end
		end
	end

	-- Nothing built means nothing is uploaded yet. Drop the empty folder rather
	-- than leaving litter in Workspace.
	if #holder:GetChildren() == 0 then
		holder:Destroy()
		return
	end
	holder.Parent = Workspace
	folder = holder
end

function CaveDecor.Init()
	local function apply()
		local state = State.Get()
		local layer = state and (state.Layer :: number?) or nil
		if not layer or layer == shown then
			return
		end
		shown = layer
		build(layer)
	end

	State.Changed:Connect(apply)
	apply()

	-- The models come from the server's preload, so at join there is a window
	-- where every Build would return nil and the cavern would stay bare for the
	-- session. Wait for the library, then redraw once — clearing `shown` is what
	-- makes the next apply actually rebuild rather than early-out.
	task.spawn(function()
		if MeshAssets.WaitForLibrary(45) then
			shown = -1
			apply()
		end
	end)
end

return CaveDecor
