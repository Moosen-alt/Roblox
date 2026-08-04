--!strict
-- HUD: coins/geodes pills, screen buttons, event banner, boost + streak
-- indicators, and the one-time starter-pack offer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Monetization = require(Shared.Config.Monetization)
local Purchase = require(script.Parent.Purchase)
local ScreenManager = require(script.Parent.ScreenManager)
local State = require(script.Parent.State)
local UiKit = require(script.Parent.UiKit)

local Hud = {}

local coinsLabel: TextLabel? = nil
local geodesLabel: TextLabel? = nil
local streakLabel: TextLabel? = nil
local eventBanner: TextLabel? = nil
local starterButton: TextButton? = nil

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
	geodesLabel = pill(gui, UDim2.fromOffset(12, 58), Color3.fromRGB(170, 110, 240))
	streakLabel = pill(gui, UDim2.fromOffset(12, 104), UiKit.Colors.Good)
	local boost = pill(gui, UDim2.fromOffset(12, 150), UiKit.Colors.Robux)
	local boostFrame = boost.Parent :: Frame
	boostFrame.Visible = false

	-- Event banner (top center, under toasts)
	eventBanner = UiKit.Create("TextLabel", {
		Text = "",
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = UiKit.Colors.Accent,
		BackgroundColor3 = UiKit.Colors.Bg,
		BackgroundTransparency = 0.2,
		Size = UDim2.fromOffset(420, 40),
		Position = UDim2.new(0.5, -210, 0, 236),
		Visible = false,
		Parent = gui,
	}) :: TextLabel
	UiKit.Corner(12).Parent = eventBanner
	UiKit.Stroke(UiKit.Colors.Accent, 2).Parent = eventBanner

	-- Bottom button row
	local row = UiKit.Create("Frame", {
		Size = UDim2.fromOffset(660, 56),
		Position = UDim2.new(0.5, -330, 1, -70),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = row
	local buttons = {
		{ Label = "Crack", Screen = "Crack", Color = Color3.fromRGB(255, 170, 40) },
		{ Label = "Racks", Screen = "Racks", Color = Color3.fromRGB(120, 255, 200) },
		{ Label = "Shop", Screen = "Shop", Color = Color3.fromRGB(120, 170, 255) },
		{ Label = "Index", Screen = "Index", Color = Color3.fromRGB(190, 90, 255) },
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
			Size = UDim2.fromOffset(102, 52),
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

	-- Starter pack offer (hidden once owned / unconfigured)
	local starter = UiKit.Create("TextButton", {
		Text = "Starter Pack  R$" .. Monetization.Products.StarterPack.Price,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(28, 24, 20),
		BackgroundColor3 = UiKit.Colors.Accent,
		Size = UDim2.fromOffset(200, 46),
		Position = UDim2.new(1, -212, 1, -60),
		Visible = false,
		Parent = gui,
	}) :: TextButton
	starterButton = starter
	UiKit.Corner(12).Parent = starter
	UiKit.Pad(6).Parent = starter
	starter.Activated:Connect(function()
		Purchase.PromptProduct("StarterPack")
	end)

	State.Changed:Connect(function(state)
		if coinsLabel then
			coinsLabel.Text = "Coins: " .. Format.Number(state.Coins) .. "  (x" .. string.format("%.2f", state.CoinMult) .. ")"
		end
		if geodesLabel then
			geodesLabel.Text = "Geodes: " .. state.Geodes .. " / " .. state.BackpackCapacity
		end
		if streakLabel then
			streakLabel.Text = "Streak: Day " .. state.Streak.Count
		end
		if starterButton then
			starterButton.Visible = not state.StarterPackOwned and Monetization.Products.StarterPack.Id ~= 0
		end
	end)

	RunService.Heartbeat:Connect(function()
		local state = State.Get()
		if state then
			local remaining = (state.Boost2xUntil or 0) - os.time()
			local frame = boostFrame
			if remaining > 0 then
				frame.Visible = true
				boost.Text = "2x Coins: " .. Format.Clock(remaining)
			else
				frame.Visible = false
			end
		end
		local banner = eventBanner
		if banner then
			local event = State.CurrentEvent()
			if event and event.Name then
				banner.Visible = true
				local remaining = (event.EndsAt or 0) - os.time()
				local desc = if (event.LuckMult or 1) > 1 then (event.LuckMult .. "x LUCK") else ((event.MutationMult or 1) .. "x MUTATIONS")
				banner.Text = event.Name .. "!  " .. desc .. "  •  " .. Format.Clock(remaining)
				if event.Color then
					banner.TextColor3 = event.Color
				end
			else
				banner.Visible = false
			end
		end
	end)
end

return Hud
