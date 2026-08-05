--!strict
-- Toast notifications (Notify), auto-crack result toasts, and the welcome-back
-- popup (streak + offline earnings) — the daily dopamine moment.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Crystals = require(Shared.Config.Crystals)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local UiKit = require(script.Parent.UiKit)
local WorldFx = require(script.Parent.WorldFx)

local Toasts = {}

local container: Frame? = nil
local gui: ScreenGui? = nil

local function pushToast(text: string, color: Color3?)
	if not container then
		return
	end
	local toast = UiKit.Create("TextLabel", {
		Text = text,
		Font = Enum.Font.GothamBold,
		TextColor3 = color or UiKit.Colors.Text,
		TextScaled = true,
		BackgroundColor3 = UiKit.Colors.Bg,
		BackgroundTransparency = 0.15,
		Size = UDim2.new(1, 0, 0, 34),
		Parent = container,
	})
	UiKit.Corner(8).Parent = toast
	UiKit.Stroke(color or UiKit.Colors.BgLighter, 1).Parent = toast
	UiKit.Pad(6).Parent = toast
	task.delay(3.2, function()
		local tween = TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		toast:Destroy()
	end)
end

Toasts.Push = pushToast

-- Server-wide rare-find callout. This is the game's status economy: pulling a
-- Mythic in front of 14 other people is worth more than the coins are, and
-- seeing someone else's callout is the most convincing possible proof that the
-- rare stuff is really in there.
local function showRareFind(payload: { [string]: any })
	if not gui then
		return
	end
	local color = typeof(payload.Color) == "Color3" and payload.Color or UiKit.Colors.Accent
	local mine = payload.Player == Players.LocalPlayer.DisplayName
	local rank = tonumber(payload.Rank) or 5

	local banner = UiKit.Create("Frame", {
		Size = UDim2.fromOffset(0, 62),
		Position = UDim2.new(0.5, 0, 0, 96),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = UiKit.Colors.Bg,
		BackgroundTransparency = 0.08,
		ZIndex = 20,
		Parent = gui,
	})
	UiKit.Corner(14).Parent = banner
	local stroke = UiKit.Stroke(color, 3)
	stroke.Parent = banner
	UiKit.Label({
		Text = mine and "★  YOU REELED IN A " .. string.upper(payload.Label or "") .. "!  ★"
			or ((payload.Player or "Someone") .. " reeled in a " .. (payload.Label or "relic") .. "!"),
		Font = Enum.Font.FredokaOne,
		TextColor3 = color,
		Size = UDim2.new(1, -20, 0, 34),
		Position = UDim2.fromOffset(10, 6),
		ZIndex = 21,
		Parent = banner,
	})
	UiKit.Label({
		Text = (payload.Tier or "Legendary") .. "  •  worth " .. Format.Number(tonumber(payload.Value) or 0),
		Font = Enum.Font.GothamBold,
		TextColor3 = UiKit.Colors.TextDim,
		Size = UDim2.new(1, -20, 0, 18),
		Position = UDim2.fromOffset(10, 38),
		ZIndex = 21,
		Parent = banner,
	})

	TweenService:Create(banner, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(mine and 560 or 480, 62),
	}):Play()
	TweenService:Create(
		stroke,
		TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 6, true),
		{ Thickness = 7 }
	):Play()
	WorldFx.Shake(mine and 1.6 or 0.5)

	for i, pitch in { 0.7, 1.05, 1.4, 1.85 } do
		task.delay((i - 1) * 0.09, function()
			if not banner.Parent then
				return
			end
			local sting = Instance.new("Sound")
			sting.SoundId = "rbxasset://sounds/electronicpingshort.wav"
			sting.PlaybackSpeed = pitch
			sting.Volume = rank >= 6 and 0.8 or 0.55
			sting.Parent = banner
			sting:Play()
		end)
	end

	task.delay(mine and 6 or 4.5, function()
		if not banner.Parent then
			return
		end
		local fade = TweenService:Create(banner, TweenInfo.new(0.35), { BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 62) })
		fade:Play()
		fade.Completed:Wait()
		banner:Destroy()
	end)
end

