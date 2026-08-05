--!strict
-- Recrystallize: pay coins, reset run progress, gain a permanent +25% coin
-- multiplier and (up to layer cap) unlock the next cave layer. The infinite
-- ladder is the long-term retention loop — months of goals, zero new content.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Remotes = require(Shared.Remotes)
local Spotlight = require(script.Parent.Spotlight)

local REBIRTH_COLOR = Color3.fromRGB(255, 120, 255)

local RebirthService = {}

local ctx: any = nil

function RebirthService.Perform(player: Player, free: boolean): (boolean, string?)
	local data = ctx.Data.Get(player)
	if not data then
		return false, "Loading..."
	end
	local cost = ctx.Data.RebirthCost(data)
	if not free then
		if data.Coins < cost then
			return false, "Need " .. cost .. " coins to Recrystallize."
		end
		data.Coins -= cost
	end

	-- Clear racks; the crystals themselves stay in inventory (never lost).
	for slot in data.Racks do
		data.Racks[slot] = nil
	end
	data.Coins = if free then data.Coins else 0
	data.Geodes = 0
	data.Pickaxe = 1
	data.Backpack = 1
	data.RackSlots = Balance.BaseRackSlots
	data.Rebirths += 1

	ctx.Data.MarkDirty(player)
	ctx.Analytics.FunnelStep(player, data, 5, "FirstRebirth")
	local layer = ctx.Data.Layer(data)
	local layerName = Balance.LayerNames[layer]
	local bonus = math.floor(Balance.RebirthCoinBonus * data.Rebirths * 100 + 0.5)

	-- The prestige ritual. Giving up everything you built deserves more than a
	-- toast: the screen goes, the world flashes, and the room is told.
	Remotes.Event("RebirthFx"):FireClient(player, {
		Rebirths = data.Rebirths,
		LayerName = layerName,
		Bonus = bonus,
	})
	Spotlight.Pillar(player, REBIRTH_COLOR)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			Remotes.Event("Notify"):FireClient(other, {
				Text = ("%s just Recrystallized into %s! (rebirth #%d)"):format(player.DisplayName, layerName, data.Rebirths),
				Color = REBIRTH_COLOR,
			})
		end
	end
	return true, nil
end

function RebirthService.Init(serviceCtx: any)
	ctx = serviceCtx
	Remotes.Function("Rebirth").OnServerInvoke = function(player)
		return RebirthService.Perform(player, false)
	end
end

return RebirthService
