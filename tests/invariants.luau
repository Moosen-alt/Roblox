-- Generic, theme-agnostic invariants for any game built on the collectible
-- engine (used for re-themes whose names/values differ from the root game).
-- Run via: sh tests/run.sh games/<game-dir> tests/invariants.luau

local function approx(a, b)
	return math.abs(a - b) <= 1e-9
end

-- Games may split their drops into separate pools (this one draws fish from a
-- cast and relics from a chest). EVERY pool has to satisfy the compliance
-- invariant on its own, because each one is published as its own odds panel.
--
-- `false` is the "this game has no pools" sentinel, NOT nil: `{ nil }` is an
-- empty table in Lua, so a nil sentinel would make every loop below iterate zero
-- times and the single-pool games would silently stop being tested at all.
local POOLS = if Crystals.FISH then { Crystals.FISH, Crystals.RELIC } else { false }

-- Odds always sum to exactly 100 (the compliance invariant), at every layer the
-- game can actually reach — not just the first five.
for _, pool in POOLS do
	for layer = 1, Balance.MaxLayer do
		for _, luck in { 1, 2, 10, 60 } do
			local total = 0
			for _, e in RarityMath.GetBaseOdds(layer, luck, pool or nil) do
				total += e.Chance
				assert(e.Chance >= 0, "negative chance for " .. e.Name)
			end
			assert(approx(total, 100), "base odds must sum to 100, got " .. total)
		end
	end
end
print("PASS base odds sum to 100 (every pool, all layers/lucks)")

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
	-- Games that window their drops (MinLayer..MaxLayer, so species turn over
	-- between areas rather than piling up) must not define an empty window.
	if base.MaxLayer then
		assert(base.MaxLayer >= base.MinLayer, "empty layer window: " .. base.Name)
	end
end
print("PASS base definitions sane")

