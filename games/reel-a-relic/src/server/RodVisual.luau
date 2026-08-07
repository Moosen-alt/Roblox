--!strict
-- The held fishing rod: a real Tool (Roblox handles grip + hold pose), tilted
-- forward like a rod at rest. The grip wrap and glowing tip upgrade per rod
-- tier so every upgrade is visible in your hands. Pure cosmetics — casting
-- input goes through the raycast tap path.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

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

--------------------------------------------------------------------------------
-- Casting
--
-- The cast is PURELY cosmetic: the rod swings, a bobber arcs out and lands on
-- the water, and it dips when a fish takes it. The input is still one click,
-- deliberately. A power meter or a hold-and-release swing would be a second
-- skill test stacked on top of the bite-timing one, and for the audience this
-- game is for that trades a lot of players for a little depth. What the animation
-- buys is the FEELING of casting; the click is what makes it playable.
--------------------------------------------------------------------------------

local REST_GRIP = CFrame.Angles(math.rad(-35), 0, 0)
local WIND_UP_GRIP = CFrame.Angles(math.rad(-105), 0, 0)
local RELEASE_GRIP = CFrame.Angles(math.rad(22), 0, 0)

-- One bobber per player at most, so a re-cast or a respawn can always find and
-- clean up the last one.
local castBobbers: { [Player]: BasePart } = {}
-- Bumped on every cast; a swing whose token is stale has been superseded and
-- must stop animating rather than fight the newer one for the same Grip.
local castToken: { [Player]: number } = {}

local function equippedTool(player: Player): Tool?
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if tool and tool:GetAttribute(TOOL_TAG) then
		return tool
	end
	return nil
end

local function dangle(tool: Tool, visible: boolean)
	for _, name in { "Bobber", "BobberBase" } do
		local part = tool:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Transparency = if visible then 0 else 1
		end
	end
	local tip = tool:FindFirstChild("Tip")
	local line = tip and tip:FindFirstChildOfClass("Beam")
	if line then
		line.Enabled = visible
	end
end

-- Hand-rolled interpolation rather than TweenService: Tool.Grip is not a
-- reliably tweenable property, and a dozen task.wait steps for half a second of
-- swing is cheaper than finding that out in production.
local function swing(player: Player, tool: Tool, token: number)
	local function glide(from: CFrame, to: CFrame, seconds: number)
		local steps = math.max(math.floor(seconds * 30), 1)
		for i = 1, steps do
			if castToken[player] ~= token or tool.Parent == nil then
				return false
			end
			tool.Grip = from:Lerp(to, i / steps)
			task.wait(seconds / steps)
		end
		return true
	end
	-- Back over the shoulder, whip forward, settle. The whip is deliberately the
	-- shortest of the three: that snap is the whole read.
	if not glide(REST_GRIP, WIND_UP_GRIP, 0.18) then
		return
	end
	if not glide(WIND_UP_GRIP, RELEASE_GRIP, 0.1) then
		return
	end
	glide(RELEASE_GRIP, REST_GRIP, 0.3)
end

local function clearBobber(player: Player)
	local existing = castBobbers[player]
	if existing then
		existing:Destroy()
		castBobbers[player] = nil
	end
end

