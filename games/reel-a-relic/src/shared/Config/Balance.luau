--!strict
-- Every tuning constant in one place. Post-launch "balancing" is editing this file only.

local Balance = {}

-- FILM MODE: set true in Studio to record marketing clips — maxed profile,
-- 36/48 collection, Day 30 streak, 8h of offline earnings waiting, and server
-- events firing every few seconds. It is ignored outside Studio and ships as
-- false, so it can never affect the live game. See src/server/FilmMode.luau.
Balance.FilmMode = false

-- Fishing areas. Internally these are still "layers" — the engine's word for a
-- content tier, and the same name the sibling games use — but the player buys
-- and sails to an AREA. Each is a physically separate stretch of water with its
-- own species, its own lighting and its own dock.
Balance.MaxLayer = 5
Balance.LayerValueMult = 2.5 -- fish value x 2.5 per area
Balance.LayerLuckBonus = 0.15 -- +15% luck per area past the first
Balance.LayerNames = { "Sunny Shallows", "Kelp Forest", "Twilight Reef", "Midnight Trench", "The Abyss" }

-- Coins to unlock each area, paid once and kept forever. Index 1 is free (you
-- start there); index N is the price of sailing to area N.
--
-- Areas are bought with COINS, not Robux, and Set Sail does not take them back.
-- That is what makes them safe to want: a locked dock you can see across the
-- water is a goal, and a goal you can lose is a threat. The coin sink is the
-- point — it gives selling fish a destination beyond the next rod.
Balance.AreaCosts = { 0, 6000, 45000, 350000, 3000000 }
Balance.AreaSpacing = 600 -- studs between area origins on the X axis

-- Fishing
Balance.MineCooldown = 0.22 -- seconds between counted casts (server enforced)
Balance.NodeBaseHealth = 3 -- unused by the fishing loop; kept for shared math
Balance.NodeRespawnTime = 2.5
Balance.NodeCount = 12 -- fishing spots per area
Balance.CastRange = 60 -- studs; how far you can cast from a spot
-- Roughly one catch in eight comes up as a chest instead of a fish. Frequent
-- enough that the opening animation is a regular beat, rare enough that it stays
-- an event — and every chest is a guaranteed Rare+, so it can never disappoint.
Balance.CrateChance = 0.12
Balance.PityForcedRareCrack = 3 -- the Nth lifetime open is guaranteed Rare+ (first-session hook)
-- Auto-Cast is offered once, after this many lifetime catches — late enough that
-- the player has felt the clicking, early enough that they still care.
Balance.AutoCastOfferAfterCatches = 150

-- Rods. `Damage` drives how fast fish bite and the double-hook chance. Index 1
-- is the freebie. The authored run is long, and past it `Balance.Pickaxe(level)`
-- keeps generating tiers forever — an upgrade button that greys out with nothing
-- behind it is the fastest way to end a session.
export type RodTier = {
	Name: string,
	Damage: number,
	Cost: number,
	Color: Color3,
	Material: Enum.Material,
	Glow: boolean,
}

