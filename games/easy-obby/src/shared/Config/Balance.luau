--!strict
-- Every tuning constant in one place.

local Balance = {}

-- FILM MODE: set true in Studio to record marketing clips — capped jump power
-- (the mega-leap shot), every trail owned, Day 30 streak, and 8h of offline
-- coins waiting. It is ignored outside Studio and ships as false, so it can
-- never affect the live game. See src/server/FilmMode.luau.
Balance.FilmMode = false

-- Course
Balance.Stages = 100
Balance.StageLength = 26 -- studs of course per stage
Balance.RespawnSeconds = 2

-- The +1 loop: every stage pad adds jump power; speed scales with it so
-- late-game players leap whole sections (the clip moment).
Balance.BaseJumpPower = 50
Balance.JumpPerStage = 1
Balance.JumpBonusCap = 350 -- total bonus cap (base + bonus <= 400)
Balance.BaseWalkSpeed = 16
Balance.SpeedPerJumpBonus = 0.12
Balance.WalkSpeedCap = 90
Balance.SpeedCoilBonus = 8 -- Speed Coil gamepass

-- Coins
Balance.CoinsPerStage = 5
Balance.CoinsStageScale = 0.02 -- +2% per stage index
Balance.VipCoinBonus = 0.25

-- Rebirth: reach the Finish pad (stage 100), reset jump/checkpoint, keep coins
-- and trails, bank a permanent +25% jump-gain & coin multiplier.
Balance.RebirthStage = 100
Balance.RebirthGainBonus = 0.25
Balance.MegaStartJump = 100 -- Mega Start gamepass: starting jump bonus each rebirth

-- Offline "Jump Charge": coins accrue while away, scaled by checkpoint.
Balance.OfflineCoinsPerStagePerMinute = 0.6
Balance.OfflineCapSeconds = 8 * 3600

-- Daily streaks (same shape as the other games)
Balance.StreakBaseReward = 100
Balance.StreakDayCap = 30
Balance.StreakMilestones = { [7] = 3, [14] = 4, [30] = 6 }
Balance.StreakGraceDays = 1

-- Trail cosmetics: the coin sink. "Rainbow" is VIP-exclusive, not buyable.
Balance.Trails = {
	{ Name = "Sunset", Color = Color3.fromRGB(255, 150, 80), Cost = 250 },
	{ Name = "Mint", Color = Color3.fromRGB(120, 255, 200), Cost = 500 },
	{ Name = "Sky", Color = Color3.fromRGB(120, 200, 255), Cost = 1000 },
	{ Name = "Bubblegum", Color = Color3.fromRGB(255, 150, 220), Cost = 2000 },
	{ Name = "Lime", Color = Color3.fromRGB(170, 255, 100), Cost = 4000 },
	{ Name = "Royal", Color = Color3.fromRGB(150, 120, 255), Cost = 8000 },
	{ Name = "Gold", Color = Color3.fromRGB(255, 210, 90), Cost = 15000 },
	{ Name = "Crimson", Color = Color3.fromRGB(255, 80, 90), Cost = 25000 },
	{ Name = "Void", Color = Color3.fromRGB(60, 50, 90), Cost = 40000 },
	{ Name = "Star White", Color = Color3.fromRGB(255, 255, 255), Cost = 60000 },
}

export type TrailDef = { Name: string, Color: Color3, Cost: number }

function Balance.GetTrail(name: string): TrailDef?
	for _, trail in Balance.Trails do
		if trail.Name == name then
			return trail
		end
	end
	return nil
end

return Balance
