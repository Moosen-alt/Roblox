--!strict
-- FILM MODE — for recording clips, never for the live game.
--
-- Marketing needs footage of things that take days to reach honestly: a maxed
-- rod, a near-complete collection, a Day 30 streak, a Feeding Frenzy on
-- demand. Editing six config files by hand before every shoot is how a wrong
-- number ends up published, so it is one switch instead:
--
--     ReplicatedStorage -> Shared -> Config -> Balance -> FilmMode = true
--
-- Two independent guards mean this can never reach players:
--   1. It only runs when RunService:IsStudio() is true.
--   2. Balance.FilmMode ships as false, and CI publishes whatever is committed.
-- Two further containments, because "Studio only" is not the same as "harmless":
--   3. The profile loads from ProfileStore's Mock store, so a staged save is
--      never written to the real one.
--   4. Leaderboards.Save returns early while film mode is on. Those are separate
--      OrderedDataStores keyed by your real UserId — without the guard, a film
--      take published an endgame score to the live boards.
-- Flip it in Studio, press Play, film, close WITHOUT saving.
--
-- What it does NOT do: change the odds panel's honesty, or fake any number the
-- UI reports. Everything below hands you a real endgame profile and lets the
-- real systems run — the footage is of the actual game, just fast-forwarded.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Crystals = require(Shared.Config.Crystals)
local RarityMath = require(Shared.RarityMath)

local FilmMode = {}

function FilmMode.Active(): boolean
	return Balance.FilmMode == true and RunService:IsStudio()
end

-- Applied to the profile right after it loads, before the first StateSync.
function FilmMode.Apply(data: any)
	if not FilmMode.Active() then
		return
	end

	data.Coins = 5_000_000
	data.Geodes = 20 -- uncracked chests
	data.Pickaxe = #Balance.Pickaxes
	data.Backpack = #Balance.Backpacks
	data.RackSlots = Balance.MaxRackSlots
	data.Rebirths = 6
	-- Every area bought, fishing the deepest one: the drop table with the best
	-- footage in it. Areas no longer follow rebirths, so both have to be staged.
	data.AreaUnlocked = Balance.MaxLayer
	data.AreaCurrent = Balance.MaxLayer
	local layer = Balance.MaxLayer
	data.Stats.GeodesMined = 4820
	data.Stats.GeodesCracked = 4610

	-- Collection at 75%: enough to look like a real save, with the last stretch
	-- still missing so the "what am I still hunting" shot has something to show.
	local target = math.floor(Crystals.TotalIndexEntries() * 0.75)
	local filled = 0
	for _, base in Crystals.Bases do
		for _, mutation in Crystals.MutationNames do
			if filled >= target then
				break
			end
			local key = Crystals.IndexKey(base.Name, mutation)
			if not data.Collection[key] then
				data.Collection[key] = true
				filled += 1
			end
		end
	end
	data.CollectionCount = filled

	-- Streak sits at 29 with yesterday's claim, so joining rolls it to Day 30
	-- and the milestone popup fires for real.
	data.Streak.Count = 29
	data.Streak.Best = 29
	data.Streak.LastDay = (os.time() // 86400) - 1

	-- An eight-hour absence, so the welcome-back popup has a real number in it.
	data.LastSeen = os.time() - Balance.OfflineCapSeconds

	-- ...but offline earnings are computed from SOCKETED items, so an empty
	-- inventory made the welcome popup show no earnings line at all and left the
	-- racks bare on camera. Stage a spread worth showing, including one big
	-- mutated piece that becomes the flex aura over the character's head.
	local staged = {
		{ Base = Crystals.Bases[#Crystals.Bases].Name, Mut = Crystals.MutationNames[#Crystals.MutationNames], Size = 2.4 },
		{ Base = Crystals.Bases[math.max(#Crystals.Bases - 1, 1)].Name, Mut = "Normal", Size = 1.8 },
		{ Base = Crystals.Bases[math.max(#Crystals.Bases - 2, 1)].Name, Mut = "Normal", Size = 1.5 },
		{ Base = Crystals.Bases[math.max(#Crystals.Bases - 3, 1)].Name, Mut = "Normal", Size = 1.2 },
	}
	-- The record comes from the SECOND piece, not the showpiece. A rolled crystal
	-- maxes out at size 1.2, so making a rack-grown 2.4 the record would put the
	-- bar above anything a crack could beat — freezing the aura and killing the
	-- "NEW PERSONAL BEST" line, which are two of the shots this mode exists for.
	-- A Legendary record still dresses the character and still leaves headroom.
	local record = staged[2]
	data.Stats.RarestName = (record.Mut ~= "Normal" and (record.Mut .. " ") or "") .. record.Base
	data.Stats.RarestValue = RarityMath.ComputeValue(record.Base, record.Mut, record.Size, layer)

	local socketedAt = os.time() - Balance.OfflineCapSeconds
	for slot, entry in staged do
		local id = tostring(data.NextCrystalId)
		data.NextCrystalId += 1
		data.Crystals[id] = {
			Base = entry.Base,
			Mut = entry.Mut,
			Size = entry.Size,
			Layer = layer,
		}
		data.Racks[tostring(slot)] = { CrystalId = id, LastTick = socketedAt }
		-- ...and mark them found. The fill loop above deliberately leaves the
		-- rarest entries unowned, which is exactly where these are drawn from —
		-- a pan from the racks to the index would otherwise contradict itself.
		local key = Crystals.IndexKey(entry.Base, entry.Mut)
		if not data.Collection[key] then
			data.Collection[key] = true
			data.CollectionCount += 1
		end
	end

	-- Personal bests, for the Index shots. Staged from a size a real catch can
	-- beat (rolls cap at 1.2) for the same reason the value record is: a wall of
	-- unbeatable records on camera is a wall the player can never interact with.
	for _, def in Crystals.BasesInLayer(layer) do
		if data.Collection[Crystals.IndexKey(def.Name, "Normal")] then
			data.BestWeight[def.Name] = Crystals.WeightOf(def.Name, 1.05)
		end
	end
end

return FilmMode
