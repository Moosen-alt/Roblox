--!strict
-- Builds the entire world procedurally so the whole game lives in code:
-- a beach with a wooden dock over real terrain water, glowing fishing spots,
-- station pads, leaderboard boards, spawn, and lighting.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local FishShape = require(Shared.FishShape)

local MapBuilder = {}

export type MapRefs = {
	Nodes: { BasePart },
	Origins: { Vector3 }, -- dock position of each area, for AreaService
	CrackPrompt: ProximityPrompt,
	RackPrompt: ProximityPrompt,
	ShopPrompt: ProximityPrompt,
	RebirthPrompt: ProximityPrompt,
	DockPrompt: ProximityPrompt,
	BoardRebirths: BasePart,
	BoardRarest: BasePart,
}

-- Each area gets its own water, sand and buoy colours. Roblox lighting and
-- terrain water tint are global, so colour is the only per-area atmosphere that
-- actually varies — which makes it worth spending here rather than on a fog
-- setting that would follow the player between areas anyway.
type AreaTheme = {
	Sand: Color3,
	Water: Color3,
	Spots: { Color3 },
	Palms: number,
}

local AREA_THEMES: { AreaTheme } = {
	{ -- 1 Sunny Shallows
		Sand = Color3.fromRGB(232, 214, 165),
		Water = Color3.fromRGB(120, 210, 230),
		Spots = { Color3.fromRGB(255, 200, 60), Color3.fromRGB(120, 220, 255), Color3.fromRGB(120, 255, 160) },
		Palms = 8,
	},
	{ -- 2 Kelp Forest
		Sand = Color3.fromRGB(180, 190, 150),
		Water = Color3.fromRGB(70, 160, 130),
		Spots = { Color3.fromRGB(120, 255, 160), Color3.fromRGB(90, 200, 130), Color3.fromRGB(200, 255, 120) },
		Palms = 5,
	},
	{ -- 3 Twilight Reef
		Sand = Color3.fromRGB(205, 175, 175),
		Water = Color3.fromRGB(90, 150, 220),
		Spots = { Color3.fromRGB(255, 150, 220), Color3.fromRGB(90, 210, 220), Color3.fromRGB(255, 120, 80) },
		Palms = 3,
	},
	{ -- 4 Midnight Trench
		Sand = Color3.fromRGB(110, 105, 130),
		Water = Color3.fromRGB(40, 60, 120),
		Spots = { Color3.fromRGB(120, 200, 255), Color3.fromRGB(180, 160, 255), Color3.fromRGB(255, 240, 120) },
		Palms = 0,
	},
	{ -- 5 The Abyss
		Sand = Color3.fromRGB(70, 66, 88),
		Water = Color3.fromRGB(20, 25, 60),
		Spots = { Color3.fromRGB(190, 90, 255), Color3.fromRGB(255, 70, 120), Color3.fromRGB(150, 255, 245) },
		Palms = 0,
	},
}


local rng = Random.new(20260804)

local function part(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p
end

-- Bright, sunny and readable — not blown out. Haze compounds with every neon
-- surface and point light in view, and over open water there is nothing to break
-- it up, so the sea was washing to flat white. Sunlight and haze both came down;
-- the scene keeps its colour and the buoys keep their edges.
local function setLighting()
	Lighting.ClockTime = 15.5
	Lighting.Brightness = 1.9
	Lighting.Ambient = Color3.fromRGB(128, 130, 142)
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 132, 152)
	Lighting.FogColor = Color3.fromRGB(190, 220, 245)
	Lighting.FogEnd = 900
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.24
	atmosphere.Color = Color3.fromRGB(199, 224, 255)
	atmosphere.Haze = 0.5
	atmosphere.Parent = Lighting
end

local function makePalm(position: Vector3, parent: Instance)
	local trunk = part({
		Name = "PalmTrunk",
		Size = Vector3.new(1.4, 10, 1.4),
		Position = position + Vector3.new(0, 5, 0),
		Color = Color3.fromRGB(130, 95, 60),
		Material = Enum.Material.Wood,
	}, parent)
	trunk.CanCollide = false
	for i = 1, 5 do
		local angle = (i / 5) * math.pi * 2
		local frond = part({
			Name = "Frond" .. i,
			Size = Vector3.new(6, 0.4, 1.8),
			CFrame = CFrame.new(position + Vector3.new(0, 10, 0))
				* CFrame.Angles(0, angle, -0.35)
				* CFrame.new(3, 0, 0),
			Color = Color3.fromRGB(70, 170, 90),
			Material = Enum.Material.Grass,
		}, parent)
		frond.CanCollide = false
	end
end

--------------------------------------------------------------------------------
-- Station furniture. Each station reads as the thing it does — an open treasure
-- chest spilling gold, a glass aquarium on a table, a market stall of chests,
-- and a beached sailboat ready to Set Sail — instead of four identical pads.
--
-- All of it is visual only: nothing collides (players walk straight through)
-- and nothing answers queries (a cast-ray toward the water can never die on a
-- piece of furniture). Players walk up the beach from the dock (-Z), so the
-- furniture sits on the +Z half of each pad and the front stays open.
--------------------------------------------------------------------------------

-- The aquarium's glass volume, shared between the builder here and the client
-- that swims fish inside it (AquariumView reads the tagged part's own Size, so
-- this constant only has to be right in one place).
local TANK_SIZE = Vector3.new(9, 5.2, 3.6)

