--!strict
-- A real, rotating 3D crystal rendered inside a UI frame. Reveal cards used to
-- show a tilted coloured square; this shows the actual rock, turning, catching
-- the light — the thing worth screenshotting.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrystalShape = require(Shared.CrystalShape)

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
	Shards: number?,
}

function GemView.Create(props: Props): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Gem"
	viewport.Size = props.Size
	viewport.Position = props.Position
	viewport.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	viewport.BackgroundTransparency = 1
	viewport.ZIndex = props.ZIndex or 2
	-- Neon renders flat-bright in a viewport; full ambient keeps the facets from
	-- going muddy on low graphics settings.
	viewport.Ambient = Color3.fromRGB(255, 255, 255)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-0.4, -1, -0.6)

	local model = CrystalShape.Build({
		Color = props.Color,
		Scale = 1,
		Shards = props.Shards or 5,
		Segments = 3,
		Seed = props.Seed or 11,
	})
	model.Parent = viewport

	local camera = Instance.new("Camera")
	camera.FieldOfView = 42
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 2.1, 7.4), Vector3.new(0, 1.5, 0))
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
	-- viewport keeps its own parent, so a Parent check never fires and the spin
	-- would run forever holding the model in memory. Characters get removed that
	-- way, and every player wears one of these.
	viewport.Destroying:Once(stop)
	viewport.AncestryChanged:Connect(function()
		if not viewport:IsDescendantOf(game) then
			stop()
		end
	end)
	connection = RunService.RenderStepped:Connect(function(dt: number)
		-- A gem nobody can see does not need to turn. With fifteen players
		-- wearing one of these over their head, the ones behind you, off screen,
		-- or past the billboard's MaxDistance are the common case.
		if not viewport.Visible or viewport.AbsoluteSize.X < 1 then
			return
		end
		clock += dt * speed
		model:PivotTo(CFrame.Angles(0, clock, 0))
	end)

	return viewport
end

return GemView
