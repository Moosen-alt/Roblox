--!strict
-- Client-side purchase prompts, driven by the Monetization config. Offers with
-- an unconfigured (0) ID show a friendly toast instead of erroring.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monetization = require(Shared.Config.Monetization)
local Toasts = require(script.Parent.Toasts)

local Purchase = {}

function Purchase.PromptPass(key: string)
	local def = (Monetization.Gamepasses :: any)[key]
	if not def or def.Id == 0 then
		Toasts.Push("This offer isn't set up yet!", Color3.fromRGB(255, 200, 90))
		return
	end
	MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, def.Id)
end

function Purchase.PromptProduct(key: string)
	local def = (Monetization.Products :: any)[key]
	if not def or def.Id == 0 then
		Toasts.Push("This offer isn't set up yet!", Color3.fromRGB(255, 200, 90))
		return
	end
	MarketplaceService:PromptProductPurchase(Players.LocalPlayer, def.Id)
end

return Purchase
