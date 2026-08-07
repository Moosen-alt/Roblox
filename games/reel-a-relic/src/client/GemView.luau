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
local FishShape = require(Shared.FishShape)

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
	Shards: number?, -- kept for call-site compatibility; unused by the fish build
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

	local model = FishShape.Build({
		Color = props.Color,
		Scale = 1,
		Seed = props.Seed or 11,
	})
	model.Parent = viewport

	local camera = Instance.new("Camera")
	camera.FieldOfView = 42
	-- Slightly off the beam and a touch above: dead side-on reads as a sticker,
	-- and dead front-on hides the whole fish behind its own nose.
	camera.CFrame = CFrame.lookAt(Vector3.new(1.6, 1.4, 6.6), Vector3.new(0, 0, 0))
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
