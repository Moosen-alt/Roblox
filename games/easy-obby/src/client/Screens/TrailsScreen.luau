--!strict
-- Trail shop: the coin sink. Rainbow is VIP-only and upsells the pass.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Purchase = require(script.Parent.Parent.Purchase)
local ScreenManager = require(script.Parent.Parent.ScreenManager)
local State = require(script.Parent.Parent.State)
local Toasts = require(script.Parent.Parent.Toasts)
local UiKit = require(script.Parent.Parent.UiKit)

local TrailsScreen = {}

local list: ScrollingFrame? = nil

local function invoke(name: string, ...: any)
	local ok, err = Remotes.Function(name):InvokeServer(...)
	if not ok and typeof(err) == "string" then
		Toasts.Push(err, UiKit.Colors.Bad)
	end
	return ok
end

local function render()
	local state = State.Get()
	if not state or not list then
		return
	end
	UiKit.Clear(list)
	local order = 0

	local function addCard(name: string, color: Color3, costText: string, owned: boolean, equipped: boolean, onAction: () -> ())
		order += 1
		local card = UiKit.Create("Frame", {
			Size = UDim2.new(1, -6, 0, 56),
			BackgroundColor3 = UiKit.Colors.BgLighter,
			LayoutOrder = order,
			Parent = list,
		})
		UiKit.Corner(10).Parent = card
		local swatch = UiKit.Create("Frame", {
			Size = UDim2.fromOffset(36, 36),
			Position = UDim2.fromOffset(10, 10),
			BackgroundColor3 = color,
			Parent = card,
		})
		UiKit.Corner(8).Parent = swatch
		UiKit.Label({
			Text = name,
			TextColor3 = UiKit.Colors.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -200, 1, -16),
			Position = UDim2.fromOffset(56, 8),
			Parent = card,
		})
		local action = UiKit.Create("TextButton", {
			Text = equipped and "EQUIPPED" or (owned and "Equip" or costText),
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			TextColor3 = equipped and UiKit.Colors.Good or Color3.fromRGB(25, 22, 18),
			BackgroundColor3 = equipped and UiKit.Colors.Bg or (owned and UiKit.Colors.Good or UiKit.Colors.Accent),
			AutoButtonColor = not equipped,
			Size = UDim2.fromOffset(130, 38),
			Position = UDim2.new(1, -140, 0, 9),
			Parent = card,
		})
		UiKit.Corner(8).Parent = action
		if not equipped then
			action.Activated:Connect(onAction)
		end
	end

	-- VIP Rainbow at the top
	local isVip = state.Passes and state.Passes.Vip
	addCard(
		"Rainbow (VIP)",
		Color3.fromRGB(255, 170, 220),
		"VIP",
		isVip == true,
		state.EquippedTrail == "Rainbow",
		function()
			if isVip then
				invoke("EquipTrail", "Rainbow")
			else
				Purchase.PromptPass("Vip")
			end
		end
	)

	for _, trail in Balance.Trails do
		local owned = state.Trails[trail.Name] == true
		local trailName = trail.Name
		addCard(
			trail.Name,
			trail.Color,
			Format.Number(trail.Cost) .. " coins",
			owned,
			state.EquippedTrail == trail.Name,
			function()
				if owned then
					invoke("EquipTrail", trailName)
				else
					if invoke("BuyTrail", trailName) then
						Toasts.Push(trailName .. " trail unlocked!", UiKit.Colors.Good)
						invoke("EquipTrail", trailName)
					end
				end
			end
		)
	end

	-- Unequip row
	if state.EquippedTrail ~= "" then
		order += 1
		local clear = UiKit.Button({
			Text = "Remove trail",
			BackgroundColor3 = UiKit.Colors.BgLight,
			TextColor3 = UiKit.Colors.TextDim,
			Size = UDim2.new(1, -6, 0, 40),
			Parent = list,
		})
		clear.LayoutOrder = order
		clear.Activated:Connect(function()
			invoke("EquipTrail", "")
		end)
	end

	local layout = list:FindFirstChildOfClass("UIListLayout")
	if layout then
		list.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 10)
	end
end

function TrailsScreen.Init(gui: ScreenGui)
	local panel, content, close = UiKit.Panel(gui, "Trails", UDim2.fromScale(0.52, 0.78))

	local scroll = UiKit.Create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
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

	ScreenManager.Register("Trails", panel, close, render)
end

return TrailsScreen
