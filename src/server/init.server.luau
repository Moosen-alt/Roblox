--!strict
-- Bootstrap: build the world, wire services into a shared context, start data.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local AnalyticsService = require(script.AnalyticsService)
local AssetPreload = require(script.AssetPreload)
local AutoMineService = require(script.AutoMineService)
local CrackService = require(script.CrackService)
local DataService = require(script.DataService)
local EventService = require(script.EventService)
local FlexAura = require(script.FlexAura)
local Leaderboards = require(script.Leaderboards)
local MapBuilder = require(script.MapBuilder)
local MiningService = require(script.MiningService)
local MonetizationService = require(script.MonetizationService)
local PickaxeVisual = require(script.PickaxeVisual)
local PolicyGuard = require(script.PolicyGuard)
local RackService = require(script.RackService)
local RebirthService = require(script.RebirthService)
local ShopService = require(script.ShopService)
local Spotlight = require(script.Spotlight)
local StreakService = require(script.StreakService)
local UpgradeService = require(script.UpgradeService)

Remotes.Init()
-- The map goes up FIRST, the mesh library fills in the background. It used to
-- be the other way round, and a player joining a cold server spawned over a
-- world that had no floor yet — 138 LoadAsset round trips stood between them
-- and the ground. Everything mesh-shaped redraws itself when the library's
-- Loaded attribute flips, so nothing is baked wrong by building early.
AssetPreload.Start()
local map = MapBuilder.Build()

local ctx: any = {
	Data = DataService,
	Crack = CrackService,
	Mining = MiningService,
	Racks = RackService,
	Rebirth = RebirthService,
	Shop = ShopService,
	Events = EventService,
	Streak = StreakService,
	Upgrades = UpgradeService,
	Monetization = MonetizationService,
	Policy = PolicyGuard,
	Analytics = AnalyticsService,
	PickaxeVis = PickaxeVisual,
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
MiningService.Init(ctx, map.Nodes)
AutoMineService.Init(ctx) -- after MiningService: it drives swings through it
PickaxeVisual.Init(ctx)
Leaderboards.Init(ctx, map.BoardRebirths, map.BoardRarest)
DataService.Init(ctx)

print("[CrackAGeode] Server ready.")
