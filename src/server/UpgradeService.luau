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
	-- There is no top tier any more: Balance.Pickaxe and Balance.Backpack always
	-- return one, generating past the hand-authored list. The old "Best pickaxe
	-- already!" dead end is gone, which is the whole point.
	if kind == "Pickaxe" then
		local nextTier = Balance.Pickaxe(data.Pickaxe + 1)
		if data.Coins < nextTier.Cost then
			return false, "Not enough coins."
		end
		data.Coins -= nextTier.Cost
		data.Pickaxe += 1
		ctx.PickaxeVis.Refresh(player)
		Remotes.Event("Notify"):FireClient(player, { Text = nextTier.Name .. " equipped!", Color = Color3.fromRGB(120, 255, 200) })
	elseif kind == "Backpack" then
		local nextTier = Balance.Backpack(data.Backpack + 1)
		if data.Coins < nextTier.Cost then
			return false, "Not enough coins."
		end
		data.Coins -= nextTier.Cost
		data.Backpack += 1
	elseif kind == "RackSlot" then
		if data.RackSlots >= Balance.MaxRackSlots then
			return false, "All rack slots owned!"
		end
		local cost = Balance.RackSlotCosts[data.RackSlots - Balance.BaseRackSlots + 1]
		if not cost then
			return false, "All rack slots owned!"
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
