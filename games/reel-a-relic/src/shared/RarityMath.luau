--!strict
-- Single source of truth for every random roll AND for the odds the player sees.
-- The compliance odds panel (May 2026 paid-random-items rules: exact percentages,
-- summing to 100, updating live with luck boosts) renders straight from these
-- functions, so displayed odds can never drift from actual odds.

local Crystals = require(script.Parent.Config.Crystals)
local Balance = require(script.Parent.Config.Balance)

local RarityMath = {}

export type OddsEntry = { Name: string, Tier: string, Chance: number, Color: Color3 }

local function tierIndex(tier: string): number
	for i, name in Crystals.Tiers do
		if name == tier then
			return i
		end
	end
	return 1
end

-- Effective luck = gamepass (2x) * active event * layer creep. Multiplies the
-- weight of Rare+ bases, then everything renormalizes to 100%.
function RarityMath.EffectiveLuck(passLuck: number, eventLuck: number, layer: number): number
	local layerLuck = 1 + Balance.LayerLuckBonus * (math.max(layer, 1) - 1)
	return passLuck * eventLuck * layerLuck
end

-- `kind` picks the pool: "Fish" is what a cast can bring up, "Relic" is what is
-- inside a chest. They are separate draws with separate odds — a chest cannot
-- give you a mackerel and a cast cannot give you a crown — and each pool
-- renormalises to 100 on its own, so the odds panel is honest about whichever
-- one the player is looking at. Defaults to Fish, the far more common question.
function RarityMath.GetBaseOdds(layer: number, luck: number, kind: string?): { OddsEntry }
	local pool = kind or Crystals.FISH
	local weighted = {}
	local total = 0
	for _, def in Crystals.Bases do
		-- A window, not a floor. Species drop OUT of the pool as you sail deeper,
		-- so an area is a different set of fish rather than the last set plus a few.
		if def.Kind == pool and def.MinLayer <= layer and layer <= def.MaxLayer then
			local weight = def.Weight
			if tierIndex(def.Tier) >= Crystals.LuckyTierThreshold then
				weight *= luck
			end
			table.insert(weighted, { Def = def, Weight = weight })
			total += weight
		end
	end
	local odds: { OddsEntry } = {}
	for _, entry in weighted do
		table.insert(odds, {
			Name = entry.Def.Name,
			Tier = entry.Def.Tier,
			Chance = entry.Weight / total * 100,
			Color = entry.Def.Color,
		})
	end
	-- Sorted by actual chance, not by config order. Luck multiplies Rare+ weights
	-- only, so at 2x luck an Emerald genuinely does out-drop a Topaz — that is
	-- luck working. Listing them in config order just made it look like a bug.
	table.sort(odds, function(a, b)
		return a.Chance > b.Chance
	end)
	return odds
end

function RarityMath.RollBase(layer: number, luck: number, rng: Random, kind: string?): string
	local odds = RarityMath.GetBaseOdds(layer, luck, kind)
	local roll = rng:NextNumber() * 100
	local cursor = 0
	for _, entry in odds do
		cursor += entry.Chance
		if roll <= cursor then
			return entry.Name
		end
	end
	return odds[#odds].Name
end

-- Mutations roll independently of base luck; the Aurora event multiplies them.
function RarityMath.GetMutationOdds(mutationMult: number): { OddsEntry }
	local odds: { OddsEntry } = {}
	local usedChance = 0
	for _, def in Crystals.Mutations do
		local chance = math.min(def.Chance * mutationMult, 100 - usedChance)
		usedChance += chance
		table.insert(odds, {
			Name = def.Name,
			Tier = "Mutation",
			Chance = chance,
			Color = def.Color or Color3.new(1, 1, 1),
		})
	end
	table.insert(odds, {
		Name = "Normal",
		Tier = "Mutation",
		Chance = 100 - usedChance,
		Color = Color3.fromRGB(200, 200, 200),
	})
	table.sort(odds, function(a, b)
		return a.Chance > b.Chance
	end)
	return odds
end

function RarityMath.RollMutation(mutationMult: number, rng: Random): string
	local odds = RarityMath.GetMutationOdds(mutationMult)
	local roll = rng:NextNumber() * 100
	local cursor = 0
	for _, entry in odds do
		cursor += entry.Chance
		if roll <= cursor then
			return entry.Name
		end
	end
	return "Normal"
end

function RarityMath.ComputeValue(baseName: string, mutationName: string, size: number, layer: number): number
	local base = Crystals.GetBase(baseName)
	if not base then
		return 0
	end
	local mutationMult = 1
	local mutation = Crystals.GetMutation(mutationName)
	if mutation then
		mutationMult = mutation.ValueMult
	end
	local layerMult = Balance.LayerValueMult ^ (math.max(layer, 1) - 1)
	return math.floor(base.Value * mutationMult * size * layerMult + 0.5)
end

-- Guaranteed Rare-or-better roll from one pool. Drives the first-session pity
-- roll and the premium shop offer — a pull that cannot disappoint.
--
-- The fallback is computed, not hard-coded. Entries drop out of the pool between
-- areas, so naming one here would eventually return something that does not
-- exist where the player is.
function RarityMath.RollRarePlus(layer: number, luck: number, rng: Random, kind: string?): string
	local pool = kind or Crystals.FISH
	for _ = 1, 40 do
		local name = RarityMath.RollBase(layer, luck, rng, pool)
		local def = Crystals.GetBase(name)
		if def and tierIndex(def.Tier) >= Crystals.LuckyTierThreshold then
			return name
		end
	end
	-- 40 misses: fall back to the rarest entry this area actually holds.
	local best: Crystals.CrystalDef? = nil
	for _, def in Crystals.BasesInLayer(layer, pool) do
		if not best or def.Weight < best.Weight then
			best = def
		end
	end
	return best and best.Name or Crystals.Bases[1].Name
end

return RarityMath
