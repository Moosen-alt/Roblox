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
local CrystalShape = require(Shared.CrystalShape)

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

local SPOT_COLORS = {
	Color3.fromRGB(255, 120, 120),
	Color3.fromRGB(120, 220, 255),
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(120, 255, 160),
	Color3.fromRGB(255, 150, 220),
	Color3.fromRGB(180, 160, 255),
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

local function setLighting()
	Lighting.ClockTime = 15.5
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(140, 140, 150)
	Lighting.OutdoorAmbient = Color3.fromRGB(130, 140, 160)
	Lighting.FogColor = Color3.fromRGB(190, 220, 245)
	Lighting.FogEnd = 900
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Color = Color3.fromRGB(199, 224, 255)
	atmosphere.Haze = 1.2
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
	for _, x in { -2.1, 2.1 } do
		deco({
			Name = "TableLeg",
			Size = Vector3.new(0.5, 0.6, 2.6),
			Position = position + Vector3.new(x, 0.8, 3.2),
			Color = DARK_WOOD,
			Material = Enum.Material.Wood,
		}, parent)
	end
	deco({
		Name = "AquariumTable",
		Size = Vector3.new(5, 0.6, 3),
		Position = position + Vector3.new(0, 1.4, 3.2),
		Color = WOOD,
		Material = Enum.Material.WoodPlanks,
	}, parent)
	deco({
		Name = "AquariumWater",
		Size = Vector3.new(4.1, 1.7, 2.1),
		Position = position + Vector3.new(0, 2.6, 3.2),
		Color = Color3.fromRGB(70, 160, 235),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.45,
	}, parent)
	deco({
		Name = "AquariumGlass",
		Size = Vector3.new(4.4, 2.4, 2.4),
		Position = position + Vector3.new(0, 2.9, 3.2),
		Color = Color3.fromRGB(170, 225, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.55,
	}, parent)
	for i, x in { -0.9, 0.8 } do
		local relic = CrystalShape.Build({
			Color = SPOT_COLORS[rng:NextInteger(1, #SPOT_COLORS)],
			Scale = 0.3,
			Shards = 4,
			Segments = 2,
			Seed = 90 + i * 7,
			Glow = 8,
		})
		relic.Name = "TankRelic"
		relic:PivotTo(CFrame.new(position + Vector3.new(x, 1.9, 3.2)))
		relic.Parent = parent
	end
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

	-- A sign at the head of the dock, so you always know what water you are in.
	local sign = part({
		Name = "AreaSign" .. index,
		Size = Vector3.new(18, 5, 0.6),
		CFrame = CFrame.lookAt(Vector3.new(ox, 6, oz - 4), Vector3.new(ox, 6, oz - 40)),
		Color = Color3.fromRGB(90, 65, 45),
		Material = Enum.Material.Wood,
	}, parent)
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
		local position =
			Vector3.new(ox + math.cos(angle) * radius, -0.2, oz - 52 + math.sin(angle) * radius)
		local color = theme.Spots[rng:NextInteger(1, #theme.Spots)]
		local spot = part({
			Name = ("Spot%d_%d"):format(index, i),
			Size = Vector3.new(3, 2, 3),
			Position = position,
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.05,
			Shape = Enum.PartType.Ball,
		}, nodeFolder)
		spot:SetAttribute("NodeIndex", i)
		spot:SetAttribute("Area", index)
		spot.CanCollide = false
		local glow = Instance.new("PointLight")
		glow.Color = color
		glow.Range = 12
		glow.Brightness = 1
		glow.Parent = spot
		local click = Instance.new("ClickDetector")
		click.MaxActivationDistance = Balance.CastRange
		click.Parent = spot
		-- Buoys ride the swell. The bob runs on each client, so sixty floating
		-- markers across five areas cost the server nothing.
		CollectionService:AddTag(spot, "SpinCrystal")
		spot:SetAttribute("SpinSpeed", 0)
		spot:SetAttribute("BobHeight", rng:NextNumber(0.5, 0.9))
		spot:SetAttribute("BobSpeed", rng:NextNumber(0.9, 1.5))
		table.insert(nodes, spot)
	end

	-- Landmark crystals turning above the water: something to look at on the walk
	-- down the dock, and a hint of what is down there.
	for _, at in { Vector3.new(ox - 46, 12, oz - 58), Vector3.new(ox + 46, 12, oz - 58) } do
		local crystal = CrystalShape.Build({
			Color = theme.Spots[rng:NextInteger(1, #theme.Spots)],
			Scale = rng:NextNumber(2.4, 3.2),
			Shards = 6,
			Segments = 3,
			Seed = math.floor(at.X * 7 + at.Z),
			Glow = 34,
			Sparkle = true,
		})
		crystal.Name = "Landmark" .. index
		crystal:PivotTo(CFrame.new(at))
		crystal.Parent = parent
		CollectionService:AddTag(crystal, "SpinCrystal")
		crystal:SetAttribute("SpinSpeed", rng:NextNumber(0.18, 0.32))
		crystal:SetAttribute("BobHeight", rng:NextNumber(1.2, 2.2))
		crystal:SetAttribute("BobSpeed", rng:NextNumber(0.5, 0.8))
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
