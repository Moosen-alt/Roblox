--!strict
-- All collectible content lives in these two tables. Adding a row here is a full
-- "content update" (new index entries, new drops) with zero other code changes.
-- (Internal module name stays "Crystals" — it's the engine's collectible table;
-- everything player-facing calls them fish.)
--
-- ONE table feeds both ways of getting a fish: a fish on the line rolls it
-- straight, a crate rolls it guaranteed-Rare-or-better. That is deliberate. A
-- second parallel loot table would double the Index, the odds panel, the value
-- maths and every test for no gameplay a player could name, and it would make
-- the crate a different game instead of a better pull.

export type CrystalDef = {
	Name: string,
	Tier: string,
	Weight: number, -- base drop weight; all weights sum to 100 so they read as percentages
	Value: number,
	Color: Color3,
	MinLayer: number, -- first area this fish swims in
	MaxLayer: number, -- last area it swims in; past this it stops biting entirely
	WeightMin: number, -- pounds, at size 1.0
	WeightMax: number,
}

export type MutationDef = {
	Name: string,
	Chance: number, -- base chance out of 100; remainder rolls Normal
	ValueMult: number,
	Color: Color3?,
}

local Crystals = {}

Crystals.Tiers = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

Crystals.TierColors = {
	Common = Color3.fromRGB(190, 190, 190),
	Uncommon = Color3.fromRGB(120, 220, 120),
	Rare = Color3.fromRGB(80, 150, 255),
	Epic = Color3.fromRGB(190, 90, 255),
	Legendary = Color3.fromRGB(255, 170, 40),
	Mythic = Color3.fromRGB(255, 70, 120),
}

-- Luck multipliers (gamepass / events) scale the weights of these tiers and above.
Crystals.LuckyTierThreshold = 3 -- index into Tiers: Rare+

-- Species turn over between areas rather than piling up. `MinLayer..MaxLayer` is
-- a window, not a floor: sailing to the Kelp Forest means the Sunny Shallows
-- minnows STOP biting, which is what makes a new area feel like new content
-- instead of a longer list. Each boundary keeps one familiar species across it
-- so an area still has an anchor, and every area holds at least one Rare+ so a
-- crate always has something to give you.
Crystals.Bases = {
	-- Area 1: Sunny Shallows
	{ Name = "Minnow", Tier = "Common", Weight = 55, Value = 5, Color = Color3.fromRGB(190, 200, 175), MinLayer = 1, MaxLayer = 1, WeightMin = 0.2, WeightMax = 1.4 },
	{ Name = "Sunfish", Tier = "Uncommon", Weight = 22, Value = 15, Color = Color3.fromRGB(255, 210, 90), MinLayer = 1, MaxLayer = 2, WeightMin = 0.8, WeightMax = 4 },
	{ Name = "Spotted Bass", Tier = "Uncommon", Weight = 10, Value = 30, Color = Color3.fromRGB(120, 160, 90), MinLayer = 1, MaxLayer = 2, WeightMin = 2, WeightMax = 11 },
	{ Name = "Rainbow Trout", Tier = "Rare", Weight = 7, Value = 75, Color = Color3.fromRGB(255, 140, 170), MinLayer = 1, MaxLayer = 2, WeightMin = 3, WeightMax = 16 },
	-- Area 1's second Rare, and the reason it is here: every chest is a
	-- guaranteed Rare+, so a starting area with only two Rare+ species made four
	-- chests in five open on the same trout. A third splits the pull three ways
	-- (54 / 32 / 14) without touching the odds anyone sees on the panel.
	{ Name = "Glass Catfish", Tier = "Rare", Weight = 4.2, Value = 120, Color = Color3.fromRGB(200, 225, 235), MinLayer = 1, MaxLayer = 1, WeightMin = 1.5, WeightMax = 9 },
	{ Name = "Golden Koi", Tier = "Epic", Weight = 1.8, Value = 400, Color = Color3.fromRGB(255, 190, 60), MinLayer = 1, MaxLayer = 1, WeightMin = 4, WeightMax = 22 },

	-- Area 2: Kelp Forest
	{ Name = "Kelp Perch", Tier = "Common", Weight = 55, Value = 40, Color = Color3.fromRGB(150, 190, 120), MinLayer = 2, MaxLayer = 3, WeightMin = 1, WeightMax = 6 },
	{ Name = "Ribbon Eel", Tier = "Rare", Weight = 6, Value = 190, Color = Color3.fromRGB(90, 200, 130), MinLayer = 2, MaxLayer = 3, WeightMin = 5, WeightMax = 26 },
	{ Name = "Sea Otter's Prize", Tier = "Epic", Weight = 1.6, Value = 900, Color = Color3.fromRGB(180, 130, 90), MinLayer = 2, MaxLayer = 3, WeightMin = 8, WeightMax = 38 },
	{ Name = "Kelp Dragon", Tier = "Legendary", Weight = 0.5, Value = 3200, Color = Color3.fromRGB(60, 220, 160), MinLayer = 2, MaxLayer = 2, WeightMin = 20, WeightMax = 95 },

	-- Area 3: Twilight Reef
	{ Name = "Parrotfish", Tier = "Common", Weight = 50, Value = 160, Color = Color3.fromRGB(90, 210, 220), MinLayer = 3, MaxLayer = 4, WeightMin = 2, WeightMax = 12 },
	{ Name = "Lionfish", Tier = "Uncommon", Weight = 20, Value = 320, Color = Color3.fromRGB(255, 120, 80), MinLayer = 3, MaxLayer = 4, WeightMin = 1.5, WeightMax = 9 },
	{ Name = "Reef Shark", Tier = "Rare", Weight = 6, Value = 800, Color = Color3.fromRGB(140, 160, 180), MinLayer = 3, MaxLayer = 4, WeightMin = 40, WeightMax = 210 },
	{ Name = "Moon Jelly", Tier = "Epic", Weight = 1.5, Value = 2600, Color = Color3.fromRGB(200, 220, 255), MinLayer = 3, MaxLayer = 3, WeightMin = 0.5, WeightMax = 5 },

	-- Area 4: Midnight Trench
	{ Name = "Lanternfish", Tier = "Common", Weight = 48, Value = 700, Color = Color3.fromRGB(120, 200, 255), MinLayer = 4, MaxLayer = 5, WeightMin = 0.3, WeightMax = 2.2 },
	{ Name = "Gulper Eel", Tier = "Uncommon", Weight = 18, Value = 1400, Color = Color3.fromRGB(110, 90, 150), MinLayer = 4, MaxLayer = 5, WeightMin = 6, WeightMax = 30 },
	{ Name = "Anglerfish", Tier = "Rare", Weight = 5, Value = 3400, Color = Color3.fromRGB(255, 240, 120), MinLayer = 4, MaxLayer = 5, WeightMin = 9, WeightMax = 48 },
	{ Name = "Ghost Squid", Tier = "Legendary", Weight = 0.6, Value = 11000, Color = Color3.fromRGB(150, 255, 245), MinLayer = 4, MaxLayer = 4, WeightMin = 30, WeightMax = 170 },

	-- Area 5: The Abyss
	{ Name = "Abyss Ray", Tier = "Uncommon", Weight = 20, Value = 5000, Color = Color3.fromRGB(80, 70, 120), MinLayer = 5, MaxLayer = 5, WeightMin = 55, WeightMax = 300 },
	{ Name = "Colossal Squid", Tier = "Epic", Weight = 2, Value = 18000, Color = Color3.fromRGB(190, 90, 255), MinLayer = 5, MaxLayer = 5, WeightMin = 120, WeightMax = 640 },
	{ Name = "Leviathan", Tier = "Mythic", Weight = 0.1, Value = 90000, Color = Color3.fromRGB(255, 70, 120), MinLayer = 5, MaxLayer = 5, WeightMin = 400, WeightMax = 2200 },
} :: { CrystalDef }