local WOOD = Color3.fromRGB(120, 88, 54)
local DARK_WOOD = Color3.fromRGB(92, 64, 40)
local GOLD = Color3.fromRGB(255, 200, 60)

local function deco(props: { [string]: any }, parent: Instance): Part
	local piece = part(props, parent)
	piece.CanCollide = false
	piece.CanQuery = false
	return piece
end

-- Treasure Chests: a big chest mid-open with gold light spilling out, a small
-- locked one beside it, loose coins in the sand.
local function decorateCrack(position: Vector3, _color: Color3, parent: Instance)
	deco({
		Name = "ChestBase",
		Size = Vector3.new(3.2, 1.8, 2.2),
		Position = position + Vector3.new(0, 1.4, 3.2),
		Color = WOOD,
		Material = Enum.Material.Wood,
	}, parent)
	deco({
		Name = "ChestBand",
		Size = Vector3.new(0.3, 1.9, 2.3),
		Position = position + Vector3.new(0, 1.4, 3.2),
		Color = Color3.fromRGB(70, 70, 80),
		Material = Enum.Material.Metal,
	}, parent)
	local gold = deco({
		Name = "ChestGold",
		Size = Vector3.new(2.8, 0.5, 1.8),
		Position = position + Vector3.new(0, 2.4, 3.2),
		Color = GOLD,
		Material = Enum.Material.Neon,
	}, parent)
	local glow = Instance.new("PointLight")
	glow.Color = GOLD
	glow.Range = 12
	glow.Brightness = 1.3
	glow.Parent = gold
	deco({
		Name = "ChestLid",
		Size = Vector3.new(3.2, 0.5, 2.2),
		CFrame = CFrame.new(position + Vector3.new(0, 2.9, 4.4)) * CFrame.Angles(math.rad(-62), 0, 0),
		Color = DARK_WOOD,
		Material = Enum.Material.Wood,
	}, parent)
	deco({
		Name = "SmallChest",
		Size = Vector3.new(1.8, 1.1, 1.3),
		Position = position + Vector3.new(2.7, 1.05, 1.6),
		Color = DARK_WOOD,
		Material = Enum.Material.Wood,
	}, parent)
	deco({
		Name = "SmallChestLid",
		Size = Vector3.new(1.9, 0.4, 1.4),
		Position = position + Vector3.new(2.7, 1.8, 1.6),
		Color = WOOD,
		Material = Enum.Material.Wood,
	}, parent)
	for i = 1, 3 do
		deco({
			Name = "LooseCoin" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.15, 0.7, 0.7),
			CFrame = CFrame.new(position + Vector3.new(rng:NextNumber(-2.4, 1.4), 0.58, rng:NextNumber(0.4, 1.8)))
				* CFrame.Angles(0, 0, math.rad(90)),
			Color = GOLD,
			Material = Enum.Material.Metal,
		}, parent)
	end
end

-- Aquarium: a glass tank on a wooden table with a relic glowing inside.
local function decorateRacks(position: Vector3, _color: Color3, parent: Instance)
	for _, x in { -3.8, 3.8 } do
		deco({
			Name = "TableLeg",
			Size = Vector3.new(0.6, 1.1, 3),
			Position = position + Vector3.new(x, 0.55, 3.2),
			Color = DARK_WOOD,
			Material = Enum.Material.Wood,
		}, parent)
	end
	deco({
		Name = "AquariumTable",
		Size = Vector3.new(9.6, 0.7, 3.9),
		Position = position + Vector3.new(0, 1.45, 3.2),
		Color = WOOD,
		Material = Enum.Material.WoodPlanks,
	}, parent)
	-- A big tank, because the fish in it have to be legible from outside the
	-- glass. The old one was 4x2 studs with two ornaments glued in it; you could
	-- not have told eight fish apart in there, let alone watched them swim.
	local tankCenter = position + Vector3.new(0, 3.6, 3.2)
	local water = deco({
		Name = "AquariumWater",
		Size = Vector3.new(TANK_SIZE.X - 0.4, TANK_SIZE.Y - 0.5, TANK_SIZE.Z - 0.4),
		Position = tankCenter - Vector3.new(0, 0.2, 0),
		Color = Color3.fromRGB(70, 160, 235),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.62,
	}, parent)
	deco({
		Name = "AquariumGlass",
		Size = TANK_SIZE,
		Position = tankCenter,
		Color = Color3.fromRGB(170, 225, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.72,
	}, parent)
	-- The client fills this with THIS player's socketed fish — racks are per
	-- player, so the tank has to be, and a local fill costs the server nothing.
	CollectionService:AddTag(water, "AquariumTank")

	-- Gravel, plants and a bubble stream, so an empty tank still looks like a
	-- tank rather than a blue box waiting for content.
	deco({
		Name = "TankGravel",
		Size = Vector3.new(TANK_SIZE.X - 0.5, 0.4, TANK_SIZE.Z - 0.5),
		Position = tankCenter - Vector3.new(0, TANK_SIZE.Y / 2 - 0.35, 0),
		Color = Color3.fromRGB(198, 176, 140),
		Material = Enum.Material.Sand,
	}, parent)
	for i = 1, 5 do
		local height = rng:NextNumber(1.2, 2.6)
		deco({
			Name = "TankPlant" .. i,
			Size = Vector3.new(0.22, height, 0.22),
			CFrame = CFrame.new(
				tankCenter + Vector3.new(rng:NextNumber(-3, 3), -TANK_SIZE.Y / 2 + height / 2 + 0.5, rng:NextNumber(-1, 1))
			) * CFrame.Angles(0, rng:NextNumber(0, 3), rng:NextNumber(-0.25, 0.25)),
			Color = Color3.fromRGB(60, 150, 90),
			Material = Enum.Material.Grass,
		}, parent)
	end
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255))
	bubbles.Size = NumberSequence.new(0.12, 0.02)
	bubbles.Transparency = NumberSequence.new(0.4, 1)
	bubbles.Lifetime = NumberRange.new(1.4, 2.2)
	bubbles.Rate = 7
	bubbles.Speed = NumberRange.new(1.4, 2.4)
	bubbles.SpreadAngle = Vector2.new(6, 6)
	bubbles.Acceleration = Vector3.new(0, 2, 0)
	bubbles.Parent = water
