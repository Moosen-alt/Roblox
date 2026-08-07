--!strict
-- Relic geometry: every piece of sunken treasure built as the object it actually
-- is, from primitives, with no asset uploads.
--
-- Routing relics through CrystalShape made all eleven of them the same faceted
-- gem cluster in eleven colours. That is the exact failure the fish had before
-- FishShape — a name on a card doing all the work while the picture says
-- "generic collectible". A Rusty Anchor has to look like an anchor, or the
-- second collection is just the first one with different text.
--
-- Everything is built upright and facing +Z, because that is where the viewport
-- camera and the billboard over a player's head both look from.

local RelicShape = {}

export type Options = {
	Name: string,
	Color: Color3,
	Scale: number?,
	Seed: number?,
	Glow: number?,
	Sparkle: boolean?,
}

local GOLD = Color3.fromRGB(226, 178, 62)
local BRASS = Color3.fromRGB(198, 152, 74)
local DARK = Color3.fromRGB(48, 44, 52)

local function piece(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
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

-- A ring standing in the XY plane, made of short bars around a circle. Used for
-- the anchor's shackle, the astrolabe's rings and the crown's band.
local function ring(parent: Instance, center: Vector3, radius: number, thick: number, segments: number, color: Color3, material: Enum.Material)
	local chord = 2 * radius * math.sin(math.pi / segments) * 1.3
	for i = 1, segments do
		local theta = (i - 1) / segments * math.pi * 2
		piece(parent, {
			Name = "RingSeg",
			Size = Vector3.new(chord, thick, thick),
			CFrame = CFrame.new(center + Vector3.new(math.cos(theta) * radius, math.sin(theta) * radius, 0))
				* CFrame.Angles(0, 0, theta + math.pi * 0.5),
			Color = color,
			Material = material,
		})
	end
end

type Builder = (Model, Color3) -> ()

local BUILDERS: { [string]: Builder } = {}

BUILDERS["Rusty Anchor"] = function(model, color)
	piece(model, { Name = "Shank", Size = Vector3.new(0.34, 3, 0.34), Position = Vector3.new(0, 0.2, 0), Color = color, Material = Enum.Material.CorrodedMetal })
	piece(model, { Name = "Stock", Size = Vector3.new(2.2, 0.28, 0.28), Position = Vector3.new(0, 1.2, 0), Color = color, Material = Enum.Material.CorrodedMetal })
	ring(model, Vector3.new(0, 1.95, 0), 0.42, 0.2, 8, color, Enum.Material.CorrodedMetal)
	-- Flukes: two arms sweeping up and out from the bottom of the shank.
	for _, side in { -1, 1 } do
		piece(model, {
			Name = "Arm",
			Size = Vector3.new(1.5, 0.3, 0.3),
			CFrame = CFrame.new(side * 0.65, -1.15, 0) * CFrame.Angles(0, 0, side * 0.5),
			Color = color,
			Material = Enum.Material.CorrodedMetal,
		})
		piece(model, {
			Name = "Fluke",
			Size = Vector3.new(0.6, 0.62, 0.22),
			CFrame = CFrame.new(side * 1.28, -0.72, 0) * CFrame.Angles(0, 0, side * 0.9),
			Color = color,
			Material = Enum.Material.CorrodedMetal,
		})
	end
end

BUILDERS["Message in a Bottle"] = function(model, color)
	piece(model, { Name = "Body", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 1.25, 1.25), CFrame = CFrame.new(0, -0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = Enum.Material.Glass, Transparency = 0.45 })
	piece(model, { Name = "Neck", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 0.55, 0.55), CFrame = CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = Enum.Material.Glass, Transparency = 0.45 })
	piece(model, { Name = "Cork", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.45, 0.52, 0.52), CFrame = CFrame.new(0, 1.95, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(196, 160, 108), Material = Enum.Material.Wood })
	-- The scroll inside, which is the entire reason it is a message in a bottle.
	piece(model, { Name = "Scroll", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.5, 0.55, 0.55), CFrame = CFrame.new(0, -0.2, 0) * CFrame.Angles(0, 0, math.rad(65)), Color = Color3.fromRGB(238, 226, 190), Material = Enum.Material.SmoothPlastic })
