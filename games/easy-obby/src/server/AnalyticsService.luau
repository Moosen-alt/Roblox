--!strict
-- Thin, fail-safe wrapper over Roblox AnalyticsService. The onboarding funnel
-- (FirstGeode -> FirstCrack -> FirstRare -> FirstSocket -> FirstRebirth) is the
-- go/no-go dashboard for spending any ad budget: fix the biggest drop-off first.

local RobloxAnalytics = game:GetService("AnalyticsService")

local AnalyticsService = {}

function AnalyticsService.FunnelStep(player: Player, data: any, step: number, stepName: string)
	if data.Funnel[stepName] then
		return
	end
	data.Funnel[stepName] = true
	pcall(function()
		RobloxAnalytics:LogOnboardingFunnelStepEvent(player, step, stepName)
	end)
end

function AnalyticsService.LogCustom(player: Player, eventName: string, value: number?)
	pcall(function()
		RobloxAnalytics:LogCustomEvent(player, eventName, value or 1)
	end)
end

function AnalyticsService.Init(_serviceCtx: any) end

return AnalyticsService
