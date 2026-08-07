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
-- Shorter than it was (1.5-4.0). The wait used to be the whole gap between
-- catches and had to be long enough to feel like fishing; now the reel-in fills
-- that role with something the player is actually doing, so a long stare at a
-- buoy on top of it is just dead time twice.
Balance.BiteDelayMin = 1.0
Balance.BiteDelayMax = 2.8

-- THE REEL-IN.
--
-- A fish on the line opens a bar with the fish darting up and down it and a
-- bracket you steer by holding the button — hold to rise, release to fall. Keep
-- the fish in the bracket to fill the meter.
--
-- This is the genre standard for a reason. It turns the dead wait into the
-- actual game, it is one input so it plays identically on a phone and a mouse,
-- and it gives skill somewhere to live that is not a reaction test. A reaction
-- window rewards being twelve; tracking a moving target rewards paying
-- attention, which is a skill an eight-year-old can visibly get better at.
--
-- It keeps the rule the reaction window broke: you cannot LOSE a fish here. The
-- meter drains when you are off the fish but the reel always completes — on the
-- timeout if nothing else. How well you tracked decides the bonus, never whether
-- you get anything.
-- Tuned so a reel is a FIGHT, not a formality. Flawless tracking fills the meter
-- in ~3.3s; staying on the fish 70% of the time takes ~6s; a scrappy 40% runs
-- out the clock and lands the fish anyway on about half a meter. Fill much
-- faster than this and the bar is over before the player has read it.
Balance.ReelZoneSize = 0.24 -- bracket height, as a fraction of the bar
Balance.ReelFillRate = 0.3 -- meter per second while the fish is in the bracket
Balance.ReelDrainRate = 0.14 -- meter per second while it is not
-- The bracket must be able to OUTRUN the fish, or tracking becomes luck. Under
-- damping its top speed is acceleration / drag: 0.79 up, 0.57 down. Compare
-- against ReelFishSpeed below, which tops out at 0.66 in the Abyss.
Balance.ReelRise = 2.2 -- bracket acceleration while holding
Balance.ReelGravity = 1.6 -- bracket acceleration while not
Balance.ReelDrag = 2.8 -- damping, so the bracket settles instead of pinballing
-- A player who cannot track well still lands every fish — but they should not
-- spend fifteen seconds doing it, because that halves their catch rate against
-- someone who can, and the gap between a good and a struggling eight-year-old
-- should be a bonus, not a tax.
Balance.ReelTimeout = 10 -- seconds, after which you land it regardless
Balance.ReelMaxBonus = 2 -- extra fish at a flawless reel

-- Deeper fish fight harder: they change direction more often and move faster.
-- Difficulty comes from the AREA rather than the species because the species is
-- not rolled until the fish is in the boat — and because "the Abyss is harder
-- than the Shallows" is a promise the map already makes.
-- Capped below the bracket's 0.79 top speed on purpose: an Abyss fish at 0.66
-- can be caught by a player who commits to the chase, which is hard. One that
-- outruns the bracket outright would just be unfair, and unfair reads as broken.
Balance.ReelFishSpeedBase = 0.42 -- bar-fractions per second in area 1
Balance.ReelFishSpeedPerArea = 0.06
Balance.ReelFishTurnBase = 1.1 -- seconds between direction changes in area 1
Balance.ReelFishTurnPerArea = -0.12

-- Auto-Cast plays the reel for you, at a deliberately ordinary standard. It
-- removes the work; it must not beat a player who is actually trying.
Balance.ReelAutoQuality = 0.62

-- Mashing the button before the bite spooks the fish and pushes it back a
-- moment. That is the counterweight that keeps patience worth something now
-- that missing costs nothing — and unlike losing the catch, it is a delay the
-- player can see happen and understand.
Balance.SpookDelay = 0.6

function Balance.ReelFishSpeed(area: number): number
	return Balance.ReelFishSpeedBase + Balance.ReelFishSpeedPerArea * (math.max(area, 1) - 1)
end

function Balance.ReelFishTurn(area: number): number
	return math.max(Balance.ReelFishTurnBase + Balance.ReelFishTurnPerArea * (math.max(area, 1) - 1), 0.35)
end

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

-- DAILY QUESTS: three things to do today, rerolled at the same daily boundary
-- the streak uses.
--
-- This is the strongest honest retention lever a simulator has. Everything else
-- here rewards you for playing; a checklist gives you a REASON to open the app,
-- a defined stopping point, and the small satisfaction of finishing something.
-- All three are things a player was going to do anyway - it names them and pays
-- for them, which is the difference between a task list and a chore.
--
-- Deliberately NOT here: anything that expires mid-session, anything that
-- punishes a miss, anything that can only be finished by paying. A quest a kid
-- cannot finish without Robux is an advert wearing a checklist's clothes.
Balance.QuestCount = 3
-- Reward scales with the water you have unlocked, so a day-30 player's quests
-- are worth doing without a day-1 player's being unfinishable.
Balance.QuestRewardBase = 900
Balance.QuestRewardPerLayer = 2.6 -- reward = base * this ^ (layer - 1)

export type QuestDef = {
	Id: string,
	Kind: string, -- Catch | Chest | Perfect | Rare
	Text: string, -- "%d" is the target
	Target: number,
	Reward: number, -- multiplier on the scaled base
}

Balance.QuestPool = {
	{ Id = "catch_small", Kind = "Catch", Text = "Catch %d fish", Target = 25, Reward = 1 },
	{ Id = "catch_big", Kind = "Catch", Text = "Catch %d fish", Target = 60, Reward = 2 },
	{ Id = "chest_small", Kind = "Chest", Text = "Open %d treasure chests", Target = 3, Reward = 1.1 },
	{ Id = "chest_big", Kind = "Chest", Text = "Open %d treasure chests", Target = 8, Reward = 2.2 },
	{ Id = "perfect_small", Kind = "Perfect", Text = "Land %d PERFECT reels", Target = 5, Reward = 1.2 },
	{ Id = "perfect_big", Kind = "Perfect", Text = "Land %d PERFECT reels", Target = 15, Reward = 2.4 },
	{ Id = "rare_small", Kind = "Rare", Text = "Find %d Rare or better", Target = 3, Reward = 1.4 },
	{ Id = "rare_big", Kind = "Rare", Text = "Find %d Rare or better", Target = 8, Reward = 2.8 },
} :: { QuestDef }

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
