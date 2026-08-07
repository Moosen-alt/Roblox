--!strict
-- Shared fish geometry: a recognisable fish built from primitives (no asset
-- uploads). One builder feeds the reveal card viewports, the aquarium tank, the
-- trophy over your head and the landmarks above the water — so a Rainbow Trout
-- is the same fish everywhere in the game.
--
-- This replaces CrystalShape for anything that represents a CATCH. A fishing
-- game whose fish render as glowing gems is a re-skin wearing a fishing hat;
-- the silhouette is the single cheapest thing that makes it its own game.

local FishShape = {}

export type Options = {
	Color: Color3,
	Scale: number?, -- overall size multiplier (1 ~= 3.5 studs nose to tail)
	Seed: number?,
	Glow: number?, -- PointLight range at the body (nil/0 = no light)
	Sparkle: boolean?, -- drifting glints (used for mutated/rare fish)
	Neon: boolean?, -- deep-water species that light themselves
}

-- Unlike the crystals, fish must NOT be fullbright. Neon renders flat and
-- unshaded, which is what turned every crystal cluster into one glowing blob —
-- on a fish it would erase the body/fin/tail separation that makes it read as a
-- fish at all. SmoothPlastic takes the light, so the form survives.
local function piece(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false -- a cast must never land on a decoration fish
	p.CanTouch = false
	p.Massless = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p
end

-- Fins and tail are a saturated, darker version of the body so they separate
-- from it without introducing a second unrelated colour.
local function finColor(body: Color3): Color3
	return body:Lerp(Color3.fromRGB(20, 18, 34), 0.42)
end

-- Nose points +X, so a camera on +Z sees the fish side-on — the only angle a
-- fish is recognisable from.
function FishShape.Build(options: Options): Model
	local model = Instance.new("Model")
	model.Name = "Fish"

	local scale = options.Scale or 1
	local rng = Random.new(options.Seed or 5)
	local color = options.Color
	local fin = finColor(color)
	local material = if options.Neon then Enum.Material.Neon else Enum.Material.SmoothPlastic

	-- Body: an ellipsoid, deeper than it is wide. Roblox scales a Ball part
	-- non-uniformly, so this is one part rather than a stack of them.
	local bodyLength = rng:NextNumber(2.6, 3.0) * scale
	local bodyHeight = rng:NextNumber(1.4, 1.8) * scale
	local bodyWidth = rng:NextNumber(0.72, 0.95) * scale
	local body = piece(model, {
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(bodyLength, bodyHeight, bodyWidth),
		CFrame = CFrame.new(0, 0, 0),
		Color = color,
		Material = material,
	})

	-- Pale belly. A flattened ellipsoid tucked under the body is the whole
	-- difference between "a fish" and "a coloured blob with fins".
	piece(model, {
		Name = "Belly",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(bodyLength * 0.82, bodyHeight * 0.52, bodyWidth * 0.94),
		CFrame = CFrame.new(-bodyLength * 0.04, -bodyHeight * 0.3, 0),
		Color = color:Lerp(Color3.new(1, 1, 1), 0.55),
		Material = material,
	})

	-- Snout: a smaller ellipsoid at the front, so the head tapers instead of
	-- ending in the same round curve as the tail.
	piece(model, {
		Name = "Snout",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(bodyLength * 0.42, bodyHeight * 0.62, bodyWidth * 0.72),
		CFrame = CFrame.new(bodyLength * 0.42, -bodyHeight * 0.05, 0),
		Color = color,
		Material = material,
	})

	-- Tail: a narrow stalk into a forked fin. The fork is the strongest read in
	-- the silhouette, so it is deliberately oversized.
	local tailX = -bodyLength * 0.52
	piece(model, {
		Name = "TailStalk",
		Size = Vector3.new(bodyLength * 0.26, bodyHeight * 0.34, bodyWidth * 0.42),
		CFrame = CFrame.new(tailX, 0, 0),
		Color = color,
		Material = material,
	})
	for i, lean in { 0.55, -0.55 } do
		piece(model, {
			Name = "TailFin" .. i,
			Size = Vector3.new(bodyLength * 0.52, bodyHeight * 0.62, bodyWidth * 0.16),
			CFrame = CFrame.new(tailX - bodyLength * 0.24, lean * bodyHeight * 0.34, 0)
				* CFrame.Angles(0, 0, lean * 0.75),
			Color = fin,
			Material = material,
		})
	end

	-- Dorsal fin, swept back
	piece(model, {
		Name = "Dorsal",
		Size = Vector3.new(bodyLength * 0.46, bodyHeight * 0.5, bodyWidth * 0.15),
		CFrame = CFrame.new(-bodyLength * 0.04, bodyHeight * 0.56, 0) * CFrame.Angles(0, 0, -0.35),
		Color = fin,
		Material = material,
	})
	-- Pectoral fins, one each side, angled down and back
	for i, side in { 1, -1 } do
		piece(model, {
			Name = "Pectoral" .. i,
			Size = Vector3.new(bodyLength * 0.3, bodyHeight * 0.14, bodyWidth * 0.5),
			CFrame = CFrame.new(bodyLength * 0.1, -bodyHeight * 0.2, side * bodyWidth * 0.42)
				* CFrame.Angles(side * 0.5, 0, -0.3),
			Color = fin,
			Material = material,
		})
	end

	-- Eyes: the single detail that turns a shape into an animal. One per side.
	for _, side in { 1, -1 } do
		piece(model, {
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(bodyHeight * 0.3, bodyHeight * 0.3, bodyHeight * 0.3),
			CFrame = CFrame.new(bodyLength * 0.42, bodyHeight * 0.16, side * bodyWidth * 0.3),
			Color = Color3.fromRGB(250, 250, 252),
			Material = Enum.Material.SmoothPlastic,
		})
		piece(model, {
			Name = "Pupil",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(bodyHeight * 0.17, bodyHeight * 0.17, bodyHeight * 0.17),
			CFrame = CFrame.new(bodyLength * 0.45, bodyHeight * 0.16, side * bodyWidth * 0.37),
			Color = Color3.fromRGB(18, 16, 26),
			Material = Enum.Material.SmoothPlastic,
		})
	end

	-- A couple of bands across the body. Seeded, so the same species always gets
	-- the same markings rather than reshuffling every time it is drawn.
	local bands = rng:NextInteger(0, 3)
	for i = 1, bands do
		local at = -bodyLength * 0.22 + (i - 1) * bodyLength * 0.2
		piece(model, {
			Name = "Band" .. i,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(bodyLength * 0.09, bodyHeight * 0.96, bodyWidth * 1.02),
			CFrame = CFrame.new(at, bodyHeight * 0.04, 0),
			Color = color:Lerp(Color3.fromRGB(30, 26, 44), 0.35),
			Material = material,
		})
	end

	if options.Glow and options.Glow > 0 then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = options.Glow
		light.Brightness = 1.3
		light.Shadows = false
		light.Parent = body
	end
	if options.Sparkle then
		local glints = Instance.new("ParticleEmitter")
		glints.Color = ColorSequence.new(color)
		glints.LightEmission = 1
		glints.Size = NumberSequence.new(0.3 * scale, 0)
		glints.Transparency = NumberSequence.new(0.1, 1)
		glints.Lifetime = NumberRange.new(0.7, 1.5)
		glints.Rate = 7
		glints.Speed = NumberRange.new(0.5, 1.6)
		glints.SpreadAngle = Vector2.new(60, 60)
		glints.Parent = body
	end

	model.PrimaryPart = body
	model.WorldPivot = CFrame.new()
	return model
end

return FishShape