Balance.Pickaxes = {
	{ Name = "Twig Rod", Damage = 1, Cost = 0, Color = Color3.fromRGB(140, 105, 70), Material = Enum.Material.Wood, Glow = false },
	{ Name = "Copper Rod", Damage = 2, Cost = 150, Color = Color3.fromRGB(205, 125, 70), Material = Enum.Material.Metal, Glow = false },
	{ Name = "Iron Rod", Damage = 3, Cost = 600, Color = Color3.fromRGB(190, 190, 200), Material = Enum.Material.Metal, Glow = false },
	{ Name = "Golden Rod", Damage = 5, Cost = 2000, Color = Color3.fromRGB(255, 200, 60), Material = Enum.Material.Metal, Glow = false },
	{ Name = "Coral Rod", Damage = 8, Cost = 8000, Color = Color3.fromRGB(255, 120, 140), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Laser Rod", Damage = 12, Cost = 30000, Color = Color3.fromRGB(255, 60, 80), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Storm Rod", Damage = 20, Cost = 120000, Color = Color3.fromRGB(120, 200, 255), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Leviathan Rod", Damage = 30, Cost = 500000, Color = Color3.fromRGB(120, 90, 200), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Kraken Rod", Damage = 46, Cost = 1_800_000, Color = Color3.fromRGB(90, 200, 130), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Tidecaller", Damage = 72, Cost = 6_500_000, Color = Color3.fromRGB(90, 210, 220), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Moonlit Rod", Damage = 112, Cost = 24_000_000, Color = Color3.fromRGB(200, 220, 255), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Trench Rod", Damage = 175, Cost = 90_000_000, Color = Color3.fromRGB(80, 70, 120), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Siren's Rod", Damage = 270, Cost = 340_000_000, Color = Color3.fromRGB(255, 150, 220), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Maelstrom Rod", Damage = 420, Cost = 1_300_000_000, Color = Color3.fromRGB(150, 110, 255), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Abyssal Rod", Damage = 650, Cost = 5_000_000_000, Color = Color3.fromRGB(70, 60, 110), Material = Enum.Material.Neon, Glow = true },
	{ Name = "Poseidon's Rod", Damage = 1000, Cost = 19_000_000_000, Color = Color3.fromRGB(120, 255, 255), Material = Enum.Material.Neon, Glow = true },
}

-- What a rod's Damage actually buys. These are curves, not clamps, and that is
-- the point: the old maths was `math.clamp(1 - damage * 0.015, 0.5, 1)` for bite
-- speed and `math.min(damage * 0.02, 0.6)` for the double hook, both of which
-- pinned at around damage 30 — so every rod past the eighth tier bought you
-- literally nothing. Players noticed, correctly, that upgrading stopped working.
--
-- Asymptotes fix it honestly. Bite delay approaches BiteFloor without ever
-- reaching it and extra catches grow with the logarithm of damage, so tier 40 is
-- still a real improvement over tier 39 — small, but never zero, and never a
-- wall you hit without being told.
-- How long a fish takes to find your bait, before the rod's factor is applied.
-- Lives here rather than inside MiningService so the shop can quote a real
-- number of seconds at the player instead of an abstract stat.
Balance.BiteDelayMin = 1.5
Balance.BiteDelayMax = 4.0

-- TIMING IS A BONUS, NOT A GATE.
--
-- The original loop gave you a 1.2s window to strike and threw the whole catch
-- away if you missed it. That is a fighting-game convention, and it is wrong for
-- who plays this: an eight-year-old who misses by a tenth of a second loses
-- three seconds of waiting and is told nothing about why. Every successful
-- Roblox simulator this game sits next to shares one rule — an input always
-- produces something, and good timing produces MORE.
--
-- So: once a fish is on, it stays on until you reel it in. Strike inside this
-- window and it is a PERFECT catch worth an extra fish. Strike later and you
-- still get the fish. You cannot lose one by being slow.
Balance.PerfectWindow = 1.2
Balance.PerfectBonusCatch = 1

-- Mashing the button before the bite spooks the fish and pushes it back a
-- moment. That is the counterweight that keeps patience worth something now
-- that missing costs nothing — and unlike losing the catch, it is a delay the
-- player can see happen and understand.
Balance.SpookDelay = 0.6

Balance.BiteFloor = 0.45 -- fastest possible bite, as a fraction of the base wait
Balance.BiteSharpness = 0.08 -- how quickly early rods approach that floor
Balance.ExtraCatchScale = 0.35 -- catches per landing grow as log(1 + damage) * this
-- Subtracted so the STARTER rod lands on the old 2% double-hook chance exactly.
-- Without it the fix would have quietly buffed the first ten minutes of the game
-- by 10x, which is not what "upgrades stopped working" asked for.
Balance.ExtraCatchBase = 0.22

