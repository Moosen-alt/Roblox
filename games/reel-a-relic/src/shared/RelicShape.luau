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

local MeshBuild = require(script.Parent.MeshBuild)
local Meshes = require(script.Parent.Config.Meshes)

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
	-- An uploaded mesh wins if one exists for this relic. Per-relic, not
	-- all-or-nothing, so a partly-uploaded set is a valid state to ship in.
	-- See Config/Meshes.
	local override = Meshes.ForRelic(options.Name)
	if override then
		return MeshBuild.Build(override, options.Name, options.Color, options.Scale or 1, options.Glow)
	end

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

--------------------------------------------------------------------------------
-- AREA TREASURE. Each stretch of water has its own history, so each one has its
-- own things to dredge up: Spanish plate-fleet gold in the Keys, hard-hat diving
-- and cannery scrap off California, island carvings on the reef, lost research
-- hardware in the trench, and shrine relics in the Abyss. A chest that can only
-- come up with the same eleven objects everywhere makes five areas feel like one.
--------------------------------------------------------------------------------

local IVORY = Color3.fromRGB(238, 230, 208)
local STEEL = Color3.fromRGB(150, 156, 168)

-- 1. FLORIDA KEYS: the Spanish treasure fleets went down here.
BUILDERS["Conch Shell"] = function(model, color)
	-- A spiral: shrinking whorls climbing and turning.
	for i = 1, 9 do
		local t = (i - 1) / 9
		local radius = 0.85 * (1 - t * 0.8)
		local angle = t * 6.2
		piece(model, {
			Name = "Whorl",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.5 - t * 1.15, 1.4 - t * 1.1, 1.5 - t * 1.15),
			CFrame = CFrame.new(math.cos(angle) * radius, -0.9 + t * 2.4, math.sin(angle) * radius),
			Color = color:Lerp(IVORY, t * 0.5),
			Material = Enum.Material.Sandstone,
		})
	end
	-- The flared pink lip, which is the whole silhouette of a conch.
	for i = 1, 5 do
		local a = -0.6 + i * 0.3
		piece(model, {
			Name = "Lip",
			Size = Vector3.new(0.9, 1.5, 0.22),
			CFrame = CFrame.new(math.cos(a) * 1.15, -0.55, math.sin(a) * 1.15) * CFrame.Angles(0, -a, 0.25),
			Color = Color3.fromRGB(248, 196, 190),
			Material = Enum.Material.Sandstone,
		})
	end
	piece(model, { Name = "Spike", Size = Vector3.new(0.24, 0.7, 0.24), CFrame = CFrame.new(0.5, 1.5, 0) * CFrame.Angles(0, 0, -0.5), Color = IVORY, Material = Enum.Material.Sandstone })
end

