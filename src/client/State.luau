--!strict
-- Client replica of the server snapshot (StateSync) + current server event.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local State = {}

local snapshot: { [string]: any }? = nil
local changed = Instance.new("BindableEvent")
local eventChanged = Instance.new("BindableEvent")
local currentEvent: { [string]: any }? = nil

State.Changed = changed.Event :: RBXScriptSignal
State.EventChanged = eventChanged.Event :: RBXScriptSignal

function State.Get(): { [string]: any }?
	return snapshot
end

function State.CurrentEvent(): { [string]: any }?
	if currentEvent and os.time() >= (currentEvent.EndsAt or 0) then
		currentEvent = nil
	end
	return currentEvent
end

function State.Init()
	Remotes.Event("StateSync").OnClientEvent:Connect(function(newSnapshot)
		snapshot = newSnapshot
		changed:Fire(newSnapshot)
	end)
	Remotes.Event("ServerEvent").OnClientEvent:Connect(function(eventInfo)
		currentEvent = eventInfo
		eventChanged:Fire(eventInfo)
	end)
end

return State
