--!strict
-- Robux store: the 6-pass ladder + repeatable dev products. Offers whose IDs
-- aren't configured yet (0) are hidden.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monetization = require(Shared.Config.Monetization)
local Purchase = require(script.Parent.Parent.Purchase)
local ScreenManager = require(script.Parent.Parent.ScreenManager)
local State = require(script.Parent.Parent.State)
local UiKit = require(script.Parent.Parent.UiKit)

local StoreScreen = {}

local list: ScrollingFrame? = nil

local PASS_ORDER = { "SpeedCoil", "Coins2x", "JumpGain2x", "Vip", "MegaStart" }
local PRODUCT_ORDER = { "Skip1", "Skip10", "JumpBoost50", "InstantRebirth", "Coins1k", "Coins5k" }

local function addCard(order: number, title: string, desc: string, price: number, owned: boolean, onBuy: () -> ()): number
	if not list then
		return order
	end
	order += 1
	local card = UiKit.Create("Frame", {
		Size = UDim2.new(1, -6, 0, 66),
		BackgroundColor3 = UiKit.Colors.BgLighter,
		LayoutOrder = order,
		Parent = list,
	})
	UiKit.Corner(10).Parent = card
	UiKit.Label({
		Text = title,
		TextColor3 = UiKit.Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -150, 0, 28),
		Position = UDim2.fromOffset(10, 4),
		Parent = card,
	})
	UiKit.Label({
		Text = desc,
		Font = Enum.Font.Gotham,
		TextColor3 = UiKit.Colors.TextDim,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -150, 0, 30),
		Position = UDim2.fromOffset(10, 32),
		Parent = card,
	})
	local buy = UiKit.Create("TextButton", {
		Text = owned and "OWNED" or ("R$ " .. price),
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = owned and UiKit.Colors.Good or Color3.fromRGB(25, 22, 18),
		BackgroundColor3 = owned and UiKit.Colors.Bg or UiKit.Colors.Robux,
		AutoButtonColor = not owned,
		Size = UDim2.fromOffset(130, 42),
		Position = UDim2.new(1, -140, 0, 12),
		Parent = card,
	})
	UiKit.Corner(8).Parent = buy
	if not owned then
		buy.Activated:Connect(onBuy)
	end
	return order
end

local function addHeader(order: number, text: string): number
	if not list then
		return order
	end
	order += 1
	UiKit.Create("TextLabel", {
		Text = text,
		Font = Enum.Font.FredokaOne,
		TextColor3 = UiKit.Colors.Accent,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -6, 0, 30),
		LayoutOrder = order,
		Parent = list,
	})
	return order
end

local function render()
	local state = State.Get()
	if not list then
		return
	end
	UiKit.Clear(list)
	local order = 0
	local anyConfigured = false

	order = addHeader(order, "Gamepasses")
	for _, key in PASS_ORDER do
		local def = (Monetization.Gamepasses :: any)[key]
		if def.Id ~= 0 then
			anyConfigured = true
			local owned = state and state.Passes and state.Passes[key] == true
			local passKey = key
			order = addCard(order, def.Title, def.Desc or "", def.Price, owned or false, function()
				Purchase.PromptPass(passKey)
			end)
		end
	end

	order = addHeader(order, "Skips & Coins")
	for _, key in PRODUCT_ORDER do
		local def = (Monetization.Products :: any)[key]
		if def.Id ~= 0 then
			if key == "StarterPack" and state and state.StarterPackOwned then
				continue
			end
			anyConfigured = true
			local desc = def.Desc or (def.Coins and ("+" .. def.Coins .. " coins") or "")
			local productKey = key
			order = addCard(order, def.Title, desc, def.Price, false, function()
				Purchase.PromptProduct(productKey)
			end)
		end
	end

	if not anyConfigured then
		order += 1
		UiKit.Create("TextLabel", {
			Text = "Store offers appear once gamepass/product IDs are set in Config/Monetization.luau (see SETUP.md).",
			Font = Enum.Font.Gotham,
			TextColor3 = UiKit.Colors.TextDim,
			TextWrapped = true,
			TextScaled = false,
			TextSize = 18,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -6, 0, 60),
			LayoutOrder = order,
			Parent = list,
		})
	end

	local layout = list:FindFirstChildOfClass("UIListLayout")
	if layout then
		list.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 10)
	end
end

function StoreScreen.Init(gui: ScreenGui)
	local panel, content, close = UiKit.Panel(gui, "Store", UDim2.fromScale(0.58, 0.78))

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

	ScreenManager.Register("Store", panel, close, render)
end

return StoreScreen
