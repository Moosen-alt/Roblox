--!strict
-- Every tuning constant in one place. Post-launch "balancing" is editing this file only.

local Balance = {}

-- FILM MODE: set true in Studio to record marketing clips — maxed profile,
-- 36/48 collection, Day 30 streak, 8h of offline earnings waiting, and server
-- events firing every few seconds. It is ignored outside Studio and ships as
-- false, so it can never affect the live game. See src/server/FilmMode.luau.
Balance.FilmMode = false

-- Cave layers (unlocked by rebirths). Values multiply, rarity luck creeps up.
Balance.MaxLayer = 5
Balance.LayerValueMult = 2.5 -- crystal value x 2.5 per layer
Balance.LayerLuckBonus = 0.15 -- +15% luck per layer past the first
Balance.LayerNames = { "Sunny Shallows", "Kelp Forest", "Twilight Reef", "Midnight Trench", "The Abyss" }

-- Mining
Balance.MineCooldown = 0.22 -- seconds between counted taps (server enforced)
Balance.NodeBaseHealth = 3 -- taps to pop a geode at pickaxe damage 1
Balance.NodeRespawnTime = 2.5
Balance.NodeCount = 12 -- deposit nodes on the mine wall
Balance.PityForcedRareCrack = 3 -- the Nth lifetime crack is guaranteed Rare+ (first-session hook)

-- Pickaxes: damage per tap. Index 1 is the freebie.
Balance.Pickaxes = {
	{ Name = "Twig Rod", Damage = 1, Cost = 0, Color = Color3.fromRGB(140, 105, 70), Material = Enum.Material.Wood, Glow = false },
	{ Name = "Copper Rod", Damage = 2, Cost = 150, Color = Color3.fromRGB(205, 125, 70), Material = Enum.Material.Metal, Glow = false },
	{ Name = "Iron Rod", Damage = 3, Cost = 600, Color = Color3.fromRGB(190, 190, 200), Material = Enum.Material.Metal, Glow = false },
	{ Name = "Golden Rod", Damage = 5, Cost = 2000, Color = Color3.fromRGB(255, 200, 60), Material = Enum.Material.Metal, Glow = false },
	{ Name = "Coral Rod", Damage = 8, Cost = 8000, Color = Color3.fromRGB(255, 120, 140), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Laser Rod", Damage = 12, Cost = 30000, Color = Color3.fromRGB(255, 60, 80), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Storm Rod", Damage = 20, Cost = 120000, Color = Color3.fromRGB(120, 200, 255), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Leviathan Rod", Damage = 30, Cost = 500000, Color = Color3.fromRGB(120, 90, 200), Material = Enum.Material.Neon, Glow = true },
}

-- Backpacks: how many uncracked geodes you can carry.
Balance.Backpacks = {
	{ Name = "Dinghy", Capacity = 6, Cost = 0 },
	{ Name = "Rowboat", Capacity = 12, Cost = 200 },
	{ Name = "Sloop", Capacity = 24, Cost = 900 },
	{ Name = "Trawler", Capacity = 48, Cost = 4000 },
	{ Name = "Galleon", Capacity = 96, Cost = 18000 },
}

-- Growth racks: socketed crystals produce coins and slowly grow in size (value).
Balance.BaseRackSlots = 2
Balance.MaxRackSlots = 8
Balance.RackSlotCosts = { 500, 2500, 10000, 40000, 150000, 600000 } -- slots 3..8
Balance.RackCoinsPerValuePerSecond = 0.001 -- a 100-value crystal makes 0.1 coins/sec
Balance.RackGrowthPerSecond = 0.0001 -- size units/sec; size starts ~1.0
Balance.MaxCrystalSize = 3.0

-- Offline progress (the daily-return hook). Computed from timestamps on rejoin.
Balance.OfflineCapSeconds = 8 * 3600
Balance.OfflineCapSecondsVip = 24 * 3600 -- with Overnight Miner pass
Balance.OfflineRateVip = 1.5 -- Overnight Miner also boosts offline earnings

-- Rebirth (Recrystallize): pay coins, reset progress, permanent +25% coins each.
Balance.RebirthBaseCost = 10000
Balance.RebirthCostGrowth = 2.5 -- cost = base * growth^rebirths
Balance.RebirthCoinBonus = 0.25 -- +25% coin value per rebirth, forever

-- Shop: clock-synced restock (same stock for everyone in the world, no live-ops).
Balance.ShopRestockSeconds = 300
Balance.ShopDailyDealSeconds = 86400
Balance.ShopGeodeBaseCost = 25 -- coins, scaled by layer
Balance.ShopPremiumGeodeLuck = 3 -- premium shop geode rolls with 3x luck
Balance.ShopPremiumGeodeCostMult = 4

-- Random server events: limited-time feel with zero developer intervention.
Balance.EventCheckInterval = 360 -- consider an event roughly every 6 minutes
Balance.EventChance = 0.45
Balance.EventDuration = 180
Balance.Events = {
	{ Name = "Feeding Frenzy", LuckMult = 10, MutationMult = 1, Color = Color3.fromRGB(255, 170, 40) },
	{ Name = "Moon Tide", LuckMult = 1, MutationMult = 5, Color = Color3.fromRGB(160, 200, 255) },
}

-- Daily streaks: a VISIBLE 7-day reward cycle (repeats forever, 1 grace day).
-- Day 7 anchor: big coins + a guaranteed Golden Chest roll (free-action
-- randomness, no paid-random surface).
Balance.StreakGraceDays = 1
Balance.StreakCycle = {
	{ Coins = 150 },
	{ Coins = 300 },
	{ Coins = 600 },
	{ Coins = 1000 },
	{ Coins = 1500 },
	{ Coins = 2500 },
	{ Coins = 5000, PremiumGeode = true },
}

-- Boosts
Balance.StarterPackCoins = 2500
Balance.StarterPackBoostSeconds = 24 * 3600 -- 24h of 2x coins
Balance.TimeWarpSeconds = 8 * 3600 -- Time Warp dev product: +8h of rack progress, instantly

-- VIP
Balance.VipCoinBonus = 0.25

return Balance