function Balance.RodBiteFactor(damage: number): number
	return Balance.BiteFloor + (1 - Balance.BiteFloor) / (1 + math.max(damage, 0) * Balance.BiteSharpness)
end

-- Average extra fish on a landing. The whole part is guaranteed, the fraction is
-- the chance of one more — so 1.9 means "always +1, and 90% of the time +2".
function Balance.RodExtraCatch(damage: number): number
	return math.max(math.log(1 + math.max(damage, 0)) * Balance.ExtraCatchScale - Balance.ExtraCatchBase, 0)
end

-- The two numbers a player can actually feel, for the shop to show: how long
-- they wait for a bite, and how many fish come up when they land one.
function Balance.RodAverageWait(damage: number): number
	return (Balance.BiteDelayMin + Balance.BiteDelayMax) * 0.5 * Balance.RodBiteFactor(damage)
end

function Balance.RodFishPerCatch(damage: number): number
	return 1 + Balance.RodExtraCatch(damage)
end

Balance.PickaxeDamageGrowth = 1.55
Balance.PickaxeCostGrowth = 3.85
local ROD_TITLES = { "Ascendant", "Celestial", "Infinite", "Leviathan's", "Sovereign", "Worldtide" }
local ROD_TINTS = {
	Color3.fromRGB(120, 255, 255),
	Color3.fromRGB(150, 255, 245),
	Color3.fromRGB(190, 90, 255),
	Color3.fromRGB(255, 70, 120),
	Color3.fromRGB(120, 255, 190),
}

-- The one way to look up a rod. Always returns a tier: there is no top.
function Balance.Pickaxe(level: number): RodTier
	local authored = Balance.Pickaxes[math.max(math.floor(level), 1)]
	if authored then
		return authored
	end
	local count = #Balance.Pickaxes
	local past = math.floor(level) - count
	local last = Balance.Pickaxes[count]
	local title = ROD_TITLES[(past - 1) % #ROD_TITLES + 1]
	local mark = math.floor((past - 1) / #ROD_TITLES) + 1
	return {
		Name = if mark > 1 then ("%s Rod %d"):format(title, mark) else (title .. " Rod"),
		Damage = math.floor(last.Damage * Balance.PickaxeDamageGrowth ^ past + 0.5),
		Cost = math.floor(last.Cost * Balance.PickaxeCostGrowth ^ past + 0.5),
		Color = ROD_TINTS[(past - 1) % #ROD_TINTS + 1],
		Material = Enum.Material.Neon,
		Glow = true,
	}
end

-- Boats: how much your hold carries (fish + unopened chests together). Endless
-- for the same reason as the rod — a boat that stops growing is just the same
-- wall one step later.
export type BoatTier = { Name: string, Capacity: number, Cost: number }

Balance.Backpacks = {
	{ Name = "Dinghy", Capacity = 6, Cost = 0 },
	{ Name = "Rowboat", Capacity = 12, Cost = 200 },
	{ Name = "Sloop", Capacity = 24, Cost = 900 },
	{ Name = "Trawler", Capacity = 48, Cost = 4000 },
	{ Name = "Galleon", Capacity = 96, Cost = 18000 },
	{ Name = "Clipper", Capacity = 180, Cost = 85_000 },
	{ Name = "Icebreaker", Capacity = 340, Cost = 400_000 },
	{ Name = "Research Vessel", Capacity = 640, Cost = 1_900_000 },
	{ Name = "Submersible", Capacity = 1200, Cost = 9_000_000 },
	{ Name = "Abyssal Ark", Capacity = 2400, Cost = 44_000_000 },
}

Balance.BackpackCapacityGrowth = 1.9
Balance.BackpackCostGrowth = 4.8

function Balance.Backpack(level: number): BoatTier
	local authored = Balance.Backpacks[math.max(math.floor(level), 1)]
	if authored then
		return authored
	end
	local count = #Balance.Backpacks
	local past = math.floor(level) - count
	local last = Balance.Backpacks[count]
	return {
		Name = ("Abyssal Ark %d"):format(past + 1),
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
