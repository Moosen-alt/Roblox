--!strict
-- A real, swimming 3D fish rendered inside a UI frame. Reveal cards, the Index
-- and the trophy over your head all draw through here, so what you catch and
-- what you see are the same object.
--
-- (Module name stays GemView — it is the engine's "collectible in a viewport"
-- widget, the same way Crystals holds fish and CrackService opens chests.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crystals = require(Shared.Config.Crystals)
local FishShape = require(Shared.FishShape)
local RelicShape = require(Shared.RelicShape)

local GemView = {}

export type Props = {
	Parent: Instance,
	Size: UDim2,
	Position: UDim2,
	Color: Color3,
	AnchorPoint: Vector2?,
	ZIndex: number?,
	Spin: number?,
	Seed: number?,
	Shards: number?, -- unused; kept so existing call sites keep compiling
	-- The NAME of the thing being drawn. Not a boolean and not a colour: BOTH
	-- halves of the collection have their own models now — 33 fish silhouettes
	-- and 11 relics — so "which one is this" is the only thing that can pick a
	-- shape. A Sunken Crown drawn as a gem and an Anchovy drawn as a generic fish
	-- are the same mistake one level apart.
	Name: string?,
}

function GemView.Create(props: Props): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Gem"
	viewport.Size = props.Size
	viewport.Position = props.Position
	viewport.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	viewport.BackgroundTransparency = 1
	viewport.ZIndex = props.ZIndex or 2
	-- Partial ambient, not full. The crystals needed full ambient because Neon
	-- renders flat and went muddy without it; a fish is SmoothPlastic and needs
	-- the opposite — enough directional light to separate body from fin from
	-- tail. Blow the ambient out and the silhouette flattens into one shape.
	viewport.Ambient = Color3.fromRGB(150, 158, 175)
	viewport.LightColor = Color3.fromRGB(255, 252, 240)
	viewport.LightDirection = Vector3.new(-0.35, -1, -0.55)

	local name = props.Name
	local model = if name and Crystals.IsRelic(name)
		then RelicShape.Build({
			Name = name,
			Color = props.Color,
			Scale = 1,
			Seed = props.Seed or 11,
		})
		else FishShape.Build({
			Name = name,
			Color = props.Color,
			Scale = 1,
			Seed = props.Seed or 11,
		})
	model.Parent = viewport
	-- Centre it immediately. The spin loop re-centres every frame, but it bails
	-- out while the viewport is hidden, so without this a card that starts
	-- invisible shows the model off-centre the moment it is revealed.
	model:PivotTo(CFrame.new())

	local camera = Instance.new("Camera")
	camera.FieldOfView = 42
	-- FRAME THE SPECIES, don't assume one size. Species are built at their real
	-- relative proportions — an Anchovy is 1.7 studs and a Megalodon is 6 — which
	-- is the point in the tank, but on a card at a fixed camera distance it would
	-- mean a shark cropped to its middle and an anchovy lost as a dot. So pull the
	-- camera back in proportion to the model actually built.
	--
	-- Slightly off the beam and a touch above: dead side-on reads as a sticker,
	-- and dead front-on hides the whole fish behind its own nose.
	local _, extents = model:GetBoundingBox()
	local reach = math.max(extents.X, extents.Y, extents.Z)
	-- 2.05x reach reproduces the old framing for the old 3.4-stud fish, so
	-- everything that already looked right still does.
	local distance = math.max(reach * 2.05, 3.2)
	local eye = Vector3.new(0.23, 0.2, 0.95).Unit * distance
	camera.CFrame = CFrame.lookAt(eye, Vector3.new(0, 0, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	viewport.Parent = props.Parent

	local speed = props.Spin or 1.1
	local clock = 0
	local connection: RBXScriptConnection? = nil
	local function stop()
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end
	-- Watch ancestry, not viewport.Parent: when an ANCESTOR is removed the
	-- viewport keeps its own parent, so a Parent check never fires and the swim
	-- would run forever holding the model in memory. Characters get removed that
	-- way, and every player wears one of these.
	viewport.Destroying:Once(stop)
	viewport.AncestryChanged:Connect(function()
		if not viewport:IsDescendantOf(game) then
			stop()
		end
	end)
	connection = RunService.RenderStepped:Connect(function(dt: number)
		-- A fish nobody can see does not need to swim. With fifteen players
		-- wearing one of these over their head, the ones behind you, off screen,
		-- or past the billboard's MaxDistance are the common case.
		if not viewport.Visible or viewport.AbsoluteSize.X < 1 then
			return
		end
		clock += dt * speed
		-- Turning on the spot, but leaning and bobbing with it, so it reads as
		-- swimming rather than as a model on a turntable.
		model:PivotTo(
			CFrame.new(0, math.sin(clock * 1.6) * 0.16, 0)
				* CFrame.Angles(0, clock, math.sin(clock * 2.2) * 0.13)
		)
	end)

	return viewport
end

return GemView
