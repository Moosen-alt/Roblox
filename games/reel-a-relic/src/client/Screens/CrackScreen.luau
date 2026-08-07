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
local GemView = require(script.Parent.Parent.GemView)
local Purchase = require(script.Parent.Parent.Purchase)
local RevealFx = require(script.Parent.Parent.RevealFx)
local ScreenManager = require(script.Parent.Parent.ScreenManager)
local State = require(script.Parent.Parent.State)
local Toasts = require(script.Parent.Parent.Toasts)
local UiKit = require(script.Parent.Parent.UiKit)
local WorldFx = require(script.Parent.Parent.WorldFx)

local CrackScreen = {}

local oddsList: ScrollingFrame? = nil
local geodeLabel: TextLabel? = nil
local revealGui: ScreenGui? = nil
local currentOverlay: Frame? = nil
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

-- The flex line. Same numbers as the odds panel, multiplied out: "1 in 12,500"
-- is the thing players screenshot and paste into a group chat. Only shown when
-- the pull was genuinely long odds, so it never becomes wallpaper.
local function oddsBrag(crystal: { [string]: any }): string?
	local state = State.Get()
	if not state then
		return nil
	end
	if crystal.Pity then
		return nil -- the first-session guaranteed Rare+ beat no odds at all
	end
	-- Quote the pool this thing actually came out of. Every card on this screen
	-- came out of a chest, so that is the relic table — telling a player their
	-- Sunken Crown beat the odds on a mackerel would be a made-up number.
	local pool = if Crystals.IsRelic(crystal.Base) then Crystals.RELIC else Crystals.FISH
	local baseChance = 0
	for _, entry in RarityMath.GetBaseOdds(state.Layer, state.LuckMult, pool) do
		if entry.Name == crystal.Base then
			baseChance = entry.Chance
		end
	end
	local mutChance = 100
	for _, entry in RarityMath.GetMutationOdds(state.MutationMult) do
		if entry.Name == crystal.Mut then
			mutChance = entry.Chance
		end
	end
	local probability = (baseChance / 100) * (mutChance / 100)
	if probability <= 0 then
		return nil
	end
	local oneIn = math.floor(1 / probability + 0.5)
	if oneIn < 40 then
		return nil
	end
	return "1 in " .. Format.Number(oneIn)
end

-- Mythic pulls get a colour cycling around the card border. Costs one gradient.
local function rainbowStroke(stroke: UIStroke)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 120)),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 220, 90)),
		ColorSequenceKeypoint.new(0.7, Color3.fromRGB(120, 255, 200)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 120, 255)),
	})
	gradient.Parent = stroke
	task.spawn(function()
		while gradient.Parent do
			TweenService:Create(gradient, TweenInfo.new(2.4, Enum.EasingStyle.Linear), { Rotation = 360 }):Play()
			task.wait(2.4)
			if gradient.Parent then
				gradient.Rotation = 0
			end
		end
	end)
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
	-- This is the CHEST station's panel, so it must publish what is in a chest.
	addRow(("Relic odds (Luck x%.2f)"):format(state.LuckMult), UiKit.Colors.Accent, true)
	for _, entry in RarityMath.GetBaseOdds(state.Layer, state.LuckMult, Crystals.RELIC) do
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

