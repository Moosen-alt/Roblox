--!strict
-- Generates the whole 100-stage course from ~6 segment archetypes. Every
-- server rolls a fresh seed, so each server is a new tower layout — systemic
-- content, Tower-of-Hell style, with zero authored maps.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)

local CourseBuilder = {}

export type CourseRefs = {
	Pads: { BasePart }, -- index 1..Stages; pad i has attribute StageIndex = i
	SpawnPad: BasePart,
	BoardStages: BasePart,
	BoardRebirths: BasePart,
}

local rng = Random.new(os.time())

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

local function stageColor(i: number): Color3
	return Color3.fromHSV((i * 0.043) % 1, 0.55, 0.95)
end

local function setLighting()
	Lighting.ClockTime = 13
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(150, 150, 160)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 150, 170)
	Lighting.FogColor = Color3.fromRGB(200, 220, 250)
	Lighting.FogEnd = 1200
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.2
	atmosphere.Color = Color3.fromRGB(199, 224, 255)
	atmosphere.Parent = Lighting
end

-- Segment archetypes fill the gap between pad i-1 (at fromZ) and pad i.
-- All are "easy": short gaps, wide platforms, gentle heights.
local function segmentPlatforms(stageRng: Random, kind: number, fromZ: number, toZ: number, folder: Instance, color: Color3)
	local span = toZ - fromZ
	if kind == 1 then -- straight hops
		for j = 1, 3 do
			part({
				Size = Vector3.new(8, 1, 5),
				Position = Vector3.new(stageRng:NextNumber(-2, 2), 0, fromZ + span * j / 4),
				Color = color,
				Material = Enum.Material.SmoothPlastic,
			}, folder)
		end
	elseif kind == 2 then -- zigzag
		for j = 1, 3 do
			part({
				Size = Vector3.new(7, 1, 5),
				Position = Vector3.new((j % 2 == 0 and 7 or -7), 0, fromZ + span * j / 4),
				Color = color,
				Material = Enum.Material.SmoothPlastic,
			}, folder)
		end
	elseif kind == 3 then -- rising stairs then drop
		for j = 1, 3 do
			part({
				Size = Vector3.new(8, 1, 5),
				Position = Vector3.new(0, j * 1.6, fromZ + span * j / 4),
				Color = color,
				Material = Enum.Material.SmoothPlastic,
			}, folder)
		end
	elseif kind == 4 then -- one long narrow beam
		part({
			Size = Vector3.new(3, 1, span - 8),
			Position = Vector3.new(0, 0, fromZ + span / 2),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
		}, folder)
	elseif kind == 5 then -- pillar hops
		for j = 1, 4 do
			part({
				Size = Vector3.new(4.5, 1, 4.5),
				Position = Vector3.new(stageRng:NextNumber(-4, 4), 0, fromZ + span * j / 5),
				Color = color,
				Material = Enum.Material.SmoothPlastic,
			}, folder)
		end
	else -- two platforms, one slightly longer gap (jump power shines here)
		part({
			Size = Vector3.new(8, 1, 6),
			Position = Vector3.new(0, 0, fromZ + span * 0.3),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
		}, folder)
		part({
			Size = Vector3.new(8, 1, 6),
			Position = Vector3.new(0, 0, fromZ + span * 0.72),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
		}, folder)
	end
end

local function makePad(i: number, z: number, folder: Instance): BasePart
	local isFinish = i == Balance.Stages
	local pad = part({
		Name = "Pad" .. i,
		Size = isFinish and Vector3.new(24, 1, 12) or Vector3.new(14, 1, 6),
		Position = Vector3.new(0, 0, z),
		Color = isFinish and Color3.fromRGB(255, 210, 90) or stageColor(i),
		Material = isFinish and Enum.Material.Neon or Enum.Material.SmoothPlastic,
	}, folder)
	pad:SetAttribute("StageIndex", i)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = isFinish and "FINISH — REBIRTH!" or tostring(i)
	label.TextColor3 = Color3.fromRGB(30, 26, 20)
	label.TextScaled = true
	label.Rotation = 180
	label.Parent = gui
	gui.Parent = pad
	return pad
end

local function makeBoard(position: Vector3, title: string, parent: Instance): BasePart
	local board = part({
		Name = "Board_" .. title,
		Size = Vector3.new(14, 12, 1),
		CFrame = CFrame.lookAt(position, Vector3.new(0, position.Y, 20)),
		Color = Color3.fromRGB(40, 40, 60),
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

function CourseBuilder.Build(): CourseRefs
	setLighting()
	local folder = Instance.new("Folder")
	folder.Name = "GeneratedCourse"

	-- Start platform
	local spawnPad = part({
		Name = "StartPlatform",
		Size = Vector3.new(30, 1, 20),
		Position = Vector3.new(0, 0, -14),
		Color = Color3.fromRGB(120, 220, 120),
		Material = Enum.Material.SmoothPlastic,
	}, folder)

	local pads: { BasePart } = {}
	for i = 1, Balance.Stages do
		local z = i * Balance.StageLength
		local stageRng = Random.new(rng:NextInteger(1, 2 ^ 30))
		segmentPlatforms(stageRng, stageRng:NextInteger(1, 6), z - Balance.StageLength, z, folder, stageColor(i))
		pads[i] = makePad(i, z, folder)
	end

	local boardStages = makeBoard(Vector3.new(-26, 7, -30), "Best Stage", folder)
	local boardRebirths = makeBoard(Vector3.new(26, 7, -30), "Top Rebirths", folder)

	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(0, 0.5, -14)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Color = Color3.fromRGB(120, 220, 120)
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Duration = 0
	spawn.Parent = folder

	folder.Parent = Workspace

	return {
		Pads = pads,
		SpawnPad = spawnPad,
		BoardStages = boardStages,
		BoardRebirths = boardRebirths,
	}
end

return CourseBuilder
