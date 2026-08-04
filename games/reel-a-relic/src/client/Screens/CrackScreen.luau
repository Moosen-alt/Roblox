--!strict
-- Crack Station: live odds panel (always visible — the compliance surface AND
-- a trust feature) + the slow-mo reveal, the game's engineered clip moment.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crystals = require(Shared.Config.Crystals)
local Format = require(Shared.Format)
local RarityMath = require(Shared.RarityMath)
local Remotes = require(Shared.Remotes)
local Purchase = require(script.Parent.Parent.Purchase)
local ScreenManager = require(script.Parent.Parent.ScreenManager)
local State = require(script.Parent.Parent.State)
local Toasts = require(script.Parent.Parent.Toasts)
local UiKit = require(script.Parent.Parent.UiKit)

local CrackScreen = {}

local oddsList: ScrollingFrame? = nil
local geodeLabel: TextLabel? = nil
local revealGui: ScreenGui? = nil
local cracking = false

local function renderOdds()
	local state = State.Get()
	if not state or not oddsList then
		return
	end
	UiKit.Clear(oddsList)
	local order = 0
	local function addRow(text: string, color: Color3, bold: boolean?)
		order += 1
		UiKit.Create("TextLabel", {
			Text = text,
			Font = bold and Enum.Font.FredokaOne or Enum.Font.GothamBold,
			TextColor3 = color,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -6, 0, bold and 26 or 22),
			LayoutOrder = order,
			Parent = oddsList,
		})
	end
	addRow(("Relic odds (Luck x%.2f)"):format(state.LuckMult), UiKit.Colors.Accent, true)
	for _, entry in RarityMath.GetBaseOdds(state.Layer, state.LuckMult) do
		addRow(entry.Name .. "  —  " .. Format.Percent(entry.Chance), entry.Color)
	end
	addRow("Aura odds", UiKit.Colors.Accent, true)
	for _, entry in RarityMath.GetMutationOdds(state.MutationMult) do
		addRow(entry.Name .. "  —  " .. Format.Percent(entry.Chance), entry.Color)
	end
	local layout = oddsList:FindFirstChildOfClass("UIListLayout")
	if layout then
		oddsList.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 10)
	end
end

