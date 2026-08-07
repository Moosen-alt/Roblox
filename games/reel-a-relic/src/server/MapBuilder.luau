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
local Crystals = require(Shared.Config.Crystals)
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
	-- What GROWS in the water here. Colour alone made all five areas the same
	-- beach with a filter over it — the Kelp Forest had no kelp in it, which is
	-- the kind of thing a player notices immediately and a spec sheet never does.
	Growth: string, -- Reeds | Kelp | Coral | Vent | Bone
	-- What stands on the SHORE.
	Shore: string, -- Palm | Pine | Rock | Spire
	-- Which marker floats out on the water. The lantern on top is identical
	-- across all five (the fishing loop drives it), so only the hull changes.
	Buoy: string, -- Ring | Float | Glass | Can | Orb
	-- What the station decks and the dock are built out of.
	DeckColor: Color3,
	DeckMaterial: Enum.Material,
}

local AREA_THEMES: { AreaTheme } = {
	{ -- 1 Sunny Shallows: a bright holiday beach. Palms, pale sand, clear water.
		Sand = Color3.fromRGB(232, 214, 165),
		Water = Color3.fromRGB(120, 210, 230),
		Spots = { Color3.fromRGB(255, 200, 60), Color3.fromRGB(120, 220, 255), Color3.fromRGB(120, 255, 160) },
		Palms = 8,
		Growth = "Reeds",
		Shore = "Palm",
		Buoy = "Ring",
		DeckColor = Color3.fromRGB(210, 185, 140),
		DeckMaterial = Enum.Material.WoodPlanks,
	},
	{ -- 2 Kelp Forest: a cold northern cove. Kelp towers up THROUGH the surface
		-- and mats out into a canopy you look across, pines on a rocky shore.
		Sand = Color3.fromRGB(150, 160, 130),
		Water = Color3.fromRGB(56, 132, 110),
		Spots = { Color3.fromRGB(120, 255, 160), Color3.fromRGB(90, 200, 130), Color3.fromRGB(200, 255, 120) },
		Palms = 0,
		Growth = "Kelp",
		Shore = "Pine",
		Buoy = "Otter",
		DeckColor = Color3.fromRGB(112, 92, 72),
		DeckMaterial = Enum.Material.Wood,
	},
	{ -- 3 Twilight Reef: warm and loud. Coral heads, fans, urchins.
		Sand = Color3.fromRGB(228, 196, 186),
		Water = Color3.fromRGB(90, 150, 220),
		Spots = { Color3.fromRGB(255, 150, 220), Color3.fromRGB(90, 210, 220), Color3.fromRGB(255, 120, 80) },
		Palms = 3,
		Growth = "Coral",
		Shore = "Rock",
		Buoy = "Tiki",
		DeckColor = Color3.fromRGB(226, 168, 150),
		DeckMaterial = Enum.Material.Sandstone,
	},
	{ -- 4 Midnight Trench: black basalt spires and hydrothermal vents.
		Sand = Color3.fromRGB(96, 92, 116),
		Water = Color3.fromRGB(40, 60, 120),
		Spots = { Color3.fromRGB(120, 200, 255), Color3.fromRGB(180, 160, 255), Color3.fromRGB(255, 240, 120) },
		Palms = 0,
		Growth = "Vent",
		Shore = "Spire",
		Buoy = "Can",
		DeckColor = Color3.fromRGB(78, 80, 96),
		DeckMaterial = Enum.Material.DiamondPlate,
	},
	{ -- 5 The Abyss: no light that isn't alive. Bones on the floor.
		Sand = Color3.fromRGB(58, 55, 74),
		Water = Color3.fromRGB(20, 25, 60),
		Spots = { Color3.fromRGB(190, 90, 255), Color3.fromRGB(255, 70, 120), Color3.fromRGB(150, 255, 245) },
		Palms = 0,
		Growth = "Bone",
		Shore = "Spire",
		Buoy = "Lantern",
		DeckColor = Color3.fromRGB(206, 200, 186),
		DeckMaterial = Enum.Material.Slate,
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

-- Bright, sunny and readable — not blown out.
--
-- The white sheets lying across the sea were never the lights. Roblox terrain
-- water ships with WaterReflectance at 1, so it mirrors the sky, and a bright
-- sky over open water with nothing to break it up means large stretches of the
-- surface render as flat white. Turning point lights down could never have fixed
-- that, because the point lights were not doing it.
--
-- So: kill most of the reflectance and let the water be water. Exposure comes
-- down a notch on top, which pulls the whole image back from the clip point
-- rather than dimming any one thing in it.
local function setLighting()
	Lighting.ClockTime = 15.5
	Lighting.Brightness = 1.5
	Lighting.ExposureCompensation = -0.4
	Lighting.Ambient = Color3.fromRGB(122, 126, 140)
	Lighting.OutdoorAmbient = Color3.fromRGB(116, 128, 150)
	Lighting.FogColor = Color3.fromRGB(178, 208, 236)
	Lighting.FogEnd = 1400 -- far enough to see the next area on the horizon
	Lighting.FogStart = 260
	-- Sun glare off a mirror-flat sea is the single brightest thing on screen and
	-- it is not information. The scene keeps its own light instead.
	Lighting.EnvironmentSpecularScale = 0.35
	Lighting.EnvironmentDiffuseScale = 0.8

	local terrain = Workspace.Terrain
	terrain.WaterColor = Color3.fromRGB(46, 128, 168)
	terrain.WaterReflectance = 0.12
	terrain.WaterTransparency = 0.55
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 8

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Color = Color3.fromRGB(190, 214, 244)
	atmosphere.Decay = Color3.fromRGB(120, 150, 190)
	atmosphere.Haze = 1.1 -- distance haze, which is what makes a far vista read as far
	atmosphere.Glare = 0
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
	glow.Brightness = 0.7
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

local function makeStation(
	position: Vector3,
	title: string,
	stationKey: string,
	color: Color3,
	parent: Instance,
	theme: AreaTheme?
): ProximityPrompt
	-- Round pad with a glowing rim. The old "Ring" was an 11x11 neon SLAB laid
	-- over a square pad, which rendered as a giant glowing square on the cave
	-- floor — it read as a crack in the rock, not as a station.
	-- The deck is built out of whatever this area is made of: planks on the
	-- holiday beach, dark timber in the kelp cove, sandstone on the reef, steel
	-- plate in the trench, bone in the Abyss. A station that looks identical in
	-- all five is the same "one area in five colours" problem one level in.
	local pad = part({
		Name = title .. "Pad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 10, 10),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = if theme then theme.DeckColor else Color3.fromRGB(210, 185, 140),
		Material = if theme then theme.DeckMaterial else Enum.Material.WoodPlanks,
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
	light.Range = 16
	light.Brightness = 0.6
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

--------------------------------------------------------------------------------
-- Per-area set dressing.
--
-- The five areas used to differ by tint and palm count, which is why the Kelp
-- Forest had no kelp in it. Water at this scale is mostly empty, so what fills
-- it IS the area — these are the things a player actually looks at while waiting
-- for a bite, and the reason sailing somewhere new feels like somewhere new.
--
-- Everything here is CanCollide false and CanQuery false (via `deco`): a cast
-- ray must never die on scenery, and a player must never get stuck in a coral.
--------------------------------------------------------------------------------

-- Giant kelp, built the way it actually grows: a stipe anchored on the sea floor
-- running all the way UP, then matting out into a canopy of blades lying flat on
-- the surface. The canopy is the whole point — real kelp forests read from above
-- as a floating field you look across, not as poles sticking out of the sea.
--
-- (An earlier version put loose strands at random heights and they read as green
-- boxes floating in mid-air. Rooted bottom, matted top, nothing in between.)
local SEA_FLOOR = -6.4
local SURFACE = -0.2

local function makeKelpColumn(at: Vector3, color: Color3, parent: Instance)
	local lean = rng:NextNumber(-0.09, 0.09)
	local segments = 6
	local span = SURFACE - 0.45 - SEA_FLOOR
	for i = 1, segments do
		local t = (i - 0.5) / segments
		local height = span / segments
		deco({
			Name = "KelpStipe",
			Size = Vector3.new(0.42, height + 0.15, 0.42),
			CFrame = CFrame.new(
				at.X + lean * t * 6,
				SEA_FLOOR + (i - 0.5) * height,
				at.Z + lean * t * 3
			) * CFrame.Angles(0, rng:NextNumber(0, 3), lean),
			Color = color:Lerp(Color3.fromRGB(48, 40, 24), 0.45 - t * 0.3),
			Material = Enum.Material.Grass,
		}, parent)
		-- Pneumatocysts: the little gas floats that hold the blades up. Tiny, but
		-- they are what stops the stipe reading as a green stick.
		if i > 2 then
			deco({
				Name = "KelpFloat",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.5, 0.62, 0.5),
				CFrame = CFrame.new(at.X + lean * t * 6 + 0.3, SEA_FLOOR + i * height, at.Z + lean * t * 3),
				Color = color:Lerp(Color3.fromRGB(190, 200, 90), 0.4),
				Material = Enum.Material.SmoothPlastic,
			}, parent)
		end
	end

	-- The canopy: blades fanned out just under the surface.
	local blades = rng:NextInteger(4, 6)
	local top = Vector3.new(at.X + lean * 6, SURFACE - 0.28, at.Z + lean * 3)
	for i = 1, blades do
		local theta = (i / blades) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local length = rng:NextNumber(5, 9)
		deco({
			Name = "KelpBlade",
			Size = Vector3.new(length, 0.22, rng:NextNumber(0.9, 1.6)),
			CFrame = CFrame.new(top + Vector3.new(math.cos(theta) * length * 0.5, 0, math.sin(theta) * length * 0.5))
				* CFrame.Angles(0, -theta, rng:NextNumber(-0.06, 0.06)),
			Color = color:Lerp(Color3.fromRGB(30, 60, 30), rng:NextNumber(0, 0.3)),
			Material = Enum.Material.Grass,
		}, parent)
	end
end

-- A coral head: a lump with branching arms and a brain or two. Reef colour comes
-- from the area palette, so the reef is loud in the way a reef is.
local function makeCoralHead(at: Vector3, palette: { Color3 }, parent: Instance)
	local base = palette[rng:NextInteger(1, #palette)]
	deco({
		Name = "CoralBase",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(rng:NextNumber(3, 5), rng:NextNumber(1.6, 2.6), rng:NextNumber(3, 5)),
		CFrame = CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
		Color = base:Lerp(Color3.fromRGB(120, 90, 90), 0.35),
		Material = Enum.Material.Rock,
	}, parent)
	-- Branches: a staghorn cluster leaning outward.
	for i = 1, rng:NextInteger(3, 6) do
		local theta = (i / 6) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local height = rng:NextNumber(1.6, 3.4)
		local tint = palette[rng:NextInteger(1, #palette)]
		deco({
			Name = "CoralBranch",
			Size = Vector3.new(0.55, height, 0.55),
			CFrame = CFrame.new(
				at + Vector3.new(math.cos(theta) * 1.5, height * 0.45, math.sin(theta) * 1.5)
			) * CFrame.Angles(math.sin(theta) * 0.3, 0, math.cos(theta) * -0.3),
			Color = tint,
			Material = Enum.Material.Sandstone,
		}, parent)
		deco({
			Name = "CoralTip",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.8, 0.8, 0.8),
			CFrame = CFrame.new(
				at + Vector3.new(math.cos(theta) * 2.0, height * 0.95, math.sin(theta) * 2.0)
			),
			Color = tint:Lerp(Color3.new(1, 1, 1), 0.3),
			Material = Enum.Material.Sandstone,
		}, parent)
	end
	-- A brain coral beside it: round, ribbed, a different silhouette so a reef
	-- does not read as one shape repeated.
	if rng:NextNumber() < 0.6 then
		local brainAt = at + Vector3.new(rng:NextNumber(-4, 4), 0.4, rng:NextNumber(-4, 4))
		local brain = palette[rng:NextInteger(1, #palette)]
		deco({
			Name = "BrainCoral",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2.6, 2.0, 2.6),
			CFrame = CFrame.new(brainAt),
			Color = brain,
			Material = Enum.Material.Sandstone,
		}, parent)
		for i = 1, 4 do
			deco({
				Name = "BrainRib",
				Size = Vector3.new(2.7, 0.22, 0.3),
				CFrame = CFrame.new(brainAt + Vector3.new(0, 0.5 - i * 0.22, 0))
					* CFrame.Angles(0, i * 0.7, 0),
				Color = brain:Lerp(Color3.fromRGB(40, 30, 40), 0.4),
				Material = Enum.Material.Sandstone,
			}, parent)
		end
	end
end

-- A hydrothermal vent: a basalt chimney with heat shimmering out of the top.
-- The trench needs a reason to look alive without looking lit.
local function makeVent(at: Vector3, color: Color3, parent: Instance)
	local height = rng:NextNumber(4, 8)
	local segments = 4
	for i = 1, segments do
		local t = (i - 1) / segments
		local width = (3.2 - t * 2.0) * rng:NextNumber(0.85, 1.15)
		deco({
			Name = "VentStack",
			Size = Vector3.new(width, height / segments + 0.4, width),
			CFrame = CFrame.new(at + Vector3.new(
				rng:NextNumber(-0.4, 0.4),
				(i - 0.5) * (height / segments),
				rng:NextNumber(-0.4, 0.4)
			)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			Color = Color3.fromRGB(52, 48, 60),
			Material = Enum.Material.Basalt,
		}, parent)
	end
	local mouth = deco({
		Name = "VentMouth",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.5, 0.7, 1.5),
		CFrame = CFrame.new(at + Vector3.new(0, height, 0)),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
	}, parent)
	-- The plume. Particles rather than parts, because it has to move and it must
	-- never be something a cast can land on.
	local plume = Instance.new("ParticleEmitter")
	plume.Color = ColorSequence.new(color)
	plume.LightEmission = 0.25
	plume.Size = NumberSequence.new(1.4, 3.4)
	plume.Transparency = NumberSequence.new(0.55, 1)
	plume.Lifetime = NumberRange.new(1.6, 3.2)
	plume.Rate = 5
	plume.Speed = NumberRange.new(2.5, 5)
	plume.SpreadAngle = Vector2.new(12, 12)
	plume.Parent = mouth
end

-- A basalt spire: taller, thinner and sharper than a sea stack, leaning. Trench
-- and Abyss geology, so the deep areas do not just look like a dark beach.
local function makeSpire(at: Vector3, height: number, tint: Color3, parent: Instance)
	local segments = math.max(math.floor(height / 6), 3)
	local lean = rng:NextNumber(-0.12, 0.12)
	for i = 1, segments do
		local t = (i - 1) / segments
		local width = (5.5 - t * 4.4) * rng:NextNumber(0.8, 1.2)
		deco({
			Name = "Spire",
			Size = Vector3.new(width, height / segments + 1.2, width * rng:NextNumber(0.8, 1.2)),
			CFrame = CFrame.new(at + Vector3.new(
				lean * i * 1.6,
				(i - 0.5) * (height / segments),
				lean * i * 0.8
			)) * CFrame.Angles(lean * 0.4, rng:NextNumber(0, 3), lean),
			Color = Color3.fromRGB(46, 44, 58):Lerp(tint, 0.22),
			Material = Enum.Material.Basalt,
		}, parent)
	end
end

-- Something enormous died here. A spine and a cage of ribs half-buried on the
-- floor of the Abyss, which does more for "this is the deep" than any tint.
local function makeBones(at: Vector3, parent: Instance)
	local BONE = Color3.fromRGB(214, 208, 190)
	local length = rng:NextNumber(16, 26)
	local heading = rng:NextNumber(0, 3)
	local facing = CFrame.new(at) * CFrame.Angles(0, heading, 0)
	deco({
		Name = "Spine",
		Size = Vector3.new(1.1, 1.1, length),
		CFrame = facing,
		Color = BONE,
		Material = Enum.Material.Sandstone,
	}, parent)
	local ribs = 7
	for i = 1, ribs do
		local z = -length * 0.4 + (i - 1) * (length * 0.8 / (ribs - 1))
		local span = (2.6 + math.sin(i / ribs * math.pi) * 3.4)
		for _, side in { 1, -1 } do
			deco({
				Name = "Rib",
				Size = Vector3.new(0.55, span, 0.55),
				CFrame = facing
					* CFrame.new(side * span * 0.42, span * 0.3, z)
					* CFrame.Angles(0, 0, side * 0.85),
				Color = BONE,
				Material = Enum.Material.Sandstone,
			}, parent)
		end
	end
	-- The skull, at one end.
	deco({
		Name = "Skull",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3.4, 2.8, 3.0),
		CFrame = facing * CFrame.new(0, 1.0, length * 0.55),
		Color = BONE,
		Material = Enum.Material.Sandstone,
	}, parent)
end

-- A conifer, for the cold rocky shore of the Kelp Forest. Palms there were the
-- single most obviously wrong thing on the beach.
local function makePine(position: Vector3, parent: Instance)
	local height = rng:NextNumber(10, 17)
	local trunk = deco({
		Name = "PineTrunk",
		Size = Vector3.new(1.3, height, 1.3),
		Position = position + Vector3.new(0, height * 0.5, 0),
		Color = Color3.fromRGB(92, 68, 50),
		Material = Enum.Material.Wood,
	}, parent)
	trunk.CanCollide = true
	local tiers = 5
	for i = 1, tiers do
		local t = (i - 1) / tiers
		local width = (9 - t * 6.2) * rng:NextNumber(0.9, 1.1)
		deco({
			Name = "PineTier",
			Size = Vector3.new(width, height * 0.2, width),
			CFrame = CFrame.new(position + Vector3.new(0, height * (0.34 + t * 0.62), 0))
				* CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			Color = Color3.fromRGB(38, 82, 56):Lerp(Color3.fromRGB(70, 130, 80), t * 0.5),
			Material = Enum.Material.Grass,
		}, parent)
	end
end

--------------------------------------------------------------------------------
-- CULTURE PACKS: what makes each area a PLACE and not a palette.
--
-- Every area's species list is real, and real species come from somewhere. That
-- somewhere is free theming, and it is far stronger than inventing one:
--
--   1 Sunny Shallows  Sailfish, Snapper, Tarpon water -> a FLORIDA KEYS marina
--   2 Kelp Forest     Garibaldi (California's state marine fish), Sheephead,
--                     Leopard Shark, Giant Sea Bass -> the SOUTHERN CALIFORNIA
--                     kelp coast: a timber pier, a cannery, and sea otters
--                     floating on their backs in the canopy
--   3 Twilight Reef   Clownfish, Parrotfish, Blue Tang, Manta -> INDO-PACIFIC,
--                     so a Polynesian tiki island with huts out over the water
--   4 Midnight Trench Anglerfish, Barreleye, Gulper Eel -> nobody LIVES here,
--                     they visit: a DEEP-SEA RESEARCH RIG with a submersible
--   5 The Abyss       Goblin Shark and Frilled Shark are Sagami Bay animals ->
--                     RYUGU-JO, the dragon god's palace: a torii gate standing
--                     out of black water, stone lanterns, a drowned shrine
--
-- Every one of these is a landmark you can see from the dock before you can
-- afford the water it stands in, which is the Dock Master's price list doing its
-- own advertising.
--------------------------------------------------------------------------------

-- A sea otter, floating on its back with a shell on its chest, the way they
-- actually sleep in the canopy. Pure charm, and charm is what a kelp bed needs
-- to stop being a green car park.
local function makeOtter(at: Vector3, parent: Instance)
	local FUR = Color3.fromRGB(112, 84, 62)
	local FACE = Color3.fromRGB(198, 176, 150)
	local heading = rng:NextNumber(0, 6)
	local facing = CFrame.new(at) * CFrame.Angles(0, heading, 0)
	deco({
		Name = "OtterBody",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.5, 1.1, 3.4),
		CFrame = facing,
		Color = FUR,
		Material = Enum.Material.SmoothPlastic,
	}, parent)
	deco({
		Name = "OtterBelly",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.25, 0.7, 2.7),
		CFrame = facing * CFrame.new(0, 0.32, 0),
		Color = FACE:Lerp(FUR, 0.35),
		Material = Enum.Material.SmoothPlastic,
	}, parent)
	deco({
		Name = "OtterHead",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.15, 1.0, 1.1),
		CFrame = facing * CFrame.new(0, 0.5, 1.75),
		Color = FUR,
		Material = Enum.Material.SmoothPlastic,
	}, parent)
	deco({
		Name = "OtterMuzzle",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.7, 0.5, 0.6),
		CFrame = facing * CFrame.new(0, 0.34, 2.2),
		Color = FACE,
		Material = Enum.Material.SmoothPlastic,
	}, parent)
	for _, side in { 1, -1 } do
		deco({
			Name = "OtterEye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.2, 0.2, 0.2),
			CFrame = facing * CFrame.new(side * 0.28, 0.72, 2.05),
			Color = Color3.fromRGB(22, 20, 26),
		}, parent)
		deco({
			Name = "OtterEar",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.26, 0.26, 0.2),
			CFrame = facing * CFrame.new(side * 0.48, 0.95, 1.5),
			Color = FUR,
		}, parent)
		-- Paws folded on the chest, holding the shell.
		deco({
			Name = "OtterPaw",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.42, 0.34, 0.5),
			CFrame = facing * CFrame.new(side * 0.34, 0.7, 0.85),
			Color = FUR:Lerp(Color3.new(0, 0, 0), 0.25),
		}, parent)
	end
	deco({
		Name = "OtterShell",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.7, 0.3, 0.7),
		CFrame = facing * CFrame.new(0, 0.85, 0.9),
		Color = Color3.fromRGB(206, 198, 180),
		Material = Enum.Material.Sandstone,
	}, parent)
	deco({
		Name = "OtterTail",
		Size = Vector3.new(0.5, 0.3, 1.6),
		CFrame = facing * CFrame.new(0, 0.05, -2.1),
		Color = FUR,
		Material = Enum.Material.SmoothPlastic,
	}, parent)
