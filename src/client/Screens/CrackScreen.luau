--!strict
-- Crack Station: live odds panel (always visible — the compliance surface AND
-- a trust feature) + the multi-phase reveal, the game's engineered clip moment.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crystals = require(Shared.Config.Crystals)
local Format = require(Shared.Format)
local RarityMath = require(Shared.RarityMath)
local Remotes = require(Shared.Remotes)
local Purchase = require(script.Parent.Parent.Purchase)
local RevealFx = require(script.Parent.Parent.RevealFx)
local ScreenManager = require(script.Parent.Parent.ScreenManager)
local State = require(script.Parent.Parent.State)
local Toasts = require(script.Parent.Parent.Toasts)
local UiKit = require(script.Parent.Parent.UiKit)

local CrackScreen = {}

local oddsList: ScrollingFrame? = nil
local geodeLabel: TextLabel? = nil
local revealGui: ScreenGui? = nil
local cracking = false

-- Suspense seconds by best tier in the batch (rarer = longer shake)
local SUSPENSE = {
	Common = 0.7,
	Uncommon = 0.8,
	Rare = 1.1,
	Epic = 1.5,
	Legendary = 2.0,
	Mythic = 2.4,
}

local function tierRank(tier: string): number
	for i, name in Crystals.Tiers do
		if name == tier then
			return i
		end
	end
	return 1
end

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
	addRow(("Crystal odds (Luck x%.2f)"):format(state.LuckMult), UiKit.Colors.Accent, true)
	for _, entry in RarityMath.GetBaseOdds(state.Layer, state.LuckMult) do
		addRow(entry.Name .. "  —  " .. Format.Percent(entry.Chance), entry.Color)
	end
	addRow("Mutation odds", UiKit.Colors.Accent, true)
	for _, entry in RarityMath.GetMutationOdds(state.MutationMult) do
		addRow(entry.Name .. "  —  " .. Format.Percent(entry.Chance), entry.Color)
	end
	local layout = oddsList:FindFirstChildOfClass("UIListLayout")
	if layout then
		oddsList.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 10)
	end
end

