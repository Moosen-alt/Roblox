--!strict
-- Builds the entire world procedurally so the whole game lives in code:
-- a beach with a wooden dock over real terrain water, glowing fishing spots,
-- station pads, leaderboard boards, spawn, and lighting.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local MapBuilder = {}

export type MapRefs = {
	Nodes: { BasePart },
	CrackPrompt: ProximityPrompt,
	RackPrompt: ProximityPrompt,
	ShopPrompt: ProximityPrompt,
	RebirthPrompt: ProximityPrompt,
	BoardRebirths: BasePart,
	BoardRarest: BasePart,
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

local function makeStation(position: Vector3, title: string, stationKey: string, color: Color3, parent: Instance): ProximityPrompt
	local pad = part({
		Name = title .. "Pad",
		Size = Vector3.new(10, 1, 10),
		Position = position,
		Color = Color3.fromRGB(210, 185, 140),
		Material = Enum.Material.WoodPlanks,
	}, parent)
	local ring = part({
		Name = "Ring",
		Size = Vector3.new(11, 0.4, 11),
		Position = position + Vector3.new(0, 0.4, 0),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
	}, parent)
	ring.CanCollide = false

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

function MapBuilder.Build(): MapRefs
	setLighting()
	local map = Instance.new("Folder")
	map.Name = "GeneratedMap"

	-- Terrain: sandy beach shelf + a lagoon of real water in front of it
	local terrain = Workspace.Terrain
	terrain:FillBlock(CFrame.new(0, -6, 60), Vector3.new(280, 12, 140), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(0, -10, -70), Vector3.new(280, 12, 160), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(0, -3.2, -70), Vector3.new(280, 6, 160), Enum.Material.Water)

	-- Beach floor (walkable) and dock over the water
	part({
		Name = "Beach",
		Size = Vector3.new(240, 1, 110),
		Position = Vector3.new(0, -0.5, 62),
		Color = Color3.fromRGB(232, 214, 165),
		Material = Enum.Material.Sand,
	}, map)
	part({
		Name = "Dock",
		Size = Vector3.new(14, 1, 70),
		Position = Vector3.new(0, 0.6, -20),
		Color = Color3.fromRGB(160, 120, 80),
		Material = Enum.Material.WoodPlanks,
	}, map)
	part({
		Name = "DockT",
		Size = Vector3.new(60, 1, 12),
		Position = Vector3.new(0, 0.6, -52),
		Color = Color3.fromRGB(160, 120, 80),
		Material = Enum.Material.WoodPlanks,
	}, map)
	for _ = 1, 8 do
		makePalm(Vector3.new(rng:NextNumber(-110, 110), 0, rng:NextNumber(40, 100)), map)
	end

	-- Fishing spots: glowing buoys floating in an arc around the dock head
	local nodes: { BasePart } = {}
	local nodeFolder = Instance.new("Folder")
	nodeFolder.Name = "Nodes"
	nodeFolder.Parent = map
	for i = 1, 12 do
		local angle = math.rad(180 + (i - 1) * (180 / 11))
		local radius = 32 + (i % 2) * 10
		local position = Vector3.new(math.cos(angle) * radius, -0.2, -52 + math.sin(angle) * radius)
		local color = SPOT_COLORS[rng:NextInteger(1, #SPOT_COLORS)]
		local spot = part({
			Name = "Spot" .. i,
			Size = Vector3.new(3, 2, 3),
			Position = position,
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.05,
			Shape = Enum.PartType.Ball,
		}, nodeFolder)
		spot:SetAttribute("NodeIndex", i)
		spot.CanCollide = false
		local glow = Instance.new("PointLight")
		glow.Color = color
		glow.Range = 12
		glow.Brightness = 1
		glow.Parent = spot
		local click = Instance.new("ClickDetector")
		click.MaxActivationDistance = 60
		click.Parent = spot
		table.insert(nodes, spot)
	end

	-- Stations on the beach
	local crackPrompt = makeStation(Vector3.new(-34, 0.5, 30), "Treasure Chests", "Crack", Color3.fromRGB(255, 170, 40), map)
	local rackPrompt = makeStation(Vector3.new(0, 0.5, 40), "Aquarium", "Racks", Color3.fromRGB(120, 255, 200), map)
	local shopPrompt = makeStation(Vector3.new(34, 0.5, 30), "Chest Shop", "Shop", Color3.fromRGB(120, 170, 255), map)
	local rebirthPrompt = makeStation(Vector3.new(0, 0.5, 78), "Set Sail", "Rebirth", Color3.fromRGB(255, 120, 255), map)

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

	map.Parent = Workspace

	return {
		Nodes = nodes,
		CrackPrompt = crackPrompt,
		RackPrompt = rackPrompt,
		ShopPrompt = shopPrompt,
		RebirthPrompt = rebirthPrompt,
		BoardRebirths = boardRebirths,
		BoardRarest = boardRarest,
	}
end

return MapBuilder
