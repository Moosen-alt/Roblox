--!strict
-- Clock-synced shop: stock derives from floor(os.time()/300), so every server
-- shows the same stock and it "restocks" every 5 minutes forever, no live-ops.
-- Compliance: geode offers are random-content items purchasable with a
-- Robux-purchasable currency, so their exact odds ship with the stock payload,
-- and players whose policy restricts paid random items only ever see the
-- deterministic crystal offers (PolicyService gating).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Crystals = require(Shared.Config.Crystals)
local RarityMath = require(Shared.RarityMath)
local Remotes = require(Shared.Remotes)

local ShopService = {}

local ctx: any = nil

local BUY_LIMIT_PER_WINDOW = 3

export type ShopItem = {
	Kind: string, -- "Geode" | "GeodeBundle" | "PremiumGeode" | "Crystal"
	Title: string,
	Cost: number,
	Count: number?,
	Luck: number?,
	Base: string?,
	Mut: string?,
	Value: number?,
	Odds: { RarityMath.OddsEntry }?,
	DailyDeal: boolean?,
}

local function windowSeed(): number
	return os.time() // Balance.ShopRestockSeconds
end

local function dailySeed(): number
	return os.time() // Balance.ShopDailyDealSeconds
end

local function geodeCost(layer: number): number
	return math.floor(Balance.ShopGeodeBaseCost * Balance.LayerValueMult ^ (layer - 1))
end

-- Seed-rolled deterministic crystal offer: everyone sees the same exact crystal
-- this window; contents are fully visible before purchase (policy-safe).
local function rolledCrystalOffer(seedRng: Random, layer: number, priceMult: number): ShopItem
	-- Rare-or-better only. Rolling the full table meant that half the time this
	-- slot offered a Quartz for more coins than a Quartz sells for — an offer
	-- with no reason to exist. The point of a fixed crystal is skipping the
	-- gamble for something you actually want.
	local baseName = RarityMath.RollRarePlus(layer, 2, seedRng)
	local mutName = RarityMath.RollMutation(1, seedRng)
	local size = 1.0 + seedRng:NextNumber() * 0.2
	local value = RarityMath.ComputeValue(baseName, mutName, size, layer)
	return {
		Kind = "Crystal",
		Title = (mutName ~= "Normal" and (mutName .. " ") or "") .. baseName,
		Cost = math.max(math.floor(value * priceMult), 10),
		Base = baseName,
		Mut = mutName,
		Value = value,
	}
end