local function makeCard(overlay: Frame, crystal: { [string]: any }, position: UDim2, cardWidth: number, handledIds: { [string]: boolean }, onHandled: () -> ()): Frame
	local tierColor = Crystals.TierColors[crystal.Tier] or UiKit.Colors.Text
	local baseDef = Crystals.GetBase(crystal.Base)
	local card = UiKit.Create("Frame", {
		Size = UDim2.fromOffset(cardWidth, 260),
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = UiKit.Colors.Bg,
		ZIndex = 2,
		Parent = overlay,
	})
	UiKit.Corner(16).Parent = card
	UiKit.Stroke(tierColor, 4).Parent = card
	local gem = UiKit.Create("Frame", {
		Size = UDim2.fromOffset(90, 90),
		Position = UDim2.new(0.5, -45, 0, 22),
		BackgroundColor3 = baseDef and baseDef.Color or tierColor,
		Rotation = 45,
		ZIndex = 2,
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
		ZIndex = 2,
		Parent = card,
	})
	UiKit.Label({
		Text = crystal.Tier,
		TextColor3 = tierColor,
		Size = UDim2.new(1, -12, 0, 26),
		Position = UDim2.fromOffset(6, 158),
		ZIndex = 2,
		Parent = card,
	})
	UiKit.Label({
		Text = "Value: " .. Format.Number(crystal.Value),
		TextColor3 = UiKit.Colors.Accent,
		Size = UDim2.new(1, -12, 0, 26),
		Position = UDim2.fromOffset(6, 190),
		ZIndex = 2,
		Parent = card,
	})

	-- Per-crystal choice, right on the card: sell it or socket it on a rack.
	local function cardButton(text: string, color: Color3, x: number): TextButton
		local button = UiKit.Create("TextButton", {
			Text = text,
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			TextColor3 = Color3.fromRGB(25, 22, 18),
			BackgroundColor3 = color,
			Size = UDim2.fromOffset(cardWidth // 2 - 14, 30),
			Position = UDim2.fromOffset(x, 222),
			ZIndex = 3,
			Parent = card,
		})
		UiKit.Corner(8).Parent = button
		return button
	end
	local sellButton = cardButton("Sell", UiKit.Colors.Buy, 8)
	local socketButton = cardButton("Socket", UiKit.Colors.Good, cardWidth // 2 + 6)
	-- The server call yields, so lock BEFORE invoking — otherwise a fast
	-- double-tap (or tapping both buttons) can double-render the done state.
	local busy = false
	-- Overlap-proof by construction: the Sell button ITSELF becomes the status
	-- text (one instance mutated in place — nothing new is ever added at these
	-- coordinates, so no race can double-render).
	local function markDone(text: string)
		handledIds[crystal.Id] = true
		if socketButton.Parent then
			socketButton:Destroy()
		end
		sellButton.Active = false
		sellButton.AutoButtonColor = false
		sellButton.BackgroundTransparency = 1
		sellButton.Font = Enum.Font.GothamBold
		sellButton.TextColor3 = UiKit.Colors.TextDim
		sellButton.Text = text
		sellButton.Size = UDim2.new(1, -16, 0, 26)
		sellButton.Position = UDim2.fromOffset(8, 224)
		onHandled()
	end
	sellButton.Activated:Connect(function()
		if busy or handledIds[crystal.Id] then
			return
		end
		busy = true
		local ok, err = Remotes.Function("SellCrystal"):InvokeServer(crystal.Id)
		if ok then
			markDone("Sold  (+" .. Format.Number(crystal.Value) .. ")")
		else
			busy = false
			if typeof(err) == "string" then
				Toasts.Push(err, UiKit.Colors.Bad)
			end
		end
	end)
	socketButton.Activated:Connect(function()
		if busy or handledIds[crystal.Id] then
			return
		end
		busy = true
		local ok, err = Remotes.Function("SocketCrystal"):InvokeServer(crystal.Id)
		if ok then
			markDone("Socketed!")
		else
			busy = false
			if typeof(err) == "string" then
				Toasts.Push(err, UiKit.Colors.Bad)
			end
		end
	end)
	if crystal.New then
		local badge = UiKit.Create("TextLabel", {
			Text = "NEW!",
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			TextColor3 = Color3.fromRGB(30, 26, 20),
			BackgroundColor3 = UiKit.Colors.Good,
			Rotation = -12,
			Size = UDim2.fromOffset(64, 30),
			Position = UDim2.new(1, -48, 0, -10),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 3,
			Parent = card,
		})
		UiKit.Corner(8).Parent = badge
		badge.Size = UDim2.fromOffset(0, 0)
		TweenService:Create(
			badge,
			TweenInfo.new(0.35, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0.2),
			{ Size = UDim2.fromOffset(64, 30) }
		):Play()
	end

	-- pop in
	card.Size = UDim2.fromOffset(0, 0)
	TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(cardWidth, 260),
	}):Play()
	local spin = TweenService:Create(gem, TweenInfo.new(2.4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), { Rotation = 405 })
	spin:Play()
	return card
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

	local bestTier = "Common"
	local bestIndex = 1
	for i, crystal in results do
		if tierRank(crystal.Tier) > tierRank(bestTier) then
			bestTier = crystal.Tier
			bestIndex = i
		end
	end
	local bestColor = Crystals.TierColors[bestTier] or UiKit.Colors.Accent
	local bestRank = tierRank(bestTier)

	local cardWidth = 200
	local totalWidth = #results * cardWidth + (#results - 1) * 16
	local handledIds: { [string]: boolean } = {}

	-- Sell All stays live: recomputed from unhandled cards, hidden when empty.
	local sellAllRef: TextButton? = nil
	local function refreshSellAll()
		local button = sellAllRef
		if not button then
			return
		end
		local remaining = 0
		for _, crystal in results do
			if not handledIds[crystal.Id] then
				remaining += crystal.Value
			end
		end
		button.Visible = remaining > 0
		if remaining > 0 then
			button.Text = "Sell All  (+" .. Format.Number(remaining) .. ")"
		end
	end

	RevealFx.Play(overlay, {
		Color = bestColor,
		Suspense = SUSPENSE[bestTier] or 1,
		Charged = bestRank >= 4,
	}, function()
		-- Celebration extras land with the burst
		RevealFx.Fanfare(overlay, bestRank)
		if bestRank >= 4 then
			RevealFx.Confetti(overlay, bestColor, bestRank >= 5 and 36 or 20)
		end
		for i, crystal in results do
			local position = UDim2.new(0.5, -totalWidth // 2 + (i - 1) * (cardWidth + 16) + cardWidth // 2, 0.42, 0)
			if i == bestIndex and bestRank >= 5 then
				RevealFx.Sunburst(overlay, position, bestColor)
			end
			task.delay((i - 1) * 0.18, function()
				if overlay.Parent then
					makeCard(overlay, crystal, position, cardWidth, handledIds, refreshSellAll)
				end
			end)
		end

		task.delay(#results * 0.18 + 0.3, function()
			if not overlay.Parent then
				return
			end
			local sellAll = UiKit.Button({
				Text = "Sell All",
				BackgroundColor3 = UiKit.Colors.Buy,
				Size = UDim2.fromOffset(220, 48),
				Position = UDim2.new(0.5, -232, 0.72, 0),
				Parent = overlay,
			})
			sellAll.ZIndex = 4
			sellAllRef = sellAll
			refreshSellAll()
			local keepAll = UiKit.Button({
				Text = "Keep",
				BackgroundColor3 = UiKit.Colors.BgLighter,
				TextColor3 = UiKit.Colors.Text,
				Size = UDim2.fromOffset(160, 48),
				Position = UDim2.new(0.5, 12, 0.72, 0),
				Parent = overlay,
			})
			keepAll.ZIndex = 4
			sellAll.Activated:Connect(function()
				for _, crystal in results do
					if not handledIds[crystal.Id] then
						Remotes.Function("SellCrystal"):InvokeServer(crystal.Id)
					end
				end
				overlay:Destroy()
			end)
			keepAll.Activated:Connect(function()
				overlay:Destroy()
			end)
		end)
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

	local panel, content, close = UiKit.Panel(gui, "Crack Station", UDim2.fromScale(0.66, 0.74))

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
		Text = "Geodes: 0",
		Font = Enum.Font.FredokaOne,
		TextColor3 = UiKit.Colors.Text,
		Size = UDim2.new(1, 0, 0, 44),
		Parent = right,
	}) :: TextLabel
	local crackOne = UiKit.Button({
		Text = "CRACK!",
		Size = UDim2.new(0.9, 0, 0, 62),
		Position = UDim2.fromScale(0.05, 0.28),
		Parent = right,
	})
	local crackThree = UiKit.Button({
		Text = "Crack x3",
		BackgroundColor3 = UiKit.Colors.Robux,
		Size = UDim2.new(0.9, 0, 0, 50),
		Position = UDim2.fromScale(0.05, 0.52),
		Parent = right,
	})
	-- Pass owners can pause auto-cracking to enjoy the full reveal
	local autoToggle = UiKit.Button({
		Text = "Auto-Crack: ON",
		BackgroundColor3 = UiKit.Colors.BgLighter,
		TextColor3 = UiKit.Colors.Text,
		Size = UDim2.new(0.9, 0, 0, 36),
		Position = UDim2.fromScale(0.05, 0.7),
		Visible = false,
		Parent = right,
	})
	autoToggle.Activated:Connect(function()
		Remotes.Function("ToggleAutoCrack"):InvokeServer()
	end)
	UiKit.Label({
		Text = "Mine the glowing wall to find geodes!",
		TextColor3 = UiKit.Colors.TextDim,
		Font = Enum.Font.Gotham,
		TextWrapped = true,
		Size = UDim2.new(0.9, 0, 0, 44),
		Position = UDim2.fromScale(0.05, 0.84),
		Parent = right,
	})

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
			geodeLabel.Text = ("Geodes: %d / %d"):format(state.Geodes, state.BackpackCapacity)
		end
		local ownsAuto = state.Passes and state.Passes.AutoCrack == true
		autoToggle.Visible = ownsAuto == true
		if ownsAuto then
			local enabled = state.AutoCrackEnabled ~= false
			autoToggle.Text = enabled and "Auto-Crack: ON" or "Auto-Crack: OFF"
			autoToggle.BackgroundColor3 = enabled and UiKit.Colors.Good or UiKit.Colors.BgLighter
			autoToggle.TextColor3 = enabled and Color3.fromRGB(25, 22, 18) or UiKit.Colors.Text
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
