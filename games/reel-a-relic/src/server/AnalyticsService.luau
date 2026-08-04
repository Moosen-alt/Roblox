--!strict
-- Fail-safe wrapper over Roblox AnalyticsService. The onboarding funnel
-- (FirstGeode -> FirstCrack -> FirstRare -> FirstSocket -> FirstRebirth) is
-- the go/no-go dashboard for ad spend — and each first-time step now pays a
-- small coin reward so the on-screen objectives feel like a tutorial quest.

local RobloxAnalytics = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local AnalyticsService = {}

local ctx: any = nil

local STEP_REWARDS = { 50, 100, 150, 250, 500 }

function AnalyticsService.FunnelStep(player: Player, data: any, step: number, stepName: string)
	if data.Funnel[stepName] then
		return
	end
	data.Funnel[stepName] = true
	pcall(function()
		RobloxAnalytics:LogOnboardingFunnelStepEvent(player, step, stepName)
	end)
	local reward = STEP_REWARDS[step]
	if reward and ctx then
		ctx.Data.AddCoins(player, reward, false)
		Remotes.Event("Notify"):FireClient(player, {
			Text = "Objective complete!  +" .. reward .. " coins",
			Color = Color3.fromRGB(120, 255, 200),
		})
	end
end

function AnalyticsService.LogCustom(player: Player, eventName: string, value: number?)
	pcall(function()
		RobloxAnalytics:LogCustomEvent(player, eventName, value or 1)
	end)
end

function AnalyticsService.Init(serviceCtx: any)
	ctx = serviceCtx
end

return AnalyticsService
