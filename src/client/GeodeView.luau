--!strict
-- A 3D geode that cracks open, rendered inside the reveal overlay.
--
-- The reveal draws this out of flat UI frames today: two clipped half-circles
-- that slide apart. It works, and it has a hard ceiling — a geode splitting is
-- two solid objects tumbling away from a lit interior, and the interior is the
-- whole point. A flat circle behind two flat semicircles cannot show depth into
-- a cavity, which is exactly what the player is waiting to see.
--
-- THE BEAT, in order:
--
--   shake  ->  crack glow  ->  halves kick apart  ->  crystal burst  ->  card
--
-- The two halves do NOT move symmetrically. Half A stays roughly facing the
-- camera and only drifts; Half B kicks outward and rotates away. Splitting both
-- evenly reads as a diagram coming apart — one anchor and one thrown piece reads
-- as something breaking, and it keeps the lit cavity aimed at the player through
-- the whole move instead of showing them two edges.
--
-- Falls back to primitives until the meshes are uploaded, like every other
-- model path here, so the animation ships before the art does.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MeshBuild = require(Shared.MeshBuild)
local Meshes = require(Shared.Config.Meshes)

local GeodeView = {}

export type Geode = {
	Frame: ViewportFrame,
	Shake: (amount: number) -> (),
	Crack: (amount: number) -> (),
	Burst: (seconds: number) -> (),
}

-- Rock outside, bright inside: the contrast IS the reveal.
local SHELL = Color3.fromRGB(84, 72, 96)
local SHELL_DEEP = Color3.fromRGB(56, 48, 66)

local function piece(parent: Instance, props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

-- A primitive half: a rough rock dome with a lit, faceted inner face. Built
-- flat-side-on so the two halves meet along the same plane the mesh pair does.
local function primitiveHalf(tint: Color3, seed: number): Model
	local model = Instance.new("Model")
	local rng = Random.new(seed)
	local body = piece(model, {
		Name = "Shell",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.0, 3.4, 3.4),
		CFrame = CFrame.new(-0.5, 0, 0),
		Color = SHELL,
		Material = Enum.Material.Rock,
	})
	-- Lumps, so the outside is not a clean hemisphere.
	for i = 1, 5 do
		local angle = (i / 5) * math.pi * 2
		piece(model, {
			Name = "Lump",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(rng:NextNumber(0.8, 1.4), rng:NextNumber(1.0, 1.8), rng:NextNumber(1.0, 1.8)),
			CFrame = CFrame.new(-0.9, math.cos(angle) * 1.2, math.sin(angle) * 1.2),
			Color = SHELL_DEEP:Lerp(SHELL, rng:NextNumber(0, 1)),
			Material = Enum.Material.Rock,
		})
	end
	-- The inner face, in the pulled crystal's colour.
	piece(model, {
		Name = "Lining",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.7, 3.0, 3.0),
		CFrame = CFrame.new(0.28, 0, 0),
		Color = tint,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
	})
	-- Crystals standing out of the lining, which is what makes it a geode and
	-- not a painted shell.
	for i = 1, 7 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(0.2, 1.15)
		local length = rng:NextNumber(0.4, 0.9)
		piece(model, {
			Name = "Crystal",
			Size = Vector3.new(length, rng:NextNumber(0.18, 0.34), rng:NextNumber(0.18, 0.34)),
			CFrame = CFrame.new(0.4 + length * 0.4, math.cos(angle) * radius, math.sin(angle) * radius)
				* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.4, 0.4), 0),
			Color = tint:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0.1, 0.5)),
			Material = Enum.Material.Neon,
		})
	end
	model.PrimaryPart = body
	local box = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(box.Position)
	return model
end

local function buildHalf(prop: string, tint: Color3, seed: number): Model
	local override = Meshes.ForProp(prop)
	if override then
		local built = MeshBuild.Build(override, prop, tint, 1, nil, "Prop")
		if built then
			return built
		end
	end
	return primitiveHalf(tint, seed)
end