BUILDERS["Hurricane Lamp"] = function(model, color)
	piece(model, { Name = "Base", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, 1.7, 1.7), CFrame = CFrame.new(0, -1.35, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = BRASS, Material = Enum.Material.Metal })
	piece(model, { Name = "Font", Shape = Enum.PartType.Ball, Size = Vector3.new(1.3, 1.0, 1.3), Position = Vector3.new(0, -0.8, 0), Color = BRASS, Material = Enum.Material.Metal })
	piece(model, { Name = "Glass", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.9, 1.15, 1.15), CFrame = CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = Enum.Material.Neon, Transparency = 0.4 })
	piece(model, { Name = "Flame", Shape = Enum.PartType.Ball, Size = Vector3.new(0.4, 0.7, 0.4), Position = Vector3.new(0, 0.3, 0), Color = Color3.fromRGB(255, 214, 130), Material = Enum.Material.Neon })
	piece(model, { Name = "Cap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1.4, 1.4), CFrame = CFrame.new(0, 1.45, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = BRASS, Material = Enum.Material.Metal })
	-- Guard bars down the sides of the chimney, and the carry hoop.
	for _, side in { -1, 1 } do
		piece(model, { Name = "Guard", Size = Vector3.new(0.12, 2.1, 0.12), Position = Vector3.new(side * 0.62, 0.4, 0), Color = BRASS, Material = Enum.Material.Metal })
	end
	ring(model, Vector3.new(0, 2.1, 0), 0.5, 0.12, 8, BRASS, Enum.Material.Metal)
end

BUILDERS["Spanish Emerald"] = function(model, color)
	-- An emerald cut: a squat octagonal prism with a stepped crown.
	for i = 1, 4 do
		piece(model, {
			Name = "Facet",
			Size = Vector3.new(1.9, 1.5, 1.9),
			CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, i * math.pi / 4, 0),
			Color = color,
			Material = Enum.Material.Glass,
			Transparency = 0.25,
		})
	end
	for i = 1, 3 do
		piece(model, {
			Name = "Crown",
			Size = Vector3.new(1.9 - i * 0.4, 0.28, 1.9 - i * 0.4),
			CFrame = CFrame.new(0, 0.72 + i * 0.24, 0) * CFrame.Angles(0, i * 0.4, 0),
			Color = color:Lerp(Color3.new(1, 1, 1), 0.2),
			Material = Enum.Material.Glass,
			Transparency = 0.2,
		})
	end
	-- Gold claw setting: this came off something.
	for i = 1, 4 do
		local a = i * math.pi / 2 + math.pi / 4
		piece(model, { Name = "Claw", Size = Vector3.new(0.22, 1.5, 0.22), CFrame = CFrame.new(math.cos(a) * 0.95, -0.3, math.sin(a) * 0.95) * CFrame.Angles(math.sin(a) * 0.2, 0, -math.cos(a) * 0.2), Color = GOLD, Material = Enum.Material.Metal })
	end
end

BUILDERS["Galleon Bell"] = function(model, color)
	for i = 1, 5 do
		local t = (i - 1) / 5
		piece(model, {
			Name = "Bell",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.42, 0.9 + t * 1.5, 0.9 + t * 1.5),
			CFrame = CFrame.new(0, 0.85 - i * 0.42, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = color:Lerp(BRASS, 0.3),
			Material = Enum.Material.Metal,
		})
	end
	piece(model, { Name = "Crown", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.6, 0.8), Position = Vector3.new(0, 1.15, 0), Color = BRASS, Material = Enum.Material.Metal })
	ring(model, Vector3.new(0, 1.6, 0), 0.36, 0.14, 8, BRASS, Enum.Material.Metal)
	piece(model, { Name = "Clapper", Shape = Enum.PartType.Ball, Size = Vector3.new(0.4, 0.5, 0.4), Position = Vector3.new(0, -1.5, 0), Color = DARK, Material = Enum.Material.Metal })
	piece(model, { Name = "Lip", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.22, 2.5, 2.5), CFrame = CFrame.new(0, -1.35, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = GOLD, Material = Enum.Material.Metal })
end

-- 2. CALIFORNIA: hard-hat diving, canneries, and what washes into a kelp bed.
BUILDERS["Cannery Token"] = function(model, color)
	piece(model, { Name = "Disc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.26, 2.4, 2.4), CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(90), 0), Color = color:Lerp(BRASS, 0.5), Material = Enum.Material.Metal })
	ring(model, Vector3.new(0, 0, 0.14), 1.02, 0.16, 12, BRASS, Enum.Material.Metal)
	-- Square punch through the middle, the way a works token is strung.
	piece(model, { Name = "Punch", Size = Vector3.new(0.6, 0.6, 0.4), Position = Vector3.new(0, 0, 0), Color = DARK, Material = Enum.Material.Metal })
	for i = 1, 6 do
		local a = i * math.pi / 3
		piece(model, { Name = "Stamp", Size = Vector3.new(0.16, 0.5, 0.12), CFrame = CFrame.new(math.cos(a) * 0.66, math.sin(a) * 0.66, 0.16) * CFrame.Angles(0, 0, a), Color = DARK, Material = Enum.Material.Metal })
	end
end

BUILDERS["Abalone Shell"] = function(model, color)
	piece(model, { Name = "Shell", Shape = Enum.PartType.Ball, Size = Vector3.new(2.7, 0.85, 2.2), Position = Vector3.new(0, 0, 0), Color = color, Material = Enum.Material.Foil })
	piece(model, { Name = "Nacre", Shape = Enum.PartType.Ball, Size = Vector3.new(2.3, 0.6, 1.85), Position = Vector3.new(0, 0.16, 0), Color = Color3.fromRGB(150, 226, 214), Material = Enum.Material.Foil })
	-- The row of respiratory holes along one edge: the abalone tell.
	for i = 1, 5 do
		piece(model, { Name = "Pore", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 0.28, 0.28), CFrame = CFrame.new(-1.0 + i * 0.36, 0.3, -0.72) * CFrame.Angles(0, 0, math.rad(90)), Color = DARK })
	end
	for i = 1, 5 do
		piece(model, { Name = "Ridge", Size = Vector3.new(2.4 - i * 0.3, 0.12, 0.16), CFrame = CFrame.new(0, 0.3, -0.45 + i * 0.2) * CFrame.Angles(-0.1, 0, 0), Color = color:Lerp(Color3.new(1, 1, 1), 0.25), Material = Enum.Material.Foil })
	end
end

BUILDERS["Glass Float"] = function(model, color)
	piece(model, { Name = "Glass", Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 2.6, 2.6), Position = Vector3.new(0, 0, 0), Color = color, Material = Enum.Material.Glass, Transparency = 0.4 })
	-- Rope net: three rings and four verticals.
	for i = 1, 3 do
		ring(model, Vector3.new(0, -0.9 + i * 0.9, 0), 1.32 - math.abs(i - 2) * 0.32, 0.13, 10, Color3.fromRGB(206, 186, 140), Enum.Material.Fabric)
	end
	for i = 1, 4 do
		local a = i * math.pi / 4
		piece(model, { Name = "NetLine", Size = Vector3.new(0.13, 2.7, 0.13), CFrame = CFrame.new(math.cos(a) * 1.28, 0, math.sin(a) * 1.28), Color = Color3.fromRGB(206, 186, 140), Material = Enum.Material.Fabric })
	end
	piece(model, { Name = "Knot", Shape = Enum.PartType.Ball, Size = Vector3.new(0.4, 0.4, 0.4), Position = Vector3.new(0, 1.45, 0), Color = Color3.fromRGB(186, 166, 122), Material = Enum.Material.Fabric })
