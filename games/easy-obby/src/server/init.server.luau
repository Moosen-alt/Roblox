--!strict
-- Bootstrap: build the course, wire services into a shared context, start data.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Remotes = require(Shared.Remotes)

local AnalyticsService = require(script.AnalyticsService)
local CourseBuilder = require(script.CourseBuilder)
local DataService = require(script.DataService)
local Leaderboards = require(script.Leaderboards)
local MonetizationService = require(script.MonetizationService)
local RebirthService = require(script.RebirthService)
local StageService = require(script.StageService)
local StreakService = require(script.StreakService)
local TrailService = require(script.TrailService)

Remotes.Init()
local course = CourseBuilder.Build()

local ctx: any = {
	Data = DataService,
	Stages = StageService,
	Rebirth = RebirthService,
	Trails = TrailService,
	Streak = StreakService,
	Monetization = MonetizationService,
	Analytics = AnalyticsService,
}

ctx.OnProfileLoaded = function(player: Player, data: any)
	MonetizationService.PreloadPasses(player, data)
	local streakReport = StreakService.HandleJoin(player, data)

	-- Offline "Jump Charge": coins accrued while away, scaled by checkpoint.
	local offlineCoins = 0
	local away = 0
	if data.LastSeen > 0 and data.Checkpoint > 0 then
		away = math.min(os.time() - data.LastSeen, Balance.OfflineCapSeconds)
		offlineCoins = math.floor(away / 60 * data.Checkpoint * Balance.OfflineCoinsPerStagePerMinute)
		if offlineCoins > 0 then
			DataService.AddCoins(player, offlineCoins, true)
		end
	end

	StageService.ApplyStats(player)
	task.delay(2, function()
		if player.Parent then
			Remotes.Event("WelcomeReport"):FireClient(player, {
				Streak = streakReport,
				Offline = { OfflineSeconds = away, PendingCoins = offlineCoins },
			})
		end
	end)
end

ctx.OnProfileReleasing = function(player: Player, data: any)
	Leaderboards.Save(player, data)
end

AnalyticsService.Init(ctx)
MonetizationService.Init(ctx)
StageService.Init(ctx, course.Pads)
RebirthService.Init(ctx)
TrailService.Init(ctx)
StreakService.Init(ctx)
Leaderboards.Init(ctx, course.BoardStages, course.BoardRebirths)
DataService.Init(ctx)

print("[EasyObby] Server ready.")
