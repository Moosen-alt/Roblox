--!strict
-- Random server-wide events (Meteor Shower = luck, Aurora = mutations).
-- Procedural "limited-time feel" with zero developer intervention.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Remotes = require(Shared.Remotes)
local FilmMode = require(script.Parent.FilmMode)

local EventService = {}

local rng = Random.new()
local current: { Name: string?, LuckMult: number, MutationMult: number, EndsAt: number, Color: Color3? } = {
	Name = nil,
	LuckMult = 1,
	MutationMult = 1,
	EndsAt = 0,
}

function EventService.Current()
	if current.Name and os.time() >= current.EndsAt then
		current = { Name = nil, LuckMult = 1, MutationMult = 1, EndsAt = 0 }
	end
	return current
end

function EventService.Init(_serviceCtx: any)
	-- Film mode fires an event every few seconds so a Meteor Shower take does
	-- not mean waiting six minutes between attempts.
	local interval = if FilmMode.Active() then 12 else Balance.EventCheckInterval
	local chance = if FilmMode.Active() then 1 else Balance.EventChance
	task.spawn(function()
		while true do
			task.wait(interval)
			if EventService.Current().Name == nil and rng:NextNumber() < chance then
				local def = Balance.Events[rng:NextInteger(1, #Balance.Events)]
				current = {
					Name = def.Name,
					LuckMult = def.LuckMult,
					MutationMult = def.MutationMult,
					EndsAt = os.time() + Balance.EventDuration,
					Color = def.Color,
				}
				Remotes.Event("ServerEvent"):FireAllClients({
					Name = def.Name,
					EndsAt = current.EndsAt,
					Color = def.Color,
					LuckMult = def.LuckMult,
					MutationMult = def.MutationMult,
				})
				task.delay(Balance.EventDuration, function()
					if current.Name == def.Name then
						current = { Name = nil, LuckMult = 1, MutationMult = 1, EndsAt = 0 }
						Remotes.Event("ServerEvent"):FireAllClients(nil)
					end
				end)
			end
		end
	end)
end

return EventService