-- "Normal" is implicit: whatever chance is left after these rolls fail.
Crystals.Mutations = {
	{ Name = "Gilded", Chance = 8, ValueMult = 2, Color = Color3.fromRGB(255, 220, 120) },
	{ Name = "Frosted", Chance = 4, ValueMult = 3, Color = Color3.fromRGB(160, 220, 255) },
	{ Name = "Storm-Touched", Chance = 2, ValueMult = 5, Color = Color3.fromRGB(255, 240, 120) },
	{ Name = "Abyssal", Chance = 0.8, ValueMult = 10, Color = Color3.fromRGB(90, 60, 160) },
	{ Name = "Moonlit", Chance = 0.2, ValueMult = 25, Color = Color3.fromRGB(200, 220, 255) },
} :: { MutationDef }

Crystals.MutationNames = { "Normal", "Gilded", "Frosted", "Storm-Touched", "Abyssal", "Moonlit" }

function Crystals.GetBase(name: string): CrystalDef?
	for _, def in Crystals.Bases do
		if def.Name == name then
			return def
		end
	end
	return nil
end

function Crystals.GetMutation(name: string): MutationDef?
	for _, def in Crystals.Mutations do
		if def.Name == name then
			return def
		end
	end
	return nil
end

function Crystals.IndexKey(baseName: string, mutationName: string): string
	return baseName .. "|" .. mutationName
end

function Crystals.TotalIndexEntries(): number
	return #Crystals.Bases * #Crystals.MutationNames
end

-- Species catchable in one area, for the "8 / 12 in Kelp Forest" counter. An
-- area you can finish is worth far more than a single number that only ever
-- creeps: it gives every area its own ending.
function Crystals.BasesInLayer(layer: number): { CrystalDef }
	local list: { CrystalDef } = {}
	for _, def in Crystals.Bases do
		if def.MinLayer <= layer and layer <= def.MaxLayer then
			table.insert(list, def)
		end
	end
	return list
end

-- Pounds for a caught fish. `size` is the same 0.9-1.2 roll every catch makes,
-- which the aquarium then grows past 1.2 over real time.
--
-- A wild catch fills the species' stated range exactly — 0.9 lands on WeightMin
-- and 1.2 on WeightMax — so the numbers on the Index cell are the numbers you
-- can actually see. A fish left growing in a tank keeps going past its wild max,
-- but at a quarter rate: a displayed fish should be a trophy, not a way to park
-- one specimen for an hour and retire the record forever.
function Crystals.WeightOf(baseName: string, size: number): number
	local def = Crystals.GetBase(baseName)
	if not def then
		return 0
	end
	local span = def.WeightMax - def.WeightMin
	local t = (size - 0.9) / 0.3
	local over = math.max(t - 1, 0)
	return def.WeightMin + span * (math.clamp(t, 0, 1) + over * 0.25)
end

return Crystals
