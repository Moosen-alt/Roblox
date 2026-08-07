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

	local handle = toolPart("Handle", Vector3.new(0.25, 5, 0.25), Color3.fromRGB(133, 95, 60), Enum.Material.Wood, tool)
	local wrap = toolPart("GripWrap", Vector3.new(0.34, 1, 0.34), accentColor, accentMaterial, tool)
	joint(handle, wrap, CFrame.new(0, -1.6, 0))
	local reel = toolPart("Reel", Vector3.new(0.4, 0.4, 0.25), accentColor, accentMaterial, tool)
	joint(handle, reel, CFrame.new(0.28, -1, 0))
	local tip = toolPart("Tip", Vector3.new(0.32, 0.32, 0.32), accentColor, Enum.Material.Neon, tool)
	joint(handle, tip, CFrame.new(0, 2.55, 0))

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