end

-- A carved tiki totem. Stacked faces, because one head reads as a post and
-- three read as a totem.
local function makeTiki(at: Vector3, heads: number, parent: Instance)
	local WOOD_DARK = Color3.fromRGB(94, 62, 40)
	local WOOD_MID = Color3.fromRGB(126, 86, 54)
	for i = 1, heads do
		local y = (i - 1) * 3.1
		deco({
			Name = "TikiBlock",
			Size = Vector3.new(2.6, 3.0, 2.4),
			CFrame = CFrame.new(at + Vector3.new(0, y + 1.5, 0)) * CFrame.Angles(0, 0.12 * i, 0),
			Color = if i % 2 == 0 then WOOD_MID else WOOD_DARK,
			Material = Enum.Material.Wood,
		}, parent)
		-- Brow, eyes, mouth: four parts is enough for a face at this distance.
		deco({
			Name = "TikiBrow",
			Size = Vector3.new(2.7, 0.5, 0.5),
			CFrame = CFrame.new(at + Vector3.new(0, y + 2.3, -1.15)) * CFrame.Angles(0, 0.12 * i, 0),
			Color = WOOD_DARK:Lerp(Color3.new(0, 0, 0), 0.4),
			Material = Enum.Material.Wood,
		}, parent)
		for _, side in { 1, -1 } do
			deco({
				Name = "TikiEye",
				Size = Vector3.new(0.6, 0.6, 0.3),
				CFrame = CFrame.new(at + Vector3.new(side * 0.62, y + 1.8, -1.2)) * CFrame.Angles(0, 0.12 * i, 0),
				Color = Color3.fromRGB(238, 226, 200),
				Material = Enum.Material.SmoothPlastic,
			}, parent)
		end
		deco({
			Name = "TikiMouth",
			Size = Vector3.new(1.8, 0.7, 0.35),
			CFrame = CFrame.new(at + Vector3.new(0, y + 0.85, -1.15)) * CFrame.Angles(0, 0.12 * i, 0),
			Color = Color3.fromRGB(228, 210, 180),
			Material = Enum.Material.SmoothPlastic,
		}, parent)
	end
