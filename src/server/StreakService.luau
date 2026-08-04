--!strict
-- Daily login streaks on a visible 7-day reward cycle, with a 2x bonus for
-- joining the group. Day 7 grants the anchor prize: big coins + a guaranteed
-- Charged Geode roll (free-action randomness — no disclosure surface).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Monetization = require(Shared.Config.Monetization)
local Remotes = require(Shared.Remotes)

local StreakService = {}

local ctx: any = nil

export type StreakReport = {
	Count: number,
	CycleDay: number,
	Reward: number,
	GroupBonus: boolean,
	StreakLost: boolean,
	Premium: boolean,
}

function StreakService.HandleJoin(player: Player, data: any): StreakReport?
	local today = os.time() // 86400
	local streak = data.Streak
	if streak.LastDay == today then
		return nil -- already claimed today
	end

	local lost = false
	if streak.LastDay == 0 then
		streak.Count = 1
	elseif today - streak.LastDay <= 1 + Balance.StreakGraceDays then
		streak.Count += 1
	else
		streak.Count = 1
		lost = true
	end
	streak.LastDay = today
	streak.Best = math.max(streak.Best, streak.Count)

	local cycleDay = ((streak.Count - 1) % #Balance.StreakCycle) + 1
	local cycleReward = Balance.StreakCycle[cycleDay]
	local reward = cycleReward.Coins

	local inGroup = false
	if Monetization.GroupId ~= 0 then
		local ok, result = pcall(function()
			return player:IsInGroupAsync(Monetization.GroupId)
		end)
		inGroup = ok and result == true
	end
	if inGroup then
		reward *= 2
	end

	data.Coins += reward
	data.TotalCoinsEarned += reward

	if cycleReward.PremiumGeode then
		local result = ctx.Crack.RollWithLuck(player, 3)
		if result then
			task.delay(3, function()
				if player.Parent then
					Remotes.Event("CrackResult"):FireClient(player, { result }, true)
				end
			end)
		end
	end

	ctx.Data.MarkDirty(player)
	return {
		Count = streak.Count,
		CycleDay = cycleDay,
		Reward = reward,
		GroupBonus = inGroup,
		StreakLost = lost,
		Premium = cycleReward.PremiumGeode == true,
	}
end

function StreakService.Init(serviceCtx: any)
	ctx = serviceCtx
end

return StreakService
