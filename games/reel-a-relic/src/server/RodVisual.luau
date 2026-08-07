--!strict
-- The held fishing rod: a real Tool (Roblox handles grip + hold pose), tilted
-- forward like a rod at rest. The grip wrap and glowing tip upgrade per rod
-- tier so every upgrade is visible in your hands. Pure cosmetics — casting
-- input goes through the raycast tap path.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)

local RodVisual = {}

local ctx: any = nil

local TOOL_TAG = "HeldRodTool"

local function toolPart(name: string, size: Vector3, color: Color3, material: Enum.Material, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Parent = parent
	return p
end

local function joint(part0: BasePart, part1: BasePart, offset: CFrame)
	local motor = Instance.new("Motor6D")
	motor.Name = part1.Name .. "Joint"
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = offset
	motor.Parent = part0
end

-- A rod, not a stick. Cork grip, a reel with a spool you can see, line guides up
-- a blank that visibly tapers, and a line hanging off the tip to a bobber. The
-- guides and the taper are what read as "fishing rod" at a glance; the hanging
-- line is what makes it feel alive while you walk around with it.
local function buildTool(tier: { [string]: any }): Tool
	local tool = Instance.new("Tool")
	tool.Name = tier.Name
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	-- Tip the rod forward like a rod at the ready
	tool.Grip = CFrame.Angles(math.rad(-35), 0, 0)
	tool:SetAttribute(TOOL_TAG, true)

	local accentColor = tier.Color or Color3.fromRGB(190, 190, 200)
	local accentMaterial = tier.Material or Enum.Material.Metal
	local CORK = Color3.fromRGB(196, 160, 108)
	local BLANK = Color3.fromRGB(58, 48, 44)

	-- The Handle IS the grip, so Roblox puts the cork in the hand and everything
	-- else hangs off it in the right place.
	local handle = toolPart("Handle", Vector3.new(0.34, 1.5, 0.34), CORK, Enum.Material.Wood, tool)

	-- Reel seat + spool, just above the grip on the right, where a reel goes.
	local seat = toolPart("ReelSeat", Vector3.new(0.3, 0.5, 0.3), accentColor, accentMaterial, tool)
	joint(handle, seat, CFrame.new(0, 0.95, 0))
	local spool = toolPart("Spool", Vector3.new(0.7, 0.7, 0.34), accentColor, accentMaterial, tool)
	spool.Shape = Enum.PartType.Cylinder
	joint(handle, spool, CFrame.new(0.3, 0.9, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local knob = toolPart("ReelKnob", Vector3.new(0.14, 0.14, 0.3), Color3.fromRGB(40, 36, 34), Enum.Material.SmoothPlastic, tool)
	joint(handle, knob, CFrame.new(0.52, 1.08, 0))

	-- Blank: three sections that get thinner as they rise. A rod that tapers
	-- reads as a rod; a uniform pole reads as a broom.
	local sections = {
		{ length = 1.9, thick = 0.2, at = 1.75 },
		{ length = 1.9, thick = 0.145, at = 3.6 },
		{ length = 1.7, thick = 0.095, at = 5.35 },
	}
	for i, section in sections do
		local part = toolPart(
			"Blank" .. i,
			Vector3.new(section.thick, section.length, section.thick),
			BLANK:Lerp(accentColor, i * 0.16),
			Enum.Material.SmoothPlastic,
			tool
		)
		joint(handle, part, CFrame.new(0, section.at, 0))
		-- A guide ring near the top of each section, which is where they go.
		local guide = toolPart(
			"Guide" .. i,
			Vector3.new(0.07, 0.3, 0.3),
			accentColor,
			accentMaterial,
			tool
		)
		guide.Shape = Enum.PartType.Cylinder
		joint(handle, guide, CFrame.new(0, section.at + section.length * 0.42, 0.1) * CFrame.Angles(0, math.rad(90), 0))
	end

	local tip = toolPart("Tip", Vector3.new(0.16, 0.16, 0.16), accentColor, Enum.Material.Neon, tool)
	joint(handle, tip, CFrame.new(0, 6.25, 0))

	-- The line: a Beam, not a thin part. Beams sag between their attachments, so
	-- the line hangs the way a line hangs instead of standing out rigid — and it
	-- costs one instance rather than a chain of segments.
	local bobber = toolPart("Bobber", Vector3.new(0.34, 0.34, 0.34), Color3.fromRGB(230, 60, 60), Enum.Material.SmoothPlastic, tool)
	bobber.Shape = Enum.PartType.Ball
	joint(handle, bobber, CFrame.new(0, 4.5, 0.85))
	local bobberBase = toolPart("BobberBase", Vector3.new(0.3, 0.16, 0.3), Color3.fromRGB(248, 248, 250), Enum.Material.SmoothPlastic, tool)
	bobberBase.Shape = Enum.PartType.Ball
	joint(handle, bobberBase, CFrame.new(0, 4.36, 0.85))

	local fromTip = Instance.new("Attachment")
	fromTip.Parent = tip
	local toBobber = Instance.new("Attachment")
	toBobber.Parent = bobber

	local line = Instance.new("Beam")
	line.Name = "Line"
	line.Attachment0 = fromTip
	line.Attachment1 = toBobber
	line.Width0 = 0.035
	line.Width1 = 0.035
	line.FaceCamera = true
	line.Transparency = NumberSequence.new(0.15)
	line.LightInfluence = 1
	line.Color = ColorSequence.new(if tier.Glow then accentColor else Color3.fromRGB(238, 240, 245))
	-- Sag: pull the curve control points down so the slack hangs below the
	-- straight line between tip and bobber.
	line.CurveSize0 = -0.8
	line.CurveSize1 = -0.8
	line.Parent = tip

	if tier.Glow then
		local light = Instance.new("PointLight")
		light.Color = accentColor
		light.Range = 8
		light.Brightness = 1.2
		light.Parent = tip
	end

	return tool
end

local function clearOldTools(player: Player)
	local function sweep(container: Instance?)
		if not container then
			return
		end
		for _, child in container:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute(TOOL_TAG) then
				child:Destroy()
			end
		end
	end
	sweep(player.Character)
	sweep(player:FindFirstChild("Backpack"))
end

function RodVisual.Refresh(player: Player)
	local data = ctx.Data.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not data or not character or not humanoid or humanoid.Health <= 0 then
		return
	end
	clearOldTools(player)
	local tier = Balance.Pickaxe(data.Pickaxe)
	local tool = buildTool(tier)
	tool.Parent = player:FindFirstChild("Backpack") or player
	humanoid:EquipTool(tool)
end

local function onCharacterAdded(player: Player, character: Model)
	for _ = 1, 10 do
		if ctx.Data.Get(player) and character:FindFirstChildOfClass("Humanoid") then
			break
		end
		task.wait(0.5)
	end
	if player.Character == character then
		RodVisual.Refresh(player)
	end
	task.delay(1.5, function()
		if player.Character == character and not (character:FindFirstChildOfClass("Tool") or (player:FindFirstChild("Backpack") and (player.Backpack :: any):FindFirstChildOfClass("Tool"))) then
			RodVisual.Refresh(player)
		end
	end)
end

function RodVisual.Init(serviceCtx: any)
	ctx = serviceCtx
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			task.spawn(onCharacterAdded, player, character)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function(character)
			task.spawn(onCharacterAdded, player, character)
		end)
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		end
	end
end

return RodVisual