end

-- A torii gate. Two pillars, a curved double lintel, painted vermilion — the
-- single most legible "this is a sacred place" silhouette there is, and Sagami
-- Bay is where the Goblin Shark and the Frilled Shark actually come from.
local function makeTorii(at: Vector3, scale: number, parent: Instance)
	local VERMILION = Color3.fromRGB(196, 54, 44)
	local BLACK = Color3.fromRGB(34, 28, 30)
	local height = 16 * scale
	local width = 13 * scale
	for _, side in { 1, -1 } do
		deco({
			Name = "ToriiPillar",
			Size = Vector3.new(1.5 * scale, height, 1.5 * scale),
			CFrame = CFrame.new(at + Vector3.new(side * width * 0.5, height * 0.5, 0))
				* CFrame.Angles(0, 0, side * 0.02),
			Color = VERMILION,
			Material = Enum.Material.WoodPlanks,
		}, parent)
		deco({
			Name = "ToriiFoot",
			Size = Vector3.new(2.3 * scale, 1.1 * scale, 2.3 * scale),
			Position = at + Vector3.new(side * width * 0.5, 0.4 * scale, 0),
			Color = BLACK,
			Material = Enum.Material.Slate,
		}, parent)
	end
	-- Kasagi: the top lintel, wider than the gate and slightly upturned.
	deco({
		Name = "ToriiKasagi",
		Size = Vector3.new(width * 1.35, 1.3 * scale, 2.0 * scale),
		Position = at + Vector3.new(0, height + 0.5 * scale, 0),
		Color = VERMILION,
		Material = Enum.Material.WoodPlanks,
	}, parent)
	for _, side in { 1, -1 } do
		deco({
			Name = "ToriiUpturn",
			Size = Vector3.new(width * 0.22, 1.0 * scale, 1.9 * scale),
			CFrame = CFrame.new(at + Vector3.new(side * width * 0.72, height + 0.85 * scale, 0))
				* CFrame.Angles(0, 0, side * -0.16),
			Color = VERMILION,
			Material = Enum.Material.WoodPlanks,
		}, parent)
	end
	-- Nuki: the lower tie beam, and the small strut between them.
	deco({
		Name = "ToriiNuki",
		Size = Vector3.new(width * 1.06, 0.9 * scale, 1.3 * scale),
		Position = at + Vector3.new(0, height - 2.6 * scale, 0),
		Color = VERMILION,
		Material = Enum.Material.WoodPlanks,
	}, parent)
	deco({
		Name = "ToriiGakuzuka",
		Size = Vector3.new(1.1 * scale, 2.2 * scale, 1.0 * scale),
		Position = at + Vector3.new(0, height - 1.4 * scale, 0),
		Color = BLACK,
		Material = Enum.Material.WoodPlanks,
	}, parent)
end

-- A stone lantern (toro). Standing on the shore, or floating on the water for
-- toro nagashi, which is where the Abyss buoy comes from.
local function makeStoneLantern(at: Vector3, scale: number, lightColor: Color3, parent: Instance): BasePart
	local STONE = Color3.fromRGB(148, 146, 138)
	deco({
		Name = "LanternBase",
		Size = Vector3.new(2.0 * scale, 0.7 * scale, 2.0 * scale),
		Position = at + Vector3.new(0, 0.35 * scale, 0),
		Color = STONE:Lerp(Color3.new(0, 0, 0), 0.2),
		Material = Enum.Material.Slate,
	}, parent)
	deco({
		Name = "LanternPost",
		Size = Vector3.new(0.8 * scale, 2.2 * scale, 0.8 * scale),
		Position = at + Vector3.new(0, 1.8 * scale, 0),
		Color = STONE,
		Material = Enum.Material.Slate,
	}, parent)
	deco({
		Name = "LanternPlate",
		Size = Vector3.new(2.2 * scale, 0.4 * scale, 2.2 * scale),
		Position = at + Vector3.new(0, 3.1 * scale, 0),
		Color = STONE,
		Material = Enum.Material.Slate,
	}, parent)
	local box = deco({
		Name = "LanternBox",
		Size = Vector3.new(1.7 * scale, 1.6 * scale, 1.7 * scale),
		Position = at + Vector3.new(0, 4.1 * scale, 0),
		Color = lightColor,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
	}, parent)
	-- Slats over the light box, so it reads as carved stone with fire inside
	-- rather than as a glowing cube.
	for _, side in { 1, -1 } do
		deco({
			Name = "LanternPost2",
			Size = Vector3.new(0.28 * scale, 1.7 * scale, 0.28 * scale),
			Position = at + Vector3.new(side * 0.78 * scale, 4.1 * scale, 0.78 * scale),
			Color = STONE,
			Material = Enum.Material.Slate,
		}, parent)
		deco({
			Name = "LanternPost3",
			Size = Vector3.new(0.28 * scale, 1.7 * scale, 0.28 * scale),
			Position = at + Vector3.new(side * 0.78 * scale, 4.1 * scale, -0.78 * scale),
			Color = STONE,
			Material = Enum.Material.Slate,
		}, parent)
	end
	-- Kasa: the flared stone roof, and the jewel on top.
	deco({
		Name = "LanternRoof",
		Size = Vector3.new(3.0 * scale, 0.9 * scale, 3.0 * scale),
		Position = at + Vector3.new(0, 5.3 * scale, 0),
		Color = STONE:Lerp(Color3.new(0, 0, 0), 0.15),
		Material = Enum.Material.Slate,
	}, parent)
	deco({
		Name = "LanternFinial",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.9 * scale, 1.1 * scale, 0.9 * scale),
		Position = at + Vector3.new(0, 6.1 * scale, 0),
		Color = STONE,
		Material = Enum.Material.Slate,
	}, parent)
	return box
end

-- A timber pier on pilings, running out over the water. The Monterey/Catalina
-- silhouette, and the thing that makes the kelp coast read as a working coast.
local function makePier(at: Vector3, length: number, parent: Instance)
	deco({
		Name = "PierDeck",
		Size = Vector3.new(9, 0.7, length),
		Position = at + Vector3.new(0, 4.2, -length * 0.5),
		Color = Color3.fromRGB(122, 96, 72),
		Material = Enum.Material.WoodPlanks,
	}, parent).CanCollide = true
	local bays = math.floor(length / 9)
	for i = 0, bays do
		for _, side in { 1, -1 } do
			deco({
				Name = "Piling",
				Size = Vector3.new(1.1, 11, 1.1),
				Position = at + Vector3.new(side * 3.6, -1.5, -i * 9),
				Color = Color3.fromRGB(78, 62, 48),
				Material = Enum.Material.Wood,
			}, parent)
			-- Rail posts, so the deck has an edge instead of just stopping.
			deco({
				Name = "RailPost",
				Size = Vector3.new(0.4, 2.4, 0.4),
				Position = at + Vector3.new(side * 4.2, 5.7, -i * 9),
				Color = Color3.fromRGB(96, 76, 58),
				Material = Enum.Material.Wood,
			}, parent)
		end
	end
	for _, side in { 1, -1 } do
		deco({
			Name = "Rail",
			Size = Vector3.new(0.3, 0.3, length),
			Position = at + Vector3.new(side * 4.2, 6.8, -length * 0.5),
			Color = Color3.fromRGB(96, 76, 58),
			Material = Enum.Material.Wood,
		}, parent)
	end
end