end

-- Chest Shop: a market stall — counter out front, striped awning overhead,
-- chests for sale on the counter and the back shelf.
local function decorateShop(position: Vector3, color: Color3, parent: Instance)
	deco({
		Name = "ShopCounter",
		Size = Vector3.new(6, 1.2, 1.6),
		Position = position + Vector3.new(0, 1.1, 1.1),
		Color = WOOD,
		Material = Enum.Material.WoodPlanks,
	}, parent)
	local function miniChest(name: string, x: number, y: number, z: number)
		deco({
			Name = name,
			Size = Vector3.new(1.5, 0.9, 1.1),
			Position = position + Vector3.new(x, y, z),
			Color = DARK_WOOD,
			Material = Enum.Material.Wood,
		}, parent)
		deco({
			Name = name .. "Lid",
			Size = Vector3.new(1.6, 0.35, 1.2),
			Position = position + Vector3.new(x, y + 0.6, z),
			Color = WOOD,
			Material = Enum.Material.Wood,
		}, parent)
	end
	miniChest("CounterChestA", -1.7, 2.15, 1.1)
	miniChest("CounterChestB", 1.7, 2.15, 1.1)
	for _, x in { -2.9, 2.9 } do
		deco({
			Name = "ShopPost",
			Size = Vector3.new(0.5, 5.6, 0.5),
			Position = position + Vector3.new(x, 3.3, 4.2),
			Color = WOOD,
			Material = Enum.Material.Wood,
		}, parent)
	end
	deco({
		Name = "ShopShelf",
		Size = Vector3.new(5.8, 0.35, 1.4),
		Position = position + Vector3.new(0, 3.2, 4.2),
		Color = WOOD:Lerp(Color3.new(0, 0, 0), 0.15),
		Material = Enum.Material.WoodPlanks,
	}, parent)
	miniChest("ShelfChest", 0, 3.85, 4.2)
	for i = 1, 5 do
		deco({
			Name = "Awning" .. i,
			Size = Vector3.new(1.3, 0.2, 3.6),
			CFrame = CFrame.new(position + Vector3.new(-2.6 + (i - 1) * 1.3, 6, 2.6)) * CFrame.Angles(math.rad(14), 0, 0),
			Color = if i % 2 == 1 then color else Color3.fromRGB(240, 234, 214),
			Material = Enum.Material.SmoothPlastic,
		}, parent)
	end
end

-- Set Sail: a beached rowboat with its mast up and sail set — ready to go.
local function decorateRebirth(position: Vector3, color: Color3, parent: Instance)
	deco({
		Name = "BoatHull",
		Size = Vector3.new(5.6, 1.3, 2.6),
		Position = position + Vector3.new(0, 1.15, 3.2),
		Color = WOOD,
		Material = Enum.Material.Wood,
	}, parent)
	-- Angled end blocks fake the taper of a bow and stern
	for _, side in { -1, 1 } do
		deco({
			Name = "BoatBow",
			Size = Vector3.new(1.7, 1.3, 1.9),
			CFrame = CFrame.new(position + Vector3.new(side * 3.1, 1.15, 3.2)) * CFrame.Angles(0, math.rad(side * 40), 0),
			Color = WOOD,
			Material = Enum.Material.Wood,
		}, parent)
	end
	for _, z in { 2.05, 4.35 } do
		deco({
			Name = "BoatRim",
			Size = Vector3.new(5.8, 0.35, 0.4),
			Position = position + Vector3.new(0, 1.9, z),
			Color = DARK_WOOD,
			Material = Enum.Material.Wood,
		}, parent)
	end
	deco({
		Name = "BoatMast",
		Size = Vector3.new(0.35, 6, 0.35),
		Position = position + Vector3.new(0, 4.8, 3.2),
		Color = DARK_WOOD,
		Material = Enum.Material.Wood,
	}, parent)
	deco({
		Name = "BoatSail",
		Size = Vector3.new(3.2, 3.4, 0.15),
		Position = position + Vector3.new(0, 5.2, 3.35),
		Color = Color3.fromRGB(240, 234, 214),
		Material = Enum.Material.SmoothPlastic,
	}, parent)
	local pennant = deco({
		Name = "BoatPennant",
		Size = Vector3.new(1.1, 0.45, 0.12),
		Position = position + Vector3.new(0.75, 7.6, 3.2),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.15,
	}, parent)
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Range = 10
	glow.Brightness = 0.8
	glow.Parent = pennant
end

local STATION_DECOR: { [string]: (Vector3, Color3, Instance) -> () } = {
	Crack = decorateCrack,
	Racks = decorateRacks,
	Shop = decorateShop,
	Rebirth = decorateRebirth,
}

