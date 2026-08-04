--!strict
-- Builds the entire world procedurally so the whole game lives in code:
-- cave floor, glowing mine wall with deposit nodes, three station pads,
-- leaderboard boards, spawn, and lighting. Returns references for services.

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

local NODE_COLORS = {
	Color3.fromRGB(170, 110, 240),
	Color3.fromRGB(60, 220, 130),
	Color3.fromRGB(60, 120, 255),
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(150, 255, 245),
	Color3.fromRGB(255, 60, 80),
}

local rng = Random.new(20260804)

local function part(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function setLighting()
	-- Moody cave, but never so dark that the floor/stations vanish on low
	-- graphics settings — dark scenes read as "broken" to new players.
	Lighting.ClockTime = 0
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(72, 68, 102)
	Lighting.OutdoorAmbient = Color3.fromRGB(62, 58, 92)
	Lighting.FogColor = Color3.fromRGB(28, 24, 52)
	Lighting.FogEnd = 650
	Lighting.GlobalShadows = true
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Color = Color3.fromRGB(90, 80, 140)
	atmosphere.Haze = 1.3
	atmosphere.Parent = Lighting
end

local function makeCrystalCluster(position: Vector3, color: Color3, scale: number, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "CrystalCluster"
	for i = 1, 4 do
		local height = (2 + rng:NextNumber() * 3) * scale
		local shard = part({
			Name = "Shard" .. i,
			Size = Vector3.new(0.8 * scale, height, 0.8 * scale),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.1,
			CFrame = CFrame.new(position + Vector3.new(rng:NextNumber(-1, 1) * scale, height / 2 - 0.5, rng:NextNumber(-1, 1) * scale))
				* CFrame.Angles(rng:NextNumber(-0.35, 0.35), rng:NextNumber(0, 6.28), rng:NextNumber(-0.35, 0.35)),
		}, model)
		shard.CanCollide = false
	end
	model.Parent = parent
	return model
end

local function makeStation(position: Vector3, title: string, stationKey: string, color: Color3, parent: Instance): ProximityPrompt
	local pad = part({
		Name = title .. "Pad",
		Size = Vector3.new(10, 1, 10),
		Position = position,
		Color = Color3.fromRGB(40, 38, 60),
		Material = Enum.Material.Slate,
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
	makeCrystalCluster(position + Vector3.new(0, 1, -3.5), color, 0.9, parent)

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 24
	light.Brightness = 1.4
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
		Color = Color3.fromRGB(24, 22, 38),
		Material = Enum.Material.SmoothPlastic,
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

	-- Floor
	part({
		Name = "Floor",
		Size = Vector3.new(220, 4, 160),
		Position = Vector3.new(0, -2, 0),
		Color = Color3.fromRGB(45, 40, 58),
		Material = Enum.Material.Slate,
	}, map)

	-- Back wall (the mine wall) and side dressing
	part({
		Name = "MineWall",
		Size = Vector3.new(200, 44, 10),
		Position = Vector3.new(0, 22, -70),
		Color = Color3.fromRGB(58, 50, 74),
		Material = Enum.Material.Rock,
	}, map)

	-- Full cave enclosure: walls on every side + ceiling, so it reads as a
	-- cavern instead of a platform floating in the skybox.
	local ROCK = Color3.fromRGB(48, 42, 62)
	part({ Name = "CaveCeiling", Size = Vector3.new(224, 6, 164), Position = Vector3.new(0, 54, 0), Color = ROCK, Material = Enum.Material.Rock }, map)
	part({ Name = "CaveWallLeft", Size = Vector3.new(8, 60, 164), Position = Vector3.new(-110, 26, 0), Color = ROCK, Material = Enum.Material.Rock }, map)
	part({ Name = "CaveWallRight", Size = Vector3.new(8, 60, 164), Position = Vector3.new(110, 26, 0), Color = ROCK, Material = Enum.Material.Rock }, map)
	part({ Name = "CaveWallFront", Size = Vector3.new(224, 60, 8), Position = Vector3.new(0, 26, 78), Color = ROCK, Material = Enum.Material.Rock }, map)
	part({ Name = "CaveWallBack", Size = Vector3.new(224, 60, 8), Position = Vector3.new(0, 26, -76), Color = ROCK, Material = Enum.Material.Rock }, map)

	-- Stalactites (some with glowing crystal tips that light the cavern) and
	-- stalagmites rising near the walls.
	for i = 1, 16 do
		local height = rng:NextNumber(6, 14)
		local width = rng:NextNumber(2, 4)
		local x = rng:NextNumber(-100, 100)
		local z = rng:NextNumber(-60, 70)
		local stalactite = part({
			Name = "Stalactite" .. i,
			Size = Vector3.new(width, height, width),
			CFrame = CFrame.new(x, 51 - height / 2, z) * CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.06, 0.06)),
			Color = ROCK,
			Material = Enum.Material.Rock,
		}, map)
		stalactite.CanCollide = false
		if i % 3 == 0 then
			local tipColor = NODE_COLORS[rng:NextInteger(1, #NODE_COLORS)]
			local tip = part({
				Name = "StalactiteTip" .. i,
				Size = Vector3.new(width * 0.5, 2.4, width * 0.5),
				CFrame = stalactite.CFrame * CFrame.new(0, -height / 2 - 0.8, 0) * CFrame.Angles(0.3, rng:NextNumber(0, 6.28), 0.3),
				Color = tipColor,
				Material = Enum.Material.Neon,
				Transparency = 0.15,
			}, map)
			tip.CanCollide = false
			local tipLight = Instance.new("PointLight")
			tipLight.Color = tipColor
			tipLight.Range = 28
			tipLight.Brightness = 0.9
			tipLight.Parent = tip
		end
	end
	for i = 1, 8 do
		local height = rng:NextNumber(4, 9)
		local width = rng:NextNumber(2.5, 5)
		local x = rng:NextNumber(-102, 102)
		local z = rng:NextNumber(-55, 70)
		if math.abs(x) > 45 or z > 50 then
			local stalagmite = part({
				Name = "Stalagmite" .. i,
				Size = Vector3.new(width, height, width),
				CFrame = CFrame.new(x, height / 2 - 0.5, z) * CFrame.Angles(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.08, 0.08)),
				Color = ROCK,
				Material = Enum.Material.Rock,
			}, map)
			stalagmite.CanCollide = true
		end
	end

	-- Drifting dust motes + soft fill lights so the enclosed cave never goes black
	local dustSource = part({
		Name = "DustSource",
		Size = Vector3.new(200, 1, 140),
		Position = Vector3.new(0, 44, 0),
		Transparency = 1,
	}, map)
	dustSource.CanCollide = false
	local dust = Instance.new("ParticleEmitter")
	dust.Color = ColorSequence.new(Color3.fromRGB(200, 190, 235))
	dust.Size = NumberSequence.new(0.25, 0.1)
	dust.Transparency = NumberSequence.new(0.75, 1)
	dust.Lifetime = NumberRange.new(6, 11)
	dust.Rate = 10
	dust.Speed = NumberRange.new(1, 2.5)
	dust.EmissionDirection = Enum.NormalId.Bottom
	dust.LockedToPart = false
	dust.Parent = dustSource
	for _, offset in { Vector3.new(-55, 40, -30), Vector3.new(55, 40, -30), Vector3.new(-55, 40, 40), Vector3.new(55, 40, 40) } do
		local fillPart = part({ Name = "FillLight", Size = Vector3.new(1, 1, 1), Position = offset, Transparency = 1 }, map)
		fillPart.CanCollide = false
		local fill = Instance.new("PointLight")
		fill.Color = Color3.fromRGB(150, 135, 200)
		fill.Range = 70
		fill.Brightness = 0.45
		fill.Shadows = false
		fill.Parent = fillPart
	end
	for _ = 1, 14 do
		local x = rng:NextNumber(-100, 100)
		local z = rng:NextNumber(-40, 70)
		if math.abs(x) > 24 or z > 30 then
			local color = NODE_COLORS[rng:NextInteger(1, #NODE_COLORS)]
			makeCrystalCluster(Vector3.new(x, 0, z), color, rng:NextNumber(0.6, 1.6), map)
		end
	end

	-- Deposit nodes along the wall face
	local nodes: { BasePart } = {}
	local nodeFolder = Instance.new("Folder")
	nodeFolder.Name = "Nodes"
	nodeFolder.Parent = map
	for i = 1, 12 do
		local x = -82 + (i - 1) * 15
		local color = NODE_COLORS[rng:NextInteger(1, #NODE_COLORS)]
		local node = part({
			Name = "Node" .. i,
			Size = Vector3.new(6, 6, 3),
			Position = Vector3.new(x, 5, -64),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.05,
		}, nodeFolder)
		node:SetAttribute("NodeIndex", i)
		local sparkle = Instance.new("PointLight")
		sparkle.Color = color
		sparkle.Range = 14
		sparkle.Brightness = 1
		sparkle.Parent = node
		local click = Instance.new("ClickDetector")
		click.MaxActivationDistance = 26
		click.Parent = node
		table.insert(nodes, node)
	end

	-- Stations
	local crackPrompt = makeStation(Vector3.new(-34, 0.5, -20), "Crack Station", "Crack", Color3.fromRGB(255, 170, 40), map)
	local rackPrompt = makeStation(Vector3.new(0, 0.5, -10), "Crystal Racks", "Racks", Color3.fromRGB(120, 255, 200), map)
	local shopPrompt = makeStation(Vector3.new(34, 0.5, -20), "Geode Shop", "Shop", Color3.fromRGB(120, 170, 255), map)
	local rebirthPrompt = makeStation(Vector3.new(0, 0.5, 42), "Recrystallize", "Rebirth", Color3.fromRGB(255, 120, 255), map)

	-- Leaderboards
	local boardRebirths = makeBoard(Vector3.new(-70, 7, 30), Vector3.new(0, 7, 0), "Top Recrystallizers", map)
	local boardRarest = makeBoard(Vector3.new(70, 7, 30), Vector3.new(0, 7, 0), "Rarest Finds", map)

	-- Spawn: three steps from the mine wall, facing it (first geode in seconds)
	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(0, 0.5, -48)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Color = Color3.fromRGB(60, 56, 84)
	spawn.Material = Enum.Material.Slate
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