end

BUILDERS["Silver Doubloon"] = function(model, color)
	piece(model, { Name = "Coin", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2.9, 2.9), CFrame = CFrame.Angles(0, math.rad(90), 0), Color = color, Material = Enum.Material.Metal })
	ring(model, Vector3.new(0, 0, 0.16), 1.28, 0.16, 14, color:Lerp(Color3.new(1, 1, 1), 0.4), Enum.Material.Metal)
	piece(model, { Name = "Emboss", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 1.5, 1.5), CFrame = CFrame.new(0, 0, 0.2) * CFrame.Angles(0, math.rad(90), 0), Color = color:Lerp(DARK, 0.3), Material = Enum.Material.Metal })
	piece(model, { Name = "Cross", Size = Vector3.new(0.22, 1.1, 0.12), Position = Vector3.new(0, 0, 0.28), Color = color:Lerp(Color3.new(1, 1, 1), 0.5), Material = Enum.Material.Metal })
	piece(model, { Name = "CrossBar", Size = Vector3.new(0.8, 0.22, 0.12), Position = Vector3.new(0, 0.14, 0.28), Color = color:Lerp(Color3.new(1, 1, 1), 0.5), Material = Enum.Material.Metal })
end

BUILDERS["Ship's Compass"] = function(model, color)
	piece(model, { Name = "Case", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.75, 2.8, 2.8), CFrame = CFrame.Angles(0, math.rad(90), 0), Color = color, Material = Enum.Material.Metal })
	piece(model, { Name = "Face", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 2.3, 2.3), CFrame = CFrame.new(0, 0, 0.4) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(242, 232, 206), Material = Enum.Material.SmoothPlastic })
	-- Needle: red north, white south, which is the read at a glance.
	piece(model, { Name = "NeedleN", Size = Vector3.new(0.16, 1, 0.1), CFrame = CFrame.new(0, 0.42, 0.5) * CFrame.Angles(0, 0, math.rad(24)), Color = Color3.fromRGB(214, 66, 60), Material = Enum.Material.SmoothPlastic })
	piece(model, { Name = "NeedleS", Size = Vector3.new(0.16, 1, 0.1), CFrame = CFrame.new(0, -0.42, 0.5) * CFrame.Angles(0, 0, math.rad(24)), Color = Color3.fromRGB(240, 240, 244), Material = Enum.Material.SmoothPlastic })
	piece(model, { Name = "Pin", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.16, 0.3, 0.3), CFrame = CFrame.new(0, 0, 0.56) * CFrame.Angles(0, math.rad(90), 0), Color = BRASS, Material = Enum.Material.Metal })
	piece(model, { Name = "Lid", Size = Vector3.new(2.6, 0.2, 0.9), CFrame = CFrame.new(0, 1.5, -0.1) * CFrame.Angles(math.rad(-35), 0, 0), Color = color:Lerp(DARK, 0.25), Material = Enum.Material.Metal })
end

