--!strict
-- The held pickaxe: a procedural model welded into the player's hand that
-- upgrades visually with every pickaxe tier and swings on each mining tap.
-- Pure cosmetics — input still goes through the node ClickDetectors, so this
-- changes feel, not mechanics.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)

local PickaxeVisual = {}

local ctx: any = nil
local grips: { [Player]: Motor6D } = {}
local swinging: { [Player]: boolean } = {}

local GRIP_C0 = CFrame.new(0, -0.35, 0) * CFrame.Angles(math.rad(-90), 0, 0)
local GRIP_C1 = CFrame.new(0, -0.9, 0)
local SWING_C0 = GRIP_C0 * CFrame.Angles(math.rad(-75), 0, 0)

local function buildModel(tier: { [string]: any }): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "HeldPickaxe"

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 2.6, 0.3)
	handle.Color = Color3.fromRGB(110, 80, 55)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.CanQuery = false
	handle.Massless = true
	handle.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.9, 0.4, 0.45)
	head.Color = tier.Color or Color3.fromRGB(190, 190, 200)
	head.Material = tier.Material or Enum.Material.Metal
	head.CanCollide = false
	head.CanQuery = false
	head.Massless = true
	head.CFrame = handle.CFrame * CFrame.new(0, 1.25, 0)
	head.Parent = model

	for side = -1, 1, 2 do
		local tip = Instance.new("WedgePart")
		tip.Name = side == -1 and "TipL" or "TipR"
		tip.Size = Vector3.new(0.45, 0.4, 0.55)
		tip.Color = head.Color
		tip.Material = head.Material
		tip.CanCollide = false
		tip.CanQuery = false
		tip.Massless = true
		tip.CFrame = head.CFrame * CFrame.new(side * 1.15, 0, 0) * CFrame.Angles(0, side == -1 and math.rad(-90) or math.rad(90), 0)
		tip.Parent = model
		local tipWeld = Instance.new("WeldConstraint")
		tipWeld.Part0 = head
		tipWeld.Part1 = tip
		tipWeld.Parent = tip
	end

	if tier.Glow then
		local light = Instance.new("PointLight")
		light.Color = head.Color
		light.Range = 8
		light.Brightness = 1.2
		light.Parent = head
	end

	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = handle
	headWeld.Part1 = head
	headWeld.Parent = head

	model.PrimaryPart = handle
	return model, handle
end

function PickaxeVisual.Refresh(player: Player)
	local data = ctx.Data.Get(player)
	local character = player.Character
	if not data or not character then
		return
	end
	local hand = (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")) :: BasePart?
	if not hand then
		return
	end

	local existing = character:FindFirstChild("HeldPickaxe")
	if existing then
		existing:Destroy()
	end
	grips[player] = nil

	local tier = Balance.Pickaxes[math.clamp(data.Pickaxe, 1, #Balance.Pickaxes)]
	local model, handle = buildModel(tier)
	handle.CFrame = hand.CFrame * GRIP_C0 * GRIP_C1:Inverse()

	local grip = Instance.new("Motor6D")
	grip.Name = "PickaxeGrip"
	grip.Part0 = hand
	grip.Part1 = handle
	grip.C0 = GRIP_C0
	grip.C1 = GRIP_C1
	grip.Parent = hand

	model.Parent = character
	grips[player] = grip
end

-- Quick chop-and-return on every counted mining tap.
function PickaxeVisual.Swing(player: Player)
	local grip = grips[player]
	if not grip or not grip.Parent or swinging[player] then
		return
	end
	swinging[player] = true
	local down = TweenService:Create(grip, TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { C0 = SWING_C0 })
	down:Play()
	down.Completed:Once(function()
		local back = TweenService:Create(grip, TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = GRIP_C0 })
		back:Play()
		back.Completed:Once(function()
			swinging[player] = nil
		end)
	end)
end

local function onCharacterAdded(player: Player, character: Model)
	-- Profile may still be loading on first spawn; retry briefly.
	for _ = 1, 10 do
		local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
		if ctx.Data.Get(player) and hand then
			break
		end
		task.wait(0.5)
	end
	if player.Character == character then
		PickaxeVisual.Refresh(player)
	end
	-- Belt-and-suspenders: if anything raced (slow profile, R15 parts still
	-- streaming in), try once more a second later.
	task.delay(1, function()
		if player.Character == character and not character:FindFirstChild("HeldPickaxe") then
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
	Players.PlayerRemoving:Connect(function(player)
		grips[player] = nil
		swinging[player] = nil
	end)
end

return PickaxeVisual