local function makeCard(
	overlay: Frame,
	crystal: { [string]: any },
	position: UDim2,
	cardWidth: number,
	handledIds: { [string]: boolean },
	onHandled: () -> (),
	previousBest: number
): Frame
	local tierColor = Crystals.TierColors[crystal.Tier] or UiKit.Colors.Text
	local baseDef = Crystals.GetBase(crystal.Base)
	local rank = tierRank(crystal.Tier)
	local card = UiKit.Create("Frame", {
		Size = UDim2.fromOffset(cardWidth, 292),
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = UiKit.Colors.Bg,
		ZIndex = 2,
		Parent = overlay,
	})
	UiKit.Corner(16).Parent = card
	local cardStroke = UiKit.Stroke(tierColor, 4)
	cardStroke.Parent = card
	if rank >= 6 then
		rainbowStroke(cardStroke)
	elseif rank >= 5 then
		-- Legendary borders breathe, so the good card is obvious in a row of three
		TweenService:Create(
			cardStroke,
			TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Thickness = 8 }
		):Play()
	end

	-- The rock itself, in 3D, turning
	GemView.Create({
		Parent = card,
		Size = UDim2.fromOffset(112, 104),
		Position = UDim2.new(0.5, -56, 0, 12),
		Color = baseDef and baseDef.Color or tierColor,
		Seed = #crystal.Base * 17 + #crystal.Mut,
		Spin = 0.8 + rank * 0.16,
		ZIndex = 2,
		Name = crystal.Base,
	})

	local mutPrefix = crystal.Mut ~= "Normal" and (crystal.Mut .. " ") or ""
	UiKit.Label({
		Text = mutPrefix .. crystal.Base,
		TextColor3 = UiKit.Colors.Text,
		Font = Enum.Font.FredokaOne,
		Size = UDim2.new(1, -12, 0, 34),
		Position = UDim2.fromOffset(6, 120),
		ZIndex = 2,
		Parent = card,
	})
	UiKit.Label({
		Text = crystal.Tier,
		TextColor3 = tierColor,
		Size = UDim2.new(1, -12, 0, 26),
		Position = UDim2.fromOffset(6, 154),
		ZIndex = 2,
		Parent = card,
	})
	-- Relics have no weight — you do not brag about a heavy doubloon — so the
	-- pounds only appear on things that were actually swimming.
	UiKit.Label({
		Text = if Crystals.IsRelic(crystal.Base)
			then ("Value: %s"):format(Format.Number(crystal.Value))
			else ("Value: %s   •   %.1f lb"):format(Format.Number(crystal.Value), crystal.Weight or 0),
		TextColor3 = UiKit.Colors.Accent,
		Size = UDim2.new(1, -12, 0, 26),
		Position = UDim2.fromOffset(6, 182),
		ZIndex = 2,
		Parent = card,
	})

	-- Two brag lines, both earned rather than decorative: the true odds you beat,
	-- and whether this is the best thing you have ever pulled. `crystal.Best` is
	-- the server's own weight record, so a heaviest-ever bass gets the callout
	-- even when a Mythic elsewhere in your collection is worth more coins.
	local brag = oddsBrag(crystal)
	local isBest = crystal.Best == true or (crystal.Value > previousBest and previousBest > 0)
	UiKit.Label({
		Text = if crystal.Best == true
			then ("★ HEAVIEST %s YET ★"):format(string.upper(crystal.Base))
			elseif isBest then "★ NEW PERSONAL BEST ★"
			else (brag or ""),
		Font = Enum.Font.FredokaOne,
		TextColor3 = isBest and Color3.fromRGB(255, 230, 120) or UiKit.Colors.TextDim,
		Size = UDim2.new(1, -12, 0, 22),
		Position = UDim2.fromOffset(6, 210),
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
			Position = UDim2.fromOffset(x, 250),
			ZIndex = 3,
			Parent = card,
		})
		UiKit.Corner(8).Parent = button
		return button
	end
	local sellButton = cardButton("Sell", UiKit.Colors.Buy, 8)
	local socketButton = cardButton("Display", UiKit.Colors.Good, cardWidth // 2 + 6)
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
		sellButton.Position = UDim2.fromOffset(8, 252)
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
			markDone("Displayed!")
		else
			busy = false
			if typeof(err) == "string" then
				Toasts.Push(err, UiKit.Colors.Bad)
			end
		end
	end)
	-- A new index entry always carries the count with it: an unfinished set is
	-- the strongest reason to crack one more.
	if crystal.New then
		local state = State.Get()
		local caption = "NEW!"
		if state and state.TotalIndex then
			caption = ("NEW!  %d/%d"):format(state.CollectionCount, state.TotalIndex)
		end
		local badge = UiKit.Create("TextLabel", {
			Text = caption,
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			TextColor3 = Color3.fromRGB(30, 26, 20),
			BackgroundColor3 = UiKit.Colors.Good,
			Rotation = -12,
			Size = UDim2.fromOffset(96, 30),
			-- Inside the top edge, not straddling it: at 375-height the card top
			-- sits at y=11 and half the badge was clipped off screen.
			Position = UDim2.new(1, -56, 0, 14),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 3,
			Parent = card,
		})
		UiKit.Corner(8).Parent = badge
		badge.Size = UDim2.fromOffset(0, 0)
		TweenService:Create(
			badge,
			TweenInfo.new(0.35, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0.2),
			{ Size = UDim2.fromOffset(96, 30) }
		):Play()
	end

	-- pop in
	card.Size = UDim2.fromOffset(0, 0)
	TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(cardWidth, 292),
	}):Play()
	return card
end

