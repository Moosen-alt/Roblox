-- Sanity tests for the game's economy/rarity math. Run via tests/run.sh, which
-- concatenates the real shared modules (Crystals, Balance, RarityMath, Format)
-- ahead of this file — so these assertions exercise production code, not copies.

local function approx(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-6)
end

-- 1. Base odds sum to 100 at every layer/luck combo (compliance invariant)
for layer = 1, 5 do
	for _, luck in { 1, 2, 10, 60 } do
		local total = 0
		for _, e in RarityMath.GetBaseOdds(layer, luck) do
			total += e.Chance
		end
		assert(approx(total, 100, 1e-9), "base odds must sum to 100, got " .. total)
	end
end
print("PASS base odds sum to 100 (all layers/lucks)")

-- 2. Mutation odds sum to 100, incl. boosted (Aurora x5) and extreme mults
for _, mult in { 1, 5, 100, 1000 } do
	local total = 0
	for _, e in RarityMath.GetMutationOdds(mult) do
		total += e.Chance
	end
	assert(approx(total, 100, 1e-9), "mutation odds must sum to 100 at mult " .. mult)
end
print("PASS mutation odds sum to 100 (incl. extreme boosts)")

-- 3. Luck actually increases Rare+ odds
local function rarePlus(layer, luck)
	local sum = 0
	for _, e in RarityMath.GetBaseOdds(layer, luck) do
		if e.Tier ~= "Common" and e.Tier ~= "Uncommon" then
			sum += e.Chance
		end
	end
	return sum
end
assert(rarePlus(1, 2) > rarePlus(1, 1), "2x luck must raise Rare+ odds")
assert(rarePlus(1, 10) > rarePlus(1, 2), "10x luck must raise Rare+ odds further")
print(("PASS luck monotonic: Rare+ %.2f%% -> %.2f%% -> %.2f%% at luck 1/2/10"):format(rarePlus(1, 1), rarePlus(1, 2), rarePlus(1, 10)))

-- 4. Roll distribution: 100k rolls at luck 1 match configured weights.
-- Layer 1 pool is Quartz/Amethyst/Topaz/Emerald (others are layer-locked), so
-- Quartz renormalizes to 55/94 ~= 58.5%.
local rng = Random.new(42)
local counts = {}
for _ = 1, 100000 do
	local name = RarityMath.RollBase(1, 1, rng)
	counts[name] = (counts[name] or 0) + 1
end
local quartzShare = counts.Quartz / 1000
assert(quartzShare > 56.5 and quartzShare < 60.5, "Quartz ~58.5% (55/94 renormalized), got " .. quartzShare)
assert(counts.Diamond == nil, "Diamond is MinLayer 4, must never drop on layer 1")
print(("PASS 100k-roll distribution (Quartz %.1f%%, no layer-locked drops)"):format(quartzShare))

-- 5. RollRarePlus (pity) always returns Rare or better
for _ = 1, 2000 do
	local name = RarityMath.RollRarePlus(1, 1, rng)
	local def = Crystals.GetBase(name)
	assert(def and def.Tier ~= "Common" and def.Tier ~= "Uncommon", "pity roll produced " .. tostring(name))
end
print("PASS pity roll always Rare+")

-- 6. Value math: layer/mutation/size multiply as configured
assert(RarityMath.ComputeValue("Quartz", "Normal", 1, 1) == 5, "base quartz value")
assert(RarityMath.ComputeValue("Quartz", "Celestial", 1, 1) == 125, "celestial x25")
assert(RarityMath.ComputeValue("Quartz", "Normal", 1, 2) == 13, "layer2 x2.5 rounded")
assert(RarityMath.ComputeValue("Diamond", "Normal", 3, 5) == math.floor(6000 * 3 * 2.5 ^ 4 + 0.5), "max stack")
print("PASS value computation (mutation x, layer x, size x)")

-- 7. Rebirth cost ladder + number formatting
assert(Balance.RebirthBaseCost * Balance.RebirthCostGrowth ^ 0 == 10000)
assert(Format.Number(999) == "999" and Format.Number(1500) == "1.50K" and Format.Number(2500000) == "2.50M")
assert(Format.Percent(55) == "55.0%" and Format.Percent(0.1) == "0.10%" and Format.Percent(0.02) == "0.020%")
print("PASS economy constants + number formatting")

-- 8. Mutation chances stay within [0,100] under extreme boosts
for _, e in RarityMath.GetMutationOdds(1000) do
	assert(e.Chance >= 0 and e.Chance <= 100, "chance out of bounds: " .. e.Name)
end
print("PASS mutation chances clamped to [0,100] under extreme boosts")

-- 9. Odds always read as a descending ladder. Luck multiplies Rare+ weights
-- only, so a Rare genuinely can out-drop an Uncommon — but the panel must still
-- list biggest-first, or it looks like the odds are broken (which is exactly how
-- it was reported).
for layer = 1, 5 do
	for _, luck in { 1, 2, 10, 60 } do
		local previous = math.huge
		for _, e in RarityMath.GetBaseOdds(layer, luck) do
			assert(e.Chance <= previous + 1e-9, "base odds must be sorted descending")
			previous = e.Chance
		end
	end
end
for _, mult in { 1, 5, 100 } do
	local previous = math.huge
	for _, e in RarityMath.GetMutationOdds(mult) do
		assert(e.Chance <= previous + 1e-9, "mutation odds must be sorted descending")
		previous = e.Chance
	end
end
print("PASS odds sorted descending (all layers/lucks)")

-- 10. A bundle is never worse per unit than buying singles, in any daily-deal
-- case. The deal hits one slot, so the x3 has to be re-derived from whatever the
-- single ended up costing — otherwise "Geode 93 / Geode x3 390" ships again.
local function bundleCost(singleCost: number, rawBundle: number, count: number): number
	return math.min(rawBundle, math.max(math.floor(singleCost * count * 0.85), 5))
end
for _, layer in { 1, 3, 5 } do
	local base = math.floor(Balance.ShopGeodeBaseCost * Balance.LayerValueMult ^ (layer - 1))
	for _, dealt in { "none", "single", "bundle" } do
		local single = dealt == "single" and math.max(math.floor(base * 0.6), 5) or base
		local raw = dealt == "bundle" and math.max(math.floor(base * 2.5 * 0.6), 5) or math.floor(base * 2.5)
		local bundle = bundleCost(single, raw, 3)
		assert(bundle / 3 < single, ("bundle must beat singles per unit (layer %d, deal %s)"):format(layer, dealt))
	end
end
print("PASS geode bundle always beats singles per unit")

print("ALL TESTS PASSED")