function ShopService.BuildStock(player: Player, data: any): { RestockAt: number, Items: { ShopItem } }
	local layer = ctx.Data.Layer(data)
	local luck = ctx.Data.LuckMult(player, data)
	local seed = windowSeed() + (data.ShopSalt or 0) * 1e6
	local seedRng = Random.new(seed)
	local restricted = ctx.Policy.ArePaidRandomItemsRestricted(player)

	local items: { ShopItem } = {}
	if not restricted then
		table.insert(items, {
			Kind = "Geode",
			Title = "Geode",
			Cost = geodeCost(layer),
			Count = 1,
			Odds = RarityMath.GetBaseOdds(layer, luck),
		})
		table.insert(items, {
			Kind = "GeodeBundle",
			Title = "Geode x3",
			Cost = math.floor(geodeCost(layer) * 2.5),
			Count = 3,
			Odds = RarityMath.GetBaseOdds(layer, luck),
		})
		table.insert(items, {
			Kind = "PremiumGeode",
			Title = "Charged Geode",
			Cost = geodeCost(layer) * Balance.ShopPremiumGeodeCostMult,
			Count = 1,
			Luck = Balance.ShopPremiumGeodeLuck,
			Odds = RarityMath.GetBaseOdds(layer, luck * Balance.ShopPremiumGeodeLuck),
		})
		table.insert(items, rolledCrystalOffer(seedRng, layer, 1.25))
	else
		-- Deterministic-only storefront for restricted players (free path = mining).
		table.insert(items, rolledCrystalOffer(seedRng, layer, 1.15))
		table.insert(items, rolledCrystalOffer(seedRng, layer, 1.25))
		table.insert(items, rolledCrystalOffer(seedRng, layer, 1.35))
	end

	if ctx.Monetization.OwnsPass(player, "Vip") then
		table.insert(items, rolledCrystalOffer(seedRng, layer, 1.1))
	end

	-- Daily deal: one slot gets 40% off, rotating on a 24h clock.
	local dealIndex = Random.new(dailySeed()):NextInteger(1, #items)
	items[dealIndex].Cost = math.max(math.floor(items[dealIndex].Cost * 0.6), 5)
	items[dealIndex].DailyDeal = true

	-- A bundle must never cost more per geode than buying them one at a time.
	-- The daily deal is applied to a single slot, so when it landed on the plain
	-- geode the x3 next to it read as a 40% markup — correct arithmetic, terrible
	-- offer. Re-derive the bundle from whatever the single ended up costing.
	local single, bundle = nil, nil
	for _, item in items do
		if item.Kind == "Geode" then
			single = item
		elseif item.Kind == "GeodeBundle" then
			bundle = item
		end
	end
	if single and bundle then
		local count = bundle.Count or 3
		bundle.Cost = math.min(bundle.Cost, math.max(math.floor(single.Cost * count * 0.85), 5))
	end

	return {
		RestockAt = (windowSeed() + 1) * Balance.ShopRestockSeconds,
		Items = items,
	}
end

function ShopService.Buy(player: Player, itemIndex: number): (boolean, string?)
	local data = ctx.Data.Get(player)
	if not data then
		return false, "Loading..."
	end
	local stock = ShopService.BuildStock(player, data)
	local item = stock.Items[itemIndex]
	if not item then
		return false, "That offer just rotated out!"
	end

	-- Per-window purchase limits
	local seed = windowSeed()
	if data.ShopWindow.Seed ~= seed then
		data.ShopWindow.Seed = seed
		data.ShopWindow.Bought = {}
	end
	local key = tostring(itemIndex)
	local bought = data.ShopWindow.Bought[key] or 0
	if bought >= BUY_LIMIT_PER_WINDOW then
		return false, "Sold out this restock — wait for the timer!"
	end
	if data.Coins < item.Cost then
		return false, "Not enough coins."
	end

	if item.Kind == "Geode" or item.Kind == "GeodeBundle" then
		local space = ctx.Data.BackpackCapacity(data) - data.Geodes
		local count = item.Count or 1
		if space < count then
			return false, "Backpack full!"
		end
		data.Coins -= item.Cost
		data.Geodes += count
	elseif item.Kind == "PremiumGeode" then
		data.Coins -= item.Cost
		local result = ctx.Crack.RollWithLuck(player, item.Luck or Balance.ShopPremiumGeodeLuck)
		if result then
			Remotes.Event("CrackResult"):FireClient(player, { result }, false)
		end
	elseif item.Kind == "Crystal" then
		data.Coins -= item.Cost
		local id = tostring(data.NextCrystalId)
		data.NextCrystalId += 1
		local layer = ctx.Data.Layer(data)
		data.Crystals[id] = { Base = item.Base :: string, Mut = item.Mut :: string, Size = 1.1, Layer = layer }
		-- This branch grants a crystal outright rather than rolling one, so it has
		-- to record a personal best itself — otherwise a shop-bought Mythic never
		-- becomes the aura, the leaderboard entry, or the rarest-find board name.
		ctx.Crack.RecordRarest(player, data, item.Base :: string, item.Mut :: string, ctx.Data.CrystalValue(data, data.Crystals[id]))
		local indexKey = Crystals.IndexKey(item.Base :: string, item.Mut :: string)
		if not data.Collection[indexKey] then
			data.Collection[indexKey] = true
			data.CollectionCount += 1
		end
	else
		return false, "Unknown offer."
	end

	data.ShopWindow.Bought[key] = bought + 1
	ctx.Data.MarkDirty(player)
	return true, nil
end

-- Instant Restock dev product: personal reroll via the profile's ShopSalt.
function ShopService.PersonalRestock(player: Player)
	local data = ctx.Data.Get(player)
	if not data then
		return
	end
	data.ShopSalt = (data.ShopSalt or 0) + 1
	data.ShopWindow.Bought = {}
	ctx.Data.MarkDirty(player)
	Remotes.Event("Notify"):FireClient(player, { Text = "Shop restocked, just for you!", Color = Color3.fromRGB(120, 170, 255) })
end

function ShopService.Init(serviceCtx: any)
	ctx = serviceCtx
	Remotes.Function("GetShopStock").OnServerInvoke = function(player)
		local data = ctx.Data.Get(player)
		if not data then
			return nil
		end
		return ShopService.BuildStock(player, data)
	end
	Remotes.Function("BuyShopItem").OnServerInvoke = function(player, itemIndex)
		local index = tonumber(itemIndex)
		if not index then
			return false, "Bad request."
		end
		return ShopService.Buy(player, index)
	end
end

return ShopService
