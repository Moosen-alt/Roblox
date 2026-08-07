--!strict
-- Tap-to-mine input: the equipped pickaxe Tool swallows clicks before
-- ClickDetectors fire, so we raycast the tap ourselves and report the node.
--
-- With the Auto Swing pass, holding the button down keeps swinging instead of
-- needing one tap per hit. That is deliberately a HOLD and not an auto-clicker:
-- you still aim, you still choose the rock, you still have to be there. It
-- removes the finger damage, not the game — and because the server's mine
-- cooldown is what actually paces the swings, holding can never out-earn a very
-- fast tapper. It just means you don't have to be one.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Remotes = require(Shared.Remotes)
local State = require(script.Parent.State)

local MiningInput = {}

local MAX_TAP_RANGE = 140

-- Where the finger/cursor currently is while held, or nil when nothing is held.
local holding: Vector2? = nil
local sinceSwing = 0

local function nodeAt(position: Vector2): BasePart?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local ray = camera:ViewportPointToRay(position.X, position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local character = Players.LocalPlayer.Character
	params.FilterDescendantsInstances = character and { character } or {}
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * MAX_TAP_RANGE, params)
	if hit and hit.Instance:GetAttribute("NodeIndex") ~= nil then
		return hit.Instance
	end
	return nil
end

local function swingAt(position: Vector2)
	local node = nodeAt(position)
	if node then
		Remotes.Event("MineNode"):FireServer(node)
	end
end

local function ownsAutoSwing(): boolean
	local state = State.Get()
	return state ~= nil and state.Passes ~= nil and state.Passes.AutoMine == true
end

function MiningInput.Init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local position = Vector2.new(input.Position.X, input.Position.Y)
			swingAt(position)
			holding = position
			sinceSwing = 0
		end
	end)

	-- Track the pointer while held so dragging across the wall keeps mining
	-- whatever you are actually pointing at, rather than the rock you first hit.
	UserInputService.InputChanged:Connect(function(input)
		if holding == nil then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			holding = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)

	local function release(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			holding = nil
		end
	end
	UserInputService.InputEnded:Connect(release)
	-- Losing focus (alt-tab, a Roblox prompt) must stop the swing, or the
	-- pickaxe keeps going at a window nobody is looking at.
	UserInputService.WindowFocusReleased:Connect(function()
		holding = nil
	end)

	RunService.Heartbeat:Connect(function(dt: number)
		local position = holding
		if position == nil or not ownsAutoSwing() then
			return
		end
		sinceSwing += dt
		-- The server enforces MineCooldown regardless; firing a little faster
		-- here just means jitter never costs you a swing.
		if sinceSwing < Balance.MineCooldown * 0.5 then
			return
		end
		sinceSwing = 0
		swingAt(position)
	end)
end

return MiningInput