function GeodeView.Create(parent: Instance, position: UDim2, size: UDim2, tint: Color3): Geode
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Geode"
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	viewport.Position = position
	viewport.Size = size
	viewport.BackgroundTransparency = 1
	viewport.ZIndex = 3
	-- Dim ambient on purpose. The lining is Neon and the crystals are Neon, so
	-- the cavity lights itself; lifting the ambient to match would flatten the
	-- one contrast the whole shot depends on.
	viewport.Ambient = Color3.fromRGB(96, 92, 110)
	viewport.LightColor = Color3.fromRGB(250, 246, 255)
	viewport.LightDirection = Vector3.new(-0.5, -1, -0.4)
	viewport.Parent = parent

	local world = Instance.new("Folder")
	world.Parent = viewport

	local halfA = buildHalf("GeodeHalfA", tint, 3)
	halfA.Parent = world
	local halfB = buildHalf("GeodeHalfB", tint, 11)
	halfB.Parent = world

	-- Closed pose, taken from the pack rather than guessed: the two halves are
	-- the SAME open-face mesh, B turned 180 degrees, meeting along Z. Its
	-- asset_info gives a closed offset of 1.1532 against a 2.5627 depth — a
	-- ratio, not a stud count, so it holds at whatever Scale the mesh ends up.
	local _, halfExtents = halfA:GetBoundingBox()
	local CLOSED_RATIO = 1.1532 / 2.5627
	local gap = halfExtents.Z * CLOSED_RATIO
	local restA = CFrame.new(0, 0, gap)
	local restB = CFrame.new(0, 0, -gap) * CFrame.Angles(0, math.pi, 0)
	halfA:PivotTo(restA)
	halfB:PivotTo(restB)

	-- The glow that leaks from the seam as the crack forms, before anything
	-- moves. This is the tell that there is something inside.
	local seam = piece(world, {
		Name = "Seam",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(halfExtents.X * 0.95, halfExtents.Y * 0.95, 0.05),
		CFrame = CFrame.new(0, 0, 0),
		Color = tint:Lerp(Color3.new(1, 1, 1), 0.4),
		Material = Enum.Material.Neon,
		Transparency = 1,
	})

	local reach = math.max(halfExtents.X, halfExtents.Y, halfExtents.Z * 2)
	local distance = math.max(reach * 2.3, 7)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 42
	-- Looking slightly down the split plane, so when B swings away the camera is
	-- already pointed into the cavity rather than at A's back.
	camera.CFrame = CFrame.lookAt(Vector3.new(distance * 0.42, distance * 0.26, -distance), Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local shakeOffset = CFrame.new()
	local function shake(amount: number)
		shakeOffset = CFrame.new(
			math.random() * amount - amount * 0.5,
			math.random() * amount - amount * 0.5,
			0
		) * CFrame.Angles(0, 0, (math.random() - 0.5) * amount * 0.2)
		halfA:PivotTo(shakeOffset * restA)
		halfB:PivotTo(shakeOffset * restB)
	end

	-- The crack: the seam lights before anything moves. 0 to 1.
	local function crack(amount: number)
		local t = math.clamp(amount, 0, 1)
		seam.Transparency = 1 - t * 0.85
		seam.Size = Vector3.new(halfExtents.X * 0.95, halfExtents.Y * 0.95, 0.05 + t * 0.5)
	end

	local burst = false
	local function doBurst(seconds: number)
		if burst then
			return
		end
		burst = true
		seam.Transparency = 1

		-- Half A: the anchor. It drifts back and tips a few degrees, staying
		-- broadly where it was so the cavity keeps facing the camera.
		-- Half B: thrown. Out, up and spinning away.
		local value = Instance.new("NumberValue")
		value.Value = 0
		-- Distances in multiples of the half's own size, so retuning Scale never
		-- turns a kick into a twitch or a launch.
		local unit = halfExtents.Z
		value.Changed:Connect(function(t: number)
			halfA:PivotTo(
				CFrame.new(-t * unit * 0.5, -t * unit * 0.15, t * unit * 0.7)
					* CFrame.Angles(0, -t * 0.3, t * 0.1)
					* restA
			)
			halfB:PivotTo(
				CFrame.new(t * unit * 1.5, t * unit * 0.9, -t * unit * 2.2)
					* CFrame.Angles(t * 1.0, t * 2.4, t * 1.6)
					* restB
			)
		end)
		TweenService:Create(
			value,
			TweenInfo.new(seconds, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ Value = 1 }
		):Play()
		value.Parent = viewport
	end

	return {
		Frame = viewport,
		Shake = shake,
		Crack = crack,
		Burst = doBurst,
	}
end

return GeodeView
