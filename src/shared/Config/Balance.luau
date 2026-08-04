--!strict
-- Every tuning constant in one place. Post-launch "balancing" is editing this file only.

local Balance = {}

-- Cave layers (unlocked by rebirths). Values multiply, rarity luck creeps up.
Balance.MaxLayer = 5
Balance.LayerValueMult = 2.5 -- crystal value x 2.5 per layer
Balance.LayerLuckBonus = 0.15 -- +15% luck per layer past the first
Balance.LayerNames = { "Crystal Cavern", "Amber Depths", "Frost Hollow", "Ember Rift", "Starfall Core" }

-- Mining
Balance.MineCooldown = 0.22 -- seconds between counted taps (server enforced)
Balance.NodeBaseHealth = 3 -- damage to pop a layer-1 geode (pickaxe damage 1 = 3 taps)
Balance.NodeHealthLayerGrowth = 3 -- deposit toughness x3 per layer, so every pickaxe tier stays relevant
Balance.NodeRespawnTime = 2.5
Balance.NodeCount = 12 -- deposit nodes on the mine wall
Balance.PityForcedRareCrack = 3 -- the Nth lifetime crack is guaranteed Rare+ (first-session hook)

-- Pickaxes: damage per tap. Index 1 is the freebie. Color/Material/Glow drive
-- the held pickaxe model so every upgrade is visible in your hand.
Balance.Pickaxes = {
	{ Name = "Rusty Pick", Damage = 1, Cost = 0, Color = Color3.fromRGB(140, 100, 70), Material = Enum.Material.CorrodedMetal, Glow = false },
	{ Name = "Copper Pick", Damage = 2, Cost = 150, Color = Color3.fromRGB(205, 125, 70), Material = Enum.Material.Metal, Glow = false },
	{ Name = "Iron Pick", Damage = 3, Cost = 600, Color = Color3.fromRGB(190, 190, 200), Material = Enum.Material.Metal, Glow = false },
	{ Name = "Golden Pick", Damage = 5, Cost = 2000, Color = Color3.fromRGB(255, 200, 60), Material = Enum.Material.Metal, Glow = false },
	{ Name = "Crystal Pick", Damage = 8, Cost = 8000, Color = Color3.fromRGB(190, 90, 255), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Laser Pick", Damage = 12, Cost = 30000, Color = Color3.fromRGB(255, 60, 80), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Plasma Pick", Damage = 20, Cost = 120000, Color = Color3.fromRGB(80, 220, 255), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Singularity Pick", Damage = 30, Cost = 500000, Color = Color3.fromRGB(60, 30, 90), Material = Enum.Material.Neon, Glow = true },
}

-- Backpacks: how many uncracked geodes you can carry.
Balance.Backpacks = {
	{ Name = "Pouch", Capacity = 6, Cost = 0 },
	{ Name = "Satchel", Capacity = 12, Cost = 200 },
	{ Name = "Rucksack", Capacity = 24, Cost = 900 },
	{ Name = "Miner's Pack", Capacity = 48, Cost = 4000 },
	{ Name = "Void Pack", Capacity = 96, Cost = 18000 },
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
	{ Name = "Meteor Shower", LuckMult = 10, MutationMult = 1, Color = Color3.fromRGB(255, 170, 40) },
	{ Name = "Aurora", LuckMult = 1, MutationMult = 5, Color = Color3.fromRGB(120, 255, 200) },
}

-- Daily streaks (day 7/14/30 milestones, 1 grace day before reset).
Balance.StreakBaseReward = 100 -- coins x current streak day (capped)
Balance.StreakDayCap = 30
Balance.StreakMilestones = { [7] = 3, [14] = 4, [30] = 6 } -- reward multiplier on milestone days
Balance.StreakGraceDays = 1

-- Boosts
Balance.StarterPackCoins = 2500
Balance.StarterPackBoostSeconds = 24 * 3600 -- 24h of 2x coins
Balance.TimeWarpSeconds = 8 * 3600 -- Time Warp dev product: +8h of rack progress, instantly

-- VIP
Balance.VipCoinBonus = 0.25

return Balance
