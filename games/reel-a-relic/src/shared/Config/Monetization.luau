--!strict
-- ═══════════════════════════════════════════════════════════════════════════
--  THE ONLY FILE YOU EDIT BY HAND.
--  After publishing the game, create each gamepass and developer product on
--  the Creator Hub (see SETUP.md step 4) and paste its numeric ID below.
--  An ID of 0 means "not created yet" — the game hides that offer gracefully.
-- ═══════════════════════════════════════════════════════════════════════════

local Monetization = {}

-- Your Roblox group ID (players who join the group get 2x daily streak rewards).
Monetization.GroupId = 346261815

-- Gamepasses: { id, suggested price in Robux }
-- ── FRIENDS & FAMILY COMPS ──────────────────────────────────────────────────
-- UserIds listed here get gamepasses free. `true` comps EVERY pass; a table
-- comps only the listed ones. This is the only way to "gift" store items on
-- Roblox — passes can't be gifted on the platform, but the game decides what
-- ownership means. In-game only, no Robux moves, and it's fully reversible:
-- delete the line and the perks are gone the next time a server starts.
--
-- A friend's UserId is the number in their profile URL:
--   https://www.roblox.com/users/123456789/profile  ->  123456789
Monetization.CompUserIds = {
	-- [123456789] = true, -- everything, free
	-- [123456789] = { TripleCrack = true, Vip = true }, -- just these
} :: { [number]: boolean | { [string]: boolean } }

Monetization.Gamepasses = {
	AutoCrack = { Id = 0, Price = 100, Title = "Auto-Open", Desc = "Chests open themselves the moment you reel them in." },
	Coins2x = { Id = 0, Price = 250, Title = "2x Coins", Desc = "Permanently double every coin you earn." },
	Luck2x = { Id = 0, Price = 350, Title = "2x Luck", Desc = "Double your odds of rare fish, forever." },
	AutoCast = { Id = 0, Price = 450, Title = "Auto-Cast", Desc = "Your rod casts itself, and reels for you when you're not. Grab the line any time to reel it better." },
	TripleCrack = { Id = 0, Price = 450, Title = "Triple Open", Desc = "Open 3 chests at once." },
	OvernightMiner = { Id = 0, Price = 500, Title = "Overnight Aquarium", Desc = "Offline progress: 8h cap -> 24h, +50% offline earnings." },
	Vip = { Id = 0, Price = 1000, Title = "VIP Sea Captain", Desc = "Golden name, exclusive aura, +25% coins, +1 Daily Deal." },
}

-- Developer products (repeatable purchases): { id, suggested price in Robux }
Monetization.Products = {
	StarterPack = { Id = 0, Price = 200, Title = "Starter Pack", Desc = "2,500 coins + a guaranteed Rainbow Trout + 24h of 2x coins. One time only." },
	Coins1k = { Id = 0, Price = 100, Title = "Coin Pouch", Coins = 1000 },
	Coins5k = { Id = 0, Price = 500, Title = "Coin Chest", Coins = 5500 },
	Coins12k = { Id = 0, Price = 1000, Title = "Coin Vault", Coins = 12000 },
	TimeWarp = { Id = 0, Price = 200, Title = "Time Warp", Desc = "+8 hours of aquarium growth, instantly." },
	InstantRestock = { Id = 0, Price = 79, Title = "Instant Restock", Desc = "Refresh the shop stock right now, just for you." },
	InstantRebirth = { Id = 0, Price = 150, Title = "Instant Set Sail", Desc = "Set Sail now, no coin cost." },
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
