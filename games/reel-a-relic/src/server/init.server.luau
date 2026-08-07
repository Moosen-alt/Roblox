--!strict
-- Bootstrap: build the world, wire services into a shared context, start data.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local AnalyticsService = require(script.AnalyticsService)
local AreaService = require(script.AreaService)
local AutoCastService = require(script.AutoCastService)
local CrackService = require(script.CrackService)
local DataService = require(script.DataService)
local EventService = require(script.EventService)
local FlexAura = require(script.FlexAura)
local Leaderboards = require(script.Leaderboards)
local MapBuilder = require(script.MapBuilder)
local MiningService = require(script.MiningService)
local MonetizationService = require(script.MonetizationService)
local PolicyGuard = require(script.PolicyGuard)
local QuestService = require(script.QuestService)
local RackService = require(script.RackService)
local RebirthService = require(script.RebirthService)
local RodVisual = require(script.RodVisual)
local ShopService = require(script.ShopService)
local Spotlight = require(script.Spotlight)
local StreakService = require(script.StreakService)
local UpgradeService = require(script.UpgradeService)

Remotes.Init()
local map = MapBuilder.Build()

local ctx: any = {
	Data = DataService,
	Crack = CrackService,
	Mining = MiningService,
	Areas = AreaService,
	Racks = RackService,
	Rebirth = RebirthService,
	Shop = ShopService,
	Events = EventService,
	Streak = StreakService,
	Upgrades = UpgradeService,
	Monetization = MonetizationService,
	Policy = PolicyGuard,
	Quests = QuestService,
	RodVis = RodVisual,
	Analytics = AnalyticsService,
	Flex = FlexAura,
	Spotlight = Spotlight,
}

-- Called by DataService once a profile is loaded (before the first StateSync).
ctx.OnProfileLoaded = function(player: Player, data: any)
	MonetizationService.PreloadPasses(player, data)
	FlexAura.Apply(player, data)
	local streakReport = StreakService.HandleJoin(player, data)
	local offline = RackService.OfflineSummary(player, data)
	-- Give the client a moment to boot its UI, then show the welcome moment.
	task.delay(2, function()
		if player.Parent then
			Remotes.Event("WelcomeReport"):FireClient(player, {
				Streak = streakReport,
				Offline = offline,
			})
		end
	end)
end

ctx.OnProfileReleasing = function(player: Player, data: any)
	Leaderboards.Save(player, data)
end

AnalyticsService.Init(ctx)
PolicyGuard.Init(ctx)
EventService.Init(ctx)
MonetizationService.Init(ctx)
CrackService.Init(ctx)
RackService.Init(ctx)
RebirthService.Init(ctx)
UpgradeService.Init(ctx)
ShopService.Init(ctx)
StreakService.Init(ctx)
QuestService.Init(ctx)
MiningService.Init(ctx, map.Nodes)
AreaService.SetOrigins(map.Origins)
AreaService.Init(ctx)
AutoCastService.Init(ctx) -- after MiningService: it drives casts through it
RodVisual.Init(ctx)
Leaderboards.Init(ctx, map.BoardRebirths, map.BoardRarest)
DataService.Init(ctx)

print("[ReelARelic] Server ready.")
