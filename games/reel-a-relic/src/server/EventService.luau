--!strict
-- Random server-wide events (Meteor Shower = luck, Aurora = mutations).
-- Procedural "limited-time feel" with zero developer intervention.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Remotes = require(Shared.Remotes)

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
	task.spawn(function()
		while true do
			task.wait(Balance.EventCheckInterval)
			if EventService.Current().Name == nil and rng:NextNumber() < Balance.EventChance then
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
