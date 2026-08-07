--!strict
-- Shared fish geometry: REAL SPECIES built from primitives (no asset uploads).
-- One builder feeds the reveal card viewports, the aquarium tank, the trophy
-- over your head and the landmarks above the water — so an Anchovy is the same
-- Anchovy everywhere in the game.
--
-- This replaces CrystalShape for anything that represents a CATCH. A fishing
-- game whose fish render as glowing gems is a re-skin wearing a fishing hat;
-- the silhouette is the single cheapest thing that makes it its own game.
--
-- WHY PER-SPECIES AND NOT ONE FISH IN 33 COLOURS
--
-- The first version was exactly that, and it quietly undercut the whole product.
-- The table is real species on purpose — "I caught a Leopard Shark" is a thing a
-- kid says at school — but a Leopard Shark drawn as a recoloured Anchovy tells
-- them the name is a label, not a thing. Recognition is the asset; the shape has
-- to earn it. So a Hammerhead gets a hammer, a Manta Ray is a flying diamond, a
-- Seahorse stands up, and a Megalodon is not just a big minnow.
--
-- The style stays deliberately Roblox — chunky primitives, flat colours, read at
-- a glance and at thumbnail size. This is not a bid for realism; it is a bid for
-- each species being TELLABLE APART in a 90-stud tank and on a reveal card.
--
-- Most species are the generic fish with different proportions and fittings
-- (PROFILES below). The ones whose skeleton is genuinely a different animal —
-- eels, rays, a seahorse, a squid, an octopus, an isopod, a flatfish — get their
-- own builder, because no amount of stretching an ellipsoid makes a manta ray.

local FishShape = {}

export type Options = {
	-- The species. Optional: the landmark/vista decorations have no species and
	-- fall through to a good-looking generic fish.
	Name: string?,
	Color: Color3,
	Scale: number?, -- overall size multiplier (1 ~= 3 studs nose to tail)
	Seed: number?,
	Glow: number?, -- PointLight range at the body (nil/0 = no light)
	Sparkle: boolean?, -- drifting glints (used for mutated/rare fish)
	Neon: boolean?, -- deep-water species that light themselves
}

type Profile = {
	Family: string?, -- own skeleton; nil = the generic fish below
	Length: number?,
	Height: number?,
	Width: number?,
	Snout: number?, -- snout length, as a fraction of body length
	Tail: string?, -- Fork | Lunate | Round | Shark | Ribbon | Whip | None
	Dorsal: string?, -- Standard | Sail | SharkFin | Ridge | Spiny | None
	Pectoral: string?, -- Standard | Long | None
	Bands: number?,
	BandPale: boolean?, -- white bands (clownfish) rather than dark ones
	Spots: number?,
	Eye: number?, -- eye size multiplier
	Extras: { string }?,
}

--------------------------------------------------------------------------------
-- Primitives
--------------------------------------------------------------------------------

-- Fish must NOT be fullbright. Neon renders flat and unshaded, which is what
-- turned every crystal cluster into one glowing blob — on a fish it would erase
-- the body/fin/tail separation that makes it read as a fish at all. SmoothPlastic
-- takes the light, so the form survives. Neon is opt-in, for the deep-sea
-- species that genuinely light themselves.
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
local function paleOf(body: Color3): Color3
	return body:Lerp(Color3.new(1, 1, 1), 0.55)
end
local function darkOf(body: Color3): Color3
	return body:Lerp(Color3.fromRGB(30, 26, 44), 0.35)
end

local WHITE = Color3.fromRGB(250, 250, 252)
local PUPIL = Color3.fromRGB(18, 16, 26)
local TOOTH = Color3.fromRGB(245, 243, 232)

type Ctx = {
	Model: Model,
	Body: Part?,
	Color: Color3,
	Fin: Color3,
	Material: Enum.Material,
	L: number,
	H: number,
	W: number,
	Scale: number,
	Rng: Random,
}

local function has(list: { string }?, name: string): boolean
	if not list then
		return false
	end
	for _, entry in list do
		if entry == name then
			return true
		end
	end
	return false
end

-- Eyes: the single detail that turns a shape into an animal. One per side.
local function eyes(ctx: Ctx, atX: number, atY: number, size: number, spread: number)
	for _, side in { 1, -1 } do
		piece(ctx.Model, {
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size, size),
			CFrame = CFrame.new(atX, atY, side * spread),
			Color = WHITE,
		})
		piece(ctx.Model, {
			Name = "Pupil",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size * 0.56, size * 0.56, size * 0.56),
			CFrame = CFrame.new(atX + size * 0.1, atY, side * (spread + size * 0.24)),
			Color = PUPIL,
		})
	end
end

--------------------------------------------------------------------------------
-- Tails
--------------------------------------------------------------------------------

local function tailStalk(ctx: Ctx, atX: number, thickness: number)
	piece(ctx.Model, {
		Name = "TailStalk",
		Size = Vector3.new(ctx.L * 0.24, ctx.H * thickness, ctx.W * 0.42),
		CFrame = CFrame.new(atX, 0, 0),
		Color = ctx.Color,
		Material = ctx.Material,
	})
end

local function buildTail(ctx: Ctx, kind: string)
	local x = -ctx.L * 0.52
	if kind == "None" then
		return
	elseif kind == "Ribbon" then
		-- A long trailing ribbon, for the oarfish-shaped things.
		tailStalk(ctx, x, 0.24)
		piece(ctx.Model, {
			Name = "TailRibbon",
			Size = Vector3.new(ctx.L * 0.5, ctx.H * 0.5, ctx.W * 0.12),
			CFrame = CFrame.new(x - ctx.L * 0.3, ctx.H * 0.08, 0) * CFrame.Angles(0, 0, 0.25),
			Color = ctx.Fin,
			Material = ctx.Material,
		})
		return
	elseif kind == "Whip" then
		-- Ray tail: a long thin spike, no fin at all.
		piece(ctx.Model, {
			Name = "TailWhip",
			Size = Vector3.new(ctx.L * 1.15, ctx.H * 0.1, ctx.W * 0.08),
			CFrame = CFrame.new(x - ctx.L * 0.5, ctx.H * 0.05, 0),
			Color = ctx.Fin,
			Material = ctx.Material,
		})
		return
	end

	tailStalk(ctx, x, if kind == "Shark" then 0.44 else 0.34)

	if kind == "Round" then
		piece(ctx.Model, {
			Name = "TailFin",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(ctx.L * 0.42, ctx.H * 1.02, ctx.W * 0.16),
			CFrame = CFrame.new(x - ctx.L * 0.2, 0, 0),
			Color = ctx.Fin,
			Material = ctx.Material,
		})
	elseif kind == "Lunate" then
		-- Crescent: the fast-swimmer tail. Tips swept hard back.
		for _, lean in { 1, -1 } do
			piece(ctx.Model, {
				Name = "TailFin",
				Size = Vector3.new(ctx.L * 0.46, ctx.H * 0.9, ctx.W * 0.13),
				CFrame = CFrame.new(x - ctx.L * 0.2, lean * ctx.H * 0.42, 0)
					* CFrame.Angles(0, 0, lean * 1.05),
				Color = ctx.Fin,
				Material = ctx.Material,
			})
		end
	elseif kind == "Shark" then
		-- Heterocercal: the upper lobe is much longer. This asymmetry is most of
		-- what makes a silhouette read "shark" rather than "big fish".
		piece(ctx.Model, {
			Name = "TailUpper",
			Size = Vector3.new(ctx.L * 0.4, ctx.H * 1.15, ctx.W * 0.14),
			CFrame = CFrame.new(x - ctx.L * 0.22, ctx.H * 0.5, 0) * CFrame.Angles(0, 0, 0.55),
			Color = ctx.Fin,
			Material = ctx.Material,
		})
		piece(ctx.Model, {
			Name = "TailLower",
			Size = Vector3.new(ctx.L * 0.3, ctx.H * 0.6, ctx.W * 0.13),
			CFrame = CFrame.new(x - ctx.L * 0.2, -ctx.H * 0.3, 0) * CFrame.Angles(0, 0, -0.7),
			Color = ctx.Fin,
			Material = ctx.Material,
		})
	else -- Fork
		for _, lean in { 1, -1 } do
			piece(ctx.Model, {
				Name = "TailFin",
				Size = Vector3.new(ctx.L * 0.5, ctx.H * 0.62, ctx.W * 0.15),
				CFrame = CFrame.new(x - ctx.L * 0.24, lean * ctx.H * 0.34, 0)
					* CFrame.Angles(0, 0, lean * 0.75),
				Color = ctx.Fin,
				Material = ctx.Material,
			})
		end
	end