-- A clapboard cannery shed with a rust-red roof: Cannery Row in four parts.
local function makeShed(at: Vector3, width: number, wall: Color3, roof: Color3, parent: Instance)
	local height = rng:NextNumber(7, 10)
	deco({
		Name = "ShedWall",
		Size = Vector3.new(width, height, width * 0.75),
		Position = at + Vector3.new(0, height * 0.5, 0),
		Color = wall,
		Material = Enum.Material.WoodPlanks,
	}, parent).CanCollide = true
	-- Pitched roof: two leaning slabs.
	for _, side in { 1, -1 } do
		deco({
			Name = "ShedRoof",
			Size = Vector3.new(width * 0.62, 0.6, width * 0.85),
			CFrame = CFrame.new(at + Vector3.new(side * width * 0.26, height + width * 0.12, 0))
				* CFrame.Angles(0, 0, side * 0.42),
			Color = roof,
			Material = Enum.Material.Metal,
		}, parent)
	end
	for i = 1, 2 do
		deco({
			Name = "ShedWindow",
			Size = Vector3.new(width * 0.2, height * 0.28, 0.3),
			Position = at + Vector3.new((i - 1.5) * width * 0.45, height * 0.55, -width * 0.38),
			Color = Color3.fromRGB(150, 190, 200),
			Material = Enum.Material.Glass,
			Transparency = 0.3,
		}, parent)
	end
end

-- A thatched hut on stilts out over the reef, with a ladder down to the water.
local function makeStiltHut(at: Vector3, parent: Instance)
	local BAMBOO = Color3.fromRGB(206, 178, 116)
	local THATCH = Color3.fromRGB(176, 142, 82)
	for _, dx in { -3.2, 3.2 } do
		for _, dz in { -3.2, 3.2 } do
			deco({
				Name = "Stilt",
				Size = Vector3.new(0.6, 9, 0.6),
				Position = at + Vector3.new(dx, 1.5, dz),
				Color = Color3.fromRGB(120, 96, 60),
				Material = Enum.Material.Wood,
			}, parent)
		end
	end
	deco({
		Name = "HutFloor",
		Size = Vector3.new(8.4, 0.6, 8.4),
		Position = at + Vector3.new(0, 6.2, 0),
		Color = BAMBOO,
		Material = Enum.Material.WoodPlanks,
	}, parent).CanCollide = true
	for i = 1, 4 do
		local theta = (i / 4) * math.pi * 2 + math.pi * 0.25
		deco({
			Name = "HutPost",
			Size = Vector3.new(0.45, 5, 0.45),
			Position = at + Vector3.new(math.cos(theta) * 3.6, 9, math.sin(theta) * 3.6),
			Color = BAMBOO,
			Material = Enum.Material.Wood,
		}, parent)
	end
	-- Thatch: four leaning panels meeting in a peak.
	for i = 1, 4 do
		local theta = (i / 4) * math.pi * 2
		deco({
			Name = "Thatch",
			Size = Vector3.new(7.6, 0.7, 5.4),
			CFrame = CFrame.new(at + Vector3.new(math.cos(theta) * 2.1, 12.4, math.sin(theta) * 2.1))
				* CFrame.Angles(0, -theta, 0)
				* CFrame.Angles(-0.62, 0, 0),
			Color = THATCH,
			Material = Enum.Material.Grass,
		}, parent)
	end
	deco({
		Name = "ThatchPeak",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.2, 1.6, 2.2),
		Position = at + Vector3.new(0, 14.2, 0),
		Color = THATCH,
		Material = Enum.Material.Grass,
	}, parent)
end

-- A steel research platform on legs, with a submersible slung under its crane.
-- Nothing LIVES in the trench; people visit it, and the rig says so.
local function makeRig(at: Vector3, parent: Instance)
	local STEEL = Color3.fromRGB(96, 102, 116)
	local HAZARD = Color3.fromRGB(226, 176, 44)
	for _, dx in { -7, 7 } do
		for _, dz in { -7, 7 } do
			deco({
				Name = "RigLeg",
				Size = Vector3.new(1.5, 16, 1.5),
				Position = at + Vector3.new(dx, 4, dz),
				Color = STEEL,
				Material = Enum.Material.Metal,
			}, parent)
		end
	end
	deco({
		Name = "RigDeck",
		Size = Vector3.new(18, 1, 18),
		Position = at + Vector3.new(0, 12.2, 0),
		Color = STEEL,
		Material = Enum.Material.DiamondPlate,
	}, parent).CanCollide = true
	for i = 1, 4 do
		deco({
			Name = "RigHazard",
			Size = Vector3.new(18, 0.4, 1.1),
			Position = at + Vector3.new(0, 12.9, -8.4 + (i - 1) * 5.6),
			Color = if i % 2 == 0 then HAZARD else Color3.fromRGB(40, 42, 50),
			Material = Enum.Material.Metal,
		}, parent)
	end
	-- Container hut and a floodlight mast.
	deco({
		Name = "RigHut",
		Size = Vector3.new(7, 5, 5),
		Position = at + Vector3.new(-4, 15.2, 3),
		Color = Color3.fromRGB(52, 96, 118),
		Material = Enum.Material.CorrodedMetal,
	}, parent).CanCollide = true
	deco({
		Name = "RigMast",
		Size = Vector3.new(0.7, 10, 0.7),
		Position = at + Vector3.new(6, 17.5, -5),
		Color = STEEL,
		Material = Enum.Material.Metal,
	}, parent)
	local flood = deco({
		Name = "RigFlood",
		Size = Vector3.new(1.8, 1.4, 1.2),
		Position = at + Vector3.new(6, 22.2, -5),
		Color = Color3.fromRGB(255, 246, 210),
		Material = Enum.Material.Neon,
		Transparency = 0.25,
	}, parent)
	local lamp = Instance.new("PointLight")
	lamp.Color = Color3.fromRGB(210, 230, 255)
	lamp.Range = 22
	lamp.Brightness = 0.7
	lamp.Shadows = false
	lamp.Parent = flood

	-- The crane, and the sub on the end of it.
	deco({
		Name = "CraneArm",
		Size = Vector3.new(0.8, 0.8, 12),
		CFrame = CFrame.new(at + Vector3.new(6, 21, -11)) * CFrame.Angles(0.25, 0, 0),
		Color = HAZARD,
		Material = Enum.Material.Metal,
	}, parent)
	local subAt = at + Vector3.new(6, 14.5, -16)
	deco({
		Name = "SubHull",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(4.2, 3.6, 5.6),
		Position = subAt,
		Color = HAZARD,
		Material = Enum.Material.Metal,
	}, parent)
	deco({
		Name = "SubPort",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.0, 2.0, 2.0),
		Position = subAt + Vector3.new(0, 0.2, -2.4),
		Color = Color3.fromRGB(150, 220, 240),
		Material = Enum.Material.Glass,
		Transparency = 0.35,
	}, parent)
	deco({
		Name = "SubFin",
		Size = Vector3.new(0.4, 2.4, 1.6),
		Position = subAt + Vector3.new(0, 1.9, 2.2),
		Color = Color3.fromRGB(60, 64, 76),
		Material = Enum.Material.Metal,
	}, parent)
	for _, side in { 1, -1 } do
		deco({
			Name = "SubThruster",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.4, 1.2, 1.2),
			CFrame = CFrame.new(subAt + Vector3.new(side * 2.3, -0.4, 1.9)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(60, 64, 76),
			Material = Enum.Material.Metal,
		}, parent)
	end
end

-- A drowned shrine: a tiled roof breaking the surface at an angle, as though
-- the building under it is still down there.
local function makeShrine(at: Vector3, parent: Instance)
	local TILE = Color3.fromRGB(62, 74, 86)
	local BEAM = Color3.fromRGB(150, 62, 52)
	local tilt = rng:NextNumber(0.12, 0.26)
	local heading = rng:NextNumber(0, 6)
	local facing = CFrame.new(at) * CFrame.Angles(0, heading, 0) * CFrame.Angles(0, 0, tilt)
	for _, side in { 1, -1 } do
		deco({
			Name = "ShrineRoof",
			Size = Vector3.new(11, 0.9, 8),
			CFrame = facing * CFrame.new(side * 4.4, 2.6, 0) * CFrame.Angles(0, 0, side * 0.5),
			Color = TILE,
			Material = Enum.Material.Slate,
		}, parent)
		-- Upturned eaves, the detail that makes it read as a shrine.
		deco({
			Name = "ShrineEave",
			Size = Vector3.new(3.4, 0.7, 8.4),
			CFrame = facing * CFrame.new(side * 8.6, 0.7, 0) * CFrame.Angles(0, 0, side * 0.18),
			Color = TILE:Lerp(Color3.new(0, 0, 0), 0.2),
			Material = Enum.Material.Slate,
		}, parent)
	end
	deco({
		Name = "ShrineRidge",
		Size = Vector3.new(1.4, 1.0, 8.6),
		CFrame = facing * CFrame.new(0, 4.4, 0),
		Color = BEAM,
		Material = Enum.Material.Slate,
	}, parent)
	deco({
		Name = "ShrineBeam",
		Size = Vector3.new(9, 1.0, 1.0),
		CFrame = facing * CFrame.new(0, 1.2, -4.2),
		Color = BEAM,
		Material = Enum.Material.WoodPlanks,
	}, parent)
end

