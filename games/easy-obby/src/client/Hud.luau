--!strict
-- HUD: coins/jump/stage pills, screen buttons, and the Skip Stage quick-buy.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Monetization = require(Shared.Config.Monetization)
local Purchase = require(script.Parent.Purchase)
local ScreenManager = require(script.Parent.ScreenManager)
local State = require(script.Parent.State)
local UiKit = require(script.Parent.UiKit)

local Hud = {}

local coinsLabel: TextLabel? = nil
local jumpLabel: TextLabel? = nil
local stageLabel: TextLabel? = nil
local streakLabel: TextLabel? = nil

local function pill(parent: Instance, position: UDim2, color: Color3): TextLabel
	local frame = UiKit.Create("Frame", {
		Size = UDim2.fromOffset(190, 40),
		Position = position,
		BackgroundColor3 = UiKit.Colors.Bg,
		BackgroundTransparency = 0.15,
		Parent = parent,
	})
	UiKit.Corner(12).Parent = frame
	UiKit.Stroke(color, 2).Parent = frame
	local label = UiKit.Label({
		Text = "",
		TextColor3 = color,
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	return label :: TextLabel
end

function Hud.Init(gui: ScreenGui)
	coinsLabel = pill(gui, UDim2.fromOffset(12, 12), UiKit.Colors.Accent)
	jumpLabel = pill(gui, UDim2.fromOffset(12, 58), Color3.fromRGB(120, 200, 255))
	stageLabel = pill(gui, UDim2.fromOffset(12, 104), Color3.fromRGB(255, 150, 220))
	streakLabel = pill(gui, UDim2.fromOffset(12, 150), UiKit.Colors.Good)

	-- Bottom button row
	local row = UiKit.Create("Frame", {
		Size = UDim2.fromOffset(560, 56),
		Position = UDim2.new(0.5, -280, 1, -70),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = row
	local buttons = {
		{ Label = "Trails", Screen = "Trails", Color = Color3.fromRGB(120, 255, 200) },
		{ Label = "Teleport", Screen = "Teleport", Color = Color3.fromRGB(120, 200, 255) },
		{ Label = "Rebirth", Screen = "Rebirth", Color = Color3.fromRGB(255, 120, 255) },
		{ Label = "Store", Screen = "Store", Color = UiKit.Colors.Accent },
	}
	for i, def in buttons do
		local button = UiKit.Create("TextButton", {
			Text = def.Label,
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			TextColor3 = Color3.fromRGB(28, 24, 20),
			BackgroundColor3 = def.Color,
			Size = UDim2.fromOffset(122, 52),
			LayoutOrder = i,
			Parent = row,
		})
		UiKit.Corner(12).Parent = button
		UiKit.Pad(8).Parent = button
		local screenName = def.Screen
		button.Activated:Connect(function()
			ScreenManager.Toggle(screenName)
		end)
	end

	-- Skip Stage quick-buy (the obby revenue workhorse — always one tap away)
	local skip = UiKit.Create("TextButton", {
		Text = "Skip Stage  R$" .. Monetization.Products.Skip1.Price,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(28, 24, 20),
		BackgroundColor3 = UiKit.Colors.Robux,
		Size = UDim2.fromOffset(200, 46),
		Position = UDim2.new(1, -212, 1, -60),
		Parent = gui,
	}) :: TextButton
	UiKit.Corner(12).Parent = skip
	UiKit.Pad(6).Parent = skip
	skip.Visible = Monetization.Products.Skip1.Id ~= 0
	skip.Activated:Connect(function()
		Purchase.PromptProduct("Skip1")
	end)

	State.Changed:Connect(function(state)
		if coinsLabel then
			coinsLabel.Text = "Coins: " .. Format.Number(state.Coins) .. "  (x" .. string.format("%.2f", state.CoinMult) .. ")"
		end
		if jumpLabel then
			jumpLabel.Text = "Jump Power: " .. state.JumpPower
		end
		if stageLabel then
			stageLabel.Text = ("Stage %d  (best %d)"):format(state.Checkpoint, state.Stats.BestStage)
		end
		if streakLabel then
			streakLabel.Text = "Streak: Day " .. state.Streak.Count .. "  •  Rebirth " .. state.Rebirths
		end
	end)
end

return Hud
