--!strict
-- PolicyService gating for paid-random-item surfaces (May 2026 rules).
-- Fails CLOSED: if policy can't be fetched, the player is treated as restricted.

local PolicyService = game:GetService("PolicyService")
local Players = game:GetService("Players")

local PolicyGuard = {}

local cache: { [Player]: { ArePaidRandomItemsRestricted: boolean } } = {}

local function fetch(player: Player)
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	if ok and typeof(info) == "table" then
		cache[player] = {
			ArePaidRandomItemsRestricted = info.ArePaidRandomItemsRestricted == true,
		}
	else
		cache[player] = { ArePaidRandomItemsRestricted = true }
	end
end

function PolicyGuard.ArePaidRandomItemsRestricted(player: Player): boolean
	local entry = cache[player]
	if not entry then
		fetch(player)
		entry = cache[player]
	end
	return entry.ArePaidRandomItemsRestricted
end

function PolicyGuard.Init(_serviceCtx: any)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(fetch, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(fetch, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		cache[player] = nil
	end)
end

return PolicyGuard
