--!strict
-- ═══════════════════════════════════════════════════════════════════════════
--  THE ONLY FILE YOU EDIT BY HAND.
--  After publishing the game, create each gamepass and developer product on
--  the Creator Hub (see SETUP.md step 4) and paste its numeric ID below.
--  An ID of 0 means "not created yet" — the game hides that offer gracefully.
-- ═══════════════════════════════════════════════════════════════════════════

local Monetization = {}

-- Your Roblox group ID (players who join the group get 2x daily streak rewards).
Monetization.GroupId = 0

-- Gamepasses: { id, suggested price in Robux }
Monetization.Gamepasses = {
	AutoCrack = { Id = 1936664483, Price = 100, Title = "Auto-Crack", Desc = "Geodes crack themselves as you mine." },
	Coins2x = { Id = 1934463944, Price = 250, Title = "2x Coins", Desc = "Permanently double every coin you earn." },
	Luck2x = { Id = 1935363873, Price = 350, Title = "2x Luck", Desc = "Double your odds of rare crystals, forever." },
	TripleCrack = { Id = 1935177874, Price = 450, Title = "Triple Crack", Desc = "Crack 3 geodes at once." },
	OvernightMiner = { Id = 1934122029, Price = 500, Title = "Overnight Miner", Desc = "Offline progress: 8h cap -> 24h, +50% offline earnings." },
	Vip = { Id = 1936390525, Price = 1000, Title = "VIP Geode Baron", Desc = "Golden name, exclusive aura, +25% coins, +1 Daily Deal." },
}

-- Developer products (repeatable purchases): { id, suggested price in Robux }
Monetization.Products = {
	StarterPack = { Id = 3613222765, Price = 200, Title = "Starter Pack", Desc = "2,500 coins + a guaranteed Emerald + 24h of 2x coins. One time only." },
	Coins1k = { Id = 3613222802, Price = 100, Title = "Coin Pouch", Coins = 1000 },
	Coins5k = { Id = 3613222833, Price = 500, Title = "Coin Chest", Coins = 5500 },
	Coins12k = { Id = 3613222859, Price = 1000, Title = "Coin Vault", Coins = 12000 },
	TimeWarp = { Id = 3613222883, Price = 200, Title = "Time Warp", Desc = "+8 hours of rack growth, instantly." },
	InstantRestock = { Id = 3613222914, Price = 79, Title = "Instant Restock", Desc = "Refresh the shop stock right now, just for you." },
	InstantRebirth = { Id = 3613222944, Price = 150, Title = "Instant Recrystallize", Desc = "Recrystallize now, no coin cost." },
}

function Monetization.PassIdByKey(key: string): number
	local def = (Monetization.Gamepasses :: any)[key]
	return def and def.Id or 0
end

function Monetization.ProductIdByKey(key: string): number
	local def = (Monetization.Products :: any)[key]
	return def and def.Id or 0
end

function Monetization.ProductKeyById(id: number): string?
	if id == 0 then
		return nil
	end
	for key, def in Monetization.Products :: any do
		if def.Id == id then
			return key
		end
	end
	return nil
end

return Monetization