local function makeStation(position: Vector3, title: string, stationKey: string, color: Color3, parent: Instance): ProximityPrompt
	-- Round pad with a glowing rim. The old "Ring" was an 11x11 neon SLAB laid
	-- over a square pad, which rendered as a giant glowing square on the cave
	-- floor — it read as a crack in the rock, not as a station.
	local pad = part({
		Name = title .. "Pad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 10, 10),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(210, 185, 140),
		Material = Enum.Material.WoodPlanks,
	}, parent)
	local ring = part({
		Name = "Rim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 11.5, 11.5),
		CFrame = CFrame.new(position + Vector3.new(0, -0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.15,
	}, parent)
	ring.CanCollide = false
	ring.CanQuery = false
	local decorate = STATION_DECOR[stationKey]
	if decorate then
		decorate(position, color, parent)
	end

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 24
	light.Brightness = 1.2
	light.Parent = pad

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(12, 2.4)
	billboard.StudsOffset = Vector3.new(0, 7, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 140
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = title
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeTransparency = 0.4
	label.Parent = billboard
	billboard.Parent = pad

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = title
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 9
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt:SetAttribute("Station", stationKey)
	prompt.Parent = pad
	return prompt
end

local function makeBoard(position: Vector3, lookAt: Vector3, title: string, parent: Instance): BasePart
	local board = part({
		Name = "Board_" .. title,
		Size = Vector3.new(14, 12, 1),
		CFrame = CFrame.lookAt(position, Vector3.new(lookAt.X, position.Y, lookAt.Z)),
		Color = Color3.fromRGB(90, 65, 45),
		Material = Enum.Material.Wood,
	}, parent)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 70)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.Text = title
	titleLabel.TextColor3 = Color3.fromRGB(255, 210, 90)
	titleLabel.TextScaled = true
	titleLabel.Parent = gui
	local list = Instance.new("Frame")
	list.Name = "List"
	list.Position = UDim2.new(0, 10, 0, 80)
	list.Size = UDim2.new(1, -20, 1, -90)
	list.BackgroundTransparency = 1
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 2)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	list.Parent = gui
	gui.Parent = board
	return board
end

--------------------------------------------------------------------------------
-- Scenery. An empty sand rectangle with twelve glowing balls on it is a test
-- level, not a place — and the areas need to look DIFFERENT from each other or
-- paying 45,000 coins to reach the next one buys you a recolour.
--
-- Everything here is decoration: no collision, no raycast queries. A cast that
-- died on a rock or a crate would be a bug the player could not see the cause of.
--------------------------------------------------------------------------------

-- Sea stacks: weathered rock pillars standing out of the water. Cheap, big, and
-- they give the horizon something to be other than empty.
local function makeSeaStack(at: Vector3, height: number, tint: Color3, parent: Instance)
	local segments = math.max(math.floor(height / 5), 2)
	for i = 1, segments do
		local t = (i - 1) / segments
		local width = (7 - t * 4) * rng:NextNumber(0.85, 1.15)
		local rock = deco({
			Name = "StackRock",
			Size = Vector3.new(width, height / segments + 1, width * rng:NextNumber(0.8, 1.2)),
			CFrame = CFrame.new(at + Vector3.new(rng:NextNumber(-1, 1), (i - 0.5) * (height / segments), rng:NextNumber(-1, 1)))
				* CFrame.Angles(rng:NextNumber(-0.08, 0.08), rng:NextNumber(0, 3), rng:NextNumber(-0.08, 0.08)),
			Color = Color3.fromRGB(96, 92, 100):Lerp(tint, 0.25),
			Material = Enum.Material.Rock,
		}, parent)
		rock.CanCollide = false
	end
end

-- A tall strand of kelp or coral, swaying is left to the client tag.
local function makeStrand(at: Vector3, height: number, color: Color3, material: Enum.Material, parent: Instance)
	local segments = math.max(math.floor(height / 3), 2)
	for i = 1, segments do
		local lean = (i / segments) * rng:NextNumber(-0.5, 0.5)
		deco({
			Name = "Strand",
			Size = Vector3.new(0.7, height / segments + 0.4, 0.35),
			CFrame = CFrame.new(at + Vector3.new(lean * 2, (i - 0.5) * (height / segments), 0))
				* CFrame.Angles(0, rng:NextNumber(0, 3), lean),
			Color = color:Lerp(Color3.new(0, 0, 0), (i / segments) * 0.2),
			Material = material,
		}, parent)
	end
end

-- Dockside clutter: a crate, a barrel and a coil of rope. Small props at human
-- scale are what make a big empty space read as somewhere people work.
local function makeDockClutter(at: Vector3, parent: Instance)
	deco({
		Name = "Crate",
		Size = Vector3.new(2.2, 2.2, 2.2),
		CFrame = CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
		Color = WOOD,
		Material = Enum.Material.WoodPlanks,
	}, parent)
	deco({
		Name = "Barrel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.4, 1.7, 1.7),
		CFrame = CFrame.new(at + Vector3.new(2.6, -0.2, 0.6)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = DARK_WOOD,
		Material = Enum.Material.Wood,
	}, parent)
	for i = 1, 3 do
		deco({
			Name = "Rope" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.18, 1.6 - i * 0.25, 1.6 - i * 0.25),
			CFrame = CFrame.new(at + Vector3.new(-2.4, -0.95 + i * 0.18, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(196, 176, 130),
			Material = Enum.Material.Fabric,
		}, parent)
	end
end

local function scatterScenery(index: number, theme: AreaTheme, ox: number, oz: number, parent: Instance)
	-- Sea stacks out in the water, off to both sides so they frame the fishing
	-- arc instead of standing in it.
	for i = 1, 6 do
		local side = if i % 2 == 0 then 1 else -1
		makeSeaStack(
			Vector3.new(ox + side * rng:NextNumber(58, 120), -3, oz - rng:NextNumber(30, 130)),
			rng:NextNumber(14, 34),
			theme.Water,
			parent
		)
	end

	-- Growth on the sea floor, themed per area: palms up top already, kelp and
	-- coral below the surface. Deep areas get glowing strands instead, which is
	-- most of what makes the Trench and the Abyss feel like different water.
	local strandColor, strandMaterial
	if index <= 1 then
		strandColor, strandMaterial = Color3.fromRGB(90, 190, 120), Enum.Material.Grass
	elseif index == 2 then
		strandColor, strandMaterial = Color3.fromRGB(60, 150, 90), Enum.Material.Grass
	elseif index == 3 then
		strandColor, strandMaterial = Color3.fromRGB(255, 130, 180), Enum.Material.Neon
	else
		strandColor, strandMaterial = theme.Spots[1], Enum.Material.Neon
	end
	for _ = 1, 26 do
		local at = Vector3.new(ox + rng:NextNumber(-120, 120), -5.5, oz - rng:NextNumber(10, 140))
		makeStrand(at, rng:NextNumber(4, 11), strandColor, strandMaterial, parent)
	end

	-- Beached rocks and driftwood on the sand
	for _ = 1, 14 do
		local size = rng:NextNumber(1.6, 5)
		deco({
			Name = "ShoreRock",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size * rng:NextNumber(0.5, 0.8), size * rng:NextNumber(0.7, 1.2)),
			CFrame = CFrame.new(ox + rng:NextNumber(-120, 120), rng:NextNumber(-0.4, 0.4), oz + rng:NextNumber(15, 105))
				* CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3)),
			Color = Color3.fromRGB(104, 100, 108):Lerp(theme.Sand, 0.3),
			Material = Enum.Material.Rock,
		}, parent)
	end

	-- Mooring posts down both sides of the dock, with lanterns on the deep ones
	for i = 1, 6 do
		local z = oz - 6 - i * 8
		for _, side in { -1, 1 } do
			local post = deco({
				Name = "MooringPost",
				Size = Vector3.new(0.8, 4.5, 0.8),
				Position = Vector3.new(ox + side * 8.4, 1.2, z),
				Color = DARK_WOOD,
				Material = Enum.Material.Wood,
			}, parent)
			if i % 2 == 0 then
				local lamp = deco({
					Name = "Lantern",
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(0.9, 0.9, 0.9),
					Position = post.Position + Vector3.new(0, 2.8, 0),
					Color = theme.Spots[1],
					Material = Enum.Material.Neon,
				}, parent)
				local light = Instance.new("PointLight")
				light.Color = theme.Spots[1]
				light.Range = 11
				light.Brightness = 0.55
				light.Shadows = false
				light.Parent = lamp
			end
		end
	end

	makeDockClutter(Vector3.new(ox - 11, 1.6, oz - 12), parent)
	makeDockClutter(Vector3.new(ox + 12, 1.6, oz - 30), parent)

	-- A giant fish of the area's own colour, turning above the water. It is the
	-- landmark you can see from the previous dock, and it advertises what lives
	-- here far better than the price on the Dock Master's list does.
	for _, at in { Vector3.new(ox - 52, 15, oz - 62), Vector3.new(ox + 52, 15, oz - 62) } do
		local trophy = FishShape.Build({
			Color = theme.Spots[rng:NextInteger(1, #theme.Spots)],
			Scale = rng:NextNumber(3.4, 4.6),
			Seed = math.floor(at.X * 7 + at.Z),
			Glow = 16,
			Sparkle = true,
			Neon = index >= 4,
		})
		trophy.Name = "Landmark" .. index
		trophy:PivotTo(CFrame.new(at))
		trophy.Parent = parent
		CollectionService:AddTag(trophy, "SpinCrystal")
		trophy:SetAttribute("SpinSpeed", rng:NextNumber(0.12, 0.22))
		trophy:SetAttribute("BobHeight", rng:NextNumber(1.4, 2.4))
		trophy:SetAttribute("BobSpeed", rng:NextNumber(0.4, 0.7))
	end
end

-- An actual navigation buoy: a fat float sitting in the water with a painted
-- band, a weighted skirt below the surface, a mast, and a lamp on top.
--
-- The lamp is the working part. It is what the fishing loop recolours and
-- brightens for cast and bite, so the buoy itself never changes shape — the old
-- marker was a neon ball that got resized for every state, which is why it read
-- as an abstract blob rather than as a thing floating in the sea.
--
-- Returns the FLOAT, which is the part the rest of the game treats as the spot:
-- its position is the waterline, which is where distances and the bobber want to
-- be measured from.
local RING_RADIUS = 2.7
local RING_TUBE = 1.05
local RING_SEGMENTS = 16

local function buildBuoy(name: string, position: Vector3, color: Color3, parent: Instance): BasePart
	local model = Instance.new("Model")
	model.Name = "Buoy"

	-- The spot the rest of the game keys on. Invisible, because the buoy it
	-- stands for is a ring with a hole in the middle — there is nothing at the
	-- centre for it to be. It still carries the area colour, which is what the
	-- lamp reads its idle and dimmed shades from.
	local float = part({
		Name = name,
		Size = Vector3.new(1, 1, 1),
		Position = position,
		Color = color,
		Transparency = 1,
	}, model)
	float.CanCollide = false
	model.PrimaryPart = float

	-- The ring float, built as a circle of cylinders. Roblox has no torus, and a
	-- ring is the single thing that makes a buoy read as a buoy — sixteen
	-- segments is past the point where anyone can see the seams from the dock.
	--
	-- A cylinder's axis is its X, so each segment is turned to put that axis
	-- along the tangent of the circle at its own angle.
	-- Painted in four alternating quadrants, life-ring style, rather than with a
	-- separate white band laid over every segment. It is the bolder read at the
	-- thirty studs you actually see these from, it is unmistakably a buoy, and it
	-- costs half the parts — sixty buoys across five areas is not the place to
	-- spend thirty-two parts each on a stripe nobody can resolve.
	local segmentLength = 2 * RING_RADIUS * math.sin(math.pi / RING_SEGMENTS) * 1.25
	local perQuadrant = RING_SEGMENTS / 4
	for i = 1, RING_SEGMENTS do
		local theta = (i - 1) / RING_SEGMENTS * math.pi * 2
		local at = position + Vector3.new(math.cos(theta) * RING_RADIUS, 0, math.sin(theta) * RING_RADIUS)
		local white = math.floor((i - 1) / perQuadrant) % 2 == 1
		local tube = part({
			Name = "Ring",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(segmentLength, RING_TUBE, RING_TUBE),
			CFrame = CFrame.new(at) * CFrame.Angles(0, -theta - math.pi * 0.5, 0),
			Color = if white then Color3.fromRGB(248, 248, 250) else color,
			Material = Enum.Material.SmoothPlastic,
		}, model)
		tube.CanCollide = false
		tube.CanQuery = false
	end

	-- Tripod: three legs leaning in from the ring to meet under the lantern.
	local apex = position + Vector3.new(0, 4.5, 0)
	for i = 1, 3 do
		local theta = (i - 1) / 3 * math.pi * 2 + math.pi * 0.5
		local foot = position
			+ Vector3.new(math.cos(theta) * (RING_RADIUS - 0.35), 0.3, math.sin(theta) * (RING_RADIUS - 0.35))
		local span = (apex - foot).Magnitude
		local leg = part({
			Name = "Leg",
			Size = Vector3.new(0.34, 0.34, span),
			-- lookAt aims the part's -Z down its own length, so a part sized on Z
			-- stretches exactly from the foot to the apex however far that is.
			CFrame = CFrame.lookAt((foot + apex) * 0.5, apex),
			-- Tinted toward the area's colour rather than left bare metal. The
			-- silhouette should be a real buoy; the palette should still look like
			-- a game a twelve-year-old wants to be in.
			Color = Color3.fromRGB(96, 88, 78):Lerp(color, 0.3),
			Material = Enum.Material.Metal,
		}, model)
		leg.CanCollide = false
		leg.CanQuery = false
	end

	-- Lantern: a ribbed glass stack on a dark base with a cap, the way the light
	-- on a real channel marker is built.
	local base = part({
		Name = "LampBase",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 1.5, 1.5),
		CFrame = CFrame.new(apex + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(64, 60, 68),
		Material = Enum.Material.Metal,
	}, model)
	base.CanCollide = false
	base.CanQuery = false

	local lamp = part({
		Name = "Lamp",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.1, 1.25, 1.25),
		CFrame = CFrame.new(apex + Vector3.new(0, 0.95, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = Enum.Material.Neon,
	}, model)
	lamp.CanCollide = false
	lamp.CanQuery = false
	-- Ribs: three dark rings round the glass, which is what stops the lantern
	-- reading as a plain glowing pill.
	for i = 1, 3 do
		local rib = part({
			Name = "LampRib",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1, 1.32, 1.32),
			CFrame = CFrame.new(apex + Vector3.new(0, 0.6 + i * 0.28, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(64, 60, 68),
			Material = Enum.Material.Metal,
		}, model)
		rib.CanCollide = false
		rib.CanQuery = false
	end
	local cap = part({
		Name = "LampCap",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 1.45, 1.45),
		CFrame = CFrame.new(apex + Vector3.new(0, 1.7, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(64, 60, 68),
		Material = Enum.Material.Metal,
	}, model)
	cap.CanCollide = false
	cap.CanQuery = false

	-- Modest, because there are twelve of these in a small arc and their light
	-- adds. The lantern's own neon does the "I am lit" work; this only has to
	-- put a little colour on the water around it.
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Range = 9
	glow.Brightness = 0.5
	glow.Shadows = false
	glow.Parent = lamp

	-- Twinkle off the lantern. Costs one emitter and it is the difference between
	-- a navigation marker and something you actually want to go and click.
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Color = ColorSequence.new(color)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new(0.35, 0)
	sparkle.Transparency = NumberSequence.new(0.2, 1)
	sparkle.Lifetime = NumberRange.new(0.6, 1.2)
	sparkle.Rate = 4
	sparkle.Speed = NumberRange.new(0.4, 1.2)
	sparkle.SpreadAngle = Vector2.new(70, 70)
	sparkle.Parent = lamp

	-- No light pool on the water. Twelve nine-stud neon discs per area, even at
	-- 0.82 transparency, blew out into overlapping white sheets that swallowed
	-- the sea AND the ring float sitting on top of them — the buoys read as
	-- glowing puddles with legs. Neon does not dim the way a transparent surface
	-- suggests it will; it is fullbright, so transparency only thins it, and a
	-- dozen thin fullbright discs still add up to solid white.

	-- One invisible box owns the tap, the same way the mining game's geodes do.
	-- A buoy bobbing thirty studs out is a very small target on a phone; this
	-- makes it a fair one without inflating the buoy itself. It deliberately
	-- carries NO NodeIndex — the client resolves a hit on it to its parent float,
	-- and the server only knows about floats. Giving the box its own index would
	-- make the client report an instance the server has never heard of, and every
	-- tap would silently do nothing.
	local hitbox = part({
		Name = "Hitbox",
		Size = Vector3.new(9, 10, 9),
		Position = position + Vector3.new(0, 1.6, 0),
		Transparency = 1,
	}, float)
	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.CanQuery = true

	model.Parent = parent
	return float
end

-- One area: its own water, its own beach, its own dock, its own twelve buoys.
-- Areas are built side by side along X rather than stitched together, because
-- travel between them is by boat (a teleport) — there is no walk to preserve, so
-- there is no reason to pay for contiguous terrain.
--
-- Returns the area's fishing spots, all tagged with an `Area` attribute so one
-- MiningService can serve every area from a single flat node list.
local function buildArea(index: number, origin: Vector3, parent: Instance): { BasePart }
	local theme = AREA_THEMES[index] or AREA_THEMES[1]
	local name = Balance.LayerNames[index] or ("Area " .. index)
	local ox, oz = origin.X, origin.Z

	local terrain = Workspace.Terrain
	terrain:FillBlock(CFrame.new(ox, -6, oz + 60), Vector3.new(280, 12, 140), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(ox, -10, oz - 70), Vector3.new(280, 12, 160), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(ox, -3.2, oz - 70), Vector3.new(280, 6, 160), Enum.Material.Water)

	part({
		Name = "Beach" .. index,
		Size = Vector3.new(240, 1, 110),
		Position = Vector3.new(ox, -0.5, oz + 62),
		Color = theme.Sand,
		Material = Enum.Material.Sand,
	}, parent)
	part({
		Name = "Dock" .. index,
		Size = Vector3.new(14, 1, 70),
		Position = Vector3.new(ox, 0.6, oz - 20),
		Color = Color3.fromRGB(160, 120, 80),
		Material = Enum.Material.WoodPlanks,
	}, parent)
	part({
		Name = "DockT" .. index,
		Size = Vector3.new(60, 1, 12),
		Position = Vector3.new(ox, 0.6, oz - 52),
		Color = Color3.fromRGB(160, 120, 80),
		Material = Enum.Material.WoodPlanks,
	}, parent)
	-- A shallow water-coloured slab under each area's spots. Terrain water is one
	-- global colour, so this is what actually makes the Abyss look like the Abyss
	-- and not like the Sunny Shallows with different fish in it.
	local tint = part({
		Name = "WaterTint" .. index,
		Size = Vector3.new(280, 0.4, 160),
		Position = Vector3.new(ox, -0.4, oz - 70),
		Color = theme.Water,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.45,
	}, parent)
	tint.CanCollide = false
	tint.CanQuery = false

	for _ = 1, theme.Palms do
		makePalm(Vector3.new(ox + rng:NextNumber(-110, 110), 0, oz + rng:NextNumber(40, 100)), parent)
	end
	scatterScenery(index, theme, ox, oz, parent)

	-- An ARCH over the head of the dock, not a board across it. The first version
	-- was a solid 18x5 part standing at walking height in the middle of the only
	-- path to the water — you could not get past it to fish. Posts to either side
	-- of the dock, the board slung between them well overhead, and nothing on it
	-- collides or answers a raycast, so it can never block a walk or eat a cast.
	for _, side in { -1, 1 } do
		local post = part({
			Name = "ArchPost" .. index,
			Size = Vector3.new(0.9, 13, 0.9),
			Position = Vector3.new(ox + side * 8.6, 6.5, oz - 4),
			Color = Color3.fromRGB(90, 65, 45),
			Material = Enum.Material.Wood,
		}, parent)
		post.CanCollide = false
		post.CanQuery = false
	end
	local sign = part({
		Name = "AreaSign" .. index,
		Size = Vector3.new(18, 4, 0.6),
		CFrame = CFrame.lookAt(Vector3.new(ox, 12, oz - 4), Vector3.new(ox, 12, oz - 40)),
		Color = Color3.fromRGB(90, 65, 45),
		Material = Enum.Material.Wood,
	}, parent)
	sign.CanCollide = false
	sign.CanQuery = false
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	signGui.PixelsPerStud = 40
	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.BackgroundTransparency = 1
	signLabel.Font = Enum.Font.FredokaOne
	signLabel.Text = name
	signLabel.TextColor3 = theme.Spots[1]
	signLabel.TextScaled = true
	signLabel.Parent = signGui
	signGui.Parent = sign

	-- Fishing spots: glowing buoys floating in an arc around the dock head
	local nodes: { BasePart } = {}
	local nodeFolder = Instance.new("Folder")
	nodeFolder.Name = "Nodes" .. index
	nodeFolder.Parent = parent
	for i = 1, Balance.NodeCount do
		local angle = math.rad(180 + (i - 1) * (180 / (Balance.NodeCount - 1)))
		local radius = 32 + (i % 2) * 10
		-- Floating ON the water (top at y = -0.2), not half sunk in it. A buoy
		-- with only its cap above the surface gives a tap almost nothing to land
		-- on once terrain water is in the way.
		local position =
			Vector3.new(ox + math.cos(angle) * radius, 0.9, oz - 52 + math.sin(angle) * radius)
		local color = theme.Spots[rng:NextInteger(1, #theme.Spots)]
		local spot = buildBuoy(("Spot%d_%d"):format(index, i), position, color, nodeFolder)
		spot:SetAttribute("NodeIndex", i)
		spot:SetAttribute("Area", index)
		CollectionService:AddTag(spot, "FishingSpot")
		local click = Instance.new("ClickDetector")
		click.MaxActivationDistance = Balance.CastRange
		click.Parent = spot

		-- Buoys ride the swell. The bob runs on each client, so sixty floating
		-- markers across five areas cost the server nothing. The tag goes on the
		-- MODEL: PivotTo on a lone part leaves its mast and lamp behind, which
		-- looks like the buoy is coming apart rather than bobbing.
		local buoy = spot.Parent :: Model
		CollectionService:AddTag(buoy, "SpinCrystal")
		buoy:SetAttribute("SpinSpeed", 0)
		buoy:SetAttribute("BobHeight", rng:NextNumber(0.3, 0.55))
		buoy:SetAttribute("BobSpeed", rng:NextNumber(0.8, 1.3))
		table.insert(nodes, spot)
	end

	return nodes
end

function MapBuilder.Build(): MapRefs
	setLighting()
	local map = Instance.new("Folder")
	map.Name = "GeneratedMap"

	-- Five areas along X. Stations exist once, at the home port in area 1: you
	-- sail back to sell, open and upgrade, which is what gives the trip home a
	-- purpose and keeps the whole economy in one place.
	local nodes: { BasePart } = {}
	local origins: { Vector3 } = {}
	for index = 1, Balance.MaxLayer do
		local origin = Vector3.new((index - 1) * Balance.AreaSpacing, 0, 0)
		origins[index] = Vector3.new(origin.X, 1.6, -40) -- the dock, where boats land
		for _, spot in buildArea(index, origin, map) do
			table.insert(nodes, spot)
		end
	end

	-- Stations on the home beach
	local crackPrompt = makeStation(Vector3.new(-34, 0.5, 30), "Treasure Chests", "Crack", Color3.fromRGB(255, 170, 40), map)
	local rackPrompt = makeStation(Vector3.new(0, 0.5, 40), "Aquarium", "Racks", Color3.fromRGB(120, 255, 200), map)
	local shopPrompt = makeStation(Vector3.new(34, 0.5, 30), "Chest Shop", "Shop", Color3.fromRGB(120, 170, 255), map)
	local rebirthPrompt = makeStation(Vector3.new(0, 0.5, 78), "Set Sail", "Rebirth", Color3.fromRGB(255, 120, 255), map)
	-- The Dock Master: buy new water, and sail to any you already own.
	local dockPrompt = makeStation(Vector3.new(-16, 0.5, -8), "Dock Master", "Dock", Color3.fromRGB(120, 200, 255), map)

	-- Leaderboards
	local boardRebirths = makeBoard(Vector3.new(-70, 7, 70), Vector3.new(0, 7, 20), "Top Voyagers", map)
	local boardRarest = makeBoard(Vector3.new(70, 7, 70), Vector3.new(0, 7, 20), "Rarest Finds", map)

	-- Spawn on the dock, steps from the fishing spots (first cast in seconds)
	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(0, 1.6, -40)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Color = Color3.fromRGB(210, 185, 140)
	spawn.Material = Enum.Material.WoodPlanks
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Duration = 0
	spawn.Parent = map

	-- Friendly like prompt beside the dock spawn
	local likeSign = part({
		Name = "LikeSign",
		Size = Vector3.new(10, 4.5, 0.6),
		CFrame = CFrame.lookAt(Vector3.new(12, 4, -28), Vector3.new(0, 3, -40)),
		Color = Color3.fromRGB(90, 65, 45),
		Material = Enum.Material.Wood,
	}, map)
	local likeGui = Instance.new("SurfaceGui")
	likeGui.Face = Enum.NormalId.Front
	likeGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	likeGui.PixelsPerStud = 40
	local likeLabel = Instance.new("TextLabel")
	likeLabel.Size = UDim2.fromScale(1, 1)
	likeLabel.BackgroundTransparency = 1
	likeLabel.Font = Enum.Font.FredokaOne
	likeLabel.Text = "Enjoying the game?\nA 👍 helps small games grow!"
	likeLabel.TextColor3 = Color3.fromRGB(255, 210, 90)
	likeLabel.TextScaled = true
	likeLabel.Parent = likeGui
	likeGui.Parent = likeSign

	map.Parent = Workspace

	return {
		Nodes = nodes,
		Origins = origins,
		CrackPrompt = crackPrompt,
		RackPrompt = rackPrompt,
		ShopPrompt = shopPrompt,
		RebirthPrompt = rebirthPrompt,
		DockPrompt = dockPrompt,
		BoardRebirths = boardRebirths,
		BoardRarest = boardRarest,
	}
end

return MapBuilder