end

-- 3. THE REEF: island carving and shell work.
BUILDERS["Shell Lei"] = function(model, color)
	for i = 1, 14 do
		local a = (i / 14) * math.pi * 2
		local at = Vector3.new(math.cos(a) * 1.5, math.sin(a) * 0.35, math.sin(a) * 1.5)
		piece(model, { Name = "Cord", Shape = Enum.PartType.Ball, Size = Vector3.new(0.18, 0.18, 0.18), Position = at, Color = Color3.fromRGB(120, 96, 64), Material = Enum.Material.Fabric })
		-- Alternating shells and blossoms round the string.
		if i % 2 == 0 then
			piece(model, { Name = "Shell", Shape = Enum.PartType.Ball, Size = Vector3.new(0.62, 0.24, 0.62), CFrame = CFrame.new(at) * CFrame.Angles(0, -a, 0.4), Color = IVORY, Material = Enum.Material.Sandstone })
		else
			for petal = 1, 5 do
				local pa = (petal / 5) * math.pi * 2
				piece(model, { Name = "Petal", Shape = Enum.PartType.Ball, Size = Vector3.new(0.34, 0.12, 0.34), CFrame = CFrame.new(at + Vector3.new(math.cos(pa) * 0.2, 0, math.sin(pa) * 0.2)), Color = color, Material = Enum.Material.SmoothPlastic })
			end
		end
	end
end

