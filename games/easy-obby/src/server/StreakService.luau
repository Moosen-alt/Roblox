--!strict
-- Daily login streaks with 7/14/30 milestones, one grace day, and a 2x bonus
-- for joining the group (converts players into an owned audience).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Monetization = require(Shared.Config.Monetization)

local StreakService = {}

local ctx: any = nil

export type StreakReport = {
	Count: number,
	Reward: number,
	Milestone: boolean,
	GroupBonus: boolean,
	StreakLost: boolean,
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

	local day = math.min(streak.Count, Balance.StreakDayCap)
	local reward = Balance.StreakBaseReward * day
	local milestoneMult = Balance.StreakMilestones[streak.Count]
	if milestoneMult then
		reward *= milestoneMult
	end

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
	ctx.Data.MarkDirty(player)

	return {
		Count = streak.Count,
		Reward = reward,
		Milestone = milestoneMult ~= nil,
		GroupBonus = inGroup,
		StreakLost = lost,
	}
end

function StreakService.Init(serviceCtx: any)
	ctx = serviceCtx
end

return StreakService
