--!strict
-- Cast/strike input: the equipped rod Tool swallows clicks before ClickDetectors
-- fire, so we raycast the tap ourselves and report the spot.
--
-- With the Auto-Cast pass, holding the button down keeps sending that same
-- report while you point at a buoy. Nothing else changes, because nothing else
-- needs to: the server already casts on the first report, ignores reports before
-- the bite, and lands the catch on one inside the window. So holding recasts and
-- strikes for you without a second code path, and — this is the part that
-- matters — without fishing any faster than a person can. The bite delay and the
-- 1.2s window are untouched. It removes the clicking, not the waiting.

local CollectionService = game:GetService("CollectionService")
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
local HOLD_INTERVAL = 0.12 -- comfortably inside the 1.2s bite window

local holding: Vector2? = nil
local sinceCast = 0

-- A tap can land on a buoy's own sphere or on the wide invisible hitbox around
-- it. Either way the same spot gets fished — whichever pixel the player actually
-- hit is not something they should have to be precise about.
local function nodeOf(instance: Instance): BasePart?
	if instance:GetAttribute("NodeIndex") ~= nil and instance:IsA("BasePart") then
		return instance
	end
	local parent = instance.Parent
	if parent and parent:IsA("BasePart") and parent:GetAttribute("NodeIndex") ~= nil then
		return parent
	end
	return nil
end

-- Nearest buoy to the player, for when the tap landed on open water. Bounded by
-- the same cast range the server enforces, so this can only ever pick a spot the
-- player was already allowed to fish.
local function nearestSpot(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local best: BasePart? = nil
	local bestDistance = Balance.CastRange
	for _, tagged in CollectionService:GetTagged("FishingSpot") do
		if tagged:IsA("BasePart") then
			local distance = (tagged.Position - root.Position).Magnitude
			if distance < bestDistance then
				best = tagged
				bestDistance = distance
			end
		end
	end
	return best
end

local function spotAt(position: Vector2): BasePart?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local ray = camera:ViewportPointToRay(position.X, position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	-- Terrain water is queryable by default, and the buoys float ON it — so
	-- every tap that came in at a shallow angle died in the sea before it
	-- reached the buoy. That is what made casting feel like it needed you to be
	-- standing on top of the thing.
	params.IgnoreWater = true
	local character = Players.LocalPlayer.Character
	params.FilterDescendantsInstances = character and { character } or {}
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * MAX_TAP_RANGE, params)
	if hit then
		return nodeOf(hit.Instance)
	end
	-- Hit nothing at all: with water ignored, that means open sea or sky. Reading
	-- it as "cast at the water in front of me" is what a player means by it.
	return nearestSpot()
end

local function tryFish(position: Vector2)
	local spot = spotAt(position)
	if spot then
		Remotes.Event("MineNode"):FireServer(spot)
	end
end

local function ownsAutoCast(): boolean
	local state = State.Get()
	return state ~= nil and state.Passes ~= nil and state.Passes.AutoCast == true
end

function MiningInput.Init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local position = Vector2.new(input.Position.X, input.Position.Y)
			tryFish(position)
			holding = position
			sinceCast = 0
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if holding == nil then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			holding = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			holding = nil
		end
	end)
	-- Losing focus (alt-tab, a Roblox prompt) must stop the rod, or it keeps
	-- fishing at a window nobody is looking at.
	UserInputService.WindowFocusReleased:Connect(function()
		holding = nil
	end)

	RunService.Heartbeat:Connect(function(dt: number)
		local position = holding
		if position == nil or not ownsAutoCast() then
			return
		end
		sinceCast += dt
		if sinceCast < HOLD_INTERVAL then
			return
		end
		sinceCast = 0
		tryFish(position)
	end)
end

return MiningInput