BUILDERS["Whale Tooth Pendant"] = function(model, color)
	-- A curved tooth: shrinking blocks along an arc.
	for i = 1, 8 do
		local t = (i - 1) / 8
		local a = t * 0.9
		piece(model, {
			Name = "Tooth",
			Size = Vector3.new(0.62 - t * 0.45, 0.42, 0.62 - t * 0.45),
			CFrame = CFrame.new(math.sin(a) * 1.5 - 0.4, 0.9 - t * 2.3, 0) * CFrame.Angles(0, 0, -a),
			Color = color:Lerp(IVORY, 0.6),
			Material = Enum.Material.Sandstone,
		})
	end
	piece(model, { Name = "Collar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 0.85, 0.85), CFrame = CFrame.new(-0.4, 1.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(96, 70, 48), Material = Enum.Material.Fabric })
	-- Braided cord looping over the top.
	for i = 1, 9 do
		local a = math.pi * (i - 1) / 8
		piece(model, { Name = "Cord", Shape = Enum.PartType.Ball, Size = Vector3.new(0.16, 0.16, 0.16), Position = Vector3.new(-0.4 + math.cos(a) * 1.1, 1.2 + math.sin(a) * 1.1, 0), Color = Color3.fromRGB(120, 88, 56), Material = Enum.Material.Fabric })
	end
end

BUILDERS["Tiki Idol"] = function(model, color)
	local wood = color:Lerp(Color3.fromRGB(96, 62, 40), 0.5)
	for i = 1, 2 do
		local y = -1.2 + (i - 1) * 1.7
		piece(model, { Name = "Block", Size = Vector3.new(1.5, 1.65, 1.3), CFrame = CFrame.new(0, y, 0) * CFrame.Angles(0, 0.14 * i, 0), Color = if i == 1 then wood else wood:Lerp(Color3.new(1, 1, 1), 0.12), Material = Enum.Material.Wood })
		piece(model, { Name = "Brow", Size = Vector3.new(1.6, 0.3, 0.3), Position = Vector3.new(0, y + 0.45, -0.68), Color = wood:Lerp(Color3.new(0, 0, 0), 0.45), Material = Enum.Material.Wood })
		piece(model, { Name = "Mouth", Size = Vector3.new(1.05, 0.36, 0.22), Position = Vector3.new(0, y - 0.42, -0.66), Color = IVORY, Material = Enum.Material.SmoothPlastic })
		for _, side in { -1, 1 } do
			piece(model, { Name = "Eye", Size = Vector3.new(0.34, 0.34, 0.2), Position = Vector3.new(side * 0.36, y + 0.1, -0.7), Color = IVORY, Material = Enum.Material.SmoothPlastic })
		end
	end
	piece(model, { Name = "Crown", Size = Vector3.new(1.85, 0.4, 1.6), Position = Vector3.new(0, 1.4, 0), Color = wood:Lerp(Color3.new(0, 0, 0), 0.25), Material = Enum.Material.Wood })
	piece(model, { Name = "Plinth", Size = Vector3.new(1.9, 0.4, 1.6), Position = Vector3.new(0, -2.1, 0), Color = DARK, Material = Enum.Material.Slate })
end

BUILDERS["Coral Crown"] = function(model, color)
	ring(model, Vector3.new(0, -0.7, 0), 1.25, 0.36, 12, GOLD, Enum.Material.Metal)
	-- Points made of branching coral instead of metal spikes.
	for i = 1, 6 do
		local a = (i / 6) * math.pi * 2
		local at = Vector3.new(math.cos(a) * 1.2, -0.3, math.sin(a) * 1.2)
		for seg = 1, 3 do
			local t = seg / 3
			piece(model, {
				Name = "Branch",
				Size = Vector3.new(0.3 - t * 0.1, 0.7, 0.3 - t * 0.1),
				CFrame = CFrame.new(at + Vector3.new(math.cos(a) * t * 0.35, seg * 0.6, math.sin(a) * t * 0.35)) * CFrame.Angles(math.sin(a) * 0.2, 0, -math.cos(a) * 0.2),
				Color = color:Lerp(Color3.fromRGB(255, 150, 190), t * 0.4),
				Material = Enum.Material.Sandstone,
			})
		end
		piece(model, { Name = "Tip", Shape = Enum.PartType.Ball, Size = Vector3.new(0.42, 0.42, 0.42), Position = at + Vector3.new(math.cos(a) * 0.4, 2.0, math.sin(a) * 0.4), Color = Color3.fromRGB(255, 186, 210), Material = Enum.Material.Sandstone })
	end
end

-- 4. THE TRENCH: nobody lives here, so what is down here got dropped.
BUILDERS["Sonar Beacon"] = function(model, color)
	piece(model, { Name = "Body", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.6, 1.2, 1.2), CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = STEEL, Material = Enum.Material.Metal })
	piece(model, { Name = "Band", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 1.36, 1.36), CFrame = CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(226, 176, 44), Material = Enum.Material.Metal })
	piece(model, { Name = "Dome", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.0, 1.2), Position = Vector3.new(0, 1.5, 0), Color = color, Material = Enum.Material.Neon, Transparency = 0.3 })
	piece(model, { Name = "Nose", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 0.9, 1.2), Position = Vector3.new(0, -1.45, 0), Color = STEEL, Material = Enum.Material.Metal })
	-- Fins, so it reads as something that was dropped and sank upright.
	for i = 1, 3 do
		local a = (i / 3) * math.pi * 2
		piece(model, { Name = "Fin", Size = Vector3.new(0.12, 1.1, 0.8), CFrame = CFrame.new(math.cos(a) * 0.75, -0.9, math.sin(a) * 0.75) * CFrame.Angles(0, -a, 0), Color = Color3.fromRGB(90, 96, 108), Material = Enum.Material.Metal })
	end
