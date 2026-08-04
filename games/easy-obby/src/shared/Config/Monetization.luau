--!strict
-- ═══════════════════════════════════════════════════════════════════════════
--  THE ONLY FILE YOU EDIT BY HAND.
--  After publishing, create each gamepass and developer product on the
--  Creator Hub and paste its numeric ID below. An ID of 0 means "not created
--  yet" — the game hides that offer gracefully.
-- ═══════════════════════════════════════════════════════════════════════════

local Monetization = {}

-- Your Roblox group ID (players who join the group get 2x daily streak rewards).
Monetization.GroupId = 346261815

Monetization.Gamepasses = {
	SpeedCoil = { Id = 0, Price = 49, Title = "Speed Coil", Desc = "+8 walkspeed, forever. The classic." },
	Coins2x = { Id = 0, Price = 149, Title = "2x Coins", Desc = "Permanently double every coin you earn." },
	JumpGain2x = { Id = 0, Price = 249, Title = "2x Jump Gain", Desc = "Every stage gives +2 Jump Power instead of +1." },
	Vip = { Id = 0, Price = 499, Title = "VIP", Desc = "Rainbow trail, +25% coins, and teleport to any cleared stage." },
	MegaStart = { Id = 0, Price = 999, Title = "Mega Start", Desc = "Start every rebirth with +100 Jump Power." },
}

Monetization.Products = {
	Skip1 = { Id = 0, Price = 25, Title = "Skip Stage", Desc = "Skip 1 stage (you still get its +1 Jump and coins)." },
	Skip10 = { Id = 0, Price = 149, Title = "Skip 10 Stages", Desc = "Skip 10 stages at once — rewards included." },
	JumpBoost50 = { Id = 0, Price = 75, Title = "+50 Jump Boost", Desc = "+50 Jump Power this run, instantly." },
	InstantRebirth = { Id = 0, Price = 199, Title = "Instant Rebirth", Desc = "Rebirth right now, from anywhere." },
	Coins1k = { Id = 0, Price = 100, Title = "Coin Pouch", Coins = 1000 },
	Coins5k = { Id = 0, Price = 500, Title = "Coin Chest", Coins = 5500 },
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
