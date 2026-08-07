--!strict
-- Dock Master: buy new water, and sail to water you already own.
--
-- Every area is listed, including the ones you cannot afford. Seeing the Abyss
-- sitting there at three million coins with "12 species" beside it is the whole
-- point — a goal you can see the price of is worth more than one you unlock by
-- surprise, and unlike a rebirth gate this one can be saved toward directly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local ScreenManager = require(script.Parent.Parent.ScreenManager)
local State = require(script.Parent.Parent.State)
local Toasts = require(script.Parent.Parent.Toasts)
local UiKit = require(script.Parent.Parent.UiKit)

local DockScreen = {}

local list: ScrollingFrame? = nil

local function render()
	local state = State.Get()
	if not state or not list or not state.Areas then
		return
	end
	UiKit.Clear(list)
	for index, area in state.Areas do
		local current = index == state.AreaCurrent
		local card = UiKit.Create("Frame", {
			Size = UDim2.new(1, -6, 0, 74),
			BackgroundColor3 = current and UiKit.Colors.BgLighter or UiKit.Colors.BgLight,
			LayoutOrder = index,
			Parent = list,
		})
		UiKit.Corner(10).Parent = card
		if current then
			UiKit.Stroke(UiKit.Colors.Good, 2).Parent = card
		end

		UiKit.Label({
			Text = ("%d. %s"):format(index, area.Name),
			TextColor3 = area.Unlocked and UiKit.Colors.Text or UiKit.Colors.TextDim,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -150, 0, 28),
			Position = UDim2.fromOffset(10, 6),
			Parent = card,
		})
		-- A per-area species count gives each area its own ending. "37/120
		-- overall" never feels close to anything; "8/12 here" does.
		UiKit.Label({
			Text = if area.Unlocked
				then ("%d / %d species caught here"):format(area.Caught, area.Species)
				else ("%d species live here"):format(area.Species),
			Font = Enum.Font.Gotham,
			TextColor3 = UiKit.Colors.TextDim,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -150, 0, 24),
			Position = UDim2.fromOffset(10, 36),
			Parent = card,
		})

		local action = UiKit.Button({
			Text = "",
			Size = UDim2.fromOffset(130, 46),
			Position = UDim2.new(1, -140, 0, 14),
			Parent = card,
		})
		if current then
			action.Text = "Fishing here"
			action.BackgroundColor3 = UiKit.Colors.BgLighter
			action.TextColor3 = UiKit.Colors.TextDim
			action.Active = false
		elseif area.Unlocked then
			action.Text = "Sail here"
			action.BackgroundColor3 = UiKit.Colors.Good
			action.TextColor3 = Color3.fromRGB(25, 22, 18)
			action.Activated:Connect(function()
				local ok, err = Remotes.Function("TravelArea"):InvokeServer(index)
				if not ok and typeof(err) == "string" then
					Toasts.Push(err, UiKit.Colors.Bad)
				else
					ScreenManager.Close()
				end
			end)
		else
			local affordable = state.Coins >= area.Cost
			action.Text = Format.Number(area.Cost)
			action.BackgroundColor3 = affordable and UiKit.Colors.Accent or UiKit.Colors.BgLighter
			action.TextColor3 = affordable and Color3.fromRGB(28, 24, 20) or UiKit.Colors.TextDim
			action.Activated:Connect(function()
				local ok, err = Remotes.Function("BuyArea"):InvokeServer(index)
				if not ok and typeof(err) == "string" then
					Toasts.Push(err, UiKit.Colors.Bad)
				else
					ScreenManager.Close()
				end
			end)
		end
	end
	local layout = list:FindFirstChildOfClass("UIListLayout")
	if layout then
		list.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 10)
	end
end

function DockScreen.Init(gui: ScreenGui)
	local panel, content, close = UiKit.Panel(gui, "Dock Master", UDim2.fromScale(0.56, 0.72))

	UiKit.Label({
		Text = "Areas are yours forever — Set Sail never takes them back.",
		Font = Enum.Font.Gotham,
		TextColor3 = UiKit.Colors.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 26),
		Parent = content,
	})

	local scroll = UiKit.Create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -34),
		Position = UDim2.fromOffset(0, 30),
		BackgroundColor3 = UiKit.Colors.BgLight,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		Parent = content,
	}) :: ScrollingFrame
	UiKit.Corner(10).Parent = scroll
	UiKit.Pad(6).Parent = scroll
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	list = scroll

	State.Changed:Connect(function()
		if panel.Visible then
			render()
		end
	end)

	ScreenManager.Register("Dock", panel, close, render)
end

return DockScreen