end

--------------------------------------------------------------------------------
-- Dorsals and pectorals
--------------------------------------------------------------------------------

local function buildDorsal(ctx: Ctx, kind: string)
	if kind == "None" then
		return
	elseif kind == "Sail" then
		-- The sailfish's whole identity. Oversized on purpose.
		piece(ctx.Model, {
			Name = "Sail",
			Size = Vector3.new(ctx.L * 0.86, ctx.H * 1.5, ctx.W * 0.1),
			CFrame = CFrame.new(ctx.L * 0.02, ctx.H * 1.0, 0),
			Color = ctx.Fin,
			Material = ctx.Material,
		})
		for i = 1, 5 do
			piece(ctx.Model, {
				Name = "SailRay",
				Size = Vector3.new(ctx.L * 0.05, ctx.H * 1.5, ctx.W * 0.13),
				CFrame = CFrame.new(ctx.L * (0.34 - i * 0.14), ctx.H * 1.0, 0),
				Color = darkOf(ctx.Fin),
				Material = ctx.Material,
			})
		end
	elseif kind == "SharkFin" then
		piece(ctx.Model, {
			Name = "Dorsal",
			Size = Vector3.new(ctx.L * 0.3, ctx.H * 0.78, ctx.W * 0.16),
			CFrame = CFrame.new(ctx.L * 0.02, ctx.H * 0.66, 0) * CFrame.Angles(0, 0, -0.42),
			Color = ctx.Fin,
			Material = ctx.Material,
		})
		-- Second, small dorsal near the tail: sharks have two.
		piece(ctx.Model, {
			Name = "Dorsal2",
			Size = Vector3.new(ctx.L * 0.14, ctx.H * 0.3, ctx.W * 0.12),
			CFrame = CFrame.new(-ctx.L * 0.38, ctx.H * 0.44, 0) * CFrame.Angles(0, 0, -0.42),
			Color = ctx.Fin,
			Material = ctx.Material,
		})
	elseif kind == "Ridge" then
		-- A long low fin running most of the back (tangs, parrotfish, eels).
		piece(ctx.Model, {
			Name = "Dorsal",
			Size = Vector3.new(ctx.L * 0.78, ctx.H * 0.26, ctx.W * 0.1),
			CFrame = CFrame.new(-ctx.L * 0.04, ctx.H * 0.54, 0),
			Color = ctx.Fin,
			Material = ctx.Material,
		})
	elseif kind == "Spiny" then
		-- Spiny first dorsal + soft second: the bass/snapper signature.
		for i = 1, 5 do
			piece(ctx.Model, {
				Name = "Spine",
				Size = Vector3.new(ctx.L * 0.045, ctx.H * (0.5 - i * 0.03), ctx.W * 0.09),
				CFrame = CFrame.new(ctx.L * (0.24 - i * 0.09), ctx.H * (0.56 + (0.5 - i * 0.03) * 0.2), 0)
					* CFrame.Angles(0, 0, -0.18),
				Color = ctx.Fin,
				Material = ctx.Material,
			})
		end
		piece(ctx.Model, {
			Name = "Dorsal",
			Size = Vector3.new(ctx.L * 0.3, ctx.H * 0.34, ctx.W * 0.1),
			CFrame = CFrame.new(-ctx.L * 0.26, ctx.H * 0.58, 0),
			Color = ctx.Fin,
			Material = ctx.Material,
		})
	else -- Standard
		piece(ctx.Model, {
			Name = "Dorsal",
			Size = Vector3.new(ctx.L * 0.44, ctx.H * 0.5, ctx.W * 0.14),
			CFrame = CFrame.new(-ctx.L * 0.04, ctx.H * 0.56, 0) * CFrame.Angles(0, 0, -0.35),
			Color = ctx.Fin,
			Material = ctx.Material,
		})
	end
end

local function buildPectoral(ctx: Ctx, kind: string)
	if kind == "None" then
		return
	end
	local long = kind == "Long"
	for _, side in { 1, -1 } do
		piece(ctx.Model, {
			Name = "Pectoral",
			Size = Vector3.new(
				ctx.L * (if long then 0.5 else 0.28),
				ctx.H * 0.13,
				ctx.W * (if long then 0.9 else 0.5)
			),
			CFrame = CFrame.new(ctx.L * 0.1, -ctx.H * 0.2, side * ctx.W * 0.44)
				* CFrame.Angles(side * (if long then 0.25 else 0.5), 0, -0.3),
			Color = ctx.Fin,
			Material = ctx.Material,
		})
	end
end

--------------------------------------------------------------------------------
-- Species fittings
--------------------------------------------------------------------------------

local function addBill(ctx: Ctx)
	piece(ctx.Model, {
		Name = "Bill",
		Size = Vector3.new(ctx.L * 0.5, ctx.H * 0.09, ctx.W * 0.1),
		CFrame = CFrame.new(ctx.L * 0.78, ctx.H * 0.02, 0),
		Color = darkOf(ctx.Color),
		Material = ctx.Material,
	})
end

local function addBeak(ctx: Ctx)
	for _, sign in { 1, -1 } do
		piece(ctx.Model, {
			Name = "Beak",
			Size = Vector3.new(ctx.L * 0.12, ctx.H * 0.13, ctx.W * 0.5),
			CFrame = CFrame.new(ctx.L * 0.55, sign * ctx.H * 0.09, 0),
			Color = paleOf(ctx.Color),
			Material = ctx.Material,
		})
	end
end

local function addFangs(ctx: Ctx, count: number, length: number)
	for i = 1, count do
		local t = (i - 0.5) / count
		for _, sign in { 1, -1 } do
			piece(ctx.Model, {
				Name = "Fang",
				Size = Vector3.new(ctx.L * 0.02, ctx.H * length, ctx.W * 0.05),
				CFrame = CFrame.new(
					ctx.L * (0.5 - t * 0.22),
					sign * ctx.H * (0.02 + length * 0.5),
					(if i % 2 == 0 then 1 else -1) * ctx.W * 0.14
				),
				Color = TOOTH,
			})
		end
	end