end

BUILDERS["Submersible Porthole"] = function(model, color)
	ring(model, Vector3.new(0, 0, 0), 1.5, 0.55, 16, BRASS, Enum.Material.Metal)
	piece(model, { Name = "Glass", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2.6, 2.6), CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(90), 0), Color = color, Material = Enum.Material.Glass, Transparency = 0.45 })
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2
		piece(model, { Name = "Bolt", Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.3, 0.3), Position = Vector3.new(math.cos(a) * 1.5, math.sin(a) * 1.5, 0.2), Color = Color3.fromRGB(160, 128, 66), Material = Enum.Material.Metal })
	end
	-- A scrap of the hull still attached.
	piece(model, { Name = "Hull", Size = Vector3.new(3.4, 0.4, 0.5), CFrame = CFrame.new(0, -1.7, -0.2) * CFrame.Angles(0.3, 0, 0.1), Color = Color3.fromRGB(226, 176, 44), Material = Enum.Material.CorrodedMetal })
end

BUILDERS["Black Box"] = function(model, color)
	piece(model, { Name = "Body", Size = Vector3.new(2.4, 1.5, 1.4), Position = Vector3.new(0, 0, 0), Color = Color3.fromRGB(232, 122, 30), Material = Enum.Material.Metal })
	for i = 1, 3 do
		piece(model, { Name = "Stripe", Size = Vector3.new(0.3, 1.55, 1.45), Position = Vector3.new(-0.8 + (i - 1) * 0.8, 0, 0), Color = DARK, Material = Enum.Material.Metal })
	end
	piece(model, { Name = "Handle", Size = Vector3.new(1.4, 0.18, 0.18), Position = Vector3.new(0, 0.95, 0), Color = STEEL, Material = Enum.Material.Metal })
	for _, side in { -1, 1 } do
		piece(model, { Name = "HandleLeg", Size = Vector3.new(0.18, 0.5, 0.18), Position = Vector3.new(side * 0.6, 0.72, 0), Color = STEEL, Material = Enum.Material.Metal })
	end
	piece(model, { Name = "Pinger", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.0, 0.45, 0.45), CFrame = CFrame.new(1.5, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = Enum.Material.Neon, Transparency = 0.3 })
end

-- 5. THE ABYSS: Ryugu-jo, the dragon god's palace.
BUILDERS["Oni Mask"] = function(model, color)
	local face = color:Lerp(Color3.fromRGB(196, 54, 44), 0.6)
	piece(model, { Name = "Face", Shape = Enum.PartType.Ball, Size = Vector3.new(2.3, 2.7, 1.5), Position = Vector3.new(0, 0, 0), Color = face, Material = Enum.Material.SmoothPlastic })
	piece(model, { Name = "Jaw", Size = Vector3.new(1.9, 0.9, 1.1), CFrame = CFrame.new(0, -1.15, -0.1) * CFrame.Angles(0.2, 0, 0), Color = face, Material = Enum.Material.SmoothPlastic })
	-- Horns, brows, tusks: the three things that make a mask an oni.
	for _, side in { -1, 1 } do
		for seg = 1, 3 do
			local t = seg / 3
			piece(model, { Name = "Horn", Size = Vector3.new(0.42 - t * 0.24, 0.6, 0.42 - t * 0.24), CFrame = CFrame.new(side * (0.75 + t * 0.2), 1.4 + seg * 0.42, 0.1) * CFrame.Angles(0, 0, side * -t * 0.5), Color = IVORY, Material = Enum.Material.Sandstone })
		end
		piece(model, { Name = "Brow", Size = Vector3.new(1.0, 0.34, 0.4), CFrame = CFrame.new(side * 0.55, 0.62, -0.62) * CFrame.Angles(0, 0, side * 0.4), Color = DARK, Material = Enum.Material.SmoothPlastic })
		piece(model, { Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.4, 0.3), Position = Vector3.new(side * 0.52, 0.24, -0.66), Color = Color3.fromRGB(250, 226, 120), Material = Enum.Material.Neon })
		piece(model, { Name = "Tusk", Size = Vector3.new(0.24, 0.6, 0.24), CFrame = CFrame.new(side * 0.55, -0.95, -0.6) * CFrame.Angles(0.2, 0, side * 0.2), Color = IVORY, Material = Enum.Material.Sandstone })
	end
	piece(model, { Name = "Mouth", Size = Vector3.new(1.5, 0.5, 0.3), Position = Vector3.new(0, -0.75, -0.66), Color = DARK, Material = Enum.Material.SmoothPlastic })