local function showReveal(results: { { [string]: any } })
	if not revealGui then
		return
	end
	local overlay = UiKit.Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Parent = revealGui,
	})
	local cardWidth = 200
	local totalWidth = #results * cardWidth + (#results - 1) * 16
	local sellValue = 0
	for i, crystal in results do
		sellValue += crystal.Value
		local tierColor = Crystals.TierColors[crystal.Tier] or UiKit.Colors.Text
		local baseDef = Crystals.GetBase(crystal.Base)
		local card = UiKit.Create("Frame", {
			Size = UDim2.fromOffset(cardWidth, 260),
			Position = UDim2.new(0.5, -totalWidth // 2 + (i - 1) * (cardWidth + 16), 0.42, -130),
			BackgroundColor3 = UiKit.Colors.Bg,
			Parent = overlay,
		})
		UiKit.Corner(16).Parent = card
		UiKit.Stroke(tierColor, 4).Parent = card
		local gem = UiKit.Create("Frame", {
			Size = UDim2.fromOffset(90, 90),
			Position = UDim2.new(0.5, -45, 0, 22),
			BackgroundColor3 = baseDef and baseDef.Color or tierColor,
			Rotation = 45,
			Parent = card,
		})
		UiKit.Corner(18).Parent = gem
		UiKit.Stroke(Color3.new(1, 1, 1), 2).Parent = gem
		local mutPrefix = crystal.Mut ~= "Normal" and (crystal.Mut .. " ") or ""
		UiKit.Label({
			Text = mutPrefix .. crystal.Base,
			TextColor3 = UiKit.Colors.Text,
			Font = Enum.Font.FredokaOne,
			Size = UDim2.new(1, -12, 0, 34),
			Position = UDim2.fromOffset(6, 122),
			Parent = card,
		})
		UiKit.Label({
			Text = crystal.Tier .. (crystal.New and "  •  NEW!" or ""),
			TextColor3 = tierColor,
			Size = UDim2.new(1, -12, 0, 26),
			Position = UDim2.fromOffset(6, 158),
			Parent = card,
		})
		UiKit.Label({
			Text = "Value: " .. Format.Number(crystal.Value),
			TextColor3 = UiKit.Colors.Accent,
			Size = UDim2.new(1, -12, 0, 26),
			Position = UDim2.fromOffset(6, 190),
			Parent = card,
		})
		card.Size = UDim2.fromOffset(0, 0)
		card.Position += UDim2.fromOffset(cardWidth // 2, 130)
		TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(cardWidth, 260),
			Position = UDim2.new(0.5, -totalWidth // 2 + (i - 1) * (cardWidth + 16), 0.42, -130),
		}):Play()
		local spin = TweenService:Create(gem, TweenInfo.new(2.4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), { Rotation = 405 })
		spin:Play()
	end

	local sellAll = UiKit.Button({
		Text = "Sell All  (+" .. Format.Number(sellValue) .. ")",
		BackgroundColor3 = UiKit.Colors.Buy,
		Size = UDim2.fromOffset(220, 48),
		Position = UDim2.new(0.5, -232, 0.72, 0),
		Parent = overlay,
	})
	local keepAll = UiKit.Button({
		Text = "Keep",
		BackgroundColor3 = UiKit.Colors.BgLighter,
		TextColor3 = UiKit.Colors.Text,
		Size = UDim2.fromOffset(160, 48),
		Position = UDim2.new(0.5, 12, 0.72, 0),
		Parent = overlay,
	})
	sellAll.Activated:Connect(function()
		for _, crystal in results do
			Remotes.Function("SellCrystal"):InvokeServer(crystal.Id)
		end
		overlay:Destroy()
	end)
	keepAll.Activated:Connect(function()
		overlay:Destroy()
	end)
end

local function crack(count: number)
	if cracking then
		return
	end
	cracking = true
	local results, err = Remotes.Function("CrackGeode"):InvokeServer(count)
	cracking = false
	if not results then
		if err then
			Toasts.Push(err, UiKit.Colors.Bad)
		end
		return
	end
	showReveal(results)
end

function CrackScreen.Init(gui: ScreenGui)
	revealGui = UiKit.Create("ScreenGui", {
		Name = "RevealGui",
		ResetOnSpawn = false,
		DisplayOrder = 50,
		IgnoreGuiInset = true,
		Parent = gui.Parent,
	}) :: ScreenGui

	local panel, content, close = UiKit.Panel(gui, "Treasure Chests", UDim2.fromScale(0.66, 0.74))

	local odds = UiKit.Create("ScrollingFrame", {
		Size = UDim2.new(0.46, 0, 1, 0),
		BackgroundColor3 = UiKit.Colors.BgLight,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.fromOffset(0, 0),
		Parent = content,
	}) :: ScrollingFrame
	UiKit.Corner(10).Parent = odds
	UiKit.Pad(8).Parent = odds
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 2)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = odds
	oddsList = odds

	local right = UiKit.Create("Frame", {
		Size = UDim2.new(0.5, 0, 1, 0),
		Position = UDim2.fromScale(0.5, 0),
		BackgroundTransparency = 1,
		Parent = content,
	})
	geodeLabel = UiKit.Label({
		Text = "Chests: 0",
		Font = Enum.Font.FredokaOne,
		TextColor3 = UiKit.Colors.Text,
		Size = UDim2.new(1, 0, 0, 44),
		Parent = right,
	}) :: TextLabel
	local crackOne = UiKit.Button({
		Text = "OPEN!",
		Size = UDim2.new(0.9, 0, 0, 62),
		Position = UDim2.fromScale(0.05, 0.28),
		Parent = right,
	})
	local crackThree = UiKit.Button({
		Text = "Open x3",
		BackgroundColor3 = UiKit.Colors.Robux,
		Size = UDim2.new(0.9, 0, 0, 50),
		Position = UDim2.fromScale(0.05, 0.52),
		Parent = right,
	})
	local hint = UiKit.Label({
		Text = "Cast at a glowing fishing spot to catch chests!",
		TextColor3 = UiKit.Colors.TextDim,
		Font = Enum.Font.Gotham,
		TextWrapped = true,
		Size = UDim2.new(0.9, 0, 0, 60),
		Position = UDim2.fromScale(0.05, 0.76),
		Parent = right,
	})
	local _ = hint

	crackOne.Activated:Connect(function()
		crack(1)
	end)
	crackThree.Activated:Connect(function()
		local state = State.Get()
		if state and state.Passes and state.Passes.TripleCrack then
			crack(3)
		else
			Purchase.PromptPass("TripleCrack")
		end
	end)

	State.Changed:Connect(function(state)
		if geodeLabel then
			geodeLabel.Text = ("Chests: %d / %d"):format(state.Geodes, state.BackpackCapacity)
		end
		if panel.Visible then
			renderOdds()
		end
	end)
	State.EventChanged:Connect(function()
		if panel.Visible then
			renderOdds()
		end
	end)

	ScreenManager.Register("Crack", panel, close, renderOdds)
end

return CrackScreen
