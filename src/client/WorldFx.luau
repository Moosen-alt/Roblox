--!strict
-- Client-side world juice: crystals that turn and float, per-player mining
-- feedback (widening cracks, chips, damage numbers), and camera shake.
--
-- All of it is local. Nothing here replicates, which is why your crack progress
-- on a shared deposit can look different from the player standing next to you,
-- and why a dozen spinning crystals cost the server nothing.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local WorldFx = {}

local rng = Random.new()
local shake = 0

-- Shake decays fast and is capped, so a fast tapper gets a lively screen rather
-- than an unplayable one.
function WorldFx.Shake(amount: number)
	shake = math.min(shake + amount, 2.2)
end

local function playLocal(parent: Instance, id: string, pitch: number, volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.PlaybackSpeed = pitch
	sound.Volume = volume
	sound.Parent = parent
	sound:Play()
	task.delay(2.5, function()
		sound:Destroy()
	end)
end

--------------------------------------------------------------------------------
-- Spinning / bobbing crystals
--------------------------------------------------------------------------------

-- PVInstance, not Model: this drives crystal clusters and single parts alike.
type Spinner = { Object: PVInstance, Base: CFrame, Speed: number, Bob: number, BobSpeed: number, Phase: number }

local spinners: { Spinner } = {}
local spinnerOf: { [PVInstance]: Spinner } = {}

local function trackSpinner(instance: Instance)
	if not instance:IsA("PVInstance") then
		return
	end
	local object = instance :: PVInstance
	if spinnerOf[object] then
		return
	end
	local spinner: Spinner = {
		Object = object,
		Base = object:GetPivot(),
		Speed = (object:GetAttribute("SpinSpeed") :: number?) or 0.4,
		Bob = (object:GetAttribute("BobHeight") :: number?) or 0,
		BobSpeed = (object:GetAttribute("BobSpeed") :: number?) or 0.6,
		Phase = rng:NextNumber(0, math.pi * 2),
	}
	spinnerOf[object] = spinner
	table.insert(spinners, spinner)
end

local function untrackSpinner(instance: Instance)
	if not instance:IsA("PVInstance") then
		return
	end
	local spinner = spinnerOf[instance :: PVInstance]
	if not spinner then
		return
	end
	spinnerOf[instance :: PVInstance] = nil
	local index = table.find(spinners, spinner)
	if index then
		table.remove(spinners, index)
	end
end

--------------------------------------------------------------------------------
-- Mining feedback
--------------------------------------------------------------------------------

local CHIP_COLOR = Color3.fromRGB(120, 108, 140)

local function geodeParts(node: BasePart): (Model?, BasePart?, { BasePart })
	local model = node.Parent
	if not model or not model:IsA("Model") then
		return nil, nil, {}
	end
	local core = model:FindFirstChild("Core")
	local veins: { BasePart } = {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and string.sub(child.Name, 1, 4) == "Vein" then
			table.insert(veins, child)
		end
	end
	return model, (core :: BasePart?), veins
end

-- Absolute, not incremental: every update paints the geode from the fraction
-- the server sent, so a dropped packet can't leave it stuck half-cracked.
local function paintDamage(node: BasePart, fraction: number)
	local model, core, veins = geodeParts(node)
	if not model then
		return
	end
	for i, vein in veins do
		local grow = 1 + fraction * 1.9
		vein.Size = Vector3.new(0.3 * grow, vein.Size.Y, 0.4 * grow)
		vein.Transparency = math.max(0.5 - fraction * 0.5, 0)
		-- Cracks light up in sequence as the geode gives way
		if fraction > (i - 1) / #veins then
			vein.Material = Enum.Material.Neon
		end
	end
	if core then
		core.Transparency = math.max(0.55 - fraction * 0.5, 0.05)
		core.Size = Vector3.new(3.6, 3.6, 3.6) * (1 + fraction * 0.25)
	end
	local rock = model:FindFirstChild("Rock")
	if rock and rock:IsA("BasePart") then
		-- Squash-and-stretch punch on the rock itself
		rock.Size = Vector3.new(7.4, 7.4, 7.4) * 0.93
		TweenService:Create(rock, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = Vector3.new(7.4, 7.4, 7.4),
		}):Play()
	end
end

local function resetDamage(node: BasePart)
	local model, core, veins = geodeParts(node)
	if not model then
		return
	end
	for _, vein in veins do
		vein.Size = Vector3.new(0.3, vein.Size.Y, 0.4)
		vein.Transparency = 0.5
	end
	if core then
		core.Transparency = 0.55
		core.Size = Vector3.new(3.6, 3.6, 3.6)
	end
end

local function chips(node: BasePart, color: Color3)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(CHIP_COLOR)
	emitter.Size = NumberSequence.new(0.45, 0.05)
	emitter.Transparency = NumberSequence.new(0.1, 1)
	emitter.Lifetime = NumberRange.new(0.35, 0.7)
	emitter.Speed = NumberRange.new(9, 18)
	emitter.SpreadAngle = Vector2.new(55, 55)
	emitter.Acceleration = Vector3.new(0, -60, 0)
	emitter.Rate = 0
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-220, 220)
	emitter.Parent = node
	emitter:Emit(9)

	local glint = Instance.new("ParticleEmitter")
	glint.Color = ColorSequence.new(color)
	glint.LightEmission = 1
	glint.Size = NumberSequence.new(0.3, 0)
	glint.Lifetime = NumberRange.new(0.3, 0.55)
	glint.Speed = NumberRange.new(6, 13)
	glint.SpreadAngle = Vector2.new(70, 70)
	glint.Rate = 0
	glint.Parent = node
	glint:Emit(5)

	task.delay(1.2, function()
		emitter:Destroy()
		glint:Destroy()
	end)
