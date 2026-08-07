--!strict
-- Every tuning constant in one place. Post-launch "balancing" is editing this file only.

local Balance = {}

-- FILM MODE: set true in Studio to record marketing clips — maxed profile,
-- 36/48 collection, Day 30 streak, 8h of offline earnings waiting, and server
-- events firing every few seconds. It is ignored outside Studio and ships as
-- false, so it can never affect the live game. See src/server/FilmMode.luau.
Balance.FilmMode = false

-- Cave layers (unlocked by rebirths). Values multiply, rarity luck creeps up.
--
-- 25, not 5. Layers are the only knob in the game where the reward and the cost
-- move together by construction — deposit toughness x3 and crystal value x2.5
-- per layer — so making the ladder long is safe in a way that inflating any
-- single number is not. At five layers the whole game bottomed out four rebirths
-- in: nothing got deeper, so nothing needed a better pickaxe, so the upgrade
-- button stopped mattering. That was the real wall behind "you can't upgrade
-- your pickaxe any more".
Balance.MaxLayer = 25
Balance.LayerValueMult = 2.5 -- crystal value x 2.5 per layer
Balance.LayerLuckBonus = 0.15 -- +15% luck per layer past the first
Balance.LayerNames = { "Crystal Cavern", "Amber Depths", "Frost Hollow", "Ember Rift", "Starfall Core" }

-- Named layers past the authored five. Two words drawn from independent lists,
-- so twenty generated names read as places rather than as "Starfall Core 7".
local DEEP_PREFIX =
	{ "Obsidian", "Hollow", "Cinder", "Glacier", "Verdant", "Ashen", "Radiant", "Drowned", "Gilded", "Shattered" }
local DEEP_SUFFIX = { "Reach", "Abyss", "Expanse", "Undercroft", "Spire", "Maw", "Vault", "Chasm" }

