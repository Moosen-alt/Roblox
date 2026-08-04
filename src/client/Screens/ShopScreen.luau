--!strict
-- Geode Shop: clock-synced stock with restock countdown, per-item odds display
-- for random-content offers (compliance), daily deal, and coin upgrades.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Purchase = require(script.Parent.Parent.Purchase)
local ScreenManager = require(script.Parent.Parent.ScreenManager)
local State = require(script.Parent.Parent.State)
local Toasts = require(script.Parent.Parent.Toasts)
local UiKit = require(script.Parent.Parent.UiKit)

local ShopScreen = {}

local stockList: ScrollingFrame? = nil
local timerLabel: TextLabel? = nil
local panelRef: Frame? = nil
local restockAt = 0
local lastRenderedWindow = -1

local function renderStock()
	if not stockList then
		return
	end
	local stock = Remotes.Function("GetShopStock"):InvokeServer()
	if typeof(stock) ~= "table" then
		return
	end
	restockAt = stock.RestockAt or 0
	UiKit.Clear(stockList)
	local order = 0

	for index, item in stock.Items :: { any } do
		order += 1
		local card = UiKit.Create("Frame", {
			Size = UDim2.new(1, -6, 0, item.Odds and 118 or 64),
			BackgroundColor3 = item.DailyDeal and Color3.fromRGB(66, 52, 24) or UiKit.Colors.BgLighter,
			LayoutOrder = order,
			Parent = stockList,
		})
		UiKit.Corner(10).Parent = card
		if item.DailyDeal then
			UiKit.Stroke(UiKit.Colors.Accent, 2).Parent = card
		end
		UiKit.Label({
			Text = (item.DailyDeal and "DAILY DEAL!  " or "") .. item.Title,
			TextColor3 = item.DailyDeal and UiKit.Colors.Accent or UiKit.Colors.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -140, 0, 26),
			Position = UDim2.fromOffset(10, 4),
			Parent = card,
		})
		local subtitle = ""
		if item.Kind == "Crystal" then
			subtitle = "Exactly this crystal, value " .. Format.Number(item.Value or 0)
		elseif item.Kind == "PremiumGeode" then
			subtitle = "Cracks instantly with 3x luck"
		elseif item.Kind == "GeodeBundle" then
			subtitle = "Three uncracked geodes"
		elseif item.Kind == "Geode" then
			subtitle = "One uncracked geode"
		end
		UiKit.Label({
			Text = subtitle,
			Font = Enum.Font.Gotham,
			TextColor3 = UiKit.Colors.TextDim,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -140, 0, 20),
			Position = UDim2.fromOffset(10, 30),
			Parent = card,
		})
		if item.Odds then
			local oddsText = {}
			for _, entry in item.Odds :: { any } do
				table.insert(oddsText, entry.Name .. " " .. Format.Percent(entry.Chance))
			end
			UiKit.Label({
				Text = "Odds: " .. table.concat(oddsText, "  •  "),
				Font = Enum.Font.Gotham,
				TextColor3 = UiKit.Colors.TextDim,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Size = UDim2.new(1, -20, 0, 58),
				Position = UDim2.fromOffset(10, 54),
				Parent = card,
			})
		end
		local buy = UiKit.Create("TextButton", {
			Text = Format.Number(item.Cost) .. " coins",
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			TextColor3 = Color3.fromRGB(25, 22, 18),
			BackgroundColor3 = UiKit.Colors.Buy,
			Size = UDim2.fromOffset(120, 40),
			Position = UDim2.new(1, -130, 0, 12),
			Parent = card,
		})
		UiKit.Corner(8).Parent = buy
		local itemIndex = index
		buy.Activated:Connect(function()
			local ok, err = Remotes.Function("BuyShopItem"):InvokeServer(itemIndex)
			if ok then
				Toasts.Push("Purchased " .. item.Title .. "!", UiKit.Colors.Good)
				renderStock()
			elseif typeof(err) == "string" then
				Toasts.Push(err, UiKit.Colors.Bad)
			end
		end)
	end

	-- Upgrades (pickaxe/backpack) live at the bottom of the shop.
	local state = State.Get()
	if state then
		local upgrades = {}
		if state.NextPickaxe then
			table.insert(upgrades, {
				Title = "Pickaxe: " .. state.NextPickaxe.Name,
				Sub = "Damage " .. state.Pickaxe.Damage .. " -> " .. state.NextPickaxe.Damage,
				Cost = state.NextPickaxe.Cost,
				Kind = "Pickaxe",
			})
		end
		if state.NextBackpack then
			table.insert(upgrades, {
				Title = "Backpack: " .. state.NextBackpack.Name,
				Sub = "Capacity " .. state.BackpackCapacity .. " -> " .. state.NextBackpack.Capacity,
				Cost = state.NextBackpack.Cost,
				Kind = "Backpack",
			})
		end
		for _, upgrade in upgrades do
			order += 1
			local card = UiKit.Create("Frame", {
				Size = UDim2.new(1, -6, 0, 64),
				BackgroundColor3 = UiKit.Colors.BgLight,
				LayoutOrder = order,
				Parent = stockList,
			})
			UiKit.Corner(10).Parent = card
			UiKit.Label({
				Text = upgrade.Title,
				TextColor3 = UiKit.Colors.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, -140, 0, 26),
				Position = UDim2.fromOffset(10, 4),
				Parent = card,
			})
			UiKit.Label({
				Text = upgrade.Sub,
				Font = Enum.Font.Gotham,
				TextColor3 = UiKit.Colors.TextDim,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, -140, 0, 20),
				Position = UDim2.fromOffset(10, 30),
				Parent = card,
			})
			local buy = UiKit.Create("TextButton", {
				Text = Format.Number(upgrade.Cost) .. " coins",
				Font = Enum.Font.FredokaOne,
				TextScaled = true,
				TextColor3 = Color3.fromRGB(25, 22, 18),
				BackgroundColor3 = UiKit.Colors.Buy,
				Size = UDim2.fromOffset(120, 40),
				Position = UDim2.new(1, -130, 0, 12),
				Parent = card,
			})
			UiKit.Corner(8).Parent = buy
			local kind = upgrade.Kind
			buy.Activated:Connect(function()
				local ok, err = Remotes.Function("BuyUpgrade"):InvokeServer(kind)
				if ok then
					Toasts.Push("Upgraded!", UiKit.Colors.Good)
					renderStock()
				elseif typeof(err) == "string" then
					Toasts.Push(err, UiKit.Colors.Bad)
				end
			end)
		end
	end

	local layout = stockList:FindFirstChildOfClass("UIListLayout")
	if layout then
		stockList.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 10)
	end