end

-- The anglerfish's esca, on its stalk. The one fish silhouette everybody
-- already knows, so it has to be unmistakable.
local function addLure(ctx: Ctx)
	piece(ctx.Model, {
		Name = "LureStalk",
		Size = Vector3.new(ctx.L * 0.06, ctx.H * 0.75, ctx.W * 0.06),
		CFrame = CFrame.new(ctx.L * 0.3, ctx.H * 0.72, 0) * CFrame.Angles(0, 0, -0.4),
		Color = darkOf(ctx.Color),
		Material = ctx.Material,
	})
	local bulb = piece(ctx.Model, {
		Name = "Lure",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(ctx.H * 0.3, ctx.H * 0.3, ctx.H * 0.3),
		CFrame = CFrame.new(ctx.L * 0.44, ctx.H * 1.05, 0),
		Color = Color3.fromRGB(190, 255, 225),
		Material = Enum.Material.Neon,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(170, 255, 220)
	light.Range = 7 * ctx.Scale
	light.Brightness = 0.6
	light.Shadows = false
	light.Parent = bulb
end

-- Lionfish: the fan of venomous rays. Radiating, not swept — that is the read.
local function addSpines(ctx: Ctx)
	for i = 1, 9 do
		local angle = -0.9 + (i - 1) * 0.22
		piece(ctx.Model, {
			Name = "Spine",
			Size = Vector3.new(ctx.L * 0.04, ctx.H * 1.5, ctx.W * 0.04),
			CFrame = CFrame.new(ctx.L * (0.2 - i * 0.045), ctx.H * 0.9, 0)
				* CFrame.Angles(0, 0, angle),
			Color = ctx.Fin,
			Material = ctx.Material,
		})
	end
	for _, side in { 1, -1 } do
		for i = 1, 4 do
			piece(ctx.Model, {
				Name = "SideSpine",
				Size = Vector3.new(ctx.L * 0.04, ctx.H * 1.1, ctx.W * 0.04),
				CFrame = CFrame.new(ctx.L * (0.1 - i * 0.1), -ctx.H * 0.2, side * ctx.W * 0.4)
					* CFrame.Angles(side * 0.9, 0, -0.5 + i * 0.2),
				Color = ctx.Fin,
				Material = ctx.Material,
			})
		end
	end
end

local function addHammer(ctx: Ctx)
	piece(ctx.Model, {
		Name = "Hammer",
		Size = Vector3.new(ctx.L * 0.16, ctx.H * 0.3, ctx.W * 2.6),
		CFrame = CFrame.new(ctx.L * 0.52, -ctx.H * 0.04, 0),
		Color = ctx.Color,
		Material = ctx.Material,
	})
	-- Eyes go on the ENDS of the hammer, which is the whole joke of the animal.
	for _, side in { 1, -1 } do
		piece(ctx.Model, {
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(ctx.H * 0.2, ctx.H * 0.2, ctx.H * 0.2),
			CFrame = CFrame.new(ctx.L * 0.52, -ctx.H * 0.04, side * ctx.W * 1.24),
			Color = PUPIL,
		})
	end
end

local function addPhotophores(ctx: Ctx)
	for i = 1, 8 do
		piece(ctx.Model, {
			Name = "Photophore",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(ctx.H * 0.1, ctx.H * 0.1, ctx.H * 0.1),
			CFrame = CFrame.new(ctx.L * (0.34 - i * 0.09), -ctx.H * 0.34, ctx.W * 0.3),
			Color = Color3.fromRGB(150, 230, 255),
			Material = Enum.Material.Neon,
		})
	end
end

-- Barreleye: the transparent dome with the eyes looking up THROUGH it.
local function addDome(ctx: Ctx)
	piece(ctx.Model, {
		Name = "Dome",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(ctx.L * 0.5, ctx.H * 0.8, ctx.W * 0.85),
		CFrame = CFrame.new(ctx.L * 0.3, ctx.H * 0.24, 0),
		Color = Color3.fromRGB(210, 235, 240),
		Material = Enum.Material.Glass,
		Transparency = 0.6,
	})
	for _, side in { 1, -1 } do
		piece(ctx.Model, {
			Name = "TubeEye",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(ctx.H * 0.34, ctx.H * 0.26, ctx.H * 0.26),
			CFrame = CFrame.new(ctx.L * 0.26, ctx.H * 0.22, side * ctx.W * 0.24)
				* CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(120, 235, 130),
			Material = Enum.Material.Neon,
		})
	end
end

local function addCrest(ctx: Ctx)
	for i = 1, 6 do
		piece(ctx.Model, {
			Name = "Crest",
			Size = Vector3.new(ctx.L * 0.03, ctx.H * (0.9 - i * 0.09), ctx.W * 0.06),
			CFrame = CFrame.new(ctx.L * (0.46 - i * 0.05), ctx.H * (0.5 + (0.9 - i * 0.09) * 0.5), 0),
			Color = Color3.fromRGB(220, 60, 70),
			Material = ctx.Material,
		})
	end
end

local function addFinlets(ctx: Ctx)
	for i = 1, 4 do
		for _, sign in { 1, -1 } do
			piece(ctx.Model, {
				Name = "Finlet",
				Size = Vector3.new(ctx.L * 0.05, ctx.H * 0.08, ctx.W * 0.08),
				CFrame = CFrame.new(-ctx.L * (0.24 + i * 0.07), sign * ctx.H * 0.36, 0),
				Color = ctx.Fin,
				Material = ctx.Material,
			})
		end
	end
end

local function addBump(ctx: Ctx)
	piece(ctx.Model, {
		Name = "HeadBump",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(ctx.L * 0.3, ctx.H * 0.5, ctx.W * 0.6),
		CFrame = CFrame.new(ctx.L * 0.28, ctx.H * 0.44, 0),
		Color = ctx.Color,
		Material = ctx.Material,
	})
end

-- Goblin shark: the flat blade of a snout with the jaw slung out under it.
local function addGoblinSnout(ctx: Ctx)
	piece(ctx.Model, {
		Name = "Blade",
		Size = Vector3.new(ctx.L * 0.42, ctx.H * 0.1, ctx.W * 0.4),
		CFrame = CFrame.new(ctx.L * 0.74, ctx.H * 0.16, 0),
		Color = paleOf(ctx.Color),
		Material = ctx.Material,
	})
	piece(ctx.Model, {
		Name = "Jaw",
		Size = Vector3.new(ctx.L * 0.26, ctx.H * 0.22, ctx.W * 0.45),
		CFrame = CFrame.new(ctx.L * 0.64, -ctx.H * 0.16, 0),
		Color = Color3.fromRGB(232, 168, 178),
		Material = ctx.Material,
	})
end

local function addExtras(ctx: Ctx, extras: { string }?)
	if has(extras, "Bill") then
		addBill(ctx)
	end
	if has(extras, "Beak") then
		addBeak(ctx)
	end
	if has(extras, "Fangs") then
		addFangs(ctx, 5, 0.2)
	end
	if has(extras, "Lure") then
		addLure(ctx)
	end
	if has(extras, "Spines") then
		addSpines(ctx)
	end
	if has(extras, "Hammer") then
		addHammer(ctx)
	end
	if has(extras, "Photophores") then
		addPhotophores(ctx)
	end
	if has(extras, "Dome") then
		addDome(ctx)
	end
	if has(extras, "Crest") then
		addCrest(ctx)
	end
	if has(extras, "Finlets") then
		addFinlets(ctx)
	end
	if has(extras, "Bump") then
		addBump(ctx)
	end
	if has(extras, "GoblinSnout") then
		addGoblinSnout(ctx)
	end
end

--------------------------------------------------------------------------------
-- The generic fish
--------------------------------------------------------------------------------

local function buildGeneric(ctx: Ctx, profile: Profile): Part
	local color, material = ctx.Color, ctx.Material
	local body = piece(ctx.Model, {
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(ctx.L, ctx.H, ctx.W),
		CFrame = CFrame.new(0, 0, 0),
		Color = color,
		Material = material,
	})

	-- Pale belly. A flattened ellipsoid tucked under the body is the whole
	-- difference between "a fish" and "a coloured blob with fins".
	piece(ctx.Model, {
		Name = "Belly",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(ctx.L * 0.82, ctx.H * 0.52, ctx.W * 0.94),
		CFrame = CFrame.new(-ctx.L * 0.04, -ctx.H * 0.3, 0),
		Color = paleOf(color),
		Material = material,
	})

	-- Snout: the head tapers instead of ending in the same round curve as the
	-- tail. Length is per species — an anchovy is a point, a sheephead is blunt.
	local snout = profile.Snout or 0.42
	piece(ctx.Model, {
		Name = "Snout",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(ctx.L * snout, ctx.H * 0.62, ctx.W * 0.72),
		CFrame = CFrame.new(ctx.L * 0.42, -ctx.H * 0.05, 0),
		Color = color,
		Material = material,
	})

	buildTail(ctx, profile.Tail or "Fork")
	buildDorsal(ctx, profile.Dorsal or "Standard")
	buildPectoral(ctx, profile.Pectoral or "Standard")

	local eyeSize = ctx.H * 0.3 * (profile.Eye or 1)
	eyes(ctx, ctx.L * 0.42, ctx.H * 0.16, eyeSize, ctx.W * 0.3)

	-- Markings. Bands run across the body; spots scatter over the back.
	local bands = profile.Bands or 0
	for i = 1, bands do
		local at = ctx.L * 0.34 - (i - 0.5) * (ctx.L * 0.68 / bands)
		piece(ctx.Model, {
			Name = "Band",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(ctx.L * 0.08, ctx.H * 0.98, ctx.W * 1.03),
			CFrame = CFrame.new(at, ctx.H * 0.04, 0),
			Color = if profile.BandPale then WHITE else darkOf(color),
			Material = material,
		})
	end
	for i = 1, profile.Spots or 0 do
		local at = ctx.L * (0.36 - (i % 6) * 0.13)
		piece(ctx.Model, {
			Name = "Spot",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(ctx.H * 0.2, ctx.H * 0.2, ctx.W * 0.3),
			CFrame = CFrame.new(at, ctx.H * (0.1 + (i % 3) * 0.16), ctx.Rng:NextNumber(-1, 1) * ctx.W * 0.34),
			Color = darkOf(color),
			Material = material,
		})
	end

	addExtras(ctx, profile.Extras)
	return body
end

--------------------------------------------------------------------------------
-- Own-skeleton families
--------------------------------------------------------------------------------

-- Eels, oarfish, frilled shark: a chain of shrinking segments on a gentle
-- S-curve, with a fin running the whole back. Length is the entire read here, so
-- these are deliberately much longer than any of the generic fish.
local function buildSerpent(ctx: Ctx, profile: Profile): Part
	local segments = 11
	local head = piece(ctx.Model, {
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(ctx.L * 0.3, ctx.H, ctx.W),
		CFrame = CFrame.new(ctx.L * 0.5, 0, 0),
		Color = ctx.Color,
		Material = ctx.Material,
	})
	for i = 1, segments do
		local t = i / segments
		local taper = 1 - t * 0.72
		local x = ctx.L * (0.5 - t * 1.5)
		local y = math.sin(t * 4.2) * ctx.H * 0.42
		piece(ctx.Model, {
			Name = "Segment",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(ctx.L * 0.2, ctx.H * taper, ctx.W * taper),
			CFrame = CFrame.new(x, y, 0),
			Color = ctx.Color:Lerp(darkOf(ctx.Color), t * 0.4),
			Material = ctx.Material,
		})
		-- The fin ridge along the back, following the curve.
		piece(ctx.Model, {
			Name = "Ridge",
			Size = Vector3.new(ctx.L * 0.2, ctx.H * 0.3 * taper, ctx.W * 0.08),
			CFrame = CFrame.new(x, y + ctx.H * 0.55 * taper, 0),
			Color = ctx.Fin,
			Material = ctx.Material,
		})
	end

	-- Jaw. A gulper's is most of the animal; a moray's is just menacing.
	local gulp = has(profile.Extras, "Gulp")
	piece(ctx.Model, {
		Name = "Jaw",
		Size = Vector3.new(ctx.L * (if gulp then 0.6 else 0.3), ctx.H * (if gulp then 0.7 else 0.22), ctx.W * 0.8),
		CFrame = CFrame.new(ctx.L * (if gulp then 0.66 else 0.6), -ctx.H * (if gulp then 0.34 else 0.22), 0)
			* CFrame.Angles(0, 0, if gulp then 0.22 else 0.1),
		Color = if gulp then darkOf(ctx.Color) else paleOf(ctx.Color),
		Material = ctx.Material,
	})
	eyes(ctx, ctx.L * 0.58, ctx.H * 0.2, ctx.H * 0.24, ctx.W * 0.32)
	addExtras(ctx, profile.Extras)
	return head
end

-- Manta ray: a flat diamond that flies. Nothing about the generic fish survives
-- here, which is exactly why it gets its own builder.
local function buildRay(ctx: Ctx, profile: Profile): Part
	local body = piece(ctx.Model, {
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(ctx.L * 0.9, ctx.H * 0.42, ctx.W * 1.5),
		CFrame = CFrame.new(0, 0, 0),
		Color = ctx.Color,
		Material = ctx.Material,
	})
	piece(ctx.Model, {
		Name = "Underside",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(ctx.L * 0.8, ctx.H * 0.3, ctx.W * 1.35),
		CFrame = CFrame.new(0, -ctx.H * 0.12, 0),
		Color = paleOf(ctx.Color),
		Material = ctx.Material,
	})
	-- Wings: three tapering panels a side, swept back into a point.
	for _, side in { 1, -1 } do
		for i = 1, 3 do
			local t = i / 3
			piece(ctx.Model, {
				Name = "Wing",
				Size = Vector3.new(ctx.L * (0.8 - t * 0.5), ctx.H * (0.2 - t * 0.12), ctx.W * 0.75),
				CFrame = CFrame.new(-ctx.L * t * 0.16, ctx.H * t * 0.06, side * ctx.W * (0.7 + t * 0.72))
					* CFrame.Angles(side * -t * 0.35, 0, 0),
				Color = ctx.Color:Lerp(ctx.Fin, t * 0.5),
				Material = ctx.Material,
			})
		end
		-- Cephalic lobe: the two little horns at the mouth. Unmistakable.
		piece(ctx.Model, {
			Name = "Lobe",
			Size = Vector3.new(ctx.L * 0.26, ctx.H * 0.14, ctx.W * 0.14),
			CFrame = CFrame.new(ctx.L * 0.5, -ctx.H * 0.06, side * ctx.W * 0.3)
				* CFrame.Angles(0, side * 0.25, 0),
			Color = ctx.Fin,
			Material = ctx.Material,
		})
	end
	eyes(ctx, ctx.L * 0.3, 0, ctx.H * 0.22, ctx.W * 0.62)
	buildTail(ctx, "Whip")
	addExtras(ctx, profile.Extras)
	return body
end

-- Seahorse: upright, tube snout, curled tail. The only fish here that does not
-- point +X, and the reason Options carries a name at all.
local function buildSeahorse(ctx: Ctx, profile: Profile): Part
	local body = piece(ctx.Model, {
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(ctx.W * 1.1, ctx.L * 0.62, ctx.W),
		CFrame = CFrame.new(0, ctx.L * 0.1, 0),
		Color = ctx.Color,
		Material = ctx.Material,
	})
	-- Head, tipped forward off the top of the body.
	piece(ctx.Model, {
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(ctx.W * 0.8, ctx.L * 0.24, ctx.W * 0.8),
		CFrame = CFrame.new(ctx.W * 0.2, ctx.L * 0.5, 0) * CFrame.Angles(0, 0, -0.5),
		Color = ctx.Color,
		Material = ctx.Material,
	})
	piece(ctx.Model, {
		Name = "Snout",
		Size = Vector3.new(ctx.W * 0.7, ctx.W * 0.24, ctx.W * 0.24),
		CFrame = CFrame.new(ctx.W * 0.72, ctx.L * 0.46, 0) * CFrame.Angles(0, 0, -0.25),
		Color = paleOf(ctx.Color),
		Material = ctx.Material,
	})
	-- Crown spines.
	for i = 1, 3 do
		piece(ctx.Model, {
			Name = "Crown",
			Size = Vector3.new(ctx.W * 0.12, ctx.W * 0.3, ctx.W * 0.12),
			CFrame = CFrame.new(-ctx.W * (0.1 + i * 0.12), ctx.L * (0.6 - i * 0.02), 0),
			Color = ctx.Fin,
			Material = ctx.Material,
		})
	end
	-- Tail: a spiral of shrinking blocks curling forward.
	for i = 1, 8 do
		local t = i / 8
		local angle = t * 3.4
		local radius = ctx.L * 0.2 * (1 - t * 0.55)
		piece(ctx.Model, {
			Name = "Tail",
			Size = Vector3.new(ctx.W * (0.6 - t * 0.35), ctx.W * (0.6 - t * 0.35), ctx.W * (0.6 - t * 0.3)),
			CFrame = CFrame.new(
				math.sin(angle) * radius,
				ctx.L * -0.22 - t * ctx.L * 0.18 + (1 - math.cos(angle)) * radius * 0.3,
				0
			),
			Color = ctx.Color:Lerp(darkOf(ctx.Color), t * 0.5),
			Material = ctx.Material,
		})
	end
	-- Body ridges, the armoured rings.
	for i = 1, 4 do
		piece(ctx.Model, {
			Name = "Ring",
			Size = Vector3.new(ctx.W * 1.16, ctx.W * 0.1, ctx.W * 1.06),
			CFrame = CFrame.new(0, ctx.L * (0.32 - i * 0.11), 0),
			Color = darkOf(ctx.Color),
			Material = ctx.Material,
		})
	end
	piece(ctx.Model, {
		Name = "Dorsal",
		Size = Vector3.new(ctx.W * 0.1, ctx.L * 0.26, ctx.W * 0.7),
		CFrame = CFrame.new(-ctx.W * 0.6, ctx.L * 0.06, 0),
		Color = ctx.Fin,
		Material = ctx.Material,
	})
	for _, side in { 1, -1 } do
		piece(ctx.Model, {
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(ctx.W * 0.26, ctx.W * 0.26, ctx.W * 0.26),
			CFrame = CFrame.new(ctx.W * 0.24, ctx.L * 0.52, side * ctx.W * 0.3),
			Color = PUPIL,
		})
	end
	addExtras(ctx, profile.Extras)
	return body
end

-- Colossal squid: mantle cone, two fins, eight arms and two long tentacles. The
-- eye is deliberately enormous — it is the animal's famous feature.
local function buildSquid(ctx: Ctx, profile: Profile): Part
	local mantle = piece(ctx.Model, {
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(ctx.L * 1.1, ctx.H * 0.9, ctx.W * 1.1),
		CFrame = CFrame.new(-ctx.L * 0.3, 0, 0),
		Color = ctx.Color,
		Material = ctx.Material,
	})
	piece(ctx.Model, {
		Name = "MantleTip",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(ctx.L * 0.6, ctx.H * 0.45, ctx.W * 0.5),
		CFrame = CFrame.new(-ctx.L * 0.95, 0, 0),
		Color = ctx.Color:Lerp(darkOf(ctx.Color), 0.3),
		Material = ctx.Material,
	})
	for _, side in { 1, -1 } do
		piece(ctx.Model, {
			Name = "Fin",
			Size = Vector3.new(ctx.L * 0.5, ctx.H * 0.12, ctx.W * 0.8),
			CFrame = CFrame.new(-ctx.L * 0.8, 0, side * ctx.W * 0.6) * CFrame.Angles(side * 0.2, 0, 0),
			Color = ctx.Fin,
			Material = ctx.Material,
		})
	end
	-- Head between mantle and arms.
	piece(ctx.Model, {
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(ctx.L * 0.4, ctx.H * 0.72, ctx.W * 0.85),
		CFrame = CFrame.new(ctx.L * 0.32, 0, 0),
		Color = ctx.Color,
		Material = ctx.Material,
	})
	for _, side in { 1, -1 } do
		piece(ctx.Model, {
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(ctx.H * 0.46, ctx.H * 0.46, ctx.H * 0.46),
			CFrame = CFrame.new(ctx.L * 0.34, ctx.H * 0.1, side * ctx.W * 0.42),
			Color = WHITE,
		})
		piece(ctx.Model, {
			Name = "Pupil",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(ctx.H * 0.26, ctx.H * 0.26, ctx.H * 0.26),
			CFrame = CFrame.new(ctx.L * 0.38, ctx.H * 0.1, side * ctx.W * 0.55),
			Color = PUPIL,
		})
	end
	-- Eight arms in a ring, plus two long hunting tentacles.
	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2
		for seg = 1, 3 do
			local t = seg / 3
			piece(ctx.Model, {
				Name = "Arm",
				Size = Vector3.new(ctx.L * 0.26, ctx.H * (0.2 - t * 0.1), ctx.W * (0.2 - t * 0.1)),
				CFrame = CFrame.new(
					ctx.L * (0.56 + seg * 0.2),
					math.cos(angle) * ctx.H * 0.3 * (1 + t * 0.6),
					math.sin(angle) * ctx.W * 0.34 * (1 + t * 0.6)
				),
				Color = ctx.Color:Lerp(ctx.Fin, t * 0.5),
				Material = ctx.Material,
			})
		end
	end
	for _, side in { 1, -1 } do
		for seg = 1, 4 do
			local t = seg / 4
			piece(ctx.Model, {
				Name = "Tentacle",
				Size = Vector3.new(ctx.L * 0.34, ctx.H * 0.11, ctx.W * 0.11),
				CFrame = CFrame.new(
					ctx.L * (0.62 + seg * 0.3),
					-ctx.H * t * 0.2,
					side * ctx.W * (0.16 + t * 0.3)
				),
				Color = ctx.Fin,
				Material = ctx.Material,
			})
		end
		piece(ctx.Model, {
			Name = "Club",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(ctx.L * 0.24, ctx.H * 0.2, ctx.W * 0.2),
			CFrame = CFrame.new(ctx.L * 1.94, -ctx.H * 0.24, side * ctx.W * 0.5),
			Color = darkOf(ctx.Color),
			Material = ctx.Material,
		})
	end
	addExtras(ctx, profile.Extras)
	return mantle
end

-- Dumbo octopus: a soft dome with the two ear-fins it is named for.
local function buildOctopus(ctx: Ctx, profile: Profile): Part
	local head = piece(ctx.Model, {
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(ctx.L * 0.9, ctx.H * 1.1, ctx.W * 1.5),
		CFrame = CFrame.new(0, ctx.H * 0.2, 0),
		Color = ctx.Color,
		Material = ctx.Material,
	})
	for _, side in { 1, -1 } do
		piece(ctx.Model, {
			Name = "EarFin",
			Size = Vector3.new(ctx.L * 0.4, ctx.H * 0.12, ctx.W * 0.7),
			CFrame = CFrame.new(-ctx.L * 0.05, ctx.H * 0.62, side * ctx.W * 0.95)
				* CFrame.Angles(side * 0.5, 0, 0),
			Color = ctx.Fin,
			Material = ctx.Material,
		})
	end
	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2
		for seg = 1, 3 do
			local t = seg / 3
			piece(ctx.Model, {
				Name = "Arm",
				Size = Vector3.new(ctx.L * (0.22 - t * 0.06), ctx.H * 0.22, ctx.W * (0.22 - t * 0.06)),
				CFrame = CFrame.new(
					math.cos(angle) * ctx.L * 0.26 * (1 + t * 0.5),
					-ctx.H * (0.3 + seg * 0.22),
					math.sin(angle) * ctx.W * 0.42 * (1 + t * 0.5)
				),
				Color = ctx.Color:Lerp(ctx.Fin, t * 0.55),
				Material = ctx.Material,
			})
		end
	end
	eyes(ctx, ctx.L * 0.3, ctx.H * 0.3, ctx.H * 0.24, ctx.W * 0.5)
	addExtras(ctx, profile.Extras)
	return head
end

-- Giant isopod: overlapping armour plates, legs down both sides, antennae. A
-- woodlouse the size of a cat, which is the fact that sells it.
local function buildIsopod(ctx: Ctx, profile: Profile): Part
	local head = piece(ctx.Model, {
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(ctx.L * 0.34, ctx.H * 0.7, ctx.W * 1.15),
		CFrame = CFrame.new(ctx.L * 0.42, 0, 0),
		Color = ctx.Color,
		Material = ctx.Material,
	})
	for i = 1, 7 do
		local t = (i - 1) / 7
		local width = 1.25 - t * 0.5
		piece(ctx.Model, {
			Name = "Plate",
			Size = Vector3.new(ctx.L * 0.14, ctx.H * (0.62 - t * 0.2), ctx.W * width),
			CFrame = CFrame.new(ctx.L * (0.26 - i * 0.13), ctx.H * 0.04, 0),
			Color = ctx.Color:Lerp(darkOf(ctx.Color), t * 0.45),
			Material = ctx.Material,
		})
		for _, side in { 1, -1 } do
			piece(ctx.Model, {
				Name = "Leg",
				Size = Vector3.new(ctx.L * 0.05, ctx.H * 0.06, ctx.W * 0.42),
				CFrame = CFrame.new(ctx.L * (0.26 - i * 0.13), -ctx.H * 0.3, side * ctx.W * width * 0.62)
					* CFrame.Angles(side * 0.5, 0, 0),
				Color = ctx.Fin,
				Material = ctx.Material,
			})
		end
	end
	-- Tail fan.
	for _, side in { 1, -1 } do
		piece(ctx.Model, {
			Name = "Uropod",
			Size = Vector3.new(ctx.L * 0.2, ctx.H * 0.1, ctx.W * 0.3),
			CFrame = CFrame.new(-ctx.L * 0.72, 0, side * ctx.W * 0.2) * CFrame.Angles(0, side * 0.35, 0),
			Color = ctx.Fin,
			Material = ctx.Material,
		})
	end
	for _, side in { 1, -1 } do
		piece(ctx.Model, {
			Name = "Antenna",
			Size = Vector3.new(ctx.L * 0.42, ctx.H * 0.05, ctx.W * 0.05),
			CFrame = CFrame.new(ctx.L * 0.76, -ctx.H * 0.1, side * ctx.W * 0.3)
				* CFrame.Angles(0, side * 0.4, 0),
			Color = ctx.Fin,
			Material = ctx.Material,
		})
	end
	eyes(ctx, ctx.L * 0.5, ctx.H * 0.16, ctx.H * 0.2, ctx.W * 0.46)
	addExtras(ctx, profile.Extras)
	return head
end

-- Flounder: flat, lying on its side, with BOTH eyes on the up-facing flank.
-- That asymmetry is the entire species and it costs two parts.
local function buildFlatfish(ctx: Ctx, profile: Profile): Part
	local body = piece(ctx.Model, {
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(ctx.L, ctx.H * 0.3, ctx.W * 2.4),
		CFrame = CFrame.new(0, 0, 0),
		Color = ctx.Color,
		Material = ctx.Material,
	})
	piece(ctx.Model, {
		Name = "Underside",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(ctx.L * 0.92, ctx.H * 0.2, ctx.W * 2.2),
		CFrame = CFrame.new(0, -ctx.H * 0.1, 0),
		Color = paleOf(ctx.Color),
		Material = ctx.Material,
	})
	-- The fin fringe running right around the disc.
	for i = 1, 14 do
		local angle = (i / 14) * math.pi * 2
		piece(ctx.Model, {
			Name = "Fringe",
			Size = Vector3.new(ctx.L * 0.16, ctx.H * 0.07, ctx.W * 0.3),
			CFrame = CFrame.new(math.cos(angle) * ctx.L * 0.46, 0, math.sin(angle) * ctx.W * 1.15)
				* CFrame.Angles(0, -angle, 0),
			Color = ctx.Fin,
			Material = ctx.Material,
		})
	end
	for i = 1, 7 do
		piece(ctx.Model, {
			Name = "Spot",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(ctx.H * 0.3, ctx.H * 0.12, ctx.H * 0.3),
			CFrame = CFrame.new(
				ctx.Rng:NextNumber(-0.38, 0.3) * ctx.L,
				ctx.H * 0.14,
				ctx.Rng:NextNumber(-0.9, 0.9) * ctx.W
			),
			Color = darkOf(ctx.Color),
			Material = ctx.Material,
		})
	end
	-- Both eyes topside, close together, on stalks.
	for _, offset in { -0.14, 0.14 } do
		piece(ctx.Model, {
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(ctx.H * 0.3, ctx.H * 0.3, ctx.H * 0.3),
			CFrame = CFrame.new(ctx.L * 0.3, ctx.H * 0.2, ctx.W * offset),
			Color = WHITE,
		})
		piece(ctx.Model, {
			Name = "Pupil",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(ctx.H * 0.17, ctx.H * 0.17, ctx.H * 0.17),
			CFrame = CFrame.new(ctx.L * 0.32, ctx.H * 0.3, ctx.W * offset),
			Color = PUPIL,
		})
	end
	addExtras(ctx, profile.Extras)
	return body
end

-- Hatchetfish: a deep, paper-thin blade of a body with an upturned mouth.
local function buildHatchet(ctx: Ctx, profile: Profile): Part
	local body = piece(ctx.Model, {
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(ctx.L * 0.8, ctx.H * 1.5, ctx.W * 0.3),
		CFrame = CFrame.new(0, 0, 0),
		Color = ctx.Color,
		Material = ctx.Material,
	})
	-- The hatchet "blade" belly.
	piece(ctx.Model, {
		Name = "Blade",
		Size = Vector3.new(ctx.L * 0.62, ctx.H * 0.8, ctx.W * 0.22),
		CFrame = CFrame.new(-ctx.L * 0.02, -ctx.H * 0.62, 0) * CFrame.Angles(0, 0, 0.2),
		Color = paleOf(ctx.Color),
		Material = ctx.Material,
	})
	buildTail(ctx, "Fork")
	piece(ctx.Model, {
		Name = "Dorsal",
		Size = Vector3.new(ctx.L * 0.2, ctx.H * 0.42, ctx.W * 0.1),
		CFrame = CFrame.new(-ctx.L * 0.12, ctx.H * 0.85, 0),
		Color = ctx.Fin,
		Material = ctx.Material,
	})
	-- Huge upward-staring eyes: the deep-sea tell.
	eyes(ctx, ctx.L * 0.3, ctx.H * 0.34, ctx.H * 0.42, ctx.W * 0.16)
	addPhotophores(ctx)
	addExtras(ctx, profile.Extras)
	return body
end

-- Anglerfish: almost all head, almost all mouth, with the lamp out front.
local function buildAngler(ctx: Ctx, profile: Profile): Part
	local body = piece(ctx.Model, {
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(ctx.L * 0.95, ctx.H * 1.15, ctx.W * 1.15),
		CFrame = CFrame.new(ctx.L * 0.1, 0, 0),
		Color = ctx.Color,
		Material = ctx.Material,
	})
	piece(ctx.Model, {
		Name = "Tailpiece",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(ctx.L * 0.4, ctx.H * 0.45, ctx.W * 0.45),
		CFrame = CFrame.new(-ctx.L * 0.5, -ctx.H * 0.05, 0),
		Color = ctx.Color:Lerp(darkOf(ctx.Color), 0.35),
		Material = ctx.Material,
	})
	-- The gape: an upper and a lower jaw, hinged wide open.
	piece(ctx.Model, {
		Name = "UpperJaw",
		Size = Vector3.new(ctx.L * 0.5, ctx.H * 0.2, ctx.W * 1.0),
		CFrame = CFrame.new(ctx.L * 0.5, ctx.H * 0.2, 0) * CFrame.Angles(0, 0, -0.25),
		Color = ctx.Color,
		Material = ctx.Material,
	})
	piece(ctx.Model, {
		Name = "LowerJaw",
		Size = Vector3.new(ctx.L * 0.52, ctx.H * 0.22, ctx.W * 1.0),
		CFrame = CFrame.new(ctx.L * 0.48, -ctx.H * 0.32, 0) * CFrame.Angles(0, 0, 0.3),
		Color = paleOf(ctx.Color),
		Material = ctx.Material,
	})
	addFangs(ctx, 6, 0.3)
	buildTail(ctx, "Round")
	eyes(ctx, ctx.L * 0.34, ctx.H * 0.36, ctx.H * 0.22, ctx.W * 0.44)
	addLure(ctx)
	addExtras(ctx, profile.Extras)
	return body
end

--------------------------------------------------------------------------------
-- The species table
--
-- Proportions are multiples of `scale`, so a value of 3 is roughly 3 studs of
-- fish at Scale = 1. Relative size between species is deliberate: an Anchovy is
-- genuinely tiny next to a Megalodon, and seeing that in the tank is the point.
--------------------------------------------------------------------------------

local PROFILES: { [string]: Profile } = {
	-- Area 1: Sunny Shallows
	Anchovy = { Length = 1.7, Height = 0.5, Width = 0.3, Snout = 0.3, Tail = "Fork", Eye = 1.5, Dorsal = "Standard" },
	Mackerel = {
		Length = 2.9,
		Height = 0.85,
		Width = 0.55,
		Tail = "Lunate",
		Dorsal = "Ridge",
		Bands = 7,
		Extras = { "Finlets" },
	},
	["Sea Bass"] = { Length = 2.9, Height = 1.45, Width = 0.85, Tail = "Fork", Dorsal = "Spiny" },
	Flounder = { Family = "Flatfish", Length = 2.6, Height = 1.2, Width = 0.7 },
	["Red Snapper"] = { Length = 2.8, Height = 1.6, Width = 0.8, Snout = 0.5, Tail = "Fork", Dorsal = "Spiny" },
	Seahorse = { Family = "Seahorse", Length = 2.2, Height = 1.0, Width = 0.5 },
	Sailfish = {
		Length = 4.2,
		Height = 1.05,
		Width = 0.5,
		Snout = 0.3,
		Tail = "Lunate",
		Dorsal = "Sail",
		Pectoral = "Long",
		Extras = { "Bill" },
	},

	-- Area 2: Kelp Forest
	["Kelp Bass"] = { Length = 2.8, Height = 1.35, Width = 0.8, Tail = "Round", Dorsal = "Spiny", Spots = 7 },
	Garibaldi = { Length = 2.2, Height = 1.95, Width = 0.7, Snout = 0.3, Tail = "Fork", Dorsal = "Ridge" },
	Sheephead = {
		Length = 3.0,
		Height = 1.85,
		Width = 0.95,
		Snout = 0.3,
		Tail = "Round",
		Dorsal = "Spiny",
		Bands = 1,
		Extras = { "Bump" },
	},
	["Moray Eel"] = { Family = "Serpent", Length = 3.2, Height = 0.85, Width = 0.6, Extras = { "Fangs" } },
	["Leopard Shark"] = {
		Family = "Shark",
		Length = 4.0,
		Height = 1.0,
		Width = 0.7,
		Tail = "Shark",
		Dorsal = "SharkFin",
		Pectoral = "Long",
		Spots = 12,
	},
	["Giant Sea Bass"] = { Length = 3.6, Height = 2.05, Width = 1.15, Tail = "Round", Dorsal = "Spiny", Spots = 5 },

	-- Area 3: Twilight Reef
	Clownfish = {
		Length = 1.9,
		Height = 1.2,
		Width = 0.6,
		Snout = 0.3,
		Tail = "Round",
		Dorsal = "Ridge",
		Bands = 3,
		BandPale = true,
	},
	Parrotfish = { Length = 2.7, Height = 1.5, Width = 0.8, Tail = "Lunate", Dorsal = "Ridge", Extras = { "Beak" } },
	["Blue Tang"] = { Length = 2.1, Height = 1.9, Width = 0.42, Snout = 0.3, Tail = "Lunate", Dorsal = "Ridge" },
	Lionfish = { Length = 2.2, Height = 1.3, Width = 0.65, Tail = "Round", Dorsal = "None", Bands = 6, Extras = { "Spines" } },
	["Reef Shark"] = {
		Family = "Shark",
		Length = 4.2,
		Height = 1.05,
		Width = 0.75,
		Tail = "Shark",
		Dorsal = "SharkFin",
		Pectoral = "Long",
	},
	["Manta Ray"] = { Family = "Ray", Length = 3.4, Height = 1.0, Width = 1.1 },
	Hammerhead = {
		Family = "Shark",
		Length = 4.6,
		Height = 1.05,
		Width = 0.7,
		Tail = "Shark",
		Dorsal = "SharkFin",
		Pectoral = "Long",
		Extras = { "Hammer" },
	},

	-- Area 4: Midnight Trench
	Lanternfish = {
		Length = 1.9,
		Height = 0.75,
		Width = 0.42,
		Tail = "Fork",
		Eye = 1.5,
		Extras = { "Photophores" },
	},
	Hatchetfish = { Family = "Hatchet", Length = 1.7, Height = 1.0, Width = 0.4 },
	Viperfish = {
		Length = 3.2,
		Height = 0.7,
		Width = 0.42,
		Snout = 0.3,
		Tail = "Fork",
		Dorsal = "None",
		Eye = 1.3,
		Extras = { "Fangs", "Photophores" },
	},
	["Gulper Eel"] = { Family = "Serpent", Length = 3.4, Height = 0.8, Width = 0.55, Extras = { "Gulp" } },
	Anglerfish = { Family = "Angler", Length = 2.6, Height = 1.5, Width = 1.0 },
	Barreleye = { Length = 2.2, Height = 1.25, Width = 0.7, Snout = 0.3, Tail = "Fork", Extras = { "Dome" } },
	Oarfish = { Family = "Serpent", Length = 5.0, Height = 1.0, Width = 0.35, Extras = { "Crest" } },

	-- Area 5: The Abyss
	["Giant Isopod"] = { Family = "Isopod", Length = 2.6, Height = 1.0, Width = 0.85 },
	["Dumbo Octopus"] = { Family = "Octopus", Length = 2.0, Height = 1.1, Width = 0.75 },
	["Frilled Shark"] = { Family = "Serpent", Length = 4.4, Height = 0.95, Width = 0.6, Extras = { "Fangs" } },
	["Goblin Shark"] = {
		Family = "Shark",
		Length = 4.4,
		Height = 1.05,
		Width = 0.7,
		Tail = "Shark",
		Dorsal = "SharkFin",
		Pectoral = "Long",
		Extras = { "GoblinSnout" },
	},
	["Colossal Squid"] = { Family = "Squid", Length = 3.0, Height = 1.3, Width = 0.95 },
	Megalodon = {
		Family = "Shark",
		Length = 6.0,
		Height = 1.7,
		Width = 1.1,
		Tail = "Shark",
		Dorsal = "SharkFin",
		Pectoral = "Long",
		Extras = { "Fangs" },
	},
}

-- The decorations (landmark and vista fish) have no species. A good generic
-- fish is the right answer there, not a crash and not a default Anchovy.
local FALLBACK: Profile = { Length = 2.8, Height = 1.6, Width = 0.85, Tail = "Fork", Dorsal = "Standard" }

-- Used by tests/check-models.py to prove every species in the config has a
-- shape, so adding a fish and forgetting its silhouette cannot ship quietly.
function FishShape.HasProfile(name: string): boolean
	return PROFILES[name] ~= nil
end

--------------------------------------------------------------------------------

-- Nose points +X, so a camera on +Z sees the fish side-on — the only angle a
-- fish is recognisable from.
function FishShape.Build(options: Options): Model
	local model = Instance.new("Model")
	model.Name = options.Name or "Fish"

	local scale = options.Scale or 1
	local rng = Random.new(options.Seed or 5)
	local color = options.Color
	local profile = (if options.Name then PROFILES[options.Name] else nil) or FALLBACK

	local ctx: Ctx = {
		Model = model,
		Body = nil,
		Color = color,
		Fin = finColor(color),
		Material = if options.Neon then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		L = (profile.Length or 2.8) * scale,
		H = (profile.Height or 1.6) * scale,
		W = (profile.Width or 0.85) * scale,
		Scale = scale,
		Rng = rng,
	}

	-- Each branch calls its own builder rather than selecting one and calling it
	-- afterwards: Luau will not call a union of identically-shaped function
	-- types, and this reads better anyway.
	local family = profile.Family
	local body: Part
	if family == "Serpent" then
		body = buildSerpent(ctx, profile)
	elseif family == "Ray" then
		body = buildRay(ctx, profile)
	elseif family == "Seahorse" then
		body = buildSeahorse(ctx, profile)
	elseif family == "Squid" then
		body = buildSquid(ctx, profile)
	elseif family == "Octopus" then
		body = buildOctopus(ctx, profile)
	elseif family == "Isopod" then
		body = buildIsopod(ctx, profile)
	elseif family == "Flatfish" then
		body = buildFlatfish(ctx, profile)
	elseif family == "Hatchet" then
		body = buildHatchet(ctx, profile)
	elseif family == "Angler" then
		body = buildAngler(ctx, profile)
	else
		-- "Shark" is the generic fish with shark fittings, so it lands here too.
		body = buildGeneric(ctx, profile)
	end

	if options.Glow and options.Glow > 0 then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = options.Glow
		light.Brightness = 0.7
		light.Shadows = false
		light.Parent = body
	end
	if options.Sparkle then
		local glints = Instance.new("ParticleEmitter")
		glints.Color = ColorSequence.new(color)
		-- NOT 1. Fully additive glints stack past white and draw over solid
		-- geometry, which is what turned the bay into a blown-out smear.
		glints.LightEmission = 0.3
		glints.Size = NumberSequence.new(0.3 * scale, 0)
		glints.Transparency = NumberSequence.new(0.1, 1)
		glints.Lifetime = NumberRange.new(0.7, 1.5)
		glints.Rate = 7
		glints.Speed = NumberRange.new(0.5, 1.6)
		glints.SpreadAngle = Vector2.new(60, 60)
		glints.Parent = body
	end

	model.PrimaryPart = body
	-- Pivot at the model's own CENTROID, not the origin. Species are no longer
	-- one shape built symmetrically around zero: a squid is mostly tentacles out
	-- front and an eel trails a long way behind. With the pivot left at the
	-- origin those spin in the reveal card by ORBITING the middle of the frame
	-- instead of turning on the spot, and PivotTo elsewhere puts them down
	-- off-target by half their own length.
	local box = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(box.Position)
	return model
end

return FishShape
