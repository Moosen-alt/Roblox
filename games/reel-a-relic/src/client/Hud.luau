--!strict
-- HUD: coins/geodes pills, screen buttons, event banner, boost + streak
-- indicators, and the one-time starter-pack offer.

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
local geodesLabel: TextLabel? = nil
local streakLabel: TextLabel? = nil
local eventBanner: TextLabel? = nil
local starterButton: TextButton? = nil
local starterOffer: Frame? = nil
local indexBadge: TextLabel? = nil

-- Coins roll up to their new value instead of snapping, and the pill punches
-- when they land. A number that visibly climbs is worth more than the same
-- number appearing — it's the slot-machine payout counter, and it costs
-- nothing but a lerp.
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

	-- Slam the banner in with an alert sting when an event starts
	State.EventChanged:Connect(function(eventInfo)
		local banner = eventBanner
		if not banner or typeof(eventInfo) ~= "table" or not eventInfo.Name then
			return
		end
		banner.Visible = true
		banner.Size = UDim2.fromOffset(0, 0)
		banner.Position = UDim2.new(0.5, 0, 0, 256)
		TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(420, 40),
			Position = UDim2.new(0.5, -210, 0, 236),
		}):Play()
		for i, pitch in { 0.8, 1.2, 1.6 } do
			task.delay((i - 1) * 0.1, function()
				local sting = Instance.new("Sound")
				sting.SoundId = "rbxasset://sounds/electronicpingshort.wav"
				sting.PlaybackSpeed = pitch
				sting.Volume = 0.6
				sting.Parent = banner
				sting:Play()
				task.delay(2, function()
					if sting.Parent then
						sting:Destroy()
					end
				end)
			end)
		end
	end)

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
		{ Label = "Open", Screen = "Crack", Color = Color3.fromRGB(255, 170, 40) },
		{ Label = "Aquarium", Screen = "Racks", Color = Color3.fromRGB(120, 255, 200) },
		{ Label = "Shop", Screen = "Shop", Color = Color3.fromRGB(120, 170, 255) },
		{ Label = "Index", Screen = "Index", Color = Color3.fromRGB(190, 90, 255) },
		{ Label = "Set Sail", Screen = "Rebirth", Color = Color3.fromRGB(255, 120, 255) },
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

		-- The collection counter rides on the Index button rather than taking a
		-- fifth HUD pill. An unfinished set on screen at all times is the quiet
		-- reason to crack one more geode.
		if def.Screen == "Index" then
			local badge = UiKit.Create("TextLabel", {
				Text = "",
				Font = Enum.Font.FredokaOne,
				TextScaled = true,
				TextColor3 = Color3.fromRGB(28, 24, 20),
				BackgroundColor3 = UiKit.Colors.Good,
				Size = UDim2.fromOffset(56, 20),
				Position = UDim2.new(1, -30, 0, -14),
				AnchorPoint = Vector2.new(0.5, 0.5),
				ZIndex = 3,
				Parent = button,
			}) :: TextLabel
			UiKit.Corner(6).Parent = badge
			indexBadge = badge
		end

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
		-- Clear of the bottom button row's band (y = H-70 .. H-18). At H-60 this
		-- sat directly over the Store button on any viewport narrower than ~1068
		-- and, drawing later, swallowed the tap — the Robux store was unreachable
		-- on phones until the pack was bought.
		Position = UDim2.new(1, -212, 1, -140),
		Visible = false,
		Parent = gui,
	}) :: TextButton
	starterButton = starter
	UiKit.Corner(12).Parent = starter
	UiKit.Pad(6).Parent = starter

	-- Offer page: show exactly what's inside BEFORE the Roblox purchase prompt.
	local offer = UiKit.Create("Frame", {
		Size = UDim2.fromOffset(360, 320),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = UiKit.Colors.Bg,
		Visible = false,
		Parent = gui,
	})
	UiKit.Corner(16).Parent = offer
	UiKit.Stroke(UiKit.Colors.Accent, 3).Parent = offer
	UiKit.Label({
		Text = "STARTER PACK",
		Font = Enum.Font.FredokaOne,
		TextColor3 = UiKit.Colors.Accent,
		Size = UDim2.new(1, -60, 0, 42),
		Position = UDim2.fromOffset(16, 10),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = offer,
	})
	local offerClose = UiKit.Create("TextButton", {
		Text = "X",
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = UiKit.Colors.Text,
		BackgroundColor3 = UiKit.Colors.Bad,
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.new(1, -46, 0, 10),
		Parent = offer,
	})
	UiKit.Corner(10).Parent = offerClose
	local offerLines = {
		{ Text = "💰  2,500 Coins", Color = UiKit.Colors.Accent },
		{ Text = "👑  A guaranteed SUNKEN CROWN relic", Color = Color3.fromRGB(60, 220, 130) },
		{ Text = "⚡  24 hours of 2x Coins", Color = Color3.fromRGB(120, 200, 255) },
		{ Text = "One-time offer — best value in the game!", Color = UiKit.Colors.TextDim },
	}
	for i, line in offerLines do
		UiKit.Label({
			Text = line.Text,
			Font = Enum.Font.GothamBold,
			TextColor3 = line.Color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -32, 0, 34),
			Position = UDim2.fromOffset(16, 56 + (i - 1) * 42),
			Parent = offer,
		})
	end
	local offerBuy = UiKit.Button({
		Text = "Buy  R$" .. Monetization.Products.StarterPack.Price,
		BackgroundColor3 = UiKit.Colors.Robux,
		Size = UDim2.new(1, -32, 0, 52),
		Position = UDim2.new(0, 16, 1, -66),
		Parent = offer,
	})
	offerBuy.Activated:Connect(function()
		Purchase.PromptProduct("StarterPack")
	end)
	offerClose.Activated:Connect(function()
		offer.Visible = false
	end)
	starter.Activated:Connect(function()
		offer.Visible = not offer.Visible
	end)
	starterOffer = offer

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
		if geodesLabel then
			geodesLabel.Text = "Chests: " .. state.Geodes .. " / " .. state.BackpackCapacity
		end
		if streakLabel then
			streakLabel.Text = "Streak: Day " .. state.Streak.Count
		end
		local badge = indexBadge
		if badge and state.TotalIndex then
			badge.Text = state.CollectionCount .. "/" .. state.TotalIndex
			-- Goes gold on the home stretch: "almost done" is worth more than a
			-- number, and it is true rather than manufactured.
			local remaining = state.TotalIndex - state.CollectionCount
			badge.BackgroundColor3 = if remaining <= 5 then UiKit.Colors.Accent else UiKit.Colors.Good
		end
		local packAvailable = not state.StarterPackOwned and Monetization.Products.StarterPack.Id ~= 0
		if starterButton then
			starterButton.Visible = packAvailable
		end
		if starterOffer and not packAvailable then
			starterOffer.Visible = false
		end
	end)

	RunService.Heartbeat:Connect(function(delta: number)
		local state = State.Get()
		if state and coinsLabel then
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
		end
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