-- Koinobori: carp streamers on a pole. Japanese, instantly readable, and a carp
-- windsock over black water is exactly the note the Abyss wants.
local function makeKoinobori(at: Vector3, parent: Instance)
	deco({
		Name = "KoiPole",
		Size = Vector3.new(0.5, 20, 0.5),
		Position = at + Vector3.new(0, 10, 0),
		Color = Color3.fromRGB(70, 60, 54),
		Material = Enum.Material.Wood,
	}, parent)
	local colors = {
		Color3.fromRGB(40, 44, 60),
		Color3.fromRGB(206, 62, 52),
		Color3.fromRGB(70, 130, 200),
	}
	for i, tint in colors do
		local y = 18.5 - (i - 1) * 4.6
		local drift = rng:NextNumber(-0.14, 0.14)
		-- Body, tapering into a split tail: a carp windsock in five parts.
		deco({
			Name = "KoiBody",
			Size = Vector3.new(4.4, 2.4, 2.4),
			CFrame = CFrame.new(at + Vector3.new(2.8, y, 0)) * CFrame.Angles(0, 0, drift),
			Color = tint,
			Material = Enum.Material.Fabric,
		}, parent)
		deco({
			Name = "KoiMouth",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.5, 2.6, 2.6),
			CFrame = CFrame.new(at + Vector3.new(0.7, y, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(240, 236, 226),
			Material = Enum.Material.Fabric,
		}, parent)
		deco({
			Name = "KoiEye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.7, 0.7, 0.7),
			CFrame = CFrame.new(at + Vector3.new(1.5, y + 0.6, 1.1)),
			Color = Color3.fromRGB(245, 245, 245),
		}, parent)
		for _, side in { 1, -1 } do
			deco({
				Name = "KoiTail",
				Size = Vector3.new(2.0, 1.9, 0.4),
				CFrame = CFrame.new(at + Vector3.new(5.8, y + side * 0.7, 0))
					* CFrame.Angles(0, 0, drift + side * 0.5),
				Color = tint:Lerp(Color3.new(1, 1, 1), 0.35),
				Material = Enum.Material.Fabric,
			}, parent)
		end
	end
end

-- A pastel cabana with a striped awning. Florida Keys marina furniture.
local function makeCabana(at: Vector3, wall: Color3, parent: Instance)
	deco({
		Name = "CabanaWall",
		Size = Vector3.new(8, 6, 6),
		Position = at + Vector3.new(0, 3, 0),
		Color = wall,
		Material = Enum.Material.WoodPlanks,
	}, parent).CanCollide = true
	deco({
		Name = "CabanaRoof",
		Size = Vector3.new(9.4, 0.5, 7.4),
		Position = at + Vector3.new(0, 6.3, 0),
		Color = Color3.fromRGB(248, 248, 250),
		Material = Enum.Material.Metal,
	}, parent)
	-- Awning stripes over the front.
	for i = 1, 6 do
		deco({
			Name = "AwningStripe",
			Size = Vector3.new(1.5, 0.3, 3.2),
			CFrame = CFrame.new(at + Vector3.new(-3.75 + (i - 0.5) * 1.5, 5.6, -4.2))
				* CFrame.Angles(-0.3, 0, 0),
			Color = if i % 2 == 0 then Color3.fromRGB(240, 240, 245) else wall:Lerp(Color3.fromRGB(230, 80, 90), 0.6),
			Material = Enum.Material.Fabric,
		}, parent)
	end
	deco({
		Name = "CabanaDoor",
		Size = Vector3.new(2.2, 4, 0.3),
		Position = at + Vector3.new(0, 2, -3.1),
		Color = Color3.fromRGB(96, 72, 52),
		Material = Enum.Material.Wood,
	}, parent)
end

-- Place the area's culture pack. Shore props go on the beach (+Z of the dock
-- head); anything in the water goes wide of the fishing arc so it frames the
-- spots rather than standing in them.
local function buildCulture(index: number, theme: AreaTheme, ox: number, oz: number, parent: Instance)
	if index == 1 then
		-- FLORIDA KEYS MARINA: pastel cabanas along the sand.
		local pastels = {
			Color3.fromRGB(126, 206, 214),
			Color3.fromRGB(246, 186, 140),
			Color3.fromRGB(228, 152, 178),
			Color3.fromRGB(180, 214, 148),
		}
		for i = 1, 4 do
			makeCabana(
				Vector3.new(ox - 78 + (i - 1) * 52, 0, oz + rng:NextNumber(56, 92)),
				pastels[i],
				parent
			)
		end
		-- Pelican pilings out past the dock head: a row of posts with a bird.
		for i = 1, 5 do
			local at = Vector3.new(ox - 62 - i * 7, -1, oz - 30)
			deco({
				Name = "Piling",
				Size = Vector3.new(1.2, 9, 1.2),
				Position = at + Vector3.new(0, 3, 0),
				Color = Color3.fromRGB(96, 76, 58),
				Material = Enum.Material.Wood,
			}, parent)
			if i % 2 == 0 then
				deco({
					Name = "Pelican",
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(1.3, 1.6, 2.6),
					Position = at + Vector3.new(0, 8.2, 0),
					Color = Color3.fromRGB(238, 236, 228),
					Material = Enum.Material.SmoothPlastic,
				}, parent)
				deco({
					Name = "PelicanBill",
					Size = Vector3.new(0.4, 0.4, 2.2),
					Position = at + Vector3.new(0, 8.4, -1.9),
					Color = Color3.fromRGB(246, 196, 90),
					Material = Enum.Material.SmoothPlastic,
				}, parent)
			end
		end
	elseif index == 2 then
		-- SOUTHERN CALIFORNIA KELP COAST. Every species here is a Californian
		-- animal, so this is Monterey/Catalina: a working pier, cannery sheds,
		-- and otters asleep in the canopy.
		makePier(Vector3.new(ox - 72, 0, oz - 6), 74, parent)
		makePier(Vector3.new(ox + 72, 0, oz - 6), 58, parent)
		local walls = { Color3.fromRGB(196, 190, 176), Color3.fromRGB(150, 158, 150), Color3.fromRGB(178, 166, 148) }
		for i = 1, 3 do
			makeShed(
				Vector3.new(ox - 60 + (i - 1) * 60, 0, oz + rng:NextNumber(58, 88)),
				rng:NextNumber(10, 15),
				walls[i],
				Color3.fromRGB(146, 74, 56),
				parent
			)
		end
		-- The otters. Six of them, out among the kelp on both flanks.
		for i = 1, 6 do
			local side = if i % 2 == 0 then 1 else -1
			makeOtter(
				Vector3.new(ox + side * rng:NextNumber(52, 118), 0.5, oz - rng:NextNumber(20, 130)),
				parent
			)
		end
	elseif index == 3 then
		-- POLYNESIAN REEF: tiki totems on the sand, huts out over the water.
		for i = 1, 5 do
			makeTiki(
				Vector3.new(ox - 80 + (i - 1) * 40, 0, oz + rng:NextNumber(46, 62)),
				rng:NextInteger(2, 3),
				parent
			)
		end
		makeStiltHut(Vector3.new(ox - 66, -4, oz - 24), parent)
		makeStiltHut(Vector3.new(ox + 70, -4, oz - 34), parent)
		-- An outrigger canoe pulled up on the sand.
		local canoeAt = Vector3.new(ox + 30, 1.2, oz + 40)
		deco({
			Name = "CanoeHull",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3.0, 2.0, 14),
			Position = canoeAt,
			Color = Color3.fromRGB(104, 72, 46),
			Material = Enum.Material.Wood,
		}, parent)
		deco({
			Name = "CanoeFloat",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.4, 1.2, 9),
			Position = canoeAt + Vector3.new(5.5, -0.3, 0),
			Color = Color3.fromRGB(126, 92, 58),
			Material = Enum.Material.Wood,
		}, parent)
		for _, dz in { -3, 3 } do
			deco({
				Name = "CanoeSpar",
				Size = Vector3.new(6.2, 0.4, 0.4),
				Position = canoeAt + Vector3.new(2.8, 1.1, dz),
				Color = Color3.fromRGB(126, 92, 58),
				Material = Enum.Material.Wood,
			}, parent)
		end
	elseif index == 4 then
		-- DEEP-SEA RESEARCH RIG. Nothing lives up here; people visit.
		makeRig(Vector3.new(ox - 74, 0, oz - 40), parent)
		-- Marker floats and a container yard on the shore.
		for i = 1, 4 do
			deco({
				Name = "Container",
				Size = Vector3.new(12, 5, 5.4),
				CFrame = CFrame.new(ox - 60 + (i - 1) * 42, 2.5, oz + rng:NextNumber(56, 84))
					* CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0),
				Color = ({
					Color3.fromRGB(58, 96, 118),
					Color3.fromRGB(150, 76, 60),
					Color3.fromRGB(96, 108, 88),
					Color3.fromRGB(122, 118, 130),
				})[i],
				Material = Enum.Material.CorrodedMetal,
			}, parent).CanCollide = true
		end
	elseif index == 5 then
		-- RYUGU-JO, the dragon god's palace. The Goblin Shark and the Frilled
		-- Shark are Sagami Bay animals, so the Abyss is Japanese: a torii gate
		-- standing out of black water, stone lanterns, a drowned shrine.
		makeTorii(Vector3.new(ox, -2, oz - 96), 2.2, parent)
		makeTorii(Vector3.new(ox - 96, -2, oz - 40), 1.2, parent)
		for i = 1, 6 do
			local side = if i % 2 == 0 then 1 else -1
			makeStoneLantern(
				Vector3.new(ox + side * 12, 1.1, oz - 4 - math.floor((i - 1) / 2) * 16),
				1.0,
				theme.Spots[3],
				parent
			)
		end
		makeShrine(Vector3.new(ox + 74, -1, oz - 62), parent)
		makeShrine(Vector3.new(ox - 58, -1, oz - 120), parent)
		makeKoinobori(Vector3.new(ox - 30, 0, oz + 50), parent)
		makeKoinobori(Vector3.new(ox + 34, 0, oz + 58), parent)
	end
end

-- A spot for something that GROWS, kept clear of the fishing arc.
--
-- The arc sits at radius 32-42 around (ox, oz - 52) and carries the twelve
-- buoys. Scenery there does not block a cast — everything from `deco` has
-- CanQuery off — but a kelp column is 6 studs of green standing exactly where a
-- marker you are looking for floats, and "I can't find my buoy" is a worse
-- problem than a slightly emptier arc. So: sample, and reroll anything that
-- lands in the band. Bounded retries, because an unbounded loop in map
-- generation is a hang, not a bug.
local function growthSpot(ox: number, oz: number): Vector3
	local center = Vector2.new(ox, oz - 52)
	for _ = 1, 8 do
		local at = Vector2.new(ox + rng:NextNumber(-125, 125), oz - rng:NextNumber(14, 145))
		local distance = (at - center).Magnitude
		if distance < 24 or distance > 50 then
			return Vector3.new(at.X, 0, at.Y)
		end
	end
	-- Fell through: put it well outside the arc rather than give up on it.
	return Vector3.new(ox + rng:NextNumber(-125, 125), 0, oz - rng:NextNumber(96, 145))
end

