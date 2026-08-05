--!strict
-- A pillar of light dropped on a player, server-wide. Used for the moments
-- worth interrupting everyone else for: a Legendary+ pull, a Recrystallize.
-- Being seen is the reward; the coins are just the receipt.

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Spotlight = {}

function Spotlight.Pillar(player: Player, color: Color3)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local beam = Instance.new("Part")
	beam.Name = "Spotlight"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.Shape = Enum.PartType.Cylinder
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Transparency = 0.35
	beam.Size = Vector3.new(70, 7, 7)
	beam.CFrame = CFrame.new(root.Position + Vector3.new(0, 32, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Parent = Workspace

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 46
	light.Brightness = 4
	light.Parent = beam

	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(color)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(1.2, 0)
	sparks.Lifetime = NumberRange.new(0.8, 1.8)
	sparks.Speed = NumberRange.new(10, 26)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rate = 0
	sparks.Parent = beam
	sparks:Emit(60)

	TweenService:Create(beam, TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = Vector3.new(70, 16, 16),
		Transparency = 1,
	}):Play()
	TweenService:Create(light, TweenInfo.new(2.2), { Brightness = 0 }):Play()
	task.delay(2.6, function()
		beam:Destroy()
	end)
end

return Spotlight