end

BUILDERS["Temple Bell"] = function(model, color)
	local bronze = color:Lerp(Color3.fromRGB(96, 118, 96), 0.55)
	-- A bonsho is a straight-sided barrel with a flat top, not a flared bell.
	for i = 1, 5 do
		piece(model, { Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.56, 2.3 + i * 0.06, 2.3 + i * 0.06), CFrame = CFrame.new(0, 1.0 - i * 0.55, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = bronze, Material = Enum.Material.Metal })
	end
	piece(model, { Name = "Top", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, 2.1, 2.1), CFrame = CFrame.new(0, 1.35, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = bronze:Lerp(Color3.new(0, 0, 0), 0.2), Material = Enum.Material.Metal })
	-- Ryuzu: the twin-dragon loop it hangs from.
	ring(model, Vector3.new(0, 1.85, 0), 0.45, 0.2, 8, bronze, Enum.Material.Metal)
	-- Rows of bosses round the shoulder, which is the bonsho signature.
	for i = 1, 10 do
		local a = (i / 10) * math.pi * 2
		for row = 1, 2 do
			piece(model, { Name = "Boss", Shape = Enum.PartType.Ball, Size = Vector3.new(0.26, 0.26, 0.26), Position = Vector3.new(math.cos(a) * 1.2, 0.55 - row * 0.42, math.sin(a) * 1.2), Color = bronze:Lerp(Color3.new(1, 1, 1), 0.2), Material = Enum.Material.Metal })
		end
	end
	-- The tsuki-za, the lotus pad the beam strikes.
	piece(model, { Name = "StrikePad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 0.8, 0.8), CFrame = CFrame.new(0, -1.1, -1.25) * CFrame.Angles(0, math.rad(90), 0), Color = bronze:Lerp(Color3.new(0, 0, 0), 0.3), Material = Enum.Material.Metal })
	piece(model, { Name = "Rim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2.75, 2.75), CFrame = CFrame.new(0, -1.85, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = bronze:Lerp(Color3.new(0, 0, 0), 0.25), Material = Enum.Material.Metal })
end

BUILDERS["Tide Jewel"] = function(model, color)
	-- The kanju and manju of the Ryugu-jo story: the jewels that command the
	-- tides. An orb held in a dragon's claw.
	piece(model, { Name = "Orb", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 2.2), Position = Vector3.new(0, 0.4, 0), Color = color, Material = Enum.Material.Neon, Transparency = 0.25 })
	piece(model, { Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.new(1.1, 1.1, 1.1), Position = Vector3.new(0, 0.4, 0), Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Neon })
	for i = 1, 4 do
		local a = i * math.pi / 2 + math.pi / 4
		for seg = 1, 3 do
			local t = seg / 3
			piece(model, {
				Name = "Claw",
				Size = Vector3.new(0.3 - t * 0.12, 0.85, 0.3 - t * 0.12),
				CFrame = CFrame.new(math.cos(a) * (1.15 - t * 0.3), -0.9 + seg * 0.75, math.sin(a) * (1.15 - t * 0.3))
					* CFrame.Angles(math.sin(a) * t * 0.55, 0, -math.cos(a) * t * 0.55),
				Color = GOLD,
				Material = Enum.Material.Metal,
			})
		end
	end
	piece(model, { Name = "Foot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 1.7, 1.7), CFrame = CFrame.new(0, -1.35, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = GOLD, Material = Enum.Material.Metal })
	ring(model, Vector3.new(0, -1.0, 0), 0.85, 0.18, 10, GOLD, Enum.Material.Metal)
end

-- True when this relic has a hand-built model rather than the generic hoard.
function RelicShape.HasModel(name: string): boolean
	return BUILDERS[name] ~= nil
end

return RelicShape
