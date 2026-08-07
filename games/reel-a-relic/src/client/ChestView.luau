--!strict
-- A 3D chest that actually opens, rendered inside the reveal overlay.
--
-- The reveal already drew a chest — out of flat UI frames, with the "lid" being
-- two rectangles that slid apart. It read fine and it was never going to read
-- better than fine, because a chest opening is a HINGE, and a hinge is the one
-- thing a 2D rectangle cannot fake from the front.
--
-- This is the single most-watched two seconds in the game: every chest a player
-- ever opens ends here. It is worth real geometry.
--
-- Falls back to primitives when no mesh has been uploaded yet, exactly like
-- FishShape and RelicShape do, so the reveal never breaks mid-migration.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MeshBuild = require(Shared.MeshBuild)
local Meshes = require(Shared.Config.Meshes)

local ChestView = {}

export type Chest = {
	Frame: ViewportFrame,
	Open: (seconds: number) -> (),
	Shake: (amount: number) -> (),
}

local WOOD = Color3.fromRGB(126, 88, 52)
local DARK_WOOD = Color3.fromRGB(88, 60, 36)
local IRON = Color3.fromRGB(92, 88, 96)

-- The pack's base and lid are each normalised to a 1-unit longest axis and each
-- centred on their own origin, so the lid has to be lifted onto the base rather
-- than dropped in at zero. These are fractions of the assembled chest.
local BASE_HEIGHT = 0.58
local LID_LIFT = 0.30

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

-- Primitive chest, for before the meshes are uploaded. Deliberately simple: it
-- only has to hold the shape of a chest while the lid does the acting.
local function primitiveBase(): Model
	local model = Instance.new("Model")
	local body = piece(model, {
		Name = "Body",
		Size = Vector3.new(2.4, 1.3, 1.6),
		CFrame = CFrame.new(0, 0, 0),
		Color = WOOD,
		Material = Enum.Material.Wood,
	})
	for _, x in { -0.85, 0.85 } do
		piece(model, {
			Name = "Band",
			Size = Vector3.new(0.22, 1.36, 1.66),
			CFrame = CFrame.new(x, 0, 0),
			Color = IRON,
			Material = Enum.Material.Metal,
		})
	end
	piece(model, {
		Name = "Lock",
		Size = Vector3.new(0.4, 0.4, 0.16),
		CFrame = CFrame.new(0, 0.35, -0.82),
		Color = Color3.fromRGB(226, 178, 62),
		Material = Enum.Material.Metal,
	})
	model.PrimaryPart = body
	model.WorldPivot = CFrame.new()
	return model
end

local function primitiveLid(): Model
	local model = Instance.new("Model")
	local body = piece(model, {
		Name = "Body",
		Size = Vector3.new(2.4, 0.7, 1.6),
		CFrame = CFrame.new(0, 0, 0),
		Color = DARK_WOOD,
		Material = Enum.Material.Wood,
	})
	for _, x in { -0.85, 0.85 } do
		piece(model, {
			Name = "Band",
			Size = Vector3.new(0.22, 0.76, 1.66),
			CFrame = CFrame.new(x, 0, 0),
			Color = IRON,
			Material = Enum.Material.Metal,
		})
	end
	model.PrimaryPart = body
	model.WorldPivot = CFrame.new()
	return model
end

local function build(part: string, color: Color3, fallback: () -> Model): Model
	local override = Meshes.ForProp(part)
	if override then
		return MeshBuild.Build(override, part, color, 1, nil)
	end
	return fallback()
end

-- `tint` colours the chest to the tier that was pulled, so a Mythic chest is
-- visibly not the same object as a Common one before it even opens.
function ChestView.Create(parent: Instance, position: UDim2, size: UDim2, tint: Color3): Chest
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Chest"
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	viewport.Position = position
	viewport.Size = size
	viewport.BackgroundTransparency = 1
	viewport.ZIndex = 3
	viewport.Ambient = Color3.fromRGB(160, 165, 180)
	viewport.LightColor = Color3.fromRGB(255, 250, 235)
	viewport.LightDirection = Vector3.new(-0.4, -1, -0.6)
	viewport.Parent = parent

	local world = Instance.new("Folder")
	world.Parent = viewport

	local base = build("ChestBase", tint:Lerp(WOOD, 0.55), primitiveBase)
	base.Parent = world
	base:PivotTo(CFrame.new(0, 0, 0))

	local lid = build("ChestLid", tint:Lerp(DARK_WOOD, 0.5), primitiveLid)
	lid.Parent = world

	-- THE HINGE. A lid rotated about its own centre swings through the base and
	-- looks like it is dissolving; a real lid pivots on the back top edge. So
	-- the rotation happens about the hinge point and the lid is carried around
	-- it, rather than the lid being spun in place.
	local _, baseSize = base:GetBoundingBox()
	local _, lidSize = lid:GetBoundingBox()
	local hinge = CFrame.new(0, baseSize.Y * BASE_HEIGHT, -baseSize.Z * 0.5)
	-- Where the lid sits relative to the hinge when closed.
	local restOffset = CFrame.new(0, lidSize.Y * LID_LIFT, lidSize.Z * 0.5)

	local function placeLid(angle: number)
		lid:PivotTo(hinge * CFrame.Angles(angle, 0, 0) * restOffset)
	end
	placeLid(0)

	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	-- Slightly above and off-axis: looking straight on hides the lid's travel,
	-- which is the entire animation.
	local reach = math.max(baseSize.X, baseSize.Y + lidSize.Y, baseSize.Z)
	local distance = math.max(reach * 2.4, 4)
	camera.CFrame = CFrame.lookAt(
		Vector3.new(distance * 0.28, distance * 0.42, -distance),
		Vector3.new(0, baseSize.Y * 0.25, 0)
	)
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local opened = false
	local function open(seconds: number)
		if opened then
			return
		end
		opened = true
		-- Back easing overshoots and settles: a lid that stops dead at its final
		-- angle looks mechanical, one that bounces looks thrown open.
		--
		-- Tweened through a NumberValue because TweenService cannot drive a
		-- Model's pivot directly, and stepping the CFrame by hand on
		-- RenderStepped would be a second animation loop for one lid.
		local value = Instance.new("NumberValue")
		value.Value = 0
		value.Changed:Connect(function(angle: number)
			placeLid(angle)
		end)
		TweenService:Create(
			value,
			TweenInfo.new(seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Value = math.rad(-108) }
		):Play()
		-- The NumberValue is the only thing driving the lid, so it has to
		-- outlive the tween but not the reveal. Parented to the viewport, it
		-- dies with it.
		value.Parent = viewport
	end

	-- Rattle before it opens. Anticipation is most of what makes the opening
	-- land, and it costs one tween on the whole world folder.
	local function shake(amount: number)
		local target = CFrame.Angles(0, math.rad(amount), math.rad(amount * 0.6))
		for _, model in { base, lid } do
			local pivot = model:GetPivot()
			model:PivotTo(pivot * target)
		end
	end

	return {
		Frame = viewport,
		Open = open,
		Shake = shake,
	}
end

return ChestView
