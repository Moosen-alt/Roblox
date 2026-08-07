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
local State = require(script.Parent.State)

local CaveDecor = {}

type PropPlan = {
	Name: string,
	Count: number,
	Min: number,
	Max: number,
	Zone: string, -- Flank | Back | Front | Ceiling | Float | Hero
	Glow: number?,
}

-- The five authored layers, each dressed out of its own set. These are the same
-- names as Balance.LayerNames, in the same order, because that is what the
-- player sees on the rebirth screen when they arrive.
local LAYER_THEMES: { { PropPlan } } = {
	{ -- 1 Crystal Cavern — where everyone starts. Bright, and the only layer
		-- that gets a true hero piece, so the first room reads as the good one.
		{ Name = "Hero Crystal Cluster", Count = 1, Min = 24, Max = 24, Zone = "Hero", Glow = 40 },
		{ Name = "Crystal Arch", Count = 3, Min = 15, Max = 21, Zone = "Back" },
		{ Name = "Stalagmite Cluster", Count = 7, Min = 6, Max = 13, Zone = "Flank" },
		{ Name = "Cave Boulder A", Count = 6, Min = 5, Max = 10, Zone = "Flank" },
		{ Name = "Cave Boulder B", Count = 5, Min = 5, Max = 11, Zone = "Front" },
		{ Name = "Floating Crystal Ring", Count = 4, Min = 8, Max = 12, Zone = "Float", Glow = 26 },
	},
	{ -- 2 Amber Depths — a worked-out mine. Timber and warm stone.
		{ Name = "Amber Pillar", Count = 4, Min = 16, Max = 26, Zone = "Back" },
		{ Name = "Ruined Stone Arch", Count = 3, Min = 14, Max = 20, Zone = "Back" },
		{ Name = "Old Mine Support", Count = 8, Min = 10, Max = 15, Zone = "Flank" },
		{ Name = "Mine Boulder", Count = 7, Min = 4, Max = 9, Zone = "Flank" },
		{ Name = "Broken Plank Bridge", Count = 2, Min = 8, Max = 11, Zone = "Front" },
		{ Name = "Amber Cluster", Count = 5, Min = 5, Max = 9, Zone = "Float", Glow = 24 },
	},
	{ -- 3 Frost Hollow — the first layer that is actively hostile. Ice above.
		{ Name = "Frozen Pillar", Count = 4, Min = 18, Max = 28, Zone = "Back" },
		{ Name = "Frozen Arch", Count = 3, Min = 14, Max = 20, Zone = "Back" },
		{ Name = "Ice Spire Cluster", Count = 7, Min = 8, Max = 16, Zone = "Flank" },
		{ Name = "Frost Boulder", Count = 6, Min = 4, Max = 9, Zone = "Flank" },
		{ Name = "Icicle Ceiling Strip", Count = 9, Min = 7, Max = 14, Zone = "Ceiling" },
		{ Name = "Ice Crystal Cluster", Count = 5, Min = 5, Max = 9, Zone = "Float", Glow = 22 },
	},
	{ -- 4 Ember Rift — heat. Everything glows from below rather than above.
		{ Name = "Basalt Gate", Count = 2, Min = 18, Max = 24, Zone = "Back" },
		{ Name = "Basalt Spire Cluster", Count = 7, Min = 9, Max = 18, Zone = "Flank" },
		{ Name = "Lava Fissure Rock", Count = 7, Min = 4, Max = 9, Zone = "Flank", Glow = 18 },
		{ Name = "Hydrothermal Vent", Count = 5, Min = 7, Max = 12, Zone = "Front", Glow = 20 },
		{ Name = "Broken Rift Bridge", Count = 2, Min = 8, Max = 11, Zone = "Front" },
		{ Name = "Ember Crystal Cluster", Count = 5, Min = 5, Max = 9, Zone = "Float", Glow = 26 },
	},
	{ -- 5 Starfall Core — the end of the authored run, so it gets to be strange.
		{ Name = "Star Monolith", Count = 3, Min = 20, Max = 30, Zone = "Back", Glow = 24 },
		{ Name = "Star Pillar", Count = 4, Min = 16, Max = 26, Zone = "Back" },
		{ Name = "Meteor Chunk A", Count = 6, Min = 5, Max = 11, Zone = "Flank" },
		{ Name = "Meteor Chunk B", Count = 6, Min = 5, Max = 11, Zone = "Front" },
		{ Name = "Cosmic Ring", Count = 3, Min = 12, Max = 18, Zone = "Float", Glow = 30 },
		{ Name = "Prismatic Core Cluster", Count = 5, Min = 6, Max = 10, Zone = "Float", Glow = 30 },
	},
}

-- Layers 6 to 25 have generated names and no authored art, so they are dressed
-- from a shared remix set. Picking from it by layer number rather than at random
-- means layer 11 always looks like layer 11 — you can tell how deep you are by
-- looking, and rejoining does not reshuffle the room.
local REMIX: { PropPlan } = {
	{ Name = "Shattered Monolith", Count = 3, Min = 20, Max = 30, Zone = "Back" },
	{ Name = "Drowned Pillar", Count = 4, Min = 16, Max = 26, Zone = "Back" },
	{ Name = "Ashen Gate", Count = 2, Min = 18, Max = 24, Zone = "Back" },
	{ Name = "Cinder Spires", Count = 7, Min = 9, Max = 18, Zone = "Flank" },
	{ Name = "Glacier Shards", Count = 7, Min = 6, Max = 13, Zone = "Flank" },
	{ Name = "Obsidian Boulder", Count = 6, Min = 5, Max = 11, Zone = "Flank" },
	{ Name = "Gilded Ruin", Count = 4, Min = 8, Max = 14, Zone = "Front", Glow = 18 },
	{ Name = "Verdant Crystals", Count = 5, Min = 5, Max = 9, Zone = "Float", Glow = 24 },
	{ Name = "Radiant Cluster", Count = 5, Min = 6, Max = 10, Zone = "Float", Glow = 30 },
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

-- Somewhere in this zone, given a per-instance random source.
local function placeIn(zone: string, rng: Random, height: number): (Vector3, number?)
	if zone == "Hero" then
		-- One fixed spot, off to the side of the wall where it is the first thing
		-- you see on spawn without ever being in front of a node.
		return Vector3.new(-72, FLOOR, -46), nil
	elseif zone == "Back" then
		-- The corners either side of the mine wall. Never in front of it: the
		-- wall is the game.
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		return Vector3.new(side * rng:NextNumber(52, 98), FLOOR, rng:NextNumber(-62, -34)), nil
	elseif zone == "Flank" then
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		return Vector3.new(side * rng:NextNumber(56, 100), FLOOR, rng:NextNumber(-30, 62)), nil
	elseif zone == "Front" then
		return Vector3.new(rng:NextNumber(-96, 96), FLOOR, rng:NextNumber(56, 70)), nil
	elseif zone == "Ceiling" then
		-- Sink by the model's own height hangs it from the ceiling rather than
		-- standing it on one: the base drops a full height below the anchor, so
		-- the top ends up flush with the rock.
		return Vector3.new(rng:NextNumber(-98, 98), CEILING, rng:NextNumber(-60, 68)), height
	end
	-- Float: up in the air, out over the flanks.
	local side = if rng:NextNumber() < 0.5 then -1 else 1
	return Vector3.new(side * rng:NextNumber(50, 96), rng:NextNumber(12, 30), rng:NextNumber(-46, 60)), nil
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
end

return CaveDecor
