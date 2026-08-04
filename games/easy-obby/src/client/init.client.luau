--!strict
-- Client bootstrap: state replica, HUD, screens.

local Players = game:GetService("Players")

local State = require(script.State)
local Toasts = require(script.Toasts)
local Hud = require(script.Hud)
local TrailsScreen = require(script.Screens.TrailsScreen)
local TeleportScreen = require(script.Screens.TeleportScreen)
local RebirthScreen = require(script.Screens.RebirthScreen)
local StoreScreen = require(script.Screens.StoreScreen)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "EasyObbyGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
gui.Parent = playerGui

State.Init()
Toasts.Init(gui)
Hud.Init(gui)
TrailsScreen.Init(gui)
TeleportScreen.Init(gui)
RebirthScreen.Init(gui)
StoreScreen.Init(gui)
