--!strict
-- Toast notifications (Notify), auto-crack result toasts, and the welcome-back
-- popup (streak + offline earnings) — the daily dopamine moment.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crystals = require(Shared.Config.Crystals)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local UiKit = require(script.Parent.UiKit)

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

local function showWelcome(report: { [string]: any })
	if not gui then
		return
	end
	local lines = {}
	local streak = report.Streak
	if streak then
		local streakLine = ("Day %d streak! +%s coins"):format(streak.Count, Format.Number(streak.Reward))
		if streak.Milestone then
			streakLine ..= "  (MILESTONE!)"
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
			("While you were away (%s): your racks grew +%s coins — collect them!"):format(
				Format.Duration(offline.OfflineSeconds),
				Format.Number(offline.PendingCoins)
			)
		)
	end
	if #lines == 0 then
		return
	end

	local popup = UiKit.Create("Frame", {
		Size = UDim2.fromOffset(420, 90 + #lines * 34),
		Position = UDim2.fromScale(0.5, 0.32),
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
	local okButton = UiKit.Button({
		Text = "Let's mine!",
		Size = UDim2.fromOffset(160, 38),
		Position = UDim2.new(0.5, -80, 1, -46),
		Parent = popup,
	})
	okButton.Activated:Connect(function()
		popup:Destroy()
	end)
	task.delay(12, function()
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
			local label = isAuto and "Auto-Crack: " or "Found: "
			pushToast(label .. mutPrefix .. crystal.Base .. " (+" .. Format.Number(crystal.Value) .. ")", tierColor)
		end
	end)

	Remotes.Event("WelcomeReport").OnClientEvent:Connect(function(report)
		if typeof(report) == "table" then
			showWelcome(report)
		end
	end)
end

return Toasts
