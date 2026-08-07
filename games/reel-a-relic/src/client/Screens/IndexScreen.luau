--!strict
-- Collection index: every species x 6 auras. Completion is a core daily-return
-- hook, so undiscovered cells tease with "?".
--
-- Discovered cells also carry the heaviest one you have ever landed. That is the
-- part that never finishes: the grid can be completed, a personal best cannot,
-- and it costs a line of text to give a finished collection somewhere to go.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crystals = require(Shared.Config.Crystals)
local ScreenManager = require(script.Parent.Parent.ScreenManager)
local State = require(script.Parent.Parent.State)
local UiKit = require(script.Parent.Parent.UiKit)

local IndexScreen = {}

local grid: ScrollingFrame? = nil
local headerLabel: TextLabel? = nil

local function render()
	local state = State.Get()
	if not state or not grid then
		return
	end
	if headerLabel then
		headerLabel.Text = ("Collection: %d / %d"):format(state.CollectionCount, state.TotalIndex)
	end
	UiKit.Clear(grid)
	local order = 0
	for _, base in Crystals.Bases do
		for _, mutName in Crystals.MutationNames do
			order += 1
			local key = Crystals.IndexKey(base.Name, mutName)
			local discovered = state.Collection[key] == true
			local mutDef = Crystals.GetMutation(mutName)
			local cell = UiKit.Create("Frame", {
				BackgroundColor3 = discovered and UiKit.Colors.BgLighter or UiKit.Colors.Bg,
				LayoutOrder = order,
				Parent = grid,
			})
			UiKit.Corner(8).Parent = cell
			if discovered then
				UiKit.Stroke(base.Color, 2).Parent = cell
				local gem = UiKit.Create("Frame", {
					Size = UDim2.fromScale(0.3, 0.3),
					Position = UDim2.fromScale(0.5, 0.26),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = mutDef and mutDef.Color or base.Color,
					Rotation = 45,
					Parent = cell,
				})
				UiKit.Corner(6).Parent = gem
				UiKit.Label({
					Text = (mutName ~= "Normal" and (mutName .. " ") or "") .. base.Name,
					Font = Enum.Font.GothamBold,
					TextColor3 = UiKit.Colors.Text,
					TextWrapped = true,
					Size = UDim2.new(1, -6, 0.36, 0),
					Position = UDim2.fromScale(0.5, 0.64),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Parent = cell,
				})
				-- Keyed by species alone, so every aura of a bass shows the same
				-- "biggest bass" — which is the record an angler actually tracks.
				local best = state.BestWeight and state.BestWeight[base.Name]
				UiKit.Label({
					Text = best and ("Best %.1f lb"):format(best) or "",
					Font = Enum.Font.Gotham,
					TextColor3 = UiKit.Colors.Accent,
					Size = UDim2.new(1, -6, 0.2, 0),
					Position = UDim2.fromScale(0.5, 0.89),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Parent = cell,
				})
			else
				UiKit.Label({
					Text = "?",
					Font = Enum.Font.FredokaOne,
					TextColor3 = UiKit.Colors.TextDim,
					Size = UDim2.fromScale(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Parent = cell,
				})
			end
		end
	end
	local layout = grid:FindFirstChildOfClass("UIGridLayout")
	if layout then
		grid.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 10)
	end
end

function IndexScreen.Init(gui: ScreenGui)
	local panel, content, close = UiKit.Panel(gui, "Fish Index", UDim2.fromScale(0.68, 0.8))

	headerLabel = UiKit.Label({
		Text = "Collection: 0 / 0",
		TextColor3 = UiKit.Colors.Good,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 28),
		Parent = content,
	}) :: TextLabel

	local scroll = UiKit.Create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -36),
		Position = UDim2.fromOffset(0, 32),
		BackgroundColor3 = UiKit.Colors.BgLight,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		Parent = content,
	}) :: ScrollingFrame
	UiKit.Corner(10).Parent = scroll
	UiKit.Pad(6).Parent = scroll
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(1 / 6, -8, 0, 104)
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	grid = scroll

	State.Changed:Connect(function()
		if panel.Visible then
			render()
		end
	end)

	ScreenManager.Register("Index", panel, close, render)
end

return IndexScreen