function Balance.LayerName(layer: number): string
	local authored = Balance.LayerNames[layer]
	if authored then
		return authored
	end
	local past = layer - #Balance.LayerNames
	local prefix = DEEP_PREFIX[(past - 1) % #DEEP_PREFIX + 1]
	local suffix = DEEP_SUFFIX[(past - 1) % #DEEP_SUFFIX + 1]
	return prefix .. " " .. suffix
end

-- Mining
Balance.MineCooldown = 0.22 -- seconds between counted taps (server enforced)
Balance.NodeBaseHealth = 3 -- damage to pop a layer-1 geode (pickaxe damage 1 = 3 taps)
Balance.NodeHealthLayerGrowth = 3 -- deposit toughness x3 per layer, so every pickaxe tier stays relevant
Balance.NodeRespawnTime = 2.5 -- per player, not per server: see MiningService
Balance.NodeCount = 12 -- deposit nodes on the mine wall
Balance.MineRange = 32 -- studs; how close you must stand to swing at a geode
-- Auto Miner is offered once, after this many lifetime geodes — late enough
-- that the player has felt the tapping, early enough that they still care.
Balance.AutoMineOfferAfterGeodes = 150
Balance.PityForcedRareCrack = 3 -- the Nth lifetime crack is guaranteed Rare+ (first-session hook)

-- Pickaxes: damage per tap. Index 1 is the freebie. Color/Material/Glow drive
-- the held pickaxe model so every upgrade is visible in your hand.
--
-- These twenty are the hand-authored run. Past them `Balance.Pickaxe(level)`
-- keeps generating tiers forever, so the upgrade button is never greyed out with
-- nothing behind it — see below.
export type PickaxeTier = {
	Name: string,
	Damage: number,
	Cost: number,
	Color: Color3,
	Material: Enum.Material,
	Glow: boolean,
}

Balance.Pickaxes = {
	{ Name = "Rusty Pick", Damage = 1, Cost = 0, Color = Color3.fromRGB(160, 158, 165), Material = Enum.Material.Metal, Glow = false },
	{ Name = "Copper Pick", Damage = 2, Cost = 150, Color = Color3.fromRGB(205, 125, 70), Material = Enum.Material.Metal, Glow = false },
	{ Name = "Iron Pick", Damage = 3, Cost = 600, Color = Color3.fromRGB(190, 190, 200), Material = Enum.Material.Metal, Glow = false },
	{ Name = "Golden Pick", Damage = 5, Cost = 2000, Color = Color3.fromRGB(255, 200, 60), Material = Enum.Material.Metal, Glow = false },
	{ Name = "Crystal Pick", Damage = 8, Cost = 8000, Color = Color3.fromRGB(190, 90, 255), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Laser Pick", Damage = 12, Cost = 30000, Color = Color3.fromRGB(255, 60, 80), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Plasma Pick", Damage = 20, Cost = 120000, Color = Color3.fromRGB(80, 220, 255), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Singularity Pick", Damage = 30, Cost = 500000, Color = Color3.fromRGB(60, 30, 90), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Meteorite Pick", Damage = 46, Cost = 1_800_000, Color = Color3.fromRGB(120, 90, 70), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Thunder Pick", Damage = 72, Cost = 6_500_000, Color = Color3.fromRGB(255, 240, 120), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Frostbite Pick", Damage = 112, Cost = 24_000_000, Color = Color3.fromRGB(160, 230, 255), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Magma Pick", Damage = 175, Cost = 90_000_000, Color = Color3.fromRGB(255, 110, 40), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Prism Pick", Damage = 270, Cost = 340_000_000, Color = Color3.fromRGB(255, 150, 220), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Nebula Pick", Damage = 420, Cost = 1_300_000_000, Color = Color3.fromRGB(150, 110, 255), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Eclipse Pick", Damage = 650, Cost = 5_000_000_000, Color = Color3.fromRGB(70, 60, 110), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Quasar Pick", Damage = 1000, Cost = 19_000_000_000, Color = Color3.fromRGB(120, 255, 255), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Aurora Pick", Damage = 1550, Cost = 72_000_000_000, Color = Color3.fromRGB(120, 255, 190), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Riftbreaker", Damage = 2400, Cost = 280_000_000_000, Color = Color3.fromRGB(255, 60, 140), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Starforge Pick", Damage = 3700, Cost = 1_050_000_000_000, Color = Color3.fromRGB(255, 210, 90), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Voidheart Pick", Damage = 5700, Cost = 4_000_000_000_000, Color = Color3.fromRGB(190, 60, 255), Material = Enum.Material.Neon, Glow = true },
}

-- Past the authored list, tiers keep coming. Damage and cost both grow
-- geometrically at the same ratios the hand-written run uses, so the generated
-- tail is indistinguishable from more of the same rather than a different game.
Balance.PickaxeDamageGrowth = 1.55
Balance.PickaxeCostGrowth = 3.85
local PICK_TITLES =
	{ "Ascendant", "Celestial", "Infinite", "Paradox", "Sovereign", "Titanfall", "Everdark", "Worldsplitter" }
local PICK_TINTS = {
	Color3.fromRGB(255, 210, 90),
	Color3.fromRGB(120, 255, 255),
	Color3.fromRGB(190, 90, 255),
	Color3.fromRGB(255, 60, 140),
	Color3.fromRGB(120, 255, 190),
	Color3.fromRGB(150, 110, 255),
}

-- The one way to look up a pickaxe. Always returns a tier: there is no top.
function Balance.Pickaxe(level: number): PickaxeTier
	local authored = Balance.Pickaxes[math.max(math.floor(level), 1)]
	if authored then
		return authored
	end
	local count = #Balance.Pickaxes
	local past = math.floor(level) - count
	local last = Balance.Pickaxes[count]
	local title = PICK_TITLES[(past - 1) % #PICK_TITLES + 1]
	local mark = math.floor((past - 1) / #PICK_TITLES) + 1
	return {
		Name = if mark > 1 then ("%s Pick %d"):format(title, mark) else (title .. " Pick"),
		Damage = math.floor(last.Damage * Balance.PickaxeDamageGrowth ^ past + 0.5),
		Cost = math.floor(last.Cost * Balance.PickaxeCostGrowth ^ past + 0.5),
		Color = PICK_TINTS[(past - 1) % #PICK_TINTS + 1],
		Material = Enum.Material.Neon,
		Glow = true,
	}
end

-- Backpacks: how many uncracked geodes you can carry. Endless for the same
-- reason as the pickaxe — a pickaxe that never stops improving fills a fixed
-- backpack faster and faster, which turns the fix into a new wall.
export type BackpackTier = { Name: string, Capacity: number, Cost: number }

Balance.Backpacks = {
	{ Name = "Pouch", Capacity = 6, Cost = 0 },
	{ Name = "Satchel", Capacity = 12, Cost = 200 },
	{ Name = "Rucksack", Capacity = 24, Cost = 900 },
	{ Name = "Miner's Pack", Capacity = 48, Cost = 4000 },
	{ Name = "Void Pack", Capacity = 96, Cost = 18000 },
	{ Name = "Cavern Hauler", Capacity = 180, Cost = 85_000 },
	{ Name = "Gravity Sack", Capacity = 340, Cost = 400_000 },
	{ Name = "Pocket Dimension", Capacity = 640, Cost = 1_900_000 },
	{ Name = "Collapsed Star", Capacity = 1200, Cost = 9_000_000 },
	{ Name = "Eventide Vault", Capacity = 2400, Cost = 44_000_000 },
}

Balance.BackpackCapacityGrowth = 1.9
Balance.BackpackCostGrowth = 4.8

function Balance.Backpack(level: number): BackpackTier
	local authored = Balance.Backpacks[math.max(math.floor(level), 1)]
	if authored then
		return authored
	end
	local count = #Balance.Backpacks
	local past = math.floor(level) - count
	local last = Balance.Backpacks[count]
	return {
		Name = ("Eventide Vault %d"):format(past + 1),
		Capacity = math.floor(last.Capacity * Balance.BackpackCapacityGrowth ^ past + 0.5),
		Cost = math.floor(last.Cost * Balance.BackpackCostGrowth ^ past + 0.5),
	}
end

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

-- Daily streaks: a VISIBLE 7-day reward cycle (repeats forever, 1 grace day).
-- Players see the whole week's rewards in the welcome calendar — anticipation
-- is the retention hook. Day 7 is the anchor: big coins + a guaranteed
-- Charged Geode roll (free-action randomness, no paid-random surface).
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
