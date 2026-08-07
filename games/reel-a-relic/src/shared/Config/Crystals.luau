--!strict
-- All collectible content lives in these tables. Adding a row here is a full
-- "content update" (new index entries, new drops) with zero other code changes.
-- (Internal module name stays "Crystals" — it's the engine's collectible table.)
--
-- TWO KINDS OF THING, ONE TABLE.
--
--   Kind = "Fish"  — what you pull out of the water. Real species, and each area
--                    stocks the ones that actually live in that water.
--   Kind = "Relic" — what is INSIDE a chest. Sunken treasure: anchors, doubloons,
--                    a captain's spyglass, Poseidon's trident.
--
-- Chests used to contain a better fish, which made them "a fish, but louder" —
-- no reason to feel different from a good cast, and a strange thing to find in a
-- locked box at the bottom of the sea. Relics give the opening its own payoff,
-- its own collection to finish, and they put the game's own title back in it.
--
-- One table rather than two, deliberately: the Index, the value maths, the
-- aquarium, the shop and every test already work on this shape. A parallel
-- system would double all of them to say the same thing.

export type CrystalDef = {
	Name: string,
	Kind: string, -- "Fish" | "Relic"
	Tier: string,
	Weight: number, -- drop weight WITHIN its own kind; each kind sums to ~100
	Value: number,
	Color: Color3,
	MinLayer: number, -- first area this appears in
	MaxLayer: number, -- last area it appears in
	WeightMin: number, -- pounds at the smallest roll (fish only; 0 for relics)
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

--------------------------------------------------------------------------------
-- FISH — real species, stocked by habitat.
--
-- Every one of these is a fish (or sea creature) a child could look up and find,
-- living in water it actually lives in: reef fish on the reef, kelp species in
-- the kelp, deep-sea species in the trench. That is worth more than invented
-- names for this audience, not less — "I caught a Leopard Shark" is a thing to
-- say at school, and half of them are already known from a nature documentary.
--
-- Species still turn over between areas (MinLayer..MaxLayer is a window, not a
-- floor), so sailing somewhere new means different fish, not a longer list.
--------------------------------------------------------------------------------

Crystals.Bases = {
	-- Area 1: Sunny Shallows — sandy coastal water
	{ Name = "Anchovy", Kind = "Fish", Tier = "Common", Weight = 40, Value = 5, Color = Color3.fromRGB(196, 208, 216), MinLayer = 1, MaxLayer = 1, WeightMin = 0.1, WeightMax = 0.6 },
	{ Name = "Mackerel", Kind = "Fish", Tier = "Common", Weight = 22, Value = 9, Color = Color3.fromRGB(96, 140, 172), MinLayer = 1, MaxLayer = 2, WeightMin = 0.8, WeightMax = 4 },
	{ Name = "Sea Bass", Kind = "Fish", Tier = "Uncommon", Weight = 17, Value = 22, Color = Color3.fromRGB(120, 132, 108), MinLayer = 1, MaxLayer = 2, WeightMin = 2, WeightMax = 14 },
	{ Name = "Flounder", Kind = "Fish", Tier = "Uncommon", Weight = 10, Value = 34, Color = Color3.fromRGB(168, 148, 112), MinLayer = 1, MaxLayer = 2, WeightMin = 1, WeightMax = 9 },
	{ Name = "Red Snapper", Kind = "Fish", Tier = "Rare", Weight = 6, Value = 90, Color = Color3.fromRGB(214, 76, 66), MinLayer = 1, MaxLayer = 2, WeightMin = 3, WeightMax = 20 },
	{ Name = "Seahorse", Kind = "Fish", Tier = "Rare", Weight = 3.2, Value = 140, Color = Color3.fromRGB(240, 190, 92), MinLayer = 1, MaxLayer = 1, WeightMin = 0.05, WeightMax = 0.4 },
	{ Name = "Sailfish", Kind = "Fish", Tier = "Epic", Weight = 1.8, Value = 420, Color = Color3.fromRGB(74, 128, 200), MinLayer = 1, MaxLayer = 1, WeightMin = 60, WeightMax = 190 },

	-- Area 2: Kelp Forest — temperate kelp beds
	{ Name = "Kelp Bass", Kind = "Fish", Tier = "Common", Weight = 44, Value = 45, Color = Color3.fromRGB(126, 142, 94), MinLayer = 2, MaxLayer = 3, WeightMin = 1, WeightMax = 8 },
	{ Name = "Garibaldi", Kind = "Fish", Tier = "Uncommon", Weight = 20, Value = 120, Color = Color3.fromRGB(255, 128, 32), MinLayer = 2, MaxLayer = 3, WeightMin = 0.6, WeightMax = 4 },
	{ Name = "Sheephead", Kind = "Fish", Tier = "Uncommon", Weight = 12, Value = 180, Color = Color3.fromRGB(198, 96, 128), MinLayer = 2, MaxLayer = 2, WeightMin = 4, WeightMax = 26 },
	{ Name = "Moray Eel", Kind = "Fish", Tier = "Rare", Weight = 6, Value = 340, Color = Color3.fromRGB(120, 148, 96), MinLayer = 2, MaxLayer = 3, WeightMin = 6, WeightMax = 32 },
	{ Name = "Leopard Shark", Kind = "Fish", Tier = "Rare", Weight = 4, Value = 520, Color = Color3.fromRGB(176, 172, 156), MinLayer = 2, MaxLayer = 3, WeightMin = 20, WeightMax = 70 },
	{ Name = "Giant Sea Bass", Kind = "Fish", Tier = "Legendary", Weight = 0.6, Value = 3400, Color = Color3.fromRGB(92, 102, 116), MinLayer = 2, MaxLayer = 2, WeightMin = 120, WeightMax = 560 },

	-- Area 3: Twilight Reef — coral reef
	{ Name = "Clownfish", Kind = "Fish", Tier = "Common", Weight = 38, Value = 170, Color = Color3.fromRGB(255, 132, 40), MinLayer = 3, MaxLayer = 4, WeightMin = 0.05, WeightMax = 0.5 },
	{ Name = "Parrotfish", Kind = "Fish", Tier = "Common", Weight = 22, Value = 210, Color = Color3.fromRGB(72, 200, 176), MinLayer = 3, MaxLayer = 4, WeightMin = 2, WeightMax = 12 },
	{ Name = "Blue Tang", Kind = "Fish", Tier = "Uncommon", Weight = 18, Value = 320, Color = Color3.fromRGB(56, 118, 224), MinLayer = 3, MaxLayer = 3, WeightMin = 0.3, WeightMax = 2 },
	{ Name = "Lionfish", Kind = "Fish", Tier = "Uncommon", Weight = 11, Value = 420, Color = Color3.fromRGB(232, 96, 72), MinLayer = 3, MaxLayer = 4, WeightMin = 0.6, WeightMax = 3 },
	{ Name = "Reef Shark", Kind = "Fish", Tier = "Rare", Weight = 6, Value = 900, Color = Color3.fromRGB(140, 156, 172), MinLayer = 3, MaxLayer = 4, WeightMin = 40, WeightMax = 180 },
	{ Name = "Manta Ray", Kind = "Fish", Tier = "Epic", Weight = 2.4, Value = 2800, Color = Color3.fromRGB(60, 72, 96), MinLayer = 3, MaxLayer = 4, WeightMin = 200, WeightMax = 1400 },
	{ Name = "Hammerhead", Kind = "Fish", Tier = "Legendary", Weight = 0.7, Value = 9000, Color = Color3.fromRGB(150, 160, 150), MinLayer = 3, MaxLayer = 3, WeightMin = 150, WeightMax = 700 },

	-- Area 4: Midnight Trench — the deep
	{ Name = "Lanternfish", Kind = "Fish", Tier = "Common", Weight = 40, Value = 750, Color = Color3.fromRGB(120, 200, 255), MinLayer = 4, MaxLayer = 5, WeightMin = 0.02, WeightMax = 0.3 },
	{ Name = "Hatchetfish", Kind = "Fish", Tier = "Common", Weight = 22, Value = 950, Color = Color3.fromRGB(196, 208, 232), MinLayer = 4, MaxLayer = 5, WeightMin = 0.05, WeightMax = 0.4 },
	{ Name = "Viperfish", Kind = "Fish", Tier = "Uncommon", Weight = 16, Value = 1600, Color = Color3.fromRGB(88, 108, 140), MinLayer = 4, MaxLayer = 5, WeightMin = 0.5, WeightMax = 3 },
	{ Name = "Gulper Eel", Kind = "Fish", Tier = "Uncommon", Weight = 10, Value = 2100, Color = Color3.fromRGB(72, 60, 92), MinLayer = 4, MaxLayer = 5, WeightMin = 2, WeightMax = 14 },
	{ Name = "Anglerfish", Kind = "Fish", Tier = "Rare", Weight = 6, Value = 4200, Color = Color3.fromRGB(255, 236, 128), MinLayer = 4, MaxLayer = 5, WeightMin = 1, WeightMax = 8 },
	{ Name = "Barreleye", Kind = "Fish", Tier = "Epic", Weight = 2.2, Value = 12000, Color = Color3.fromRGB(140, 255, 190), MinLayer = 4, MaxLayer = 4, WeightMin = 0.3, WeightMax = 2 },
	{ Name = "Oarfish", Kind = "Fish", Tier = "Legendary", Weight = 0.8, Value = 34000, Color = Color3.fromRGB(206, 210, 226), MinLayer = 4, MaxLayer = 5, WeightMin = 100, WeightMax = 600 },

	-- Area 5: The Abyss — the hadal zone
	{ Name = "Giant Isopod", Kind = "Fish", Tier = "Common", Weight = 34, Value = 5200, Color = Color3.fromRGB(178, 162, 132), MinLayer = 5, MaxLayer = 5, WeightMin = 1, WeightMax = 4 },
	{ Name = "Dumbo Octopus", Kind = "Fish", Tier = "Uncommon", Weight = 20, Value = 9000, Color = Color3.fromRGB(220, 140, 160), MinLayer = 5, MaxLayer = 5, WeightMin = 1, WeightMax = 12 },
	{ Name = "Frilled Shark", Kind = "Fish", Tier = "Rare", Weight = 7, Value = 22000, Color = Color3.fromRGB(96, 88, 78), MinLayer = 5, MaxLayer = 5, WeightMin = 20, WeightMax = 90 },
	{ Name = "Goblin Shark", Kind = "Fish", Tier = "Epic", Weight = 2.6, Value = 60000, Color = Color3.fromRGB(232, 168, 178), MinLayer = 5, MaxLayer = 5, WeightMin = 100, WeightMax = 460 },
	{ Name = "Colossal Squid", Kind = "Fish", Tier = "Legendary", Weight = 0.9, Value = 180000, Color = Color3.fromRGB(190, 90, 255), MinLayer = 5, MaxLayer = 5, WeightMin = 300, WeightMax = 1100 },
	{ Name = "Megalodon", Kind = "Fish", Tier = "Mythic", Weight = 0.1, Value = 900000, Color = Color3.fromRGB(255, 70, 120), MinLayer = 5, MaxLayer = 5, WeightMin = 20000, WeightMax = 100000 },

	--------------------------------------------------------------------------
	-- RELICS — only ever found inside a chest.
	--
	-- Treasure, not habitat: a doubloon is a doubloon wherever you dredge it up,
	-- so these gate on MinLayer alone and deeper water simply offers better
	-- ones. They are worth several times a fish of the same tier, because you
	-- had to land the chest AND carry it home to find out what it was.
	--------------------------------------------------------------------------
	{ Name = "Rusty Anchor", Kind = "Relic", Tier = "Common", Weight = 34, Value = 60, Color = Color3.fromRGB(146, 118, 96), MinLayer = 1, MaxLayer = 25, WeightMin = 0, WeightMax = 0 },
	{ Name = "Message in a Bottle", Kind = "Relic", Tier = "Common", Weight = 22, Value = 95, Color = Color3.fromRGB(168, 216, 200), MinLayer = 1, MaxLayer = 25, WeightMin = 0, WeightMax = 0 },
	{ Name = "Silver Doubloon", Kind = "Relic", Tier = "Uncommon", Weight = 17, Value = 260, Color = Color3.fromRGB(214, 218, 226), MinLayer = 1, MaxLayer = 25, WeightMin = 0, WeightMax = 0 },
	{ Name = "Ship's Compass", Kind = "Relic", Tier = "Uncommon", Weight = 11, Value = 420, Color = Color3.fromRGB(206, 168, 88), MinLayer = 1, MaxLayer = 25, WeightMin = 0, WeightMax = 0 },
	-- Available from area 1 on purpose: the first-session pity roll guarantees a
	-- Rare+ on the third chest ever opened, and with nothing Rare in the starting
	-- water that promise had nothing to pay out with.
	{ Name = "Diver's Helmet", Kind = "Relic", Tier = "Rare", Weight = 7, Value = 1100, Color = Color3.fromRGB(180, 150, 70), MinLayer = 1, MaxLayer = 25, WeightMin = 0, WeightMax = 0 },
	{ Name = "Pirate Cutlass", Kind = "Relic", Tier = "Rare", Weight = 4.4, Value = 1900, Color = Color3.fromRGB(198, 200, 210), MinLayer = 2, MaxLayer = 25, WeightMin = 0, WeightMax = 0 },
	{ Name = "Captain's Spyglass", Kind = "Relic", Tier = "Epic", Weight = 2.4, Value = 6500, Color = Color3.fromRGB(228, 180, 96), MinLayer = 3, MaxLayer = 25, WeightMin = 0, WeightMax = 0 },
	{ Name = "Golden Astrolabe", Kind = "Relic", Tier = "Epic", Weight = 1.2, Value = 14000, Color = Color3.fromRGB(255, 206, 96), MinLayer = 3, MaxLayer = 25, WeightMin = 0, WeightMax = 0 },
	{ Name = "Mermaid's Mirror", Kind = "Relic", Tier = "Legendary", Weight = 0.6, Value = 60000, Color = Color3.fromRGB(150, 255, 245), MinLayer = 4, MaxLayer = 25, WeightMin = 0, WeightMax = 0 },
	{ Name = "Sunken Crown", Kind = "Relic", Tier = "Legendary", Weight = 0.3, Value = 120000, Color = Color3.fromRGB(255, 200, 60), MinLayer = 4, MaxLayer = 25, WeightMin = 0, WeightMax = 0 },
	{ Name = "Poseidon's Trident", Kind = "Relic", Tier = "Mythic", Weight = 0.1, Value = 1500000, Color = Color3.fromRGB(120, 255, 255), MinLayer = 5, MaxLayer = 25, WeightMin = 0, WeightMax = 0 },
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

Crystals.FISH = "Fish"
Crystals.RELIC = "Relic"

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

function Crystals.IsRelic(name: string): boolean
	local def = Crystals.GetBase(name)
	return def ~= nil and def.Kind == Crystals.RELIC
end

function Crystals.IndexKey(baseName: string, mutationName: string): string
	return baseName .. "|" .. mutationName
end

function Crystals.TotalIndexEntries(): number
	return #Crystals.Bases * #Crystals.MutationNames
end

-- Everything of one kind catchable in one area, for the odds panel and the
-- "8 / 12 in Kelp Forest" counter.
function Crystals.BasesInLayer(layer: number, kind: string?): { CrystalDef }
	local list: { CrystalDef } = {}
	for _, def in Crystals.Bases do
		local wantedKind = kind == nil or def.Kind == kind
		if wantedKind and def.MinLayer <= layer and layer <= def.MaxLayer then
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
--
-- Relics have no weight. You do not brag about a heavy doubloon.
function Crystals.WeightOf(baseName: string, size: number): number
	local def = Crystals.GetBase(baseName)
	if not def or def.WeightMax <= 0 then
		return 0
	end
	local span = def.WeightMax - def.WeightMin
	local t = (size - 0.9) / 0.3
	local over = math.max(t - 1, 0)
	return def.WeightMin + span * (math.clamp(t, 0, 1) + over * 0.25)
end

return Crystals