BUILDERS["Diver's Helmet"] = function(model, color)
	piece(model, { Name = "Dome", Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 2.5, 2.6), Position = Vector3.new(0, 0.25, 0), Color = color, Material = Enum.Material.Metal })
	piece(model, { Name = "Collar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 2.5, 2.5), CFrame = CFrame.new(0, -1.05, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = color:Lerp(DARK, 0.25), Material = Enum.Material.Metal })
	-- Faceplate: the round window and its bolted ring, the one detail that makes
	-- a copper ball unmistakably a diving helmet.
	piece(model, { Name = "Glass", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 1.5, 1.5), CFrame = CFrame.new(0, 0.3, 1.2) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(170, 220, 235), Material = Enum.Material.Glass, Transparency = 0.35 })
	ring(model, Vector3.new(0, 0.3, 1.22), 0.82, 0.2, 10, color:Lerp(Color3.new(1, 1, 1), 0.25), Enum.Material.Metal)
	for i = 1, 6 do
		local theta = (i - 1) / 6 * math.pi * 2
		piece(model, { Name = "Bolt", Shape = Enum.PartType.Ball, Size = Vector3.new(0.2, 0.2, 0.2), Position = Vector3.new(math.cos(theta) * 0.82, 0.3 + math.sin(theta) * 0.82, 1.3), Color = BRASS, Material = Enum.Material.Metal })
	end
	piece(model, { Name = "Valve", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 0.4, 0.4), CFrame = CFrame.new(-1.1, 0.7, 0.3) * CFrame.Angles(0, 0, math.rad(20)), Color = BRASS, Material = Enum.Material.Metal })
end

BUILDERS["Pirate Cutlass"] = function(model, color)
	-- Blade: short segments fanned along an arc, so it curves like a cutlass
	-- instead of being a straight bar with a handle.
	for i = 1, 7 do
		local t = i / 7
		piece(model, {
			Name = "Blade" .. i,
			Size = Vector3.new(0.42 - t * 0.14, 0.52, 0.12),
			CFrame = CFrame.new(t * 0.55, -0.4 + i * 0.44, 0) * CFrame.Angles(0, 0, -t * 0.26),
			Color = color,
			Material = Enum.Material.Metal,
		})
	end
	piece(model, { Name = "Guard", Size = Vector3.new(1.5, 0.24, 0.3), Position = Vector3.new(0, -0.15, 0), Color = GOLD, Material = Enum.Material.Metal })
	piece(model, { Name = "Knuckle", Size = Vector3.new(0.24, 1.1, 0.26), CFrame = CFrame.new(0.62, -0.75, 0) * CFrame.Angles(0, 0, math.rad(-18)), Color = GOLD, Material = Enum.Material.Metal })
	piece(model, { Name = "Grip", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 0.36, 0.36), CFrame = CFrame.new(0, -0.85, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(84, 54, 40), Material = Enum.Material.Wood })
	piece(model, { Name = "Pommel", Shape = Enum.PartType.Ball, Size = Vector3.new(0.46, 0.46, 0.46), Position = Vector3.new(0, -1.5, 0), Color = GOLD, Material = Enum.Material.Metal })
end

BUILDERS["Captain's Spyglass"] = function(model, color)
	-- Three telescoping sections, each shorter and narrower than the last.
	local sections = { { len = 1.5, rad = 0.72, at = -0.9 }, { len = 1.3, rad = 0.56, at = 0.5 }, { len = 1.1, rad = 0.42, at = 1.7 } }
	for i, s in sections do
		piece(model, { Name = "Tube" .. i, Shape = Enum.PartType.Cylinder, Size = Vector3.new(s.len, s.rad * 2, s.rad * 2), CFrame = CFrame.new(0, s.at, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = color:Lerp(DARK, (i - 1) * 0.12), Material = Enum.Material.Metal })
		piece(model, { Name = "Band" .. i, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.18, s.rad * 2.2, s.rad * 2.2), CFrame = CFrame.new(0, s.at + s.len * 0.45, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = BRASS, Material = Enum.Material.Metal })
	end
	piece(model, { Name = "Grip", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7, 1.5, 1.5), CFrame = CFrame.new(0, -0.9, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(84, 54, 40), Material = Enum.Material.Wood })
	piece(model, { Name = "Lens", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 0.7, 0.7), CFrame = CFrame.new(0, 2.28, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(180, 226, 240), Material = Enum.Material.Glass, Transparency = 0.3 })
end

BUILDERS["Golden Astrolabe"] = function(model, color)
	ring(model, Vector3.new(0, 0, 0), 1.45, 0.24, 16, color, Enum.Material.Metal)
	ring(model, Vector3.new(0, 0, 0), 1.05, 0.18, 12, color:Lerp(Color3.new(1, 1, 1), 0.25), Enum.Material.Metal)
	ring(model, Vector3.new(0, 0, 0), 0.65, 0.14, 10, color:Lerp(DARK, 0.2), Enum.Material.Metal)
	piece(model, { Name = "Plate", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 1.1, 1.1), CFrame = CFrame.Angles(0, math.rad(90), 0), Color = color:Lerp(DARK, 0.35), Material = Enum.Material.Metal })
	piece(model, { Name = "Rule", Size = Vector3.new(2.7, 0.16, 0.1), CFrame = CFrame.new(0, 0, 0.22) * CFrame.Angles(0, 0, math.rad(28)), Color = color:Lerp(Color3.new(1, 1, 1), 0.4), Material = Enum.Material.Metal })
	piece(model, { Name = "Hanger", Size = Vector3.new(0.2, 0.4, 0.2), Position = Vector3.new(0, 1.66, 0), Color = color, Material = Enum.Material.Metal })
	ring(model, Vector3.new(0, 2.05, 0), 0.28, 0.14, 8, color, Enum.Material.Metal)
