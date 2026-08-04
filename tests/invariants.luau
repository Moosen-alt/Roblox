-- Generic, theme-agnostic invariants for any game built on the collectible
-- engine (used for re-themes whose names/values differ from the root game).
-- Run via: sh tests/run.sh games/<game-dir> tests/invariants.luau

local function approx(a, b)
	return math.abs(a - b) <= 1e-9
end

-- Odds always sum to exactly 100 (the compliance invariant)
for layer = 1, 5 do
	for _, luck in { 1, 2, 10, 60 } do
		local total = 0
		for _, e in RarityMath.GetBaseOdds(layer, luck) do
			total += e.Chance
			assert(e.Chance >= 0, "negative chance for " .. e.Name)
		end
		assert(approx(total, 100), "base odds must sum to 100, got " .. total)
	end
end
print("PASS base odds sum to 100 (all layers/lucks)")

for _, mult in { 1, 5, 1000 } do
	local total = 0
	for _, e in RarityMath.GetMutationOdds(mult) do
		total += e.Chance
		assert(e.Chance >= 0 and e.Chance <= 100, "chance out of bounds: " .. e.Name)
	end
	assert(approx(total, 100), "mutation odds must sum to 100 at mult " .. mult)
end
print("PASS mutation odds sum to 100 (incl. extreme boosts)")

-- Config sanity: every base is positive-valued, weighted, and layer-valid
for _, base in Crystals.Bases do
	assert(base.Value > 0 and base.Weight > 0 and base.MinLayer >= 1, "bad base def: " .. base.Name)
	assert(RarityMath.ComputeValue(base.Name, "Normal", 1, 1) >= 0)
end
print("PASS base definitions sane")

-- Pity roll always lands Rare or better
local rng = Random.new(7)
for _ = 1, 500 do
	local name = RarityMath.RollRarePlus(1, 1, rng)
	local def = Crystals.GetBase(name)
	assert(def and def.Tier ~= "Common" and def.Tier ~= "Uncommon", "pity roll produced " .. tostring(name))
end
print("PASS pity roll always Rare+")

print("ALL INVARIANTS PASSED")