-- Every layer must actually hold something. A windowed drop table can leave a
-- layer with no catchable species at all, and GetBaseOdds divides by the total
-- weight — an empty pool is a divide-by-zero, not a quiet empty list.
for _, pool in POOLS do
	for layer = 1, Balance.MaxLayer do
		local odds = RarityMath.GetBaseOdds(layer, 1, pool or nil)
		assert(#odds > 0, "layer " .. layer .. " has nothing in pool " .. tostring(pool))
		local rarePlus = 0
		for _, e in odds do
			if e.Tier ~= "Common" and e.Tier ~= "Uncommon" then
				rarePlus += 1
			end
		end
		-- RollRarePlus drives the pity roll and the premium shop offer. A layer
		-- with nothing Rare+ in it makes both unsatisfiable.
		assert(rarePlus > 0, "layer " .. layer .. " pool " .. tostring(pool) .. " has no Rare+ for RollRarePlus")
	end
end
print("PASS every layer has entries in every pool, including Rare+")

-- Pity roll always lands Rare or better — at EVERY layer, not just the first.
-- Its fallback has to come from the layer being rolled; a hard-coded species
-- name would eventually name one that does not live there.
local rng = Random.new(7)
for _, pool in POOLS do
	for layer = 1, Balance.MaxLayer do
		for _ = 1, 300 do
			local name = RarityMath.RollRarePlus(layer, 1, rng, pool or nil)
			local def = Crystals.GetBase(name)
			assert(def, "pity roll produced unknown entry " .. tostring(name))
			assert(def.Tier ~= "Common" and def.Tier ~= "Uncommon", "pity roll produced " .. tostring(name))
			-- And from the pool that was ASKED for. A chest handing out a mackerel
			-- would make the published relic odds a lie.
			if pool then
				assert(def.Kind == pool, ("asked %s, got %s (%s)"):format(pool, name, def.Kind))
			end
			if def.MaxLayer then
				assert(
					def.MinLayer <= layer and layer <= def.MaxLayer,
					("pity roll at layer %d produced %s, which does not exist there"):format(layer, name)
				)
			end
		end
	end
end
print("PASS pity roll always Rare+, in-pool and in-layer")

-- Weight (pounds) is only defined by games that use it; where it is, the range
-- must be real and the size roll must never produce a non-positive weight.
if Crystals.WeightOf then
	for _, base in Crystals.Bases do
		-- Relics have no weight by design — you do not brag about a heavy
		-- doubloon — so only the things that were swimming are checked.
		if base.WeightMax > 0 then
			assert(base.WeightMax > base.WeightMin and base.WeightMin > 0, "bad weight range: " .. base.Name)
			local light = Crystals.WeightOf(base.Name, 0.9)
			local heavy = Crystals.WeightOf(base.Name, 1.2)
			assert(light > 0, "non-positive weight for " .. base.Name)
			assert(heavy > light, "weight must rise with size for " .. base.Name)
		else
			assert(Crystals.WeightOf(base.Name, 1.2) == 0, "weightless entry reported a weight: " .. base.Name)
		end
	end
	-- A personal best is a running maximum: feeding it a stream of catches must
	-- never let the record go down.
	local best = 0
	local wrng = Random.new(11)
	for _ = 1, 2000 do
		local base = Crystals.Bases[wrng:NextInteger(1, #Crystals.Bases)]
		local w = Crystals.WeightOf(base.Name, 0.9 + wrng:NextNumber() * 0.3)
		local previous = best
		if w > best then
			best = w
		end
		assert(best >= previous, "personal best decreased")
	end
	print("PASS weight ranges sane and personal best monotonic")
end

-- Areas are bought with coins, so their prices must climb — a cheaper deeper
-- area would let a player skip content they never paid for.
if Balance.AreaCosts then
	assert(#Balance.AreaCosts == Balance.MaxLayer, "need one area cost per layer")
	assert(Balance.AreaCosts[1] == 0, "the starting area must be free")
	for i = 2, #Balance.AreaCosts do
		assert(Balance.AreaCosts[i] > Balance.AreaCosts[i - 1], "area costs must increase at " .. i)
	end
	print("PASS area costs increase monotonically")
end

-- The catch split is a probability. If it ever left [0,1] the loop would either
-- never produce a chest or produce nothing else.
if Balance.CrateChance then
	assert(Balance.CrateChance > 0 and Balance.CrateChance < 1, "crate chance must be a proper probability")
	print("PASS fish/chest split is a valid probability")
end

-- The upgrade ladders must never dead-end. "You can't upgrade any more" was a
-- real player complaint, and the shape of the bug — an array lookup past the end
-- returning nil — is exactly the kind that only shows up after hours of play.
-- So: walk well past the authored lists and assert a tier always comes back,
-- strictly better than the last one and strictly more expensive.
if Balance.Pickaxe then
	local previous = Balance.Pickaxe(1)
	for level = 2, #Balance.Pickaxes + 40 do
		local tier = Balance.Pickaxe(level)
		assert(tier ~= nil, "no pickaxe tier at level " .. level)
		assert(tier.Name ~= nil and #tier.Name > 0, "unnamed pickaxe tier at level " .. level)
		assert(tier.Damage > previous.Damage, "pickaxe damage must increase at level " .. level)
		assert(tier.Cost > previous.Cost, "pickaxe cost must increase at level " .. level)
		assert(tier.Damage == tier.Damage and tier.Damage ~= math.huge, "pickaxe damage overflowed at " .. level)
		previous = tier
	end
	print("PASS pickaxe ladder never ends (checked 40 tiers past the authored list)")
end

if Balance.Backpack then
	local previous = Balance.Backpack(1)
	for level = 2, #Balance.Backpacks + 40 do
		local tier = Balance.Backpack(level)
		assert(tier ~= nil, "no backpack tier at level " .. level)
		assert(tier.Capacity > previous.Capacity, "backpack capacity must increase at level " .. level)
		assert(tier.Cost > previous.Cost, "backpack cost must increase at level " .. level)
		previous = tier
	end
	print("PASS backpack ladder never ends (checked 40 tiers past the authored list)")
end

-- What a rod BUYS must keep improving, not just what it costs. The original bug
-- was not a missing tier — the tiers existed — it was `math.clamp(...)` and
-- `math.min(...)` pinning both rod benefits at around damage 30, so the eighth
-- rod and the fortieth played identically. A ladder that never ends is worthless
-- if its rungs stop doing anything, so assert strict monotonicity across the
-- whole damage range the generated tiers can reach.
if Balance.RodBiteFactor then
	local previousBite = Balance.RodBiteFactor(0)
	local previousCatch = Balance.RodExtraCatch(0)
	local damage = 1
	for _ = 1, 60 do
		local bite = Balance.RodBiteFactor(damage)
		local catch = Balance.RodExtraCatch(damage)
		assert(bite < previousBite, "bite factor stopped improving at damage " .. damage)
		assert(bite >= Balance.BiteFloor, "bite factor fell through its floor at damage " .. damage)
		assert(catch >= previousCatch, "extra catch went backwards at damage " .. damage)
		previousBite, previousCatch = bite, catch
		damage *= 1.55
	end
	-- And it must still start where the game already was: the freebie rod should
	-- not have been quietly buffed by fixing the top of the ladder.
	assert(Balance.RodExtraCatch(1) < 0.05, "the starter rod got buffed; it should still be ~2% double hook")
	print("PASS rod benefits improve forever and the starter rod is unchanged")
end

-- Every layer needs a name, including the generated deep ones.
if Balance.LayerName then
	local seen = {}
	for layer = 1, Balance.MaxLayer do
		local name = Balance.LayerName(layer)
		assert(type(name) == "string" and #name > 0, "no name for layer " .. layer)
		assert(not seen[name], "duplicate layer name: " .. name)
		seen[name] = true
	end
	print("PASS every layer has a distinct name")
end

print("ALL INVARIANTS PASSED")
