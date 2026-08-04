--!strict
-- Crystal Racks: socket crystals to earn coins over time (incl. offline),
-- manage inventory, sell.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crystals = require(Shared.Config.Crystals)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Purchase = require(script.Parent.Parent.Purchase)
local ScreenManager = require(script.Parent.Parent.ScreenManager)
local State = require(script.Parent.Parent.State)
local Toasts = require(script.Parent.Parent.Toasts)
local UiKit = require(script.Parent.Parent.UiKit)

local RacksScreen = {}

local rackList: ScrollingFrame? = nil
local invList: ScrollingFrame? = nil
local collectButton: TextButton? = nil
local panelRef: Frame? = nil

local function invoke(name: string, ...: any)
	local ok, err = Remotes.Function(name):InvokeServer(...)
	if not ok and typeof(err) == "string" then
		Toasts.Push(err, UiKit.Colors.Bad)
	end
end

local function smallButton(text: string, color: Color3, parent: Instance): TextButton
	local button = UiKit.Create("TextButton", {
		Text = text,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(25, 22, 18),
		BackgroundColor3 = color,
		Size = UDim2.fromOffset(74, 30),
		Parent = parent,
	})
	UiKit.Corner(8).Parent = button
	return button
end

local function crystalTitle(crystal: { [string]: any }): (string, Color3)
	local baseDef = Crystals.GetBase(crystal.Base)
	local mutPrefix = crystal.Mut ~= "Normal" and (crystal.Mut .. " ") or ""
	return mutPrefix .. crystal.Base, baseDef and baseDef.Color or UiKit.Colors.Text
end

local function render()
	local state = State.Get()
	if not state or not rackList or not invList then
		return
	end

	-- Racks
	UiKit.Clear(rackList)
	local pendingTotal = 0
	local socketedIds: { [string]: boolean } = {}
	for slot = 1, state.RackSlots do
		local rack = state.Racks[tostring(slot)]
		local row = UiKit.Create("Frame", {
			Size = UDim2.new(1, -6, 0, 44),
			BackgroundColor3 = UiKit.Colors.BgLighter,
			LayoutOrder = slot,
			Parent = rackList,
		})
		UiKit.Corner(8).Parent = row
		if rack then
			socketedIds[rack.CrystalId] = true
			local crystal = state.Crystals[rack.CrystalId]
			if crystal then
				pendingTotal += rack.Pending
				local title, color = crystalTitle(crystal)
				UiKit.Label({
					Text = title .. ("  (size %.2f)"):format(crystal.Size),
					TextColor3 = color,
					TextXAlignment = Enum.TextXAlignment.Left,
					Size = UDim2.new(1, -170, 0, 22),
					Position = UDim2.fromOffset(8, 2),
					Parent = row,
				})
				UiKit.Label({
					Text = "+" .. Format.Number(rack.Pending) .. " coins ready",
					TextColor3 = UiKit.Colors.Good,
					Font = Enum.Font.Gotham,
					TextXAlignment = Enum.TextXAlignment.Left,
					Size = UDim2.new(1, -170, 0, 18),
					Position = UDim2.fromOffset(8, 24),
					Parent = row,
				})
				local unsocket = smallButton("Remove", UiKit.Colors.Accent, row)
				unsocket.Position = UDim2.new(1, -82, 0.5, -15)
				local slotIndex = slot
				unsocket.Activated:Connect(function()
					invoke("UnsocketCrystal", slotIndex)
				end)
			end
		else
			UiKit.Label({
				Text = "Empty tank — display a relic!",
				TextColor3 = UiKit.Colors.TextDim,
				Font = Enum.Font.Gotham,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, -16, 1, 0),
				Position = UDim2.fromOffset(8, 0),
				Parent = row,
			})
		end
	end
	if state.NextRackSlotCost then
		local buyRow = UiKit.Create("Frame", {
			Size = UDim2.new(1, -6, 0, 40),
			BackgroundColor3 = UiKit.Colors.BgLight,
			LayoutOrder = 99,
			Parent = rackList,
		})
		UiKit.Corner(8).Parent = buyRow
		local buy = smallButton("Buy Tank", UiKit.Colors.Buy, buyRow)
		buy.Size = UDim2.fromOffset(180, 30)
		buy.Position = UDim2.new(0.5, -90, 0.5, -15)
		buy.Text = "Buy Tank  (" .. Format.Number(state.NextRackSlotCost) .. ")"
		buy.Activated:Connect(function()
			invoke("BuyUpgrade", "RackSlot")
		end)
	end
	local rackLayout = rackList:FindFirstChildOfClass("UIListLayout")
	if rackLayout then
		rackList.CanvasSize = UDim2.fromOffset(0, rackLayout.AbsoluteContentSize.Y + 10)
	end
	if collectButton then
		collectButton.Text = "Collect All  (+" .. Format.Number(pendingTotal) .. ")"
	end

	-- Inventory
	UiKit.Clear(invList)
	local order = 0
	local invCount = 0
	for id, crystal in state.Crystals do
		if socketedIds[id] then
			continue
		end
		invCount += 1
		order += 1
		local row = UiKit.Create("Frame", {
			Size = UDim2.new(1, -6, 0, 44),
			BackgroundColor3 = UiKit.Colors.BgLighter,
			LayoutOrder = order,
			Parent = invList,
		})
		UiKit.Corner(8).Parent = row
		local title, color = crystalTitle(crystal)
		UiKit.Label({
			Text = title,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -180, 0, 22),
			Position = UDim2.fromOffset(8, 2),
			Parent = row,
		})
		UiKit.Label({
			Text = "Value " .. Format.Number(crystal.Value),
			TextColor3 = UiKit.Colors.Accent,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -180, 0, 18),
			Position = UDim2.fromOffset(8, 24),
			Parent = row,
		})
		local crystalId = id
		local socket = smallButton("Display", UiKit.Colors.Good, row)
		socket.Position = UDim2.new(1, -164, 0.5, -15)
		socket.Activated:Connect(function()
			invoke("SocketCrystal", crystalId)
		end)
		local sell = smallButton("Sell", UiKit.Colors.Accent, row)
		sell.Position = UDim2.new(1, -82, 0.5, -15)
		sell.Activated:Connect(function()
			invoke("SellCrystal", crystalId)
		end)
	end
	if invCount == 0 then
		order += 1
		UiKit.Create("TextLabel", {
			Text = "No loose relics — open some chests!",
			Font = Enum.Font.Gotham,
			TextColor3 = UiKit.Colors.TextDim,
			TextScaled = true,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -6, 0, 30),
			LayoutOrder = order,
			Parent = invList,
		})
	end
	local invLayout = invList:FindFirstChildOfClass("UIListLayout")
	if invLayout then
		invList.CanvasSize = UDim2.fromOffset(0, invLayout.AbsoluteContentSize.Y + 10)
	end
