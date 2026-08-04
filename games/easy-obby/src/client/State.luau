--!strict
-- Client replica of the server snapshot (StateSync).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local State = {}

local snapshot: { [string]: any }? = nil
local changed = Instance.new("BindableEvent")

State.Changed = changed.Event :: RBXScriptSignal

function State.Get(): { [string]: any }?
	return snapshot
end

function State.Init()
	Remotes.Event("StateSync").OnClientEvent:Connect(function(newSnapshot)
		snapshot = newSnapshot
		changed:Fire(newSnapshot)
	end)
end

return State