local function scatterScenery(index: number, theme: AreaTheme, ox: number, oz: number, parent: Instance)
	-- Rock out in the water, off to both sides so it frames the fishing arc
	-- instead of standing in it. Shallow areas get rounded sea stacks; the deep
	-- ones get leaning basalt spires, because "dark beach" is not a trench.
	for i = 1, 6 do
		local side = if i % 2 == 0 then 1 else -1
		local at = Vector3.new(ox + side * rng:NextNumber(58, 120), -3, oz - rng:NextNumber(30, 130))
		if theme.Shore == "Spire" then
			makeSpire(at, rng:NextNumber(22, 46), theme.Water, parent)
		else
			makeSeaStack(at, rng:NextNumber(14, 34), theme.Water, parent)
		end
	end

	-- WHAT GROWS HERE. This is the difference between five areas and one area in
	-- five colours, and it is the first thing a player notices about a new dock.
	--
	-- Everything rooted on the sea floor (y = -6.4) — except the kelp, which is
	-- supposed to reach the surface and mat out across it, because that is what a
	-- kelp forest is and its absence was the specific complaint.
	local growth = theme.Growth
	if growth == "Kelp" then
		-- Fewer than the old strand count and much bigger: a forest is made of
		-- columns you look between, not of scattered weeds.
		for _ = 1, 16 do
			makeKelpColumn(growthSpot(ox, oz), Color3.fromRGB(74, 120, 52), parent)
		end
		-- Low understory between the columns.
		for _ = 1, 14 do
			makeStrand(
				Vector3.new(ox + rng:NextNumber(-120, 120), SEA_FLOOR, oz - rng:NextNumber(10, 140)),
				rng:NextNumber(2.5, 4.5),
				Color3.fromRGB(58, 96, 44),
				Enum.Material.Grass,
				parent
			)
		end
	elseif growth == "Coral" then
		for _ = 1, 18 do
			local at = growthSpot(ox, oz)
			makeCoralHead(Vector3.new(at.X, SEA_FLOOR + 1, at.Z), theme.Spots, parent)
		end
		-- Sea fans: thin, tall, and a completely different silhouette from the
		-- heads, which is what stops a reef reading as one shape repeated.
		for _ = 1, 12 do
			makeStrand(
				Vector3.new(ox + rng:NextNumber(-120, 120), SEA_FLOOR, oz - rng:NextNumber(10, 140)),
				rng:NextNumber(3, 5),
				theme.Spots[rng:NextInteger(1, #theme.Spots)],
				Enum.Material.Sandstone,
				parent
			)
		end
	elseif growth == "Vent" then
		for _ = 1, 9 do
			local at = growthSpot(ox, oz)
			makeVent(Vector3.new(at.X, SEA_FLOOR, at.Z), theme.Spots[rng:NextInteger(1, #theme.Spots)], parent)
		end
		for _ = 1, 16 do
			makeStrand(
				Vector3.new(ox + rng:NextNumber(-120, 120), SEA_FLOOR, oz - rng:NextNumber(10, 140)),
				rng:NextNumber(3, 5.5),
				theme.Spots[1],
				Enum.Material.Neon,
				parent
			)
		end
	elseif growth == "Bone" then
		for _ = 1, 5 do
			local at = growthSpot(ox, oz)
			makeBones(Vector3.new(at.X, SEA_FLOOR + 0.8, at.Z), parent)
		end
		for _ = 1, 6 do
			local at = growthSpot(ox, oz)
			makeVent(Vector3.new(at.X, SEA_FLOOR, at.Z), theme.Spots[rng:NextInteger(1, #theme.Spots)], parent)
		end
		for _ = 1, 18 do
			makeStrand(
				Vector3.new(ox + rng:NextNumber(-120, 120), SEA_FLOOR, oz - rng:NextNumber(10, 140)),
				rng:NextNumber(3, 5.5),
				theme.Spots[rng:NextInteger(1, #theme.Spots)],
				Enum.Material.Neon,
				parent
			)
		end
	else -- Reeds: the shallows. Ordinary green weed, kept under the waterline.
		for _ = 1, 26 do
			makeStrand(
				Vector3.new(ox + rng:NextNumber(-120, 120), SEA_FLOOR, oz - rng:NextNumber(10, 140)),
				rng:NextNumber(3, 5.5),
				Color3.fromRGB(90, 190, 120),
				Enum.Material.Grass,
				parent
			)
		end
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

	-- Two giant fish turning above the water. They are the landmark you can see
	-- from the previous dock, and they advertise what lives here far better than
	-- the price on the Dock Master's list does.
	--
	-- They are REAL SPECIES from this area, in that species' own colours — the
	-- two rarest ones. A generic fish in a theme colour is decoration; a
	-- twenty-stud Megalodon turning over the Abyss is the argument for buying the
	-- Abyss. Every species has its own silhouette now, so this costs one lookup.
	local headline = Crystals.BasesInLayer(index, Crystals.FISH)
	table.sort(headline, function(a, b)
		return a.Value > b.Value
	end)
	for slot, at in { Vector3.new(ox - 52, 15, oz - 62), Vector3.new(ox + 52, 15, oz - 62) } do
		local star = headline[slot]
		local trophy = FishShape.Build({
			Name = if star then star.Name else nil,
			Color = if star then star.Color else theme.Spots[1],
			Scale = rng:NextNumber(2.6, 3.2),
			Seed = math.floor(at.X * 7 + at.Z),
			Glow = 12,
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

local function buildBuoy(
	name: string,
	position: Vector3,
	color: Color3,
	styleName: string?,
	parent: Instance
): BasePart
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

	-- The apex is where the lantern goes, and it is the SAME height for every
	-- hull below. The fishing loop recolours and swells that lamp for cast and
	-- bite, and MiningService hard-codes its size — so the marker's silhouette is
	-- free to change per area, but the working light on top never does.
	local apex = position + Vector3.new(0, 4.5, 0)

	local function fixture(props: { [string]: any }): Part
		local piece = part(props, model)
		piece.CanCollide = false
		piece.CanQuery = false
		return piece
	end

	local METAL = Color3.fromRGB(96, 88, 78)

	local style = styleName or "Ring"
	if style == "Otter" then
		-- KELP FOREST: a crab-pot float with a SEA OTTER asleep on it, shell on
		-- its chest. Every fish in this area is a Southern California animal and
		-- so is the otter — it is the mascot of the place, and a marker you smile
		-- at is a marker you swim towards.
		fixture({
			Name = "Raft",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.9, 5.2, 5.2),
			CFrame = CFrame.new(position + Vector3.new(0, -0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(150, 112, 74),
			Material = Enum.Material.Wood,
		})
		fixture({
			Name = "RaftRim",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.5, 5.6, 5.6),
			CFrame = CFrame.new(position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(206, 186, 140),
			Material = Enum.Material.Fabric,
		})
		makeOtter(position + Vector3.new(0, 0.95, 0), model)
		fixture({
			Name = "Mast",
			Size = Vector3.new(0.42, 4.2, 0.42),
			Position = position + Vector3.new(-1.9, 2.5, 0),
			Color = Color3.fromRGB(120, 92, 62),
			Material = Enum.Material.Wood,
		})
		-- Kelp caught round the raft, because everything out here is.
		for i = 1, 3 do
			local theta = (i / 3) * math.pi * 2
			fixture({
				Name = "TangledKelp",
				Size = Vector3.new(rng:NextNumber(2.5, 4), 0.2, 0.9),
				CFrame = CFrame.new(position + Vector3.new(math.cos(theta) * 2.9, -0.5, math.sin(theta) * 2.9))
					* CFrame.Angles(0, -theta, 0.1),
				Color = Color3.fromRGB(74, 120, 52),
				Material = Enum.Material.Grass,
			})
		end
	elseif style == "Tiki" then
		-- TWILIGHT REEF: a carved tiki head on a bamboo raft, with the lamp as
		-- the fire in its crown. Indo-Pacific reef, Polynesian island.
		for i = 1, 5 do
			fixture({
				Name = "BambooLog",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(5.4, 0.8, 0.8),
				CFrame = CFrame.new(position + Vector3.new(0, -0.35, -1.6 + (i - 1) * 0.8)),
				Color = Color3.fromRGB(206, 178, 116),
				Material = Enum.Material.Wood,
			})
		end
		fixture({
			Name = "TikiHead",
			Size = Vector3.new(2.4, 3.4, 2.2),
			Position = position + Vector3.new(0, 1.7, 0),
			Color = Color3.fromRGB(104, 70, 46),
			Material = Enum.Material.Wood,
		})
		fixture({
			Name = "TikiBrow",
			Size = Vector3.new(2.5, 0.5, 0.45),
			Position = position + Vector3.new(0, 2.5, -1.05),
			Color = Color3.fromRGB(66, 44, 30),
			Material = Enum.Material.Wood,
		})
		for _, side in { 1, -1 } do
			fixture({
				Name = "TikiEye",
				Size = Vector3.new(0.55, 0.55, 0.3),
				Position = position + Vector3.new(side * 0.58, 2.05, -1.1),
				Color = Color3.fromRGB(238, 226, 200),
				Material = Enum.Material.SmoothPlastic,
			})
			-- Tusks at the corners of the mouth.
			fixture({
				Name = "TikiTusk",
				Size = Vector3.new(0.28, 0.7, 0.28),
				Position = position + Vector3.new(side * 0.6, 0.75, -1.05),
				Color = Color3.fromRGB(240, 236, 220),
				Material = Enum.Material.SmoothPlastic,
			})
		end
		fixture({
			Name = "TikiMouth",
			Size = Vector3.new(1.7, 0.65, 0.35),
			Position = position + Vector3.new(0, 1.1, -1.05),
			Color = Color3.fromRGB(228, 210, 180),
			Material = Enum.Material.SmoothPlastic,
		})
		fixture({
			Name = "TikiCrown",
			Size = Vector3.new(2.8, 0.7, 2.5),
			Position = position + Vector3.new(0, 3.6, 0),
			Color = Color3.fromRGB(146, 100, 62),
			Material = Enum.Material.Wood,
		})
	elseif style == "Lantern" then
		-- THE ABYSS: toro nagashi — a stone lantern set adrift. The lamp on top
		-- is already a light in a housing, so here the housing is stone and the
		-- marker is a memorial floating on black water.
		fixture({
			Name = "Raft",
			Size = Vector3.new(4.6, 0.6, 4.6),
			Position = position + Vector3.new(0, -0.3, 0),
			Color = Color3.fromRGB(70, 60, 54),
			Material = Enum.Material.Wood,
		})
		fixture({
			Name = "LanternBase",
			Size = Vector3.new(3.0, 0.8, 3.0),
			Position = position + Vector3.new(0, 0.4, 0),
			Color = Color3.fromRGB(126, 124, 118),
			Material = Enum.Material.Slate,
		})
		fixture({
			Name = "LanternPost",
			Size = Vector3.new(1.0, 2.6, 1.0),
			Position = position + Vector3.new(0, 2.1, 0),
			Color = Color3.fromRGB(148, 146, 138),
			Material = Enum.Material.Slate,
		})
		fixture({
			Name = "LanternPlate",
			Size = Vector3.new(2.6, 0.5, 2.6),
			Position = position + Vector3.new(0, 3.6, 0),
			Color = Color3.fromRGB(148, 146, 138),
			Material = Enum.Material.Slate,
		})
		-- Four corner posts framing the lamp, then the flared roof over it.
		for _, dx in { -1, 1 } do
			for _, dz in { -1, 1 } do
				fixture({
					Name = "LanternMullion",
					Size = Vector3.new(0.3, 1.9, 0.3),
					Position = position + Vector3.new(dx * 0.95, 4.6, dz * 0.95),
					Color = Color3.fromRGB(138, 136, 128),
					Material = Enum.Material.Slate,
				})
			end
		end
		fixture({
			Name = "LanternRoof",
			Size = Vector3.new(3.6, 0.9, 3.6),
			Position = position + Vector3.new(0, 5.9, 0),
			Color = Color3.fromRGB(120, 118, 112),
			Material = Enum.Material.Slate,
		})
		fixture({
			Name = "LanternFinial",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.0, 1.3, 1.0),
			Position = position + Vector3.new(0, 6.7, 0),
			Color = Color3.fromRGB(148, 146, 138),
			Material = Enum.Material.Slate,
		})
	elseif style == "Float" then
		-- KELP FOREST: a working crab-pot buoy. A weathered wooden barrel riding
		-- the surface with rope whipped round it and one plain timber mast. This
		-- is what actually floats over a kelp bed, and it looks like someone's job
		-- rather than someone's harbour.
		fixture({
			Name = "Barrel",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3.0, 2.5, 2.5),
			CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(150, 112, 74):Lerp(color, 0.25),
			Material = Enum.Material.Wood,
		})
		for i = 1, 2 do
			fixture({
				Name = "RopeBand",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.34, 2.66, 2.66),
				CFrame = CFrame.new(position + Vector3.new(0, -0.55 + i * 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(196, 176, 130),
				Material = Enum.Material.Fabric,
			})
		end
		fixture({
			Name = "Mast",
			Size = Vector3.new(0.42, 4.0, 0.42),
			Position = position + Vector3.new(0, 2.6, 0),
			Color = Color3.fromRGB(120, 92, 62),
			Material = Enum.Material.Wood,
		})
		-- Kelp caught round the float, because everything out here is.
		for i = 1, 3 do
			local theta = (i / 3) * math.pi * 2
			fixture({
				Name = "TangledKelp",
				Size = Vector3.new(rng:NextNumber(2.5, 4), 0.2, 0.9),
				CFrame = CFrame.new(position + Vector3.new(math.cos(theta) * 2.2, -0.5, math.sin(theta) * 2.2))
					* CFrame.Angles(0, -theta, 0.1),
				Color = Color3.fromRGB(74, 120, 52),
				Material = Enum.Material.Grass,
			})
		end
	elseif style == "Glass" then
		-- TWILIGHT REEF: a Japanese glass fishing float in a rope net, resting on
		-- a coral knob. Warm, handmade, and see-through, which is the opposite of
		-- the trench's steel and reads instantly as "reef".
		fixture({
			Name = "GlassFloat",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3.6, 3.6, 3.6),
			Position = position + Vector3.new(0, 0.5, 0),
			Color = color:Lerp(Color3.fromRGB(180, 255, 235), 0.4),
			Material = Enum.Material.Glass,
			Transparency = 0.45,
		})
		-- The net: three rings and four verticals, which is enough to read as rope.
		for i = 1, 3 do
			fixture({
				Name = "NetRing",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.16, 3.7 - math.abs(i - 2) * 0.7, 3.7 - math.abs(i - 2) * 0.7),
				CFrame = CFrame.new(position + Vector3.new(0, -0.4 + i * 0.9, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(206, 186, 140),
				Material = Enum.Material.Fabric,
			})
		end
		for i = 1, 4 do
			local theta = (i / 4) * math.pi
			fixture({
				Name = "NetLine",
				Size = Vector3.new(0.16, 3.6, 0.16),
				CFrame = CFrame.new(position + Vector3.new(math.cos(theta) * 1.75, 0.5, math.sin(theta) * 1.75))
					* CFrame.Angles(0, -theta, 0),
				Color = Color3.fromRGB(206, 186, 140),
				Material = Enum.Material.Fabric,
			})
		end
		-- Coral knob under it, tying the marker to the reef it sits on.
		fixture({
			Name = "CoralKnob",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2.6, 1.4, 2.6),
			Position = position + Vector3.new(0, -1.2, 0),
			Color = color,
			Material = Enum.Material.Sandstone,
		})
		fixture({
			Name = "Mast",
			Size = Vector3.new(0.36, 2.6, 0.36),
			Position = position + Vector3.new(0, 3.4, 0),
			Color = Color3.fromRGB(150, 120, 80),
			Material = Enum.Material.Wood,
		})
	elseif style == "Can" then
		-- MIDNIGHT TRENCH: an industrial steel can buoy. Riveted drum, rim, and a
		-- caged lamp — heavy shipping hardware, moored somewhere nothing grows.
		fixture({
			Name = "Can",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3.4, 3.2, 3.2),
			CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(88, 92, 104):Lerp(color, 0.25),
			Material = Enum.Material.DiamondPlate,
		})
		fixture({
			Name = "Rim",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, 3.7, 3.7),
			CFrame = CFrame.new(position + Vector3.new(0, 1.8, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(210, 140, 40),
			Material = Enum.Material.Metal,
		})
		for i = 1, 8 do
			local theta = (i / 8) * math.pi * 2
			fixture({
				Name = "Rivet",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.3, 0.3, 0.3),
				Position = position + Vector3.new(math.cos(theta) * 1.62, 0.5, math.sin(theta) * 1.62),
				Color = Color3.fromRGB(62, 64, 74),
				Material = Enum.Material.Metal,
			})
		end
		-- Cage: three uprights to the apex plus a ring, so the lamp reads as
		-- protected hardware rather than a bulb on a stick.
		for i = 1, 3 do
			local theta = (i / 3) * math.pi * 2
			fixture({
				Name = "CageBar",
				Size = Vector3.new(0.24, 3.4, 0.24),
				Position = position + Vector3.new(math.cos(theta) * 0.85, 2.6, math.sin(theta) * 0.85),
				Color = METAL,
				Material = Enum.Material.Metal,
			})
		end
		fixture({
			Name = "CageRing",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.22, 2.0, 2.0),
			CFrame = CFrame.new(position + Vector3.new(0, 3.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = METAL,
			Material = Enum.Material.Metal,
		})
	elseif style == "Orb" then
		-- THE ABYSS: nothing manufactured survives down here. A black stalk of
		-- bone with a cluster of live lights round its foot and the lantern slung
		-- out front on a curved arm — the marker itself is an anglerfish lure.
		fixture({
			Name = "Stalk",
			Size = Vector3.new(0.6, 4.4, 0.6),
			Position = position + Vector3.new(0, 1.6, 0),
			Color = Color3.fromRGB(46, 44, 58),
			Material = Enum.Material.Slate,
		})
		fixture({
			Name = "Holdfast",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3.0, 1.5, 3.0),
			Position = position + Vector3.new(0, -0.3, 0),
			Color = Color3.fromRGB(38, 36, 50),
			Material = Enum.Material.Slate,
		})
		for i = 1, 6 do
			local theta = (i / 6) * math.pi * 2
			fixture({
				Name = "Bulb",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.6, 0.6, 0.6),
				Position = position
					+ Vector3.new(math.cos(theta) * 1.35, 0.35 + math.sin(theta * 2) * 0.3, math.sin(theta) * 1.35),
				Color = color,
				Material = Enum.Material.Neon,
				Transparency = 0.25,
			})
		end
		-- The lure arm, curving up and forward to the lantern.
		for i = 1, 4 do
			local t = i / 4
			fixture({
				Name = "LureArm",
				Size = Vector3.new(0.34, 0.34, 1.0),
				CFrame = CFrame.new(position + Vector3.new(0, 3.5 + t * 1.0, -t * 0.9))
					* CFrame.Angles(-0.5 + t * 0.3, 0, 0),
				Color = Color3.fromRGB(52, 50, 64),
				Material = Enum.Material.Slate,
			})
		end
	else
		-- SUNNY SHALLOWS: the classic harbour ring buoy on a tripod.
		--
		-- Roblox has no torus, and a ring is the single thing that makes a buoy
		-- read as a buoy — sixteen segments is past the point where anyone can see
		-- the seams from the dock. A cylinder's axis is its X, so each segment is
		-- turned to put that axis along the tangent of the circle at its angle.
		-- Painted in four alternating quadrants, life-ring style, rather than with
		-- a separate white band over every segment: it is the bolder read at the
		-- thirty studs you actually see these from and it costs half the parts.
		local segmentLength = 2 * RING_RADIUS * math.sin(math.pi / RING_SEGMENTS) * 1.25
		local perQuadrant = RING_SEGMENTS / 4
		for i = 1, RING_SEGMENTS do
			local theta = (i - 1) / RING_SEGMENTS * math.pi * 2
			local at = position + Vector3.new(math.cos(theta) * RING_RADIUS, 0, math.sin(theta) * RING_RADIUS)
			local white = math.floor((i - 1) / perQuadrant) % 2 == 1
			fixture({
				Name = "Ring",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(segmentLength, RING_TUBE, RING_TUBE),
				CFrame = CFrame.new(at) * CFrame.Angles(0, -theta - math.pi * 0.5, 0),
				Color = if white then Color3.fromRGB(248, 248, 250) else color,
				Material = Enum.Material.SmoothPlastic,
			})
		end
		-- Tripod: three legs leaning in from the ring to meet under the lantern.
		for i = 1, 3 do
			local theta = (i - 1) / 3 * math.pi * 2 + math.pi * 0.5
			local foot = position
				+ Vector3.new(math.cos(theta) * (RING_RADIUS - 0.35), 0.3, math.sin(theta) * (RING_RADIUS - 0.35))
			local span = (apex - foot).Magnitude
			fixture({
				Name = "Leg",
				Size = Vector3.new(0.34, 0.34, span),
				-- lookAt aims the part's -Z down its own length, so a part sized on
				-- Z stretches exactly from the foot to the apex however far that is.
				CFrame = CFrame.lookAt((foot + apex) * 0.5, apex),
				-- Tinted toward the area's colour rather than left bare metal. The
				-- silhouette should be a real buoy; the palette should still look
				-- like a game a twelve-year-old wants to be in.
				Color = METAL:Lerp(color, 0.3),
				Material = Enum.Material.Metal,
			})
		end
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
	sparkle.LightEmission = 0.3
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

-- A VISTA: the next area, seen from this one's dock.
--
-- Five stretches of water 600 studs apart are five separate rooms, and standing
-- on the first dock the horizon was empty in every direction — which reads as
-- "this is all there is" at exactly the moment the game wants you thinking about
-- what you are saving for. The Dock Master can list the Abyss at three million
-- coins; a shape on the horizon in the Abyss's own colours is a far better
-- argument, because you found it yourself.
--
-- Deliberately far out and deliberately coarse: it is scenery to look at, not a
-- place to swim to. Nothing collides, nothing answers a raycast, and it sits
-- well past the fishing arc so it can never be mistaken for somewhere to cast.
local function buildVista(theme: AreaTheme, name: string, layer: number, ox: number, oz: number, parent: Instance)
	local at = Vector3.new(ox + rng:NextNumber(-60, 60), 0, oz - 420)

	-- An island: stacked rock in the target area's palette, big enough to read
	-- through the haze.
	for i = 1, 9 do
		local t = (i - 1) / 9
		local width = (52 - t * 40) * rng:NextNumber(0.8, 1.2)
		local rock = deco({
			Name = "VistaRock",
			Size = Vector3.new(width, 16, width * rng:NextNumber(0.7, 1.3)),
			CFrame = CFrame.new(at + Vector3.new(rng:NextNumber(-16, 16), i * 11 - 12, rng:NextNumber(-16, 16)))
				* CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			Color = Color3.fromRGB(88, 86, 96):Lerp(theme.Water, 0.4),
			Material = Enum.Material.Rock,
		}, parent)
		rock.CastShadow = false
	end

	-- A beacon on top in the area's own colour, so it is identifiable at a
	-- glance and legible at night.
	local beacon = deco({
		Name = "VistaBeacon",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(14, 14, 14),
		Position = at + Vector3.new(0, 104, 0),
		Color = theme.Spots[1],
		Material = Enum.Material.Neon,
		Transparency = 0.45,
	}, parent)
	local light = Instance.new("PointLight")
	light.Color = theme.Spots[1]
	light.Range = 26
	light.Brightness = 0.5
	light.Shadows = false
	light.Parent = beacon

	-- And its name, floating above it. A landmark you can identify is a goal;
	-- an unnamed rock is set dressing.
	local sign = Instance.new("BillboardGui")
	sign.Name = "VistaName"
	sign.Size = UDim2.fromScale(46, 9)
	sign.StudsOffset = Vector3.new(0, 22, 0)
	sign.AlwaysOnTop = false
	sign.MaxDistance = 900
	sign.Parent = beacon
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = name
	label.TextColor3 = theme.Spots[1]
	label.TextScaled = true
	label.TextStrokeTransparency = 0.4
	label.Parent = sign

	-- A couple of giant fish circling it, in the water you cannot fish yet. Real
	-- species again, so what you can make out on the horizon is genuinely what
	-- swims there — the Abyss advertises itself with a Megalodon.
	local headline = Crystals.BasesInLayer(layer, Crystals.FISH)
	table.sort(headline, function(a, b)
		return a.Value > b.Value
	end)
	for i = 1, 2 do
		local star = headline[i]
		local trophy = FishShape.Build({
			Name = if star then star.Name else nil,
			Color = if star then star.Color else theme.Spots[math.min(i + 1, #theme.Spots)],
			Scale = rng:NextNumber(5, 7),
			Seed = math.floor(at.X) + i * 31,
			Neon = true,
		})
		trophy.Name = "VistaFish"
		trophy:PivotTo(
			CFrame.new(at + Vector3.new(rng:NextNumber(-80, 80), rng:NextNumber(34, 70), rng:NextNumber(-40, 40)))
				* CFrame.Angles(0, rng:NextNumber(0, 6), 0)
		)
		trophy.Parent = parent
		CollectionService:AddTag(trophy, "SpinCrystal")
		trophy:SetAttribute("SpinSpeed", rng:NextNumber(0.05, 0.1))
		trophy:SetAttribute("BobHeight", rng:NextNumber(3, 6))
		trophy:SetAttribute("BobSpeed", rng:NextNumber(0.2, 0.35))
	end
end

-- One area: its own water, its own beach, its own dock, its own twelve buoys.
-- Areas are built side by side along X rather than stitched together, because
-- travel between them is by boat (a teleport) — there is no walk to preserve, so
-- there is no reason to pay for contiguous terrain.
--
-- Returns the area's fishing spots, all tagged with an `Area` attribute so one
-- MiningService can serve every area from a single flat node list.
local function buildArea(index: number, origin: Vector3, parent: Instance): { Spots: { BasePart }, Stations: { [string]: ProximityPrompt } }
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

	-- What stands on the shore. A palm on the Kelp Forest beach was the single
	-- most obviously wrong thing in the map: that area is a cold northern cove.
	if theme.Shore == "Pine" then
		for _ = 1, 12 do
			makePine(Vector3.new(ox + rng:NextNumber(-115, 115), 0, oz + rng:NextNumber(38, 104)), parent)
		end
	elseif theme.Shore == "Spire" then
		-- Nothing grows. Rock comes up out of the beach instead.
		for _ = 1, 9 do
			makeSpire(
				Vector3.new(ox + rng:NextNumber(-118, 118), -1, oz + rng:NextNumber(42, 104)),
				rng:NextNumber(14, 30),
				theme.Water,
				parent
			)
		end
	elseif theme.Shore == "Rock" then
		for _ = 1, 8 do
			makeSeaStack(
				Vector3.new(ox + rng:NextNumber(-115, 115), -1, oz + rng:NextNumber(42, 102)),
				rng:NextNumber(8, 18),
				theme.Sand,
				parent
			)
		end
	end
	for _ = 1, theme.Palms do
		makePalm(Vector3.new(ox + rng:NextNumber(-110, 110), 0, oz + rng:NextNumber(40, 100)), parent)
	end
	scatterScenery(index, theme, ox, oz, parent)
	buildCulture(index, theme, ox, oz, parent)

	-- Show this dock what comes next. The last area has nothing after it, so it
	-- gets its own colours reflected back instead of an empty horizon — the Abyss
	-- being the end of the map is the point, but "the end" should still look like
	-- somewhere rather than like the world running out.
	local nextIndex = math.min(index + 1, Balance.MaxLayer)
	local nextTheme = AREA_THEMES[nextIndex] or theme
	buildVista(nextTheme, Balance.LayerNames[nextIndex] or "", nextIndex, ox, oz, parent)

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
		local spot = buildBuoy(("Spot%d_%d"):format(index, i), position, color, theme.Buoy, nodeFolder)
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

	-- A DOCK MASTER ON EVERY DOCK. Travel used to be a one-way trip: the only
	-- Dock Master stood on the home beach, so once you sailed to the Kelp Forest
	-- the only way back was the bottom bar. Sailing somewhere should not be a
	-- thing you can strand yourself with, and the station is the place a player
	-- already looks for it. The prompt carries a Station attribute and the client
	-- opens the screen from that, so five of them cost nothing to wire.
	-- THE FULL STATION SET, IN EVERY AREA. All five stations used to stand on
	-- the home beach only, so sailing to the Kelp Forest meant fishing until the
	-- hold filled and then sailing home to do anything with it. Areas 2-5 were
	-- water with no town attached.
	--
	-- The prompts carry a Station attribute and the client opens the screen from
	-- that, so five sets cost nothing to wire — and every deck is built out of
	-- whatever this area is made of, so the town looks like it belongs to the
	-- water it stands on.
	local crack = makeStation(Vector3.new(ox - 34, 0.5, oz + 30), "Treasure Chests", "Crack", Color3.fromRGB(255, 170, 40), parent, theme)
	local racks = makeStation(Vector3.new(ox, 0.5, oz + 40), "Aquarium", "Racks", Color3.fromRGB(120, 255, 200), parent, theme)
	local shop = makeStation(Vector3.new(ox + 34, 0.5, oz + 30), "Chest Shop", "Shop", Color3.fromRGB(120, 170, 255), parent, theme)
	local rebirth = makeStation(Vector3.new(ox, 0.5, oz + 78), "Set Sail", "Rebirth", Color3.fromRGB(255, 120, 255), parent, theme)
	local dock = makeStation(
		Vector3.new(ox - 16, 0.5, oz - 8),
		"Dock Master",
		"Dock",
		Color3.fromRGB(120, 200, 255),
		parent,
		theme
	)

	-- INVISIBLE WALLS around the area's own patch of sea. Terrain runs out at
	-- 140 studs either side and the water is swimmable, so a player heading away
	-- from the dock just kept going and fell out of the world. Roblox lets you do
	-- that; an eight-year-old on a phone should not have to know it.
	--
	-- Set well outside the fishing arc (radius 42) and the vista (420 out is
	-- scenery, deliberately unreachable), so nothing you can actually interact
	-- with is behind a wall.
	local BOUND_X, BOUND_NEAR, BOUND_FAR = 138, 126, 152
	local walls: { { pos: Vector3, size: Vector3 } } = {
		{ pos = Vector3.new(ox - BOUND_X, 24, oz - 12), size = Vector3.new(2, 80, 300) },
		{ pos = Vector3.new(ox + BOUND_X, 24, oz - 12), size = Vector3.new(2, 80, 300) },
		{ pos = Vector3.new(ox, 24, oz - BOUND_FAR), size = Vector3.new(2 * BOUND_X, 80, 2) },
		{ pos = Vector3.new(ox, 24, oz + BOUND_NEAR), size = Vector3.new(2 * BOUND_X, 80, 2) },
	}
	for i, wall in walls do
		local barrier = part({
			Name = "Barrier" .. index .. "_" .. i,
			Size = wall.size,
			Position = wall.pos,
			Transparency = 1,
		}, parent)
		barrier.CanCollide = true
		-- A cast aimed past the edge of the world must not stop dead on the wall.
		barrier.CanQuery = false
		barrier.CanTouch = false
	end

	return {
		Spots = nodes,
		Stations = { Crack = crack, Racks = racks, Shop = shop, Rebirth = rebirth, Dock = dock },
	}
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
	local stationSets: { { [string]: ProximityPrompt } } = {}
	for index = 1, Balance.MaxLayer do
		local origin = Vector3.new((index - 1) * Balance.AreaSpacing, 0, 0)
		origins[index] = Vector3.new(origin.X, 1.6, -40) -- the dock, where boats land
		local area = buildArea(index, origin, map)
		for _, spot in area.Spots do
			table.insert(nodes, spot)
		end
		stationSets[index] = area.Stations
	end


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
		CrackPrompt = stationSets[1].Crack,
		RackPrompt = stationSets[1].Racks,
		ShopPrompt = stationSets[1].Shop,
		RebirthPrompt = stationSets[1].Rebirth,
		-- Every area has a full set; the home beach's is the one callers mean.
		DockPrompt = stationSets[1].Dock,
		BoardRebirths = boardRebirths,
		BoardRarest = boardRarest,
	}
end

return MapBuilder
