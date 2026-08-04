--!strict
-- Coin-purchased progression: pickaxes, backpacks, rack slots.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Remotes = require(Shared.Remotes)

local UpgradeService = {}

local ctx: any = nil

function UpgradeService.Buy(player: Player, kind: string): (boolean, string?)
	local data = ctx.Data.Get(player)
	if not data then
		return false, "Loading..."
	end
	if kind == "Pickaxe" then
		local nextTier = Balance.Pickaxes[data.Pickaxe + 1]
		if not nextTier then
			return false, "Best rod already!"
		end
		if data.Coins < nextTier.Cost then
			return false, "Not enough coins."
		end
		data.Coins -= nextTier.Cost
		data.Pickaxe += 1
	elseif kind == "Backpack" then
		local nextTier = Balance.Backpacks[data.Backpack + 1]
		if not nextTier then
			return false, "Biggest boat already!"
		end
		if data.Coins < nextTier.Cost then
			return false, "Not enough coins."
		end
		data.Coins -= nextTier.Cost
		data.Backpack += 1
	elseif kind == "RackSlot" then
		if data.RackSlots >= Balance.MaxRackSlots then
			return false, "All aquarium tanks owned!"
		end
		local cost = Balance.RackSlotCosts[data.RackSlots - Balance.BaseRackSlots + 1]
		if not cost then
			return false, "All aquarium tanks owned!"
		end
		if data.Coins < cost then
			return false, "Not enough coins."
		end
		data.Coins -= cost
		data.RackSlots += 1
	else
		return false, "Unknown upgrade."
	end
	ctx.Data.MarkDirty(player)
	return true, nil
end

function UpgradeService.Init(serviceCtx: any)
	ctx = serviceCtx
	Remotes.Function("BuyUpgrade").OnServerInvoke = function(player, kind)
		if typeof(kind) ~= "string" then
			return false, "Bad request."
		end
		return UpgradeService.Buy(player, kind)
	end
end

return UpgradeService