-- Swing the rod and land a bobber on the water at `target`.
function RodVisual.Cast(player: Player, target: Vector3)
	local tool = equippedTool(player)
	if not tool then
		return
	end
	clearBobber(player)
	local token = (castToken[player] or 0) + 1
	castToken[player] = token

	local tip = tool:FindFirstChild("Tip")
	if not tip or not tip:IsA("BasePart") then
		return
	end
	dangle(tool, false)
	task.spawn(swing, player, tool, token)

	local bobber = Instance.new("Part")
	bobber.Name = "CastBobber"
	bobber.Shape = Enum.PartType.Ball
	bobber.Size = Vector3.new(1.1, 1.1, 1.1)
	bobber.Color = Color3.fromRGB(230, 60, 60)
	bobber.Material = Enum.Material.SmoothPlastic
	bobber.Anchored = true
	bobber.CanCollide = false
	bobber.CanQuery = false -- a bobber must never swallow the click meant for the buoy
	bobber.CanTouch = false
	bobber.Position = tip.Position
	bobber.Parent = Workspace

	local stripe = Instance.new("Part")
	stripe.Name = "BobberBase"
	stripe.Shape = Enum.PartType.Ball
	stripe.Size = Vector3.new(1, 0.5, 1)
	stripe.Color = Color3.fromRGB(248, 248, 250)
	stripe.Material = Enum.Material.SmoothPlastic
	stripe.Anchored = true
	stripe.CanCollide = false
	stripe.CanQuery = false
	stripe.CanTouch = false
	stripe.Parent = bobber
	local weld = Instance.new("Weld")
	weld.Part0 = bobber
	weld.Part1 = stripe
	weld.C0 = CFrame.new(0, -0.32, 0)
	weld.Parent = bobber

	-- Line from the rod tip out to the bobber, sagging in the middle.
	local atBobber = Instance.new("Attachment")
	atBobber.Parent = bobber
	local atTip = tip:FindFirstChildOfClass("Attachment")
	if atTip then
		local line = Instance.new("Beam")
		line.Name = "CastLine"
		line.Attachment0 = atTip
		line.Attachment1 = atBobber
		line.Width0 = 0.04
		line.Width1 = 0.04
		line.FaceCamera = true
		line.LightInfluence = 1
		line.Transparency = NumberSequence.new(0.15)
		line.Color = ColorSequence.new(Color3.fromRGB(238, 240, 245))
		line.CurveSize0 = -3
		line.CurveSize1 = -3
		line.Parent = bobber
	end

	castBobbers[player] = bobber

	-- Arc it out: the bobber leaves late, a beat after the rod starts moving, so
	-- the swing looks like it threw the thing rather than the other way round.
	task.spawn(function()
		task.wait(0.2)
		local start = tip.Position
		local flight = 0.42
		local steps = 14
		local peak = math.min((target - start).Magnitude * 0.22, 14)
		for i = 1, steps do
			if castToken[player] ~= token or bobber.Parent == nil then
				return
			end
			local t = i / steps
			-- Parabola: sin() peaks at the halfway point and returns to zero,
			-- which is exactly the shape of a thrown thing.
			bobber.Position = start:Lerp(target, t) + Vector3.new(0, math.sin(t * math.pi) * peak, 0)
			task.wait(flight / steps)
		end
		if castToken[player] ~= token or bobber.Parent == nil then
			return
		end
		bobber.Position = target + Vector3.new(0, 0.2, 0)
		local splash = Instance.new("ParticleEmitter")
		splash.Color = ColorSequence.new(Color3.fromRGB(200, 240, 255))
		splash.Size = NumberSequence.new(0.5, 0)
		splash.Transparency = NumberSequence.new(0.2, 1)
		splash.Lifetime = NumberRange.new(0.3, 0.6)
		splash.Speed = NumberRange.new(5, 11)
		splash.SpreadAngle = Vector2.new(70, 70)
		splash.Acceleration = Vector3.new(0, -30, 0)
		splash.Rate = 0
		splash.Parent = bobber
		splash:Emit(14)
		-- Riding the swell is a client job, like the buoys: free motion, and the
		-- tag driver picks up the landed position as its base.
		CollectionService:AddTag(bobber, "SpinCrystal")
		bobber:SetAttribute("SpinSpeed", 0)
		bobber:SetAttribute("BobHeight", 0.35)
		bobber:SetAttribute("BobSpeed", 1.6)
	end)
end

-- A fish has it: yank the bobber under and throw a splash.
function RodVisual.Bite(player: Player)
	local bobber = castBobbers[player]
	if not bobber then
		return
	end
	CollectionService:RemoveTag(bobber, "SpinCrystal") -- stop the idle bob fighting the dip
	local splash = Instance.new("ParticleEmitter")
	splash.Color = ColorSequence.new(Color3.fromRGB(220, 250, 255))
	splash.Size = NumberSequence.new(0.7, 0)
	splash.Transparency = NumberSequence.new(0.1, 1)
	splash.Lifetime = NumberRange.new(0.35, 0.7)
	splash.Speed = NumberRange.new(8, 16)
	splash.SpreadAngle = Vector2.new(80, 80)
	splash.Acceleration = Vector3.new(0, -35, 0)
	splash.Rate = 0
	splash.Parent = bobber
	splash:Emit(22)
	TweenService:Create(bobber, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = bobber.Position - Vector3.new(0, 1.3, 0),
	}):Play()
end

-- Line's in: take the bobber back and give the rod its dangle again.
function RodVisual.Reel(player: Player)
	castToken[player] = (castToken[player] or 0) + 1
	clearBobber(player)
	local tool = equippedTool(player)
	if tool then
		tool.Grip = REST_GRIP
		dangle(tool, true)
	end
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
	-- A new rod means any cast in flight belongs to a tool that no longer exists.
	RodVisual.Reel(player)
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
	Players.PlayerRemoving:Connect(function(player)
		clearBobber(player)
		castToken[player] = nil
	end)
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