end

function ShopScreen.Init(gui: ScreenGui)
	local panel, content, close = UiKit.Panel(gui, "Geode Shop", UDim2.fromScale(0.6, 0.78))
	panelRef = panel

	local timer = UiKit.Label({
		Text = "Restock in --:--",
		TextColor3 = UiKit.Colors.Good,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(0.6, 0, 0, 30),
		Parent = content,
	}) :: TextLabel
	timerLabel = timer

	local restockNow = UiKit.Button({
		Text = "Restock Now (R$)",
		BackgroundColor3 = UiKit.Colors.Robux,
		Size = UDim2.fromOffset(170, 34),
		Position = UDim2.new(1, -176, 0, 0),
		Parent = content,
	})
	restockNow.Activated:Connect(function()
		Purchase.PromptProduct("InstantRestock")
	end)

	local stock = UiKit.Create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -44),
		Position = UDim2.fromOffset(0, 40),
		BackgroundColor3 = UiKit.Colors.BgLight,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		Parent = content,
	}) :: ScrollingFrame
	UiKit.Corner(10).Parent = stock
	UiKit.Pad(6).Parent = stock
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = stock
	stockList = stock

	-- Countdown + auto-refresh when the restock window flips.
	RunService.Heartbeat:Connect(function()
		local label = timerLabel
		if not panel.Visible or not label then
			return
		end
		local remaining = restockAt - os.time()
		label.Text = "Restock in " .. Format.Clock(remaining)
		local window = os.time() // 300
		if remaining <= 0 and window ~= lastRenderedWindow then
			lastRenderedWindow = window
			renderStock()
		end
	end)

	ScreenManager.Register("Shop", panel, close, function()
		lastRenderedWindow = os.time() // 300
		renderStock()
	end)
end

local _ = panelRef

return ShopScreen
