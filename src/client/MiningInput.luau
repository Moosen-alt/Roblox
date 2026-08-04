--!strict
-- Tap-to-mine input: the equipped pickaxe Tool swallows clicks before
-- ClickDetectors fire, so we raycast the tap ourselves and report the node.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local MiningInput = {}

local MAX_TAP_RANGE = 140

local function tryMine(position: Vector2)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local ray = camera:ViewportPointToRay(position.X, position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local character = Players.LocalPlayer.Character
	params.FilterDescendantsInstances = character and { character } or {}
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * MAX_TAP_RANGE, params)
	if hit and hit.Instance:GetAttribute("NodeIndex") ~= nil then
		Remotes.Event("MineNode"):FireServer(hit.Instance)
	end
end

function MiningInput.Init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			tryMine(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)
end

return MiningInput
