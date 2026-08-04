--!strict
-- All collectible content lives in these two tables. Adding a row here is a full
-- "content update" (new index entries, new drops) with zero other code changes.

export type CrystalDef = {
	Name: string,
	Tier: string,
	Weight: number, -- base drop weight; all weights sum to 100 so they read as percentages
	Value: number,
	Color: Color3,
	MinLayer: number, -- first cave layer this base can drop on
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

Crystals.Bases = {
	{ Name = "Quartz", Tier = "Common", Weight = 55, Value = 5, Color = Color3.fromRGB(235, 235, 235), MinLayer = 1 },
	{ Name = "Amethyst", Tier = "Uncommon", Weight = 22, Value = 15, Color = Color3.fromRGB(170, 110, 240), MinLayer = 1 },
	{ Name = "Topaz", Tier = "Uncommon", Weight = 10, Value = 30, Color = Color3.fromRGB(255, 200, 60), MinLayer = 1 },
	{ Name = "Emerald", Tier = "Rare", Weight = 7, Value = 75, Color = Color3.fromRGB(60, 220, 130), MinLayer = 1 },
	{ Name = "Sapphire", Tier = "Rare", Weight = 3.5, Value = 150, Color = Color3.fromRGB(60, 120, 255), MinLayer = 2 },
	{ Name = "Ruby", Tier = "Epic", Weight = 1.8, Value = 400, Color = Color3.fromRGB(255, 60, 80), MinLayer = 2 },
	{ Name = "Opal", Tier = "Legendary", Weight = 0.6, Value = 1500, Color = Color3.fromRGB(150, 255, 245), MinLayer = 3 },
	{ Name = "Diamond", Tier = "Mythic", Weight = 0.1, Value = 6000, Color = Color3.fromRGB(200, 245, 255), MinLayer = 4 },
} :: { CrystalDef }

-- "Normal" is implicit: whatever chance is left after these rolls fail.
Crystals.Mutations = {
	{ Name = "Shiny", Chance = 8, ValueMult = 2, Color = Color3.fromRGB(255, 255, 180) },
	{ Name = "Frozen", Chance = 4, ValueMult = 3, Color = Color3.fromRGB(160, 220, 255) },
	{ Name = "Molten", Chance = 2, ValueMult = 5, Color = Color3.fromRGB(255, 120, 40) },
	{ Name = "Radioactive", Chance = 0.8, ValueMult = 10, Color = Color3.fromRGB(120, 255, 60) },
	{ Name = "Celestial", Chance = 0.2, ValueMult = 25, Color = Color3.fromRGB(255, 140, 255) },
} :: { MutationDef }

Crystals.MutationNames = { "Normal", "Shiny", "Frozen", "Molten", "Radioactive", "Celestial" }

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

return Crystals