end

function RacksScreen.Init(gui: ScreenGui)
	local panel, content, close = UiKit.Panel(gui, "Aquarium", UDim2.fromScale(0.72, 0.78))
	panelRef = panel

	local left = UiKit.Create("Frame", { Size = UDim2.new(0.48, 0, 1, 0), BackgroundTransparency = 1, Parent = content })
	local right = UiKit.Create("Frame", {
		Size = UDim2.new(0.5, 0, 1, 0),
		Position = UDim2.fromScale(0.5, 0),
		BackgroundTransparency = 1,
		Parent = content,
	})

	local collect = UiKit.Button({
		Text = "Collect All",
		BackgroundColor3 = UiKit.Colors.Buy,
		Size = UDim2.new(1, -6, 0, 44),
		Parent = left,
	}) :: TextButton
	collectButton = collect
	collect.Activated:Connect(function()
		local collected = Remotes.Function("CollectRacks"):InvokeServer()
		if typeof(collected) == "number" and collected > 0 then
			Toasts.Push("+" .. Format.Number(collected) .. " coins collected!", UiKit.Colors.Good)
		end
	end)

	local racks = UiKit.Create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -54),
		Position = UDim2.fromOffset(0, 50),
		BackgroundColor3 = UiKit.Colors.BgLight,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		Parent = left,
	}) :: ScrollingFrame
	UiKit.Corner(10).Parent = racks
	UiKit.Pad(6).Parent = racks
	local rackLayout = Instance.new("UIListLayout")
	rackLayout.Padding = UDim.new(0, 4)
	rackLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rackLayout.Parent = racks
	rackList = racks

	local sellAll = UiKit.Button({
		Text = "Sell All Loose Relics",
		BackgroundColor3 = UiKit.Colors.Accent,
		Size = UDim2.new(1, -6, 0, 44),
		Parent = right,
	})
	sellAll.Activated:Connect(function()
		invoke("SellCrystal", "all")
	end)

	local inv = UiKit.Create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -54),
		Position = UDim2.fromOffset(0, 50),
		BackgroundColor3 = UiKit.Colors.BgLight,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		Parent = right,
	}) :: ScrollingFrame
	UiKit.Corner(10).Parent = inv
	UiKit.Pad(6).Parent = inv
	local invLayout = Instance.new("UIListLayout")
	invLayout.Padding = UDim.new(0, 4)
	invLayout.SortOrder = Enum.SortOrder.LayoutOrder
	invLayout.Parent = inv
	invList = inv

	State.Changed:Connect(function()
		if panel.Visible then
			render()
		end
	end)

	ScreenManager.Register("Racks", panel, close, render)
end

-- Time Warp upsell lives here contextually (kept for future use).
function RacksScreen.PromptTimeWarp()
	Purchase.PromptProduct("TimeWarp")
end

local _ = panelRef

return RacksScreen
