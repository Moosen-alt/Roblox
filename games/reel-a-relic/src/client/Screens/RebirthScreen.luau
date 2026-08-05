--!strict
-- Recrystallize: the infinite prestige ladder.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Purchase = require(script.Parent.Parent.Purchase)
local ScreenManager = require(script.Parent.Parent.ScreenManager)
local State = require(script.Parent.Parent.State)
local Toasts = require(script.Parent.Parent.Toasts)
local UiKit = require(script.Parent.Parent.UiKit)

local RebirthScreen = {}

local infoLabel: TextLabel? = nil
local costButton: TextButton? = nil

local function render()
	local state = State.Get()
	if not state or not infoLabel or not costButton then
		return
	end
	local currentBonus = math.floor(Balance.RebirthCoinBonus * state.Rebirths * 100 + 0.5)
	local nextBonus = math.floor(Balance.RebirthCoinBonus * (state.Rebirths + 1) * 100 + 0.5)
	local nextLayer = math.min(state.Rebirths + 2, Balance.MaxLayer)
	infoLabel.Text = table.concat({
		("Layer: %s   •   Rebirths: %d"):format(state.LayerName, state.Rebirths),
		("Coin bonus: +%d%%  ->  +%d%%"):format(currentBonus, nextBonus),
		"Next waters: " .. Balance.LayerNames[nextLayer],
		"",
		"Resets: coins, rod, boat, aquarium tanks.",
		"Keeps: relics, collection, gamepasses, streak.",
	}, "\n")
	local affordable = state.Coins >= state.RebirthCost
	costButton.Text = "Set Sail  (" .. Format.Number(state.RebirthCost) .. " coins)"
	costButton.BackgroundColor3 = affordable and Color3.fromRGB(255, 120, 255) or UiKit.Colors.BgLighter
	costButton.TextColor3 = affordable and Color3.fromRGB(40, 20, 40) or UiKit.Colors.TextDim
end

function RebirthScreen.Init(gui: ScreenGui)
	local panel, content, close = UiKit.Panel(gui, "Set Sail", UDim2.fromScale(0.5, 0.66))

	infoLabel = UiKit.Create("TextLabel", {
		Text = "",
		Font = Enum.Font.GothamBold,
		TextColor3 = UiKit.Colors.Text,
		TextScaled = false,
		TextSize = 20,
		TextWrapped = true,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0.58, 0),
		Parent = content,
	}) :: TextLabel

	local rebirthButton = UiKit.Button({
		Text = "Set Sail",
		BackgroundColor3 = Color3.fromRGB(255, 120, 255),
		Size = UDim2.new(0.9, 0, 0, 54),
		Position = UDim2.fromScale(0.05, 0.64),
		Parent = content,
	}) :: TextButton
	costButton = rebirthButton
	rebirthButton.Activated:Connect(function()
		local ok, err = Remotes.Function("Rebirth"):InvokeServer()
		if not ok and typeof(err) == "string" then
			Toasts.Push(err, UiKit.Colors.Bad)
		end
	end)

	local instant = UiKit.Button({
		Text = "Instant Set Sail (R$)",
		BackgroundColor3 = UiKit.Colors.Robux,
		Size = UDim2.new(0.9, 0, 0, 44),
		Position = UDim2.fromScale(0.05, 0.82),
		Parent = content,
	})
	instant.Activated:Connect(function()
		Purchase.PromptProduct("InstantRebirth")
	end)

	State.Changed:Connect(function()
		if panel.Visible then
			render()
		end
	end)

	ScreenManager.Register("Rebirth", panel, close, render)
end

return RebirthScreen
