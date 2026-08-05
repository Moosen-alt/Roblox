--!strict
-- FILM MODE — for recording clips, never for the live game.
--
-- The clip this game lives or dies on is the mega leap: five stages cleared in
-- one bound. Earning that honestly takes an hour of play before every take, so
-- this hands the session a late-game jump stat instead:
--
--     ReplicatedStorage -> Shared -> Config -> Balance -> FilmMode = true
--
-- Two independent guards mean it can never reach players:
--   1. It only runs when RunService:IsStudio() is true.
--   2. Balance.FilmMode ships as false, and CI publishes whatever is committed.
-- Flip it in Studio, press Play, film, close WITHOUT saving.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)

local FilmMode = {}

function FilmMode.Active(): boolean
	return Balance.FilmMode == true and RunService:IsStudio()
end

-- Applied to the profile right after it loads, before the first StateSync.
function FilmMode.Apply(data: any)
	if not FilmMode.Active() then
		return
	end

	data.Coins = 250_000
	data.JumpBonus = Balance.JumpBonusCap -- leaps that clear 5-15 stages
	data.Checkpoint = 40 -- mid-tower, so there is course visible both ways
	data.Rebirths = 3
	data.Stats.BestStage = 100
	data.Stats.TotalStagesCleared = 340

	-- Every trail owned, so the cosmetics shot does not need a shopping trip.
	for _, trail in Balance.Trails do
		data.Trails[trail.Name] = true
	end

	-- Streak sits at 29 with yesterday's claim, so joining rolls it to Day 30
	-- and the milestone popup fires for real.
	data.Streak.Count = 29
	data.Streak.Best = 29
	data.Streak.LastDay = (os.time() // 86400) - 1

	-- An eight-hour absence, so the welcome-back popup has a real number in it.
	data.LastSeen = os.time() - Balance.OfflineCapSeconds
end

return FilmMode
