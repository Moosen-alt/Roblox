--!strict
-- Builds the entire world procedurally so the whole game lives in code:
-- cave floor, glowing mine wall with deposit nodes, three station pads,
-- leaderboard boards, spawn, and lighting. Returns references for services.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrystalShape = require(Shared.CrystalShape)
local GeodeNode = require(script.Parent.GeodeNode)

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

-- NOTE: unlike GeodeNode's helper, this one leaves CanQuery at the Roblox
-- default of true. Anything invisible or overhead that a tap-ray could cross on
-- its way to a geode must set CanQuery = false explicitly, or it silently eats
-- the tap (MiningInput drops any hit without a NodeIndex attribute).
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
	local model = CrystalShape.Build({
		Color = color,
		Scale = scale,
		Shards = 5,
		Segments = 2,
		Seed = math.floor(position.X * 13 + position.Z * 7),
		Glow = 14 * scale,
	})
	model.Name = "CrystalCluster"
	model:PivotTo(CFrame.new(position))
	model.Parent = parent
	return model
end

-- Big, slowly turning crystals floating over the cave floor. Pure eye candy —
-- the spin and bob run on each client (tags below), so they cost no bandwidth.
local function makeFloatingCrystal(position: Vector3, color: Color3, scale: number, parent: Instance)
	local model = CrystalShape.Build({
		Color = color,
		Scale = scale,
		Shards = 6,
		Segments = 3,
		Seed = math.floor(position.X * 5 + position.Z * 11),
		Glow = 34,
		Sparkle = true,
	})
	model.Name = "FloatingCrystal"
	model:PivotTo(CFrame.new(position))
	model.Parent = parent
	CollectionService:AddTag(model, "SpinCrystal")
	model:SetAttribute("SpinSpeed", rng:NextNumber(0.18, 0.35))
	model:SetAttribute("BobHeight", rng:NextNumber(1.2, 2.4))
	model:SetAttribute("BobSpeed", rng:NextNumber(0.5, 0.9))
end

--------------------------------------------------------------------------------
-- Station furniture. Each station reads as the thing it does — a splitting
-- block for cracking, shelves of rocks for the racks, a market stall for the
-- shop, an altar for rebirth — instead of four identical pads with labels.
--
-- All of it is visual only: nothing collides (players walk straight through,
-- nothing to get wedged on) and nothing answers queries (a tap-ray crossing the
-- cave from the far side can never die on a piece of furniture). The player
-- approaches from the spawn side (-Z), so furniture sits on the +Z half of the
-- pad and the front stays open.
--------------------------------------------------------------------------------

local STONE = Color3.fromRGB(72, 66, 96)
local WOOD = Color3.fromRGB(112, 84, 58)

local function deco(props: { [string]: any }, parent: Instance): Part
	local piece = part(props, parent)
	piece.CanCollide = false
	piece.CanQuery = false
	return piece
end

-- Crack Station: a stone splitting block with a geode already halfway open on
-- top, and the mallet that did it leaning against the side.
local function decorateCrack(position: Vector3, color: Color3, parent: Instance)
	deco({
		Name = "SplitBlockBase",
		Size = Vector3.new(3, 1.6, 2.6),
		Position = position + Vector3.new(0, 1.3, 3.2),
		Color = STONE,
		Material = Enum.Material.Slate,
	}, parent)
	deco({
		Name = "SplitBlockTop",
		Size = Vector3.new(3.8, 0.7, 3.2),
		Position = position + Vector3.new(0, 2.45, 3.2),
		Color = STONE,
		Material = Enum.Material.Slate,
	}, parent)
	deco({
		Name = "SplitGeode",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.4, 2.4, 2.4),
		Position = position + Vector3.new(0, 3.9, 3.2),
		Color = color:Lerp(Color3.fromRGB(52, 46, 66), 0.8),
		Material = Enum.Material.Rock,
	}, parent)
	local seam = deco({
		Name = "SplitSeam",
		Size = Vector3.new(0.3, 2.5, 2),
		Position = position + Vector3.new(0, 3.9, 3.2),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.1,
	}, parent)
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Range = 12
	glow.Brightness = 1.2
	glow.Parent = seam
	local handle = deco({
		Name = "MalletHandle",
		Size = Vector3.new(0.45, 4.2, 0.45),
		CFrame = CFrame.new(position + Vector3.new(2.6, 2.2, 2.4)) * CFrame.Angles(0, 0, math.rad(24)),
		Color = WOOD,
		Material = Enum.Material.Wood,
	}, parent)
	deco({
		Name = "MalletHead",
		Size = Vector3.new(1.5, 1, 1),
		CFrame = handle.CFrame * CFrame.new(0, 2.2, 0),
		Color = STONE,
		Material = Enum.Material.Slate,
	}, parent)
	-- Chips from previous cracks scattered around the block
	for i = 1, 4 do
		deco({
			Name = "SplitShard" .. i,
			Size = Vector3.new(0.5, 0.4, 0.6),
			CFrame = CFrame.new(position + Vector3.new(rng:NextNumber(-2.6, 2.6), 0.7, rng:NextNumber(0.4, 1.6)))
				* CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.3,
		}, parent)
	end
