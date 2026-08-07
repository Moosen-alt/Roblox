--!strict
-- Shared crystal geometry: a cluster of tapered, glowing shards built from
-- primitives (no asset uploads). One builder feeds the cave decoration, the
-- crystal inside every geode, and the spinning 3D gem on reveal cards — so a
-- Sapphire is recognisably the same rock everywhere in the game.

local CrystalShape = {}

export type Options = {
	Color: Color3,
	Scale: number?, -- overall size multiplier (1 ~= 3.5 studs tall)
	Shards: number?, -- spikes in the cluster
	Segments: number?, -- taper detail per spike: 1 = flat spike, 3 = faceted gem
	Seed: number?,
	Glow: number?, -- PointLight range at the cluster centre (nil/0 = no light)
	Sparkle: boolean?, -- drifting glints around the cluster
}

local function facet(parent: Instance, cframe: CFrame, size: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = "Facet"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false -- mining raycasts must hit the geode hitbox, not the sparkle
	p.CanTouch = false
	p.Massless = true
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.06
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cframe
	p.Parent = parent
	return p
end

-- One spike: stacked blocks that shrink as they rise, each turned 45 degrees so
-- the silhouette reads as a faceted crystal rather than a stick.
local function spike(parent: Instance, base: CFrame, height: number, width: number, color: Color3, segments: number): Part
	local segHeight = height / (segments + 0.5)
	local tallest = nil :: Part?
	for s = 1, segments do
		local t = (s - 1) / segments
		local w = width * (1 - t * 0.5)
		tallest = facet(
			parent,
			base * CFrame.new(0, segHeight * (s - 0.5), 0) * CFrame.Angles(0, math.rad(45), 0),
			Vector3.new(w, segHeight, w),
			color
		)
	end
	-- Chisel tip
	local tip = facet(
		parent,
		base * CFrame.new(0, segments * segHeight + segHeight * 0.28, 0) * CFrame.Angles(0, math.rad(45), 0),
		Vector3.new(width * 0.34, segHeight * 0.6, width * 0.34),
		color
	)
	return tallest or tip
end

function CrystalShape.Build(options: Options): Model
	local model = Instance.new("Model")
	model.Name = "Crystal"

	local scale = options.Scale or 1
	local shards = math.max(options.Shards or 5, 1)
	local segments = math.max(options.Segments or 2, 1)
	local rng = Random.new(options.Seed or 7)
	local center: Part? = nil

	for i = 1, shards do
		local angle = ((i - 1) / shards) * math.pi * 2 + rng:NextNumber(-0.35, 0.35)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local isCenter = i == 1
		local lean = isCenter and rng:NextNumber(0, 0.12) or rng:NextNumber(0.2, 0.55)
		local dist = (isCenter and 0 or rng:NextNumber(0.4, 0.85)) * scale
		local height = (isCenter and rng:NextNumber(3.1, 3.6) or rng:NextNumber(1.5, 2.8)) * scale
		local width = rng:NextNumber(0.5, 0.8) * scale
		-- Tilt away from the cluster centre: rotate about the horizontal axis
		-- perpendicular to the shard's radial direction.
		local tiltAxis = Vector3.new(-dir.Z, 0, dir.X)
		local base = CFrame.new(dir * dist) * CFrame.fromAxisAngle(tiltAxis, -lean)
		local part = spike(model, base, height, width, options.Color, segments)
		if isCenter then
			center = part
		end
	end

	local anchor = center or model:FindFirstChildWhichIsA("BasePart")
	if anchor then
		if options.Glow and options.Glow > 0 then
			local light = Instance.new("PointLight")
			light.Color = options.Color
			light.Range = options.Glow
			light.Brightness = 0.8
			light.Shadows = false
			light.Parent = anchor
		end
		if options.Sparkle then
			local glints = Instance.new("ParticleEmitter")
			glints.Color = ColorSequence.new(options.Color)
			glints.LightEmission = 0.3
			glints.Size = NumberSequence.new(0.35 * scale, 0)
			glints.Transparency = NumberSequence.new(0.1, 1)
			glints.Lifetime = NumberRange.new(0.8, 1.6)
			glints.Rate = 6
			glints.Speed = NumberRange.new(0.6, 1.8)
			glints.SpreadAngle = Vector2.new(60, 60)
			glints.Parent = anchor
		end
	end

	-- Pivot at the base of the cluster so callers can plant it on a surface and
	-- spin it about its own axis.
	model.WorldPivot = CFrame.new()
	return model
end

return CrystalShape
