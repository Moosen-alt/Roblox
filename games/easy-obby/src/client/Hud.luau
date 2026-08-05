--!strict
-- HUD: coins/jump/stage pills, screen buttons, and the Skip Stage quick-buy.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

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

-- Coins roll up to their new value instead of snapping, and the pill punches
-- when they land. A number that visibly climbs is worth more than the same
-- number appearing — it's the payout counter, and it costs nothing but a lerp.
local displayedCoins = 0
local targetCoins = 0
local seenFirstSync = false

local function coinGainPopup(anchor: Frame, amount: number)
	local label = UiKit.Label({
		Text = "+" .. Format.Number(amount),
		Font = Enum.Font.FredokaOne,
		TextColor3 = UiKit.Colors.Good,
		TextStrokeTransparency = 0.4,
		Size = UDim2.fromOffset(150, 30),
		-- Rises from inside the pill's right edge rather than out past it. Spawning
		-- outside overlapped the centred toast column at 812 wide, and the old
		-- rise to -22 carried it off the top of the screen; -10 keeps every pixel
		-- on screen (the pill's own top edge is at y=12).
		Position = UDim2.new(1, -150, 0, 6),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = anchor,
	})
	TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, -150, 0, -10),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(1, function()
		label:Destroy()
	end)

	anchor.Size = UDim2.fromOffset(205, 44)
	TweenService:Create(anchor, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(190, 40),
	}):Play()
end

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
		local gain = state.Coins - targetCoins
		targetCoins = state.Coins
		if not seenFirstSync then
			seenFirstSync = true
			displayedCoins = state.Coins
		elseif gain > 0 and coinsLabel then
			coinGainPopup(coinsLabel.Parent :: Frame, gain)
		elseif gain < 0 then
			displayedCoins = state.Coins -- spending is instant; earning is savoured
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
	RunService.Heartbeat:Connect(function(delta: number)
		local state = State.Get()
		if not state or not coinsLabel then
			return
		end
		if displayedCoins ~= targetCoins then
			local step = math.max(math.abs(targetCoins - displayedCoins) * math.min(delta * 9, 1), 1)
			if math.abs(targetCoins - displayedCoins) <= step then
				displayedCoins = targetCoins
			else
				displayedCoins += (targetCoins > displayedCoins) and step or -step
			end
		end
		coinsLabel.Text = "Coins: "
			.. Format.Number(math.floor(displayedCoins))
			.. "  (x"
			.. string.format("%.2f", state.CoinMult)
			.. ")"
	end)
end

return Hud
