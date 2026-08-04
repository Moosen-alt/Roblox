--!strict
-- VIP stage teleport: buttons for every 10th cleared stage. Non-VIP players
-- see the grid too — tapping upsells the pass.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Remotes = require(Shared.Remotes)
local Purchase = require(script.Parent.Parent.Purchase)
local ScreenManager = require(script.Parent.Parent.ScreenManager)
local State = require(script.Parent.Parent.State)
local Toasts = require(script.Parent.Parent.Toasts)
local UiKit = require(script.Parent.Parent.UiKit)

local TeleportScreen = {}

local grid: ScrollingFrame? = nil

local function render()
	local state = State.Get()
	if not state or not grid then
		return
	end
	UiKit.Clear(grid)
	local isVip = state.Passes and state.Passes.Vip == true
	local order = 0
	for stage = 0, Balance.Stages, 10 do
		order += 1
		local reachable = stage <= state.Checkpoint
		local button = UiKit.Create("TextButton", {
			Text = stage == 0 and "Start" or tostring(stage),
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			TextColor3 = reachable and Color3.fromRGB(28, 24, 20) or UiKit.Colors.TextDim,
			BackgroundColor3 = reachable and (isVip and UiKit.Colors.Good or UiKit.Colors.Robux) or UiKit.Colors.BgLighter,
			AutoButtonColor = reachable,
			LayoutOrder = order,
			Parent = grid,
		})
		UiKit.Corner(10).Parent = button
		if reachable then
			local target = stage
			button.Activated:Connect(function()
				if not isVip then
					Purchase.PromptPass("Vip")
					return
				end
				local ok, err = Remotes.Function("TeleportStage"):InvokeServer(target)
				if not ok and typeof(err) == "string" then
					Toasts.Push(err, UiKit.Colors.Bad)
				end
			end)
		end
	end
	local layout = grid:FindFirstChildOfClass("UIGridLayout")
	if layout then
		grid.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 10)
	end
end

function TeleportScreen.Init(gui: ScreenGui)
	local panel, content, close = UiKit.Panel(gui, "Teleport (VIP)", UDim2.fromScale(0.5, 0.62))

	local scroll = UiKit.Create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UiKit.Colors.BgLight,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		Parent = content,
	}) :: ScrollingFrame
	UiKit.Corner(10).Parent = scroll
	UiKit.Pad(6).Parent = scroll
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.25, -8, 0, 52)
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	grid = scroll

	State.Changed:Connect(function()
		if panel.Visible then
			render()
		end
	end)

	ScreenManager.Register("Teleport", panel, close, render)
end

return TeleportScreen