local function showReveal(results: { { [string]: any } }, previousBest: number)
	if not revealGui then
		return
	end
	-- One reveal at a time: close any previous overlay, and make this one
	-- Active so clicks can't pass through to CRACK!/mining behind it —
	-- overlays stacking from through-clicks was the double-render bug.
	if currentOverlay and currentOverlay.Parent then
		currentOverlay:Destroy()
	end
	local overlay = UiKit.Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Active = true,
		Parent = revealGui,
	})
	currentOverlay = overlay
	-- Hold any rare-find callout addressed to us until this closes: on a phone
	-- there is no band that clears both the card block and its button row.
	Toasts.SetRevealOpen(true)
	overlay.Destroying:Once(function()
		if currentOverlay == overlay then
			currentOverlay = nil
		end
		Toasts.SetRevealOpen(false)
	end)

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
	-- Once every card is handled there is nothing left to decide, so the
	-- reveal closes itself after a beat.
	local sellAllRef: TextButton? = nil
	local function refreshSellAll()
		local remaining = 0
		local unhandled = 0
		for _, crystal in results do
			if not handledIds[crystal.Id] then
				unhandled += 1
				remaining += crystal.Value
			end
		end
		local button = sellAllRef
		if button then
			button.Visible = remaining > 0
			if remaining > 0 then
				button.Text = "Sell All  (+" .. Format.Number(remaining) .. ")"
			end
		end
		if unhandled == 0 then
			task.delay(0.75, function()
				if overlay.Parent then
					overlay:Destroy()
				end
			end)
		end
	end

	RevealFx.Play(overlay, {
		Color = bestColor,
		Suspense = SUSPENSE[bestTier] or 1,
		Charged = bestRank >= 4,
	}, function()
		-- Celebration extras land with the burst
		RevealFx.Fanfare(overlay, bestRank)
		-- The whole screen kicks, scaled to what you pulled
		WorldFx.Shake(0.5 + bestRank * 0.45)
		if bestRank >= 4 then
			RevealFx.Confetti(overlay, bestColor, bestRank >= 5 and 36 or 20)
		end
		-- The server rolls a batch sequentially, so its record climbs as it goes.
		-- Comparing every card against the same pre-crack snapshot let a 300 and
		-- a 500 in one triple crack both claim the personal best.
		local runningBest = previousBest
		for i, crystal in results do
			local position = UDim2.new(0.5, -totalWidth // 2 + (i - 1) * (cardWidth + 16) + cardWidth // 2, 0.42, 0)
			if i == bestIndex and bestRank >= 5 then
				RevealFx.Sunburst(overlay, position, bestColor)
			end
			local bestBefore = runningBest
			runningBest = math.max(runningBest, crystal.Value)
			task.delay((i - 1) * 0.18, function()
				if overlay.Parent then
					makeCard(overlay, crystal, position, cardWidth, handledIds, refreshSellAll, bestBefore)
				end
			end)
		end

		task.delay(#results * 0.18 + 0.3, function()
			if not overlay.Parent then
				return
			end
			-- Below the cards, but never off the bottom of the screen. Cards are
			-- 292 tall centred at 0.42, so 0.42H+162 clears them — except on a
			-- short phone, where that offset falls past the viewport entirely.
			local height = overlay.AbsoluteSize.Y
			local rowY = if height > 0 then math.min(0.42 * height + 162, height - 58) else 0
			local sellAll = UiKit.Button({
				Text = "Sell All",
				BackgroundColor3 = UiKit.Colors.Buy,
				Size = UDim2.fromOffset(220, 48),
				Position = UDim2.new(0.5, -232, 0, rowY),
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
				Position = UDim2.new(0.5, 12, 0, rowY),
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
	-- Snapshot the record BEFORE the server updates it, or every pull would
	-- claim to be a personal best.
	local state = State.Get()
	local previousBest = (state and state.Stats and state.Stats.RarestValue) or 0
	local results, err = Remotes.Function("CrackGeode"):InvokeServer(count)
	cracking = false
	if not results then
		if err then
			Toasts.Push(err, UiKit.Colors.Bad)
		end
		return
	end
	showReveal(results, previousBest)
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
	-- Pass owners can pause auto-cracking to enjoy the full reveal
	local autoToggle = UiKit.Button({
		Text = "Auto-Open: ON",
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
		-- Chests are about one catch in eight; saying you fish for them was a
		-- leftover from before fish were the collectible, and it set players up to
		-- think the other seven catches were a miss.
		Text = "Most catches are fish. Now and then a chest comes up — every one is Rare or better.",
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
			geodeLabel.Text = ("Chests: %d   •   Hold %d / %d"):format(
				state.Geodes,
				state.Hold or state.Geodes,
				state.BackpackCapacity
			)
		end
		local ownsAuto = state.Passes and state.Passes.AutoCrack == true
		autoToggle.Visible = ownsAuto == true
		if ownsAuto then
			local enabled = state.AutoCrackEnabled ~= false
			autoToggle.Text = enabled and "Auto-Open: ON" or "Auto-Open: OFF"
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