end

-- Damage numbers: the single cheapest way to make a tap feel like it landed.
local function damageNumber(node: BasePart, damage: number, color: Color3)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(4, 1.6)
	billboard.StudsOffset = Vector3.new(rng:NextNumber(-1.6, 1.6), 2.4, 2)
	billboard.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = "-" .. damage
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeTransparency = 0.15
	label.Parent = billboard
	billboard.Parent = node
	TweenService:Create(billboard, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = billboard.StudsOffset + Vector3.new(0, 4.5, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(0.75), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.85, function()
		billboard:Destroy()
	end)
end

local function onMineFx(payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	local node = payload.Node
	if typeof(node) ~= "Instance" or not node:IsA("BasePart") then
		return
	end
	if payload.Reset then
		resetDamage(node)
		return
	end
	local color = typeof(payload.Color) == "Color3" and payload.Color or Color3.fromRGB(255, 210, 90)
	local fraction = tonumber(payload.Fraction) or 0
	paintDamage(node, fraction)
	chips(node, color)
	if typeof(payload.Damage) == "number" then
		damageNumber(node, payload.Damage, color)
	end
	if payload.Broke then
		WorldFx.Shake(1.5)
	else
		-- Pitch climbs with progress: you can hear the geode about to go
		playLocal(node, "rbxasset://sounds/electronicpingshort.wav", 0.85 + fraction * 0.6, 0.45)
		WorldFx.Shake(0.35)
	end
end

--------------------------------------------------------------------------------

function WorldFx.Init()
	for _, tagged in CollectionService:GetTagged("SpinCrystal") do
		trackSpinner(tagged)
	end
	CollectionService:GetInstanceAddedSignal("SpinCrystal"):Connect(trackSpinner)
	CollectionService:GetInstanceRemovedSignal("SpinCrystal"):Connect(untrackSpinner)

	local clock = 0
	RunService.RenderStepped:Connect(function(dt)
		clock += dt
		for _, spinner in spinners do
			if spinner.Object.Parent then
				local lift = spinner.Bob > 0
					and math.sin(clock * spinner.BobSpeed + spinner.Phase) * spinner.Bob
					or 0
				spinner.Object:PivotTo(
					spinner.Base * CFrame.new(0, lift, 0) * CFrame.Angles(0, clock * spinner.Speed * math.pi, 0)
				)
			end
		end
	end)

	-- Shake is applied after the camera script has written its CFrame, or it
	-- gets overwritten the same frame.
	RunService:BindToRenderStep("WorldFxShake", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		if shake <= 0.0005 then
			return
		end
		shake = math.max(shake - dt * 6, 0)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local magnitude = shake * 0.012
		camera.CFrame = camera.CFrame
			* CFrame.Angles(
				rng:NextNumber(-magnitude, magnitude),
				rng:NextNumber(-magnitude, magnitude),
				rng:NextNumber(-magnitude, magnitude)
			)
	end)

	Remotes.Event("MineFx").OnClientEvent:Connect(onMineFx)
end

return WorldFx
