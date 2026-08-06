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

-- Neon is FULLBRIGHT: Roblox draws it as flat unshaded colour, so no amount of
-- faceting shows up and a cluster of same-coloured neon parts silhouettes into
-- one glowing blob. That is the whole reason these read as stickers rather than
-- crystals.
--
-- The fix is not to drop neon — a dark cave needs the glow — but to make each
-- facet a slightly different shade and transparency. With a fullbright material
-- colour IS the render, so varying it is what puts the edges back.
local function facet(parent: Instance, cframe: CFrame, size: Vector3, color: Color3, shade: number, clarity: number): Part
	local p = Instance.new("Part")
	p.Name = "Facet"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false -- mining raycasts must hit the geode hitbox, not the sparkle
	p.CanTouch = false
	p.Massless = true
	p.Material = Enum.Material.Neon
	-- Negative shade darkens toward the crystal's own deep tone, positive lifts
	-- toward white, so neighbouring facets never merge into one another.
	p.Color = if shade >= 0
		then color:Lerp(Color3.new(1, 1, 1), shade)
		else color:Lerp(Color3.new(0.06, 0.05, 0.12), -shade)
	p.Transparency = clarity
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cframe
	p.Parent = parent
	return p
end

-- One spike: stacked blocks that shrink as they rise, each turned 45 degrees so
-- the silhouette reads as a faceted crystal rather than a stick.
-- One spike: stacked blocks that shrink as they rise, each turned 45 degrees so
-- the silhouette reads as a faceted crystal rather than a stick. `tone` shifts
-- the whole spike's shade so it separates from its neighbours in the cluster.
local function spike(
	parent: Instance,
	base: CFrame,
	height: number,
	width: number,
	color: Color3,
	segments: number,
	tone: number
): Part
	local segHeight = height / (segments + 0.5)
	local tallest = nil :: Part?
	for s = 1, segments do
		local t = (s - 1) / segments
		local w = width * (1 - t * 0.5)
		-- Dark at the root, bright at the tip: light looks like it is coming from
		-- inside the crystal instead of painting it evenly.
		tallest = facet(
			parent,
			base * CFrame.new(0, segHeight * (s - 0.5), 0) * CFrame.Angles(0, math.rad(45), 0),
			Vector3.new(w, segHeight, w),
			color,
			tone - 0.22 + t * 0.45,
			0.05 + (1 - t) * 0.12
		)
	end
	-- Chisel tip: the brightest, clearest part of the spike
	local tip = facet(
		parent,
		base * CFrame.new(0, segments * segHeight + segHeight * 0.28, 0) * CFrame.Angles(0, math.rad(45), 0),
		Vector3.new(width * 0.34, segHeight * 0.6, width * 0.34),
		color,
		tone + 0.34,
		0.02
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
		local lean = isCenter and rng:NextNumber(0, 0.12) or rng:NextNumber(0.2, 0.5)
		-- Squat and overlapping, not tall and separated. At a 5:1 aspect ratio
		-- with gaps between them these read as a handful of dropped sticks from
		-- any distance; ~2.5:1 and touching reads as one crystal formation.
		local dist = (isCenter and 0 or rng:NextNumber(0.28, 0.58)) * scale
		local height = (isCenter and rng:NextNumber(2.3, 2.8) or rng:NextNumber(1.2, 2.0)) * scale
		local width = rng:NextNumber(0.8, 1.1) * scale
		-- Tilt away from the cluster centre: rotate about the horizontal axis
		-- perpendicular to the shard's radial direction.
		local tiltAxis = Vector3.new(-dir.Z, 0, dir.X)
		local base = CFrame.new(dir * dist) * CFrame.fromAxisAngle(tiltAxis, -lean)
		-- Each shard sits at its own point on the light/dark ramp
		local tone = rng:NextNumber(-0.18, 0.2)
		local part = spike(model, base, height, width, options.Color, segments, tone)
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
			light.Brightness = 1.4
			light.Shadows = false
			light.Parent = anchor
		end
		if options.Sparkle then
			local glints = Instance.new("ParticleEmitter")
			glints.Color = ColorSequence.new(options.Color)
			glints.LightEmission = 1
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
