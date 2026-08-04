--!strict
-- Rebirth: reach the Finish, bank a permanent multiplier, reshuffled fun.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Remotes = require(Shared.Remotes)
local Purchase = require(script.Parent.Parent.Purchase)
local ScreenManager = require(script.Parent.Parent.ScreenManager)
local State = require(script.Parent.Parent.State)
local Toasts = require(script.Parent.Parent.Toasts)
local UiKit = require(script.Parent.Parent.UiKit)

local RebirthScreen = {}

local infoLabel: TextLabel? = nil
local rebirthButtonRef: TextButton? = nil

local function render()
	local state = State.Get()
	if not state or not infoLabel or not rebirthButtonRef then
		return
	end
	local currentMult = 1 + Balance.RebirthGainBonus * state.Rebirths
	local nextMult = 1 + Balance.RebirthGainBonus * (state.Rebirths + 1)
	infoLabel.Text = table.concat({
		("Rebirths: %d   •   Stage %d / %d"):format(state.Rebirths, state.Checkpoint, Balance.RebirthStage),
		("Jump gain & coins: x%.2f  ->  x%.2f"):format(currentMult, nextMult),
		"",
		"Resets: Jump Power and your stage.",
		"Keeps: coins, trails, gamepasses, streak.",
		state.RebirthReady and "READY! Bank your multiplier!" or ("Reach stage %d to Rebirth."):format(Balance.RebirthStage),
	}, "\n")
	rebirthButtonRef.BackgroundColor3 = state.RebirthReady and Color3.fromRGB(255, 120, 255) or UiKit.Colors.BgLighter
	rebirthButtonRef.TextColor3 = state.RebirthReady and Color3.fromRGB(40, 20, 40) or UiKit.Colors.TextDim
end

function RebirthScreen.Init(gui: ScreenGui)
	local panel, content, close = UiKit.Panel(gui, "Rebirth", UDim2.fromScale(0.5, 0.66))

	infoLabel = UiKit.Create("TextLabel", {
		Text = "",
		Font = Enum.Font.GothamBold,
		TextColor3 = UiKit.Colors.Text,
		TextSize = 20,
		TextWrapped = true,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0.58, 0),
		Parent = content,
	}) :: TextLabel

	local rebirthButton = UiKit.Button({
		Text = "REBIRTH!",
		BackgroundColor3 = Color3.fromRGB(255, 120, 255),
		Size = UDim2.new(0.9, 0, 0, 54),
		Position = UDim2.fromScale(0.05, 0.64),
		Parent = content,
	}) :: TextButton
	rebirthButtonRef = rebirthButton
	rebirthButton.Activated:Connect(function()
		local ok, err = Remotes.Function("Rebirth"):InvokeServer()
		if not ok and typeof(err) == "string" then
			Toasts.Push(err, UiKit.Colors.Bad)
		end
	end)

	local instant = UiKit.Button({
		Text = "Instant Rebirth (R$)",
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