end

BUILDERS["Mermaid's Mirror"] = function(model, color)
	ring(model, Vector3.new(0, 0.55, 0), 1.25, 0.3, 16, GOLD, Enum.Material.Metal)
	piece(model, { Name = "Glass", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.16, 2.3, 2.3), CFrame = CFrame.new(0, 0.55, 0) * CFrame.Angles(0, math.rad(90), 0), Color = color, Material = Enum.Material.Glass, Transparency = 0.25, Reflectance = 0.6 })
	piece(model, { Name = "Handle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.5, 0.3, 0.3), CFrame = CFrame.new(0, -1.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = GOLD, Material = Enum.Material.Metal })
	piece(model, { Name = "Knob", Shape = Enum.PartType.Ball, Size = Vector3.new(0.44, 0.44, 0.44), Position = Vector3.new(0, -1.9, 0), Color = GOLD, Material = Enum.Material.Metal })
	for _, side in { -1, 1 } do
		piece(model, { Name = "Scroll", Size = Vector3.new(0.5, 0.24, 0.2), CFrame = CFrame.new(side * 0.6, -0.55, 0) * CFrame.Angles(0, 0, side * 0.6), Color = GOLD, Material = Enum.Material.Metal })
	end
end

BUILDERS["Sunken Crown"] = function(model, color)
	ring(model, Vector3.new(0, -0.5, 0), 1.25, 0.42, 14, color, Enum.Material.Metal)
	-- Points around the band, alternating tall and short, each capped with a gem.
	for i = 1, 8 do
		local theta = (i - 1) / 8 * math.pi * 2
		local tall = i % 2 == 1
		local height = tall and 1.15 or 0.7
		local at = Vector3.new(math.cos(theta) * 1.15, 0.1 + height * 0.5, math.sin(theta) * 1.15)
		piece(model, {
			Name = "Point",
			Size = Vector3.new(0.34, height, 0.34),
			CFrame = CFrame.new(at) * CFrame.Angles(math.cos(theta) * 0.12, 0, -math.sin(theta) * 0.12),
			Color = color,
			Material = Enum.Material.Metal,
		})
		if tall then
			piece(model, {
				Name = "Gem",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.42, 0.42, 0.42),
				Position = at + Vector3.new(0, height * 0.55, 0),
				Color = Color3.fromRGB(90, 180, 255),
				Material = Enum.Material.Neon,
			})
		end
	end
end

BUILDERS["Poseidon's Trident"] = function(model, color)
	piece(model, { Name = "Shaft", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4.2, 0.3, 0.3), CFrame = CFrame.new(0, -0.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = Enum.Material.Metal })
	piece(model, { Name = "Head", Size = Vector3.new(1.9, 0.26, 0.26), Position = Vector3.new(0, 1.4, 0), Color = color, Material = Enum.Material.Metal })
	-- Three prongs: a long centre and two barbed outer ones.
	for _, x in { -0.8, 0, 0.8 } do
		local height = if x == 0 then 1.5 else 1.15
		piece(model, {
			Name = "Prong",
			Size = Vector3.new(0.22, height, 0.22),
			Position = Vector3.new(x, 1.4 + height * 0.5, 0),
			Color = color,
			Material = Enum.Material.Metal,
		})
		piece(model, {
			Name = "Tip",
			Size = Vector3.new(0.14, 0.4, 0.14),
			Position = Vector3.new(x, 1.4 + height + 0.18, 0),
			Color = color:Lerp(Color3.new(1, 1, 1), 0.5),
			Material = Enum.Material.Neon,
		})
	end
	piece(model, { Name = "Butt", Shape = Enum.PartType.Ball, Size = Vector3.new(0.42, 0.42, 0.42), Position = Vector3.new(0, -2.7, 0), Color = color, Material = Enum.Material.Metal })
end

-- Anything without its own builder: a small hoard of coins and a bar. Better an
-- honest generic pile of treasure than a gem pretending to be a spyglass, and it
-- means a new relic row can ship before its model does.
local function buildFallback(model: Model, color: Color3)
	piece(model, { Name = "Bar", Size = Vector3.new(1.8, 0.5, 0.9), Position = Vector3.new(0, -0.6, 0), Color = color, Material = Enum.Material.Metal })
	local rng = Random.new(3)
	for i = 1, 6 do
		piece(model, {
			Name = "Coin" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.16, 0.8, 0.8),
			CFrame = CFrame.new(rng:NextNumber(-0.9, 0.9), -0.1 + i * 0.14, rng:NextNumber(-0.4, 0.4))
				* CFrame.Angles(math.rad(90), 0, rng:NextNumber(-0.5, 0.5)),
			Color = color:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.4)),
			Material = Enum.Material.Metal,
		})
	end
