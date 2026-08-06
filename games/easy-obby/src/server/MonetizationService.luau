--!strict
-- Gamepass ownership (cached + persisted) and idempotent dev-product receipts.
-- Skip-stage products are the obby revenue workhorse.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Monetization = require(Shared.Config.Monetization)
local Remotes = require(Shared.Remotes)

local MonetizationService = {}

local ctx: any = nil
local passCache: { [Player]: { [string]: boolean } } = {}

function MonetizationService.OwnsPass(player: Player, key: string): boolean
	-- Friends-and-family comp: `true` comps every pass, a table comps only the
	-- listed keys. Checked before the Id gate so comps work even for passes not
	-- yet created on the platform. Nothing is persisted, so removing a UserId
	-- from the list takes the perks away again on the next server.
	local comp = Monetization.CompUserIds[player.UserId]
	if comp == true or (typeof(comp) == "table" and (comp :: { [string]: boolean })[key] == true) then
		return true
	end
	local id = Monetization.PassIdByKey(key)
	if id == 0 then
		return false
	end
	local cached = passCache[player]
	if cached and cached[key] ~= nil then
		return cached[key]
	end
	local data = ctx.Data.Get(player)
	if data and data.OwnedPasses[key] then
		return true
	end
	return false
end

function MonetizationService.PreloadPasses(player: Player, data: any)
	local cached: { [string]: boolean } = {}
	passCache[player] = cached
	for key, def in Monetization.Gamepasses :: any do
		if def.Id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, def.Id)
			end)
			if ok then
				cached[key] = owns == true
				if owns then
					data.OwnedPasses[key] = true
				end
			end
		end
	end
	ctx.Data.MarkDirty(player)
end

local PRODUCT_GRANTS: { [string]: (Player, any) -> () } = {
	Skip1 = function(player, data)
		ctx.Stages.AdvanceTo(player, data.Checkpoint + 1)
	end,
	Skip10 = function(player, data)
		ctx.Stages.AdvanceTo(player, data.Checkpoint + 10)
	end,
	JumpBoost50 = function(player, data)
		data.JumpBonus = math.min(data.JumpBonus + 50, Balance.JumpBonusCap)
		ctx.Stages.ApplyStats(player)
		Remotes.Event("Notify"):FireClient(player, { Text = "+50 Jump Power!", Color = Color3.fromRGB(120, 255, 200) })
	end,
	InstantRebirth = function(player, _data)
		ctx.Rebirth.Perform(player, true)
	end,
	Coins1k = function(player, data)
		local def = Monetization.Products.Coins1k
		data.Coins += def.Coins :: number
		data.TotalCoinsEarned += def.Coins :: number
		Remotes.Event("Notify"):FireClient(player, { Text = "+" .. tostring(def.Coins) .. " coins!", Color = Color3.fromRGB(255, 210, 90) })
	end,
	Coins5k = function(player, data)
		local def = Monetization.Products.Coins5k
		data.Coins += def.Coins :: number
		data.TotalCoinsEarned += def.Coins :: number
		Remotes.Event("Notify"):FireClient(player, { Text = "+" .. tostring(def.Coins) .. " coins!", Color = Color3.fromRGB(255, 210, 90) })
	end,
}

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = ctx.Data.Get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receipt.PurchaseId)
	for _, processed in data.Purchases do
		if processed == purchaseId then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end

	local key = Monetization.ProductKeyById(receipt.ProductId)
	local grant = key and PRODUCT_GRANTS[key]
	if not grant then
		warn("[Monetization] Receipt for unknown product id " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok, err = (pcall :: any)(grant, player, data)
	if not ok then
		warn("[Monetization] Grant failed for " .. tostring(key) .. ": " .. tostring(err))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	table.insert(data.Purchases, purchaseId)
	while #data.Purchases > 100 do
		table.remove(data.Purchases, 1)
	end
	ctx.Data.MarkDirty(player)
	ctx.Analytics.LogCustom(player, "ProductPurchased_" .. tostring(key))
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.Init(serviceCtx: any)
	ctx = serviceCtx
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for key, def in Monetization.Gamepasses :: any do
			if def.Id == passId then
				local cached = passCache[player]
				if cached then
					cached[key] = true
				end
				local data = ctx.Data.Get(player)
				if data then
					data.OwnedPasses[key] = true
					ctx.Data.MarkDirty(player)
				end
				Remotes.Event("Notify"):FireClient(player, { Text = def.Title .. " unlocked!", Color = Color3.fromRGB(120, 255, 200) })
				ctx.Analytics.LogCustom(player, "PassPurchased_" .. key)
				ctx.Stages.ApplyStats(player) -- coil/jump passes take effect immediately
				if key == "Vip" and player.Character then
					ctx.Trails.Attach(player, player.Character)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		passCache[player] = nil
	end)
end

return MonetizationService