local function showWelcome(report: { [string]: any })
	if not gui then
		return
	end
	local lines = {}
	local streak = report.Streak
	if streak then
		local streakLine = ("Day %d streak! +%s coins"):format(streak.Count, Format.Number(streak.Reward))
		if streak.Premium then
			streakLine ..= "  + a FREE Golden Chest!"
		end
		if streak.GroupBonus then
			streakLine ..= "  (2x group bonus)"
		end
		table.insert(lines, streakLine)
		if streak.StreakLost then
			table.insert(lines, "Your old streak expired — new streak started!")
		end
	end
	local offline = report.Offline
	if offline and offline.PendingCoins > 0 then
		table.insert(
			lines,
			("While you were away (%s): your aquarium earned +%s coins — collect them!"):format(
				Format.Duration(offline.OfflineSeconds),
				Format.Number(offline.PendingCoins)
			)
		)
	end
	if #lines == 0 then
		return
	end

	local calendarHeight = streak and 92 or 0
	local popup = UiKit.Create("Frame", {
		Size = UDim2.fromOffset(470, 96 + #lines * 34 + calendarHeight),
		Position = UDim2.fromScale(0.5, 0.34),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = UiKit.Colors.Bg,
		Parent = gui,
	})
	UiKit.Corner(14).Parent = popup
	UiKit.Stroke(UiKit.Colors.Accent, 3).Parent = popup
	UiKit.Label({
		Text = "Welcome back!",
		Font = Enum.Font.FredokaOne,
		TextColor3 = UiKit.Colors.Accent,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 8),
		Parent = popup,
	})
	for i, line in lines do
		UiKit.Label({
			Text = line,
			TextColor3 = UiKit.Colors.Text,
			Font = Enum.Font.GothamBold,
			TextWrapped = true,
			Size = UDim2.new(1, -24, 0, 30),
			Position = UDim2.fromOffset(12, 48 + (i - 1) * 34),
			Parent = popup,
		})
	end

	-- The visible 7-day cycle: tomorrow's reward is always on screen.
	if streak then
		local cycleDay = ((streak.Count - 1) % #Balance.StreakCycle) + 1
		local calendar = UiKit.Create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -20, 0, 78),
			Position = UDim2.fromOffset(10, 48 + #lines * 34 + 6),
			Parent = popup,
		})
		local cellWidth = 60
		for day, reward in Balance.StreakCycle do
			local isToday = day == cycleDay
			local isPast = day < cycleDay
			local cell = UiKit.Create("Frame", {
				Size = UDim2.fromOffset(cellWidth, 74),
				Position = UDim2.fromOffset((day - 1) * (cellWidth + 4), 0),
				BackgroundColor3 = isToday and UiKit.Colors.BgLighter or UiKit.Colors.BgLight,
				BackgroundTransparency = isPast and 0.5 or 0,
				Parent = calendar,
			})
			UiKit.Corner(8).Parent = cell
			if isToday then
				UiKit.Stroke(UiKit.Colors.Accent, 2).Parent = cell
			end
			UiKit.Label({
				Text = "Day " .. day,
				Font = Enum.Font.GothamBold,
				TextColor3 = isToday and UiKit.Colors.Accent or UiKit.Colors.TextDim,
				Size = UDim2.new(1, -4, 0, 20),
				Position = UDim2.fromOffset(2, 4),
				Parent = cell,
			})
			UiKit.Label({
				Text = isPast and "✓" or (reward.PremiumGeode and "💎 OP!" or Format.Number(reward.Coins)),
				Font = Enum.Font.FredokaOne,
				TextColor3 = reward.PremiumGeode and Color3.fromRGB(255, 140, 255) or UiKit.Colors.Text,
				Size = UDim2.new(1, -4, 0, 34),
				Position = UDim2.fromOffset(2, 28),
				Parent = cell,
			})
		end
	end

	local okButton = UiKit.Button({
		Text = "Let's fish!",
		Size = UDim2.fromOffset(160, 38),
		Position = UDim2.new(0.5, -80, 1, -46),
		Parent = popup,
	})
	okButton.Activated:Connect(function()
		popup:Destroy()
	end)
	task.delay(15, function()
		if popup.Parent then
			popup:Destroy()
		end
	end)
end

function Toasts.Init(screenGui: ScreenGui)
	gui = screenGui
	container = UiKit.Create("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(360, 220),
		Position = UDim2.new(0.5, -180, 0, 8),
		Parent = screenGui,
	}) :: Frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Parent = container

	Remotes.Event("Notify").OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" and typeof(payload.Text) == "string" then
			pushToast(payload.Text, payload.Color)
		end
	end)

	-- Auto-crack results arrive here (quiet toast instead of the full reveal).
	Remotes.Event("CrackResult").OnClientEvent:Connect(function(results, isAuto)
		if typeof(results) ~= "table" then
			return
		end
		for _, crystal in results do
			local tierColor = Crystals.TierColors[crystal.Tier] or UiKit.Colors.Text
			local mutPrefix = crystal.Mut ~= "Normal" and (crystal.Mut .. " ") or ""
			local label = isAuto and "Auto-Open: " or "Caught: "
			pushToast(label .. mutPrefix .. crystal.Base .. " (+" .. Format.Number(crystal.Value) .. ")", tierColor)
		end
	end)

	Remotes.Event("RareFind").OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" then
			showRareFind(payload)
		end
	end)

	Remotes.Event("WelcomeReport").OnClientEvent:Connect(function(report)
		if typeof(report) == "table" then
			showWelcome(report)
		end
	end)
end

return Toasts
