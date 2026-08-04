--!strict
-- The held pickaxe, done the right way: a real Tool. Roblox itself handles the
-- grip and the arm-out hold pose (same standard behavior as the classic
-- pickaxe gear), so it sits correctly for every avatar and animation set.
-- The model is the classic silhouette: wooden handle with an orange cap, and
-- a steel head bar whose ends curve down into points. Head color/material/glow
-- upgrade per tier. Pure cosmetics — mining input still goes through the node
-- ClickDetectors.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)

local PickaxeVisual = {}

local ctx: any = nil

local TOOL_TAG = "HeldPickaxeTool"

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

local function buildTool(tier: { [string]: any }): Tool
	local tool = Instance.new("Tool")
	tool.Name = tier.Name
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute(TOOL_TAG, true)

	local headColor = tier.Color or Color3.fromRGB(160, 158, 165)
	local headMaterial = tier.Material or Enum.Material.Metal

	-- Handle: vertical wooden shaft, hand grips the middle (default Tool grip)
	local handle = toolPart("Handle", Vector3.new(0.35, 3.4, 0.35), Color3.fromRGB(133, 95, 60), Enum.Material.Wood, tool)
	local cap = toolPart("Cap", Vector3.new(0.42, 0.3, 0.42), Color3.fromRGB(210, 130, 75), Enum.Material.Wood, tool)
	joint(handle, cap, CFrame.new(0, 1.85, 0))

	-- Head: center block at the top, two arms angling down-outward, pointed tips
	local headCenter = toolPart("HeadCenter", Vector3.new(0.9, 0.55, 0.42), headColor, headMaterial, tool)
	joint(handle, headCenter, CFrame.new(0, 1.45, 0))
	local armLeft = toolPart("ArmL", Vector3.new(1.2, 0.42, 0.38), headColor, headMaterial, tool)
	joint(handle, armLeft, CFrame.new(-0.95, 1.32, 0) * CFrame.Angles(0, 0, math.rad(22)))
	local armRight = toolPart("ArmR", Vector3.new(1.2, 0.42, 0.38), headColor, headMaterial, tool)
	joint(handle, armRight, CFrame.new(0.95, 1.32, 0) * CFrame.Angles(0, 0, math.rad(-22)))
	local tipLeft = toolPart("TipL", Vector3.new(0.7, 0.32, 0.34), headColor, headMaterial, tool)
	joint(handle, tipLeft, CFrame.new(-1.7, 0.95, 0) * CFrame.Angles(0, 0, math.rad(50)))
	local tipRight = toolPart("TipR", Vector3.new(0.7, 0.32, 0.34), headColor, headMaterial, tool)
	joint(handle, tipRight, CFrame.new(1.7, 0.95, 0) * CFrame.Angles(0, 0, math.rad(-50)))

	if tier.Glow then
		local light = Instance.new("PointLight")
		light.Color = headColor
		light.Range = 8
		light.Brightness = 1.2
		light.Parent = headCenter
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

function PickaxeVisual.Refresh(player: Player)
	local data = ctx.Data.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not data or not character or not humanoid or humanoid.Health <= 0 then
		return
	end
	clearOldTools(player)
	local tier = Balance.Pickaxes[math.clamp(data.Pickaxe, 1, #Balance.Pickaxes)]
	local tool = buildTool(tier)
	tool.Parent = player:FindFirstChild("Backpack") or player
	humanoid:EquipTool(tool)
end

-- Arm-swing on each counted mining tap, via the Animate script's classic
-- toolanim hook (a no-op on rigs that don't support it — the node crunch and
-- sounds still carry the feedback).
function PickaxeVisual.Swing(player: Player)
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if tool and tool:GetAttribute(TOOL_TAG) then
		local anim = Instance.new("StringValue")
		anim.Name = "toolanim"
		anim.Value = "Slash"
		anim.Parent = tool
	end
end

local function onCharacterAdded(player: Player, character: Model)
	-- Profile may still be loading on first spawn; retry briefly.
	for _ = 1, 10 do
		if ctx.Data.Get(player) and character:FindFirstChildOfClass("Humanoid") then
			break
		end
		task.wait(0.5)
	end
	if player.Character == character then
		PickaxeVisual.Refresh(player)
	end
	task.delay(1.5, function()
		if player.Character == character and not (character:FindFirstChildOfClass("Tool") or (player:FindFirstChild("Backpack") and (player.Backpack :: any):FindFirstChildOfClass("Tool"))) then
			PickaxeVisual.Refresh(player)
		end
	end)
end

function PickaxeVisual.Init(serviceCtx: any)
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

return PickaxeVisual
