--!strict
-- Today's three objectives, with a progress bar each and a claim button.
--
-- The bar is the point. A number ("12 / 25") tells you where you are; a bar
-- that is two-thirds full tells you you are nearly there, which is the thing
-- that gets one more cast out of somebody. Everything else on this screen is
-- deliberately quiet so the bars carry it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local ScreenManager = require(script.Parent.Parent.ScreenManager)
local State = require(script.Parent.Parent.State)
local UiKit = require(script.Parent.Parent.UiKit)

local QuestsScreen = {}

local list: Frame? = nil
local subtitle: TextLabel? = nil

local function render()
	local state = State.Get()
	local holder = list
	if not state or not holder then
		return
	end
	UiKit.Clear(holder)

	local quests = state.Quests or {}
	local done = 0
	for _, quest in quests do
		if quest.Claimed then
			done += 1
		end
	end
	if subtitle then
		subtitle.Text = ("%d / %d claimed today — they reset tomorrow"):format(done, #quests)
	end

	for order, quest in quests do
		local ready = quest.Progress >= quest.Target and not quest.Claimed
		local row = UiKit.Create("Frame", {
			BackgroundColor3 = if quest.Claimed then UiKit.Colors.Bg else UiKit.Colors.BgLighter,
			Size = UDim2.new(1, 0, 0, 74),
			LayoutOrder = order,
			Parent = holder,
		})
		UiKit.Corner(10).Parent = row
		if ready then
			-- Only the claimable one gets an outline. Three highlighted rows
			-- highlight nothing.
			UiKit.Stroke(UiKit.Colors.Accent, 2).Parent = row
		end

		UiKit.Label({
			Text = quest.Text,
			Font = Enum.Font.GothamBold,
			TextColor3 = if quest.Claimed then UiKit.Colors.TextDim else UiKit.Colors.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -140, 0, 24),
			Position = UDim2.fromOffset(12, 8),
			Parent = row,
		})

		-- Progress track and fill.
		local track = UiKit.Create("Frame", {
			BackgroundColor3 = UiKit.Colors.Bg,
			Size = UDim2.new(1, -150, 0, 16),
			Position = UDim2.fromOffset(12, 40),
			Parent = row,
		})
		UiKit.Corner(8).Parent = track
		local fraction = if quest.Target > 0 then math.clamp(quest.Progress / quest.Target, 0, 1) else 0
		local fill = UiKit.Create("Frame", {
			BackgroundColor3 = if quest.Claimed then UiKit.Colors.TextDim else UiKit.Colors.Good,
			Size = UDim2.fromScale(fraction, 1),
			Parent = track,
		})
		UiKit.Corner(8).Parent = fill
		UiKit.Label({
			Text = ("%d / %d"):format(quest.Progress, quest.Target),
			Font = Enum.Font.GothamBold,
			TextColor3 = UiKit.Colors.Text,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 3,
			Parent = track,
		})

		if quest.Claimed then
			UiKit.Label({
				Text = "CLAIMED",
				Font = Enum.Font.FredokaOne,
				TextColor3 = UiKit.Colors.TextDim,
				Size = UDim2.fromOffset(120, 40),
				Position = UDim2.new(1, -132, 0, 17),
				Parent = row,
			})
		else
			local button = UiKit.Create("TextButton", {
				Text = if ready then ("CLAIM %d"):format(quest.Reward) else ("%d coins"):format(quest.Reward),
				Font = Enum.Font.FredokaOne,
				TextScaled = true,
				TextColor3 = if ready then Color3.fromRGB(28, 24, 20) else UiKit.Colors.TextDim,
				BackgroundColor3 = if ready then UiKit.Colors.Accent else UiKit.Colors.Bg,
				Size = UDim2.fromOffset(120, 40),
				Position = UDim2.new(1, -132, 0, 17),
				Parent = row,
			})
			UiKit.Corner(10).Parent = button
			UiKit.Pad(6).Parent = button
			button.Active = ready
			button.AutoButtonColor = ready
			if ready then
				local index = quest.Index
				button.Activated:Connect(function()
					button.Active = false
					Remotes.Function("ClaimQuest"):InvokeServer(index)
				end)
			end
		end
	end

	local layout = holder:FindFirstChildOfClass("UIListLayout")
	if layout and holder:IsA("ScrollingFrame") then
		holder.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 10)
	end
end

function QuestsScreen.Init(gui: ScreenGui)
	local panel, content, close = UiKit.Panel(gui, "Today's Catch List", UDim2.fromScale(0.6, 0.62))

	subtitle = UiKit.Label({
		Text = "",
		TextColor3 = UiKit.Colors.Good,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 26),
		Parent = content,
	}) :: TextLabel

	local holder = UiKit.Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -34),
		Position = UDim2.fromOffset(0, 34),
		Parent = content,
	}) :: Frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder
	list = holder

	-- Register wires the close button itself; the fourth argument runs on open.
	ScreenManager.Register("Quests", panel, close, render)
	State.Changed:Connect(function()
		if panel.Visible then
			render()
		end
	end)
end

return QuestsScreen
