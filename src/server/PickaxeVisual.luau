--!strict
-- The held pickaxe: a procedural model jointed into the player's hand that
-- upgrades visually with every pickaxe tier and swings on each mining tap.
-- Every piece hangs off Motor6D joints (transform-driven, like character
-- limbs) so nothing can physically detach or drift — no welds, no physics.
-- Pure cosmetics: input still goes through the node ClickDetectors.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)

local PickaxeVisual = {}

local ctx: any = nil
local grips: { [Player]: Motor6D } = {}
local swinging: { [Player]: boolean } = {}

-- Grip: handle stands in the palm (tilted ~20 degrees forward), head above the
-- hand spanning forward/back — reads as "holding a pickaxe" in idle animations.
local GRIP_C0 = CFrame.Angles(math.rad(-20), 0, 0) * CFrame.Angles(0, math.rad(90), 0)
local GRIP_C1 = CFrame.new(0, -0.6, 0)
local SWING_C0 = CFrame.Angles(math.rad(-80), 0, 0) * GRIP_C0

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

local function buildModel(tier: { [string]: any }): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "HeldPickaxe"

	local headColor = tier.Color or Color3.fromRGB(190, 190, 200)
	local headMaterial = tier.Material or Enum.Material.Metal

	local handle = toolPart("Handle", Vector3.new(0.35, 3, 0.35), Color3.fromRGB(95, 70, 48), Enum.Material.Wood, model)

	-- Bright binding band where the head meets the handle: makes even the
	-- starter pick read as a crafted tool instead of a stick.
	local band = toolPart("Band", Vector3.new(0.45, 0.28, 0.45), Color3.fromRGB(255, 210, 90), Enum.Material.Neon, model)
	joint(handle, band, CFrame.new(0, 0.85, 0))

	-- Head bar + two down-angled spikes = the classic curved-pick silhouette
	local head = toolPart("Head", Vector3.new(2.2, 0.5, 0.55), headColor, headMaterial, model)
	joint(handle, head, CFrame.new(0, 1.15, 0))
	local spikeLeft = toolPart("SpikeL", Vector3.new(1.1, 0.38, 0.45), headColor, headMaterial, model)
	joint(head, spikeLeft, CFrame.new(-1.35, -0.35, 0) * CFrame.Angles(0, 0, math.rad(40)))
	local spikeRight = toolPart("SpikeR", Vector3.new(1.1, 0.38, 0.45), headColor, headMaterial, model)
	joint(head, spikeRight, CFrame.new(1.35, -0.35, 0) * CFrame.Angles(0, 0, math.rad(-40)))

	if tier.Glow then
		local light = Instance.new("PointLight")
		light.Color = headColor
		light.Range = 8
		light.Brightness = 1.2
		light.Parent = head
	end

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
	local oldGrip = hand:FindFirstChild("PickaxeGrip")
	if oldGrip then
		oldGrip:Destroy()
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
