--!strict
-- Client bootstrap: state replica, HUD, screens, station prompts.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local StarterGui = game:GetService("StarterGui")

-- The pickaxe Tool is permanent cosmetic equipment; hide the default backpack
-- hotbar so it doesn't overlap the HUD button row.
task.spawn(function()
	for _ = 1, 10 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		if ok then
			return
		end
		task.wait(0.5)
	end
end)

local State = require(script.State)
local ScreenManager = require(script.ScreenManager)
local MiningInput = require(script.MiningInput)
local ObjectiveBanner = require(script.ObjectiveBanner)
local Toasts = require(script.Toasts)
local Hud = require(script.Hud)
local CrackScreen = require(script.Screens.CrackScreen)
local RacksScreen = require(script.Screens.RacksScreen)
local ShopScreen = require(script.Screens.ShopScreen)
local StoreScreen = require(script.Screens.StoreScreen)
local IndexScreen = require(script.Screens.IndexScreen)
local RebirthScreen = require(script.Screens.RebirthScreen)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "CrackAGeodeGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
gui.Parent = playerGui

State.Init()
MiningInput.Init()
Toasts.Init(gui)
Hud.Init(gui)
ObjectiveBanner.Init(gui)
CrackScreen.Init(gui)
RacksScreen.Init(gui)
ShopScreen.Init(gui)
StoreScreen.Init(gui)
IndexScreen.Init(gui)
RebirthScreen.Init(gui)

-- Walking up to a station and triggering its prompt opens the matching screen.
local STATION_SCREENS: { [string]: string } = {
	Crack = "Crack",
	Racks = "Racks",
	Shop = "Shop",
	Rebirth = "Rebirth",
}

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local station = prompt:GetAttribute("Station")
	if typeof(station) == "string" then
		local screenName = STATION_SCREENS[station]
		if screenName then
			ScreenManager.Open(screenName)
		end
	end
end)