end

-- Crystal Racks: an actual rack — two posts, three shelves, rocks growing on
-- every shelf.
local function decorateRacks(position: Vector3, _color: Color3, parent: Instance)
	for _, x in { -3, 3 } do
		deco({
			Name = "RackPost",
			Size = Vector3.new(0.55, 5.4, 0.55),
			Position = position + Vector3.new(x, 3.2, 3.4),
			Color = WOOD,
			Material = Enum.Material.Wood,
		}, parent)
	end
	for level = 1, 3 do
		local shelfY = 0.9 + level * 1.4
		deco({
			Name = "RackShelf" .. level,
			Size = Vector3.new(6.6, 0.35, 1.8),
			Position = position + Vector3.new(0, shelfY, 3.4),
			Color = WOOD:Lerp(Color3.new(0, 0, 0), 0.15),
			Material = Enum.Material.WoodPlanks,
		}, parent)
		for slot = 1, 3 do
			local rock = CrystalShape.Build({
				Color = NODE_COLORS[rng:NextInteger(1, #NODE_COLORS)],
				Scale = rng:NextNumber(0.28, 0.42),
				Shards = 4,
				Segments = 2,
				Seed = level * 17 + slot * 5,
			})
			rock.Name = "ShelfRock"
			rock:PivotTo(
				CFrame.new(position + Vector3.new(-2.1 + (slot - 1) * 2.1 + rng:NextNumber(-0.3, 0.3), shelfY + 0.2, 3.4))
			)
			rock.Parent = parent
		end
	end
end

-- Geode Shop: a market stall — counter out front, striped awning overhead,
-- geodes for sale on the counter and the back shelf.
local function decorateShop(position: Vector3, color: Color3, parent: Instance)
	deco({
		Name = "ShopCounter",
		Size = Vector3.new(6, 1.2, 1.6),
		Position = position + Vector3.new(0, 1.1, 1.1),
		Color = WOOD,
		Material = Enum.Material.WoodPlanks,
	}, parent)
	local function goods(name: string, x: number, y: number, z: number, tint: Color3)
		deco({
			Name = name,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.1, 1.1, 1.1),
			Position = position + Vector3.new(x, y, z),
			Color = tint:Lerp(Color3.fromRGB(52, 46, 66), 0.8),
			Material = Enum.Material.Rock,
		}, parent)
		-- A glowing nugget peeking out, so the merchandise reads as geodes
		deco({
			Name = name .. "Nugget",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.5, 0.5, 0.5),
			Position = position + Vector3.new(x + 0.2, y + 0.35, z - 0.25),
			Color = tint,
			Material = Enum.Material.Neon,
			Transparency = 0.15,
		}, parent)
	end
	for i, x in { -1.9, 0, 1.9 } do
		goods("CounterGeode" .. i, x, 2.25, 1.1, NODE_COLORS[(i * 2) % #NODE_COLORS + 1])
	end
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
	goods("ShelfGeodeA", -1.4, 3.95, 4.2, NODE_COLORS[2])
	goods("ShelfGeodeB", 1.5, 3.95, 4.2, NODE_COLORS[5])
	-- Striped awning sloping down over the counter
	for i = 1, 5 do
		deco({
			Name = "Awning" .. i,
			Size = Vector3.new(1.3, 0.2, 3.6),
			CFrame = CFrame.new(position + Vector3.new(-2.6 + (i - 1) * 1.3, 6, 2.6)) * CFrame.Angles(math.rad(14), 0, 0),
			Color = if i % 2 == 1 then color else Color3.fromRGB(235, 230, 220),
			Material = Enum.Material.SmoothPlastic,
		}, parent)
	end
end

-- Recrystallize: a stepped stone altar ringed by standing stones, with a
-- crystal turning slowly in the air above it — the one station that should
-- look a little mystical.
local function decorateRebirth(position: Vector3, color: Color3, parent: Instance)
	deco({
		Name = "AltarBase",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 6.6, 6.6),
		CFrame = CFrame.new(position + Vector3.new(0, 0.9, 3)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = STONE,
		Material = Enum.Material.Slate,
	}, parent)
	deco({
		Name = "AltarTop",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 4.4, 4.4),
		CFrame = CFrame.new(position + Vector3.new(0, 1.7, 3)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = STONE:Lerp(color, 0.12),
		Material = Enum.Material.Slate,
	}, parent)
	for i, offset in { Vector3.new(-3.4, 0, 1.4), Vector3.new(-2.2, 0, 4.6), Vector3.new(2.2, 0, 4.6), Vector3.new(3.4, 0, 1.4) } do
		local stone = deco({
			Name = "Monolith" .. i,
			Size = Vector3.new(1, 2.8, 0.8),
			CFrame = CFrame.new(position + offset + Vector3.new(0, 1.9, 0))
				* CFrame.Angles(rng:NextNumber(-0.06, 0.06), rng:NextNumber(0, 6.28), rng:NextNumber(-0.06, 0.06)),
			Color = STONE,
			Material = Enum.Material.Rock,
		}, parent)
		deco({
			Name = "MonolithTip" .. i,
			Size = Vector3.new(0.5, 0.4, 0.5),
			CFrame = stone.CFrame * CFrame.new(0, 1.6, 0),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.2,
		}, parent)
	end
	-- The floating crystal turns and bobs on each client, like everything else
	-- tagged SpinCrystal — the altar looks alive and costs the server nothing.
	local crystal = CrystalShape.Build({
		Color = color,
		Scale = 0.9,
		Shards = 5,
		Segments = 3,
		Seed = 4242,
		Glow = 20,
		Sparkle = true,
	})
	crystal.Name = "AltarCrystal"
	crystal:PivotTo(CFrame.new(position + Vector3.new(0, 3.4, 3)))
	crystal.Parent = parent
	CollectionService:AddTag(crystal, "SpinCrystal")
	crystal:SetAttribute("SpinSpeed", 0.5)
	crystal:SetAttribute("BobHeight", 0.5)
	crystal:SetAttribute("BobSpeed", 0.9)
end

local STATION_DECOR: { [string]: (Vector3, Color3, Instance) -> () } = {
	Crack = decorateCrack,
	Racks = decorateRacks,
	Shop = decorateShop,
	Rebirth = decorateRebirth,
}

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
	local decorate = STATION_DECOR[stationKey]
	if decorate then
		decorate(position, color, parent)
	end

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
		stalactite.CanQuery = false
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
			tip.CanQuery = false
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
	dustSource.CanQuery = false
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
		fillPart.CanQuery = false
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

	-- Landmark crystals: giant, turning, impossible to miss on the walk in
	-- Corners only. One of these used to sit at (0, 18, 62), directly over the
	-- path between spawn and the stations, where it filled half the screen.
	for _, spot in { Vector3.new(-88, 16, 30), Vector3.new(88, 16, 30), Vector3.new(-88, 16, -30) } do
		makeFloatingCrystal(spot, NODE_COLORS[rng:NextInteger(1, #NODE_COLORS)], rng:NextNumber(2, 2.8), map)
	end

	-- No glowing veins painted on the rock. Bright neon sticks scattered across
	-- the face turned the wall into confetti and drowned out the one thing that
	-- actually matters — the geodes you can mine. The wall earns its look from
	-- rock, and the light comes from a handful of real formations below.

	-- Geodes still buried in the face. Deliberately dull — see GeodeNode.Buried
	-- for why these must not look tappable. They sit between the mining spots,
	-- which are spaced 15 studs apart starting at x = -82.
	for i = 1, 22 do
		local x = rng:NextNumber(-96, 96)
		-- Distance to the nearest REAL deposit column. Deposits sit every 15 studs
		-- from x = -82, but only twelve of them — a plain modulo invents phantom
		-- columns past each end and throws away perfectly good spots out at the
		-- wall edges, so snap to the actual column index and clamp it.
		-- 9 studs, not 4: a deposit's rock and lumps reach ~5 studs and a buried
		-- one reaches ~5 more, with no z separation between them, so a smaller
		-- gap let dull scenery sit inside the bright tappable geode and muddy the
		-- one cue the wall depends on. 9 still leaves a 6-stud band per column.
		local column = math.clamp(math.floor((x + 82) / 15 + 0.5), 0, 11)
		if math.abs(x - (column * 15 - 82)) < 9 then
			continue -- too close to a real deposit; would read as tappable
		end
		GeodeNode.Buried(
			Vector3.new(x, rng:NextNumber(1.5, 34), -64.2),
			NODE_COLORS[rng:NextInteger(1, #NODE_COLORS)],
			rng:NextNumber(0.6, 1.5),
			i * 97 + 13,
			map
		)
	end

	-- Crystal spurs bursting OUT of the rock. Each one gets a rock collar where
	-- it breaks the surface and a couple of broken chunks around it, so it reads
	-- as something that grew through the wall and shattered it — not a crystal
	-- decal laid flat on the face.
	-- Eight, not eighteen: a few big formations read as a crystal cave, a lot of
	-- small ones read as noise. Kept high and wide so they frame the mining row
	-- rather than competing with it.
	for i = 1, 8 do
		local x = rng:NextNumber(-96, 96)
		local y = rng:NextNumber(16, 38)
		local scale = rng:NextNumber(2.2, 3.4)
		local yaw = rng:NextNumber(-0.7, 0.7)
		local pitch = rng:NextNumber(-0.7, 0.7)
		local root = CFrame.new(x, y, -64.4) * CFrame.Angles(pitch, yaw, 0)

		-- The rock breaking outward around the base of the spur
		local collarSize = 2.6 + scale * 1.3
		local collar = part({
			Name = "SpurCollar" .. i,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(collarSize, collarSize, collarSize * 0.7),
			CFrame = root,
			Color = ROCK,
			Material = Enum.Material.Rock,
		}, map)
		collar.CanCollide = false
		collar.CanQuery = false
		for chunk = 1, 2 do
			local chunkSize = rng:NextNumber(1, 2.2)
			local chunkPart = part({
				Name = "SpurChunk" .. i .. "_" .. chunk,
				Size = Vector3.new(chunkSize, chunkSize * 0.8, chunkSize),
				CFrame = root
					* CFrame.new(rng:NextNumber(-2.4, 2.4), rng:NextNumber(-2.4, 2.4), rng:NextNumber(0.3, 1.4))
					* CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3)),
				Color = ROCK,
				Material = Enum.Material.Rock,
			}, map)
			chunkPart.CanCollide = false
			chunkPart.CanQuery = false
		end

		local spur = CrystalShape.Build({
			Color = NODE_COLORS[rng:NextInteger(1, #NODE_COLORS)],
			Scale = scale,
			Shards = rng:NextInteger(4, 6),
			Segments = 3,
			Seed = i * 41 + 3,
			Glow = 16 + scale * 6,
		})
		spur.Name = "WallSpur" .. i
		-- Rooted slightly INSIDE the wall so the shard bases are buried and only
		-- the crystal itself sticks into the cave.
		spur:PivotTo(root * CFrame.new(0, 0, -1.2) * CFrame.Angles(math.rad(90), 0, 0))
		spur.Parent = map
	end

	-- Rock shelves jutting out of the side walls, and boulders where they have
	-- fallen. Depth is what makes a cave feel like a cave — flat walls read as a
	-- room no matter how much you glue to them.
	for i = 1, 12 do
		local onLeft = i % 2 == 0
		local wallX = onLeft and -106 or 106
		local z = rng:NextNumber(-60, 70)
		local ledgeY = rng:NextNumber(6, 34)
		local depth = rng:NextNumber(5, 11)
		local ledge = part({
			Name = "WallLedge" .. i,
			Size = Vector3.new(depth, rng:NextNumber(1.6, 3.4), rng:NextNumber(7, 16)),
			CFrame = CFrame.new(wallX + (onLeft and depth / 2 or -depth / 2), ledgeY, z)
				* CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), rng:NextNumber(-0.12, 0.12)),
			Color = ROCK,
			Material = Enum.Material.Rock,
		}, map)
		ledge.CanQuery = false
		-- Something growing on the shelf, so the eye has a reason to go there
		if i % 3 == 0 then
			makeCrystalCluster(
				Vector3.new(wallX + (onLeft and depth - 1 or -(depth - 1)), ledgeY + 1.6, z),
				NODE_COLORS[rng:NextInteger(1, #NODE_COLORS)],
				rng:NextNumber(0.7, 1.3),
				map
			)
		end
	end

	-- Boulders on the floor, biggest near the walls where they would have fallen
	for i = 1, 16 do
		local x = rng:NextNumber(-100, 100)
		local z = rng:NextNumber(-58, 72)
		if math.abs(x) > 40 or z > 24 then
			local size = rng:NextNumber(2.4, 6.5)
			local boulder = part({
				Name = "Boulder" .. i,
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(size, size * rng:NextNumber(0.7, 0.95), size * rng:NextNumber(0.8, 1.1)),
				CFrame = CFrame.new(x, size * 0.32, z)
					* CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3)),
				Color = ROCK,
				Material = Enum.Material.Rock,
			}, map)
			boulder.CanQuery = false
		end
	end

	-- A few columns running floor to ceiling, where a stalactite and stalagmite
	-- have met. Nothing sells "underground" like not being able to see straight
	-- across the room.
	for i = 1, 4 do
		local x = (i % 2 == 0 and 1 or -1) * rng:NextNumber(58, 96)
		local z = rng:NextNumber(-40, 60)
		local width = rng:NextNumber(3.4, 6)
		local column = part({
			Name = "Column" .. i,
			Size = Vector3.new(width, 52, width),
			CFrame = CFrame.new(x, 25, z) * CFrame.Angles(rng:NextNumber(-0.03, 0.03), 0, rng:NextNumber(-0.03, 0.03)),
			Color = ROCK,
			Material = Enum.Material.Rock,
		}, map)
		column.CanQuery = false
		-- Waist and base flare, so it tapers like dripstone instead of a pillar
		for _, flare in { { 5, width * 1.5 }, { 20, width * 1.2 }, { 44, width * 1.35 } } do
			local flarePart = part({
				Name = "ColumnFlare",
				Size = Vector3.new(flare[2], rng:NextNumber(2.5, 5), flare[2]),
				Position = Vector3.new(x, flare[1], z),
				Color = ROCK,
				Material = Enum.Material.Rock,
			}, map)
			flarePart.CanCollide = false
			flarePart.CanQuery = false
		end
	end

	-- Deposit geodes along the wall face
	local nodes: { BasePart } = {}
	local nodeFolder = Instance.new("Folder")
	nodeFolder.Name = "Nodes"
	nodeFolder.Parent = map
	for i = 1, 12 do
		local x = -82 + (i - 1) * 15
		local color = NODE_COLORS[rng:NextInteger(1, #NODE_COLORS)]
		local node = GeodeNode.Build(i, Vector3.new(x, 5.5, -63.5), color, nodeFolder)
		table.insert(nodes, node.Hitbox)
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

	-- Friendly like prompt beside the spawn (honest version of the genre's
	-- like-goal boards — no fake counters, no reward-baiting).
	local likeSign = part({
		Name = "LikeSign",
		Size = Vector3.new(10, 4.5, 0.6),
		CFrame = CFrame.lookAt(Vector3.new(-15, 3, -58), Vector3.new(0, 3, -48)),
		Color = Color3.fromRGB(40, 38, 60),
		Material = Enum.Material.SmoothPlastic,
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
	likeLabel.TextColor3 = Color3.fromRGB(120, 255, 200)
	likeLabel.TextScaled = true
	likeLabel.Parent = likeGui
	likeGui.Parent = likeSign

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