end

function RelicShape.Build(options: Options): Model
	local model = Instance.new("Model")
	model.Name = "Relic"

	-- Typed explicitly: Luau will not call a union of two identically shaped
	-- function types, so the branch has to name what it returns.
	local build: Builder = BUILDERS[options.Name] or buildFallback
	build(model, options.Color)

	local anchor = model:FindFirstChildWhichIsA("BasePart")
	if anchor then
		if options.Glow and options.Glow > 0 then
			local light = Instance.new("PointLight")
			light.Color = options.Color
			light.Range = options.Glow
			light.Brightness = 0.7
			light.Shadows = false
			light.Parent = anchor
		end
		if options.Sparkle then
			local glints = Instance.new("ParticleEmitter")
			glints.Color = ColorSequence.new(options.Color)
			glints.LightEmission = 0.3
			glints.Size = NumberSequence.new(0.3, 0)
			glints.Transparency = NumberSequence.new(0.15, 1)
			glints.Lifetime = NumberRange.new(0.6, 1.3)
			glints.Rate = 6
			glints.Speed = NumberRange.new(0.4, 1.4)
			glints.SpreadAngle = Vector2.new(70, 70)
			glints.Parent = anchor
		end
	end

	-- Scale after building, so each builder can work in whatever studs read best
	-- for its own shape and the caller still gets one consistent size knob.
	local scale = options.Scale or 1
	if scale ~= 1 then
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") then
				part.Size *= scale
				part.CFrame = CFrame.new(part.Position * scale) * (part.CFrame - part.Position)
			end
		end
	end

	-- Pivot at the centroid, matching FishShape: relics are hand-built and none
	-- of them is symmetrical about the origin, so an origin pivot makes them
	-- orbit the frame when they spin and land off-target when placed.
	local box = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(box.Position)
	return model
end

-- True when this relic has a hand-built model rather than the generic hoard.
function RelicShape.HasModel(name: string): boolean
	return BUILDERS[name] ~= nil
end

return RelicShape
