--!strict
-- The reveal engine: anticipation (shaking shell, spreading cracks, rising
-- ticks), burst (shard explosion + screen flash), and celebration extras
-- (confetti, rotating sunburst) for high-tier pulls. Suspense scales with the
-- best rarity in the batch — slot-machine timing, the clip moment.

local TweenService = game:GetService("TweenService")

local ChestView = require(script.Parent.ChestView)

local RevealFx = {}

-- Theme knobs (the fishing re-theme overrides these)
RevealFx.ShellColor = Color3.fromRGB(130, 95, 60)
RevealFx.ShellStroke = Color3.fromRGB(255, 200, 60)
-- How the shell comes apart. A geode cracks down the middle into two
-- hemispheres; a treasure chest hinges its lid up instead.
RevealFx.SplitVertical = true -- chests hinge their lid open
-- What the shell IS. "Geode" is a round rock; "Chest" is a banded wooden box
-- with a lock. Both use the same clipped-halves machinery — only the shape
-- drawn inside each half differs — because that machinery is the part that was
-- hard to get right (see the no-rotation note further down).
RevealFx.ShellStyle = "Chest"

-- Draw the chest as real 3D geometry with a hinged lid instead of the flat
-- clipped halves. A chest opening is a HINGE, and a hinge is the one thing two
-- rectangles sliding apart cannot fake from the front — this is the most-watched
-- two seconds in the game and it is worth the geometry.
--
-- A flag rather than a rewrite: the 2D path below is tuned and carries real bug
-- history in its comments (Roblox drops clipping on any rotated subtree), so it
-- stays intact and working. Set this false to fall straight back to it.
RevealFx.Use3DChest = true
RevealFx.ChestWood = Color3.fromRGB(122, 80, 44)
RevealFx.ChestDarkWood = Color3.fromRGB(88, 56, 30)
RevealFx.ChestBand = Color3.fromRGB(230, 178, 62)

local TICK_SOUND = "rbxasset://sounds/electronicpingshort.wav"
local THUD_SOUND = "rbxasset://sounds/snap.mp3"

local function play(parent: Instance, id: string, pitch: number, volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = pitch
	sound.Parent = parent
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(2, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

-- Tier-scaled hype: built-in sounds pitched into arpeggios. Commons pop,
-- Rares get a rising triad, Legendary/Mythic get a full fanfare with bass —
-- the reveal should SOUND as big as it looks. {delay, sound, pitch, volume}
local FANFARES: { [number]: { { number } } } = {}
FANFARES[1] = { { 0, 1, 1.0, 0.5 } } :: any
FANFARES[2] = { { 0, 1, 1.15, 0.55 } } :: any
FANFARES[3] = { { 0, 0, 1.0, 0.55 }, { 0.09, 0, 1.26, 0.6 }, { 0.18, 0, 1.5, 0.65 } } :: any
FANFARES[4] = { { 0, 1, 0.6, 0.8 }, { 0.05, 0, 1.0, 0.6 }, { 0.14, 0, 1.26, 0.6 }, { 0.23, 0, 1.5, 0.65 }, { 0.32, 0, 2.0, 0.7 } } :: any
FANFARES[5] = { { 0, 1, 0.5, 0.9 }, { 0.08, 0, 1.0, 0.65 }, { 0.16, 0, 1.26, 0.65 }, { 0.24, 0, 1.5, 0.7 }, { 0.32, 0, 1.68, 0.7 }, { 0.4, 0, 2.0, 0.8 }, { 0.55, 1, 1.4, 0.7 } } :: any
FANFARES[6] = { { 0, 1, 0.4, 1 }, { 0.06, 0, 1.0, 0.7 }, { 0.12, 0, 1.26, 0.7 }, { 0.18, 0, 1.5, 0.7 }, { 0.24, 0, 1.68, 0.75 }, { 0.3, 0, 2.0, 0.8 }, { 0.38, 0, 2.52, 0.85 }, { 0.5, 0, 3.0, 0.9 }, { 0.62, 1, 1.6, 0.8 } } :: any

function RevealFx.Fanfare(parent: Instance, tierRank: number)
	local notes = FANFARES[math.clamp(tierRank, 1, 6)]
	for _, note in notes do
		task.delay(note[1], function()
			if parent.Parent then
				play(parent, note[2] == 1 and THUD_SOUND or TICK_SOUND, note[3], note[4])
			end
		end)
	end
end

export type PlayOptions = {
	Color: Color3, -- tier color for glow/burst
	Suspense: number, -- seconds of shake before the burst
	Charged: boolean, -- extra white charge-up before burst (Epic+)
}

local function tick(parent: Instance, pitch: number)
	play(parent, TICK_SOUND, pitch, 0.35)
end

local GEODE_SIZE = 180

-- The wooden slats, iron bands and lock plate that make the shell read as a
-- treasure chest rather than a brown circle. Drawn onto the full-size shape
-- inside a half, so the clip cuts through them exactly like it cuts the box.
-- `isLid` gets the curved top and the keyhole; the base gets the feet.
local function dressAsChest(box: Frame, isLid: boolean)
	box.BackgroundColor3 = RevealFx.ChestWood
	local corner = box:FindFirstChildOfClass("UICorner")
	if corner then
		-- A chest has a rounded lid and a square base. One radius for the whole
		-- box is close enough at this size and keeps it one frame.
		corner.CornerRadius = UDim.new(0, if isLid then 34 else 10)
	end

	-- Plank seams: darker horizontal lines across the wood.
	for i = 1, 3 do
		local plank = Instance.new("Frame")
		plank.AnchorPoint = Vector2.new(0.5, 0.5)
		plank.Position = UDim2.fromScale(0.5, 0.22 + (i - 1) * 0.26)
		plank.Size = UDim2.new(1, 0, 0, 3)
		plank.BackgroundColor3 = RevealFx.ChestDarkWood
		plank.BorderSizePixel = 0
		plank.ZIndex = 3
		plank.Parent = box
	end

	-- Iron bands: two vertical straps holding the box together, which is the
	-- detail that says "chest" fastest at a glance.
	for _, at in { 0.22, 0.78 } do
		local band = Instance.new("Frame")
		band.AnchorPoint = Vector2.new(0.5, 0.5)
		band.Position = UDim2.fromScale(at, 0.5)
		band.Size = UDim2.new(0, 16, 1, 0)
		band.BackgroundColor3 = RevealFx.ChestBand
		band.BorderSizePixel = 0
		band.ZIndex = 4
		band.Parent = box
	end

	-- The lock: a gold plate straddling the seam, with a dark keyhole.
	local plate = Instance.new("Frame")
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromScale(0.5, if isLid then 0.94 else 0.06)
	plate.Size = UDim2.fromOffset(40, 34)
	plate.BackgroundColor3 = RevealFx.ChestBand
	plate.BorderSizePixel = 0
	plate.ZIndex = 5
	plate.Parent = box
	local plateCorner = Instance.new("UICorner")
	plateCorner.CornerRadius = UDim.new(0, 6)
	plateCorner.Parent = plate
	if not isLid then
		local keyhole = Instance.new("Frame")
		keyhole.AnchorPoint = Vector2.new(0.5, 0.5)
		keyhole.Position = UDim2.fromScale(0.5, 0.6)
		keyhole.Size = UDim2.fromOffset(9, 13)
		keyhole.BackgroundColor3 = Color3.fromRGB(40, 28, 16)
		keyhole.BorderSizePixel = 0
		keyhole.ZIndex = 6
		keyhole.Parent = plate
		local keyCorner = Instance.new("UICorner")
		keyCorner.CornerRadius = UDim.new(0, 4)
		keyCorner.Parent = keyhole
	end
end

-- One half of the shell: a clipped frame showing exactly half of the shape, so
-- the two of them sit flush as one object until they come apart. `isFirst` is
-- the left half when splitting sideways, the LID when hinging.
local function makeHalf(parent: Frame, isFirst: boolean): Frame
	local vertical = RevealFx.SplitVertical
	local half = Instance.new("Frame")
	half.AnchorPoint = Vector2.new(0.5, 0.5)
	half.Size = if vertical
		then UDim2.fromOffset(GEODE_SIZE, GEODE_SIZE // 2)
		else UDim2.fromOffset(GEODE_SIZE // 2, GEODE_SIZE)
	local shift = if isFirst then -GEODE_SIZE // 4 else GEODE_SIZE // 4
	half.Position = UDim2.fromScale(0.5, 0.5)
		+ (if vertical then UDim2.fromOffset(0, shift) else UDim2.fromOffset(shift, 0))
	half.BackgroundTransparency = 1
	half.ClipsDescendants = true
	half.ZIndex = 3
	half.Parent = parent

	-- The full shape, offset so the clip leaves exactly the wanted half
	local back = if isFirst then 0 else -GEODE_SIZE // 2
	local rock = Instance.new("Frame")
	rock.Name = "Rock"
	rock.Size = UDim2.fromOffset(GEODE_SIZE, GEODE_SIZE)
	rock.Position = if vertical then UDim2.fromOffset(0, back) else UDim2.fromOffset(back, 0)
	rock.BackgroundColor3 = RevealFx.ShellColor
	rock.BorderSizePixel = 0
	rock.ZIndex = 3
	rock.Parent = half
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = rock
	local stroke = Instance.new("UIStroke")
	stroke.Color = RevealFx.ShellStroke
	stroke.Thickness = 5
	stroke.Parent = rock

	if RevealFx.ShellStyle == "Chest" then
		dressAsChest(rock, isFirst)
	end

	return half
end

-- Anticipation, split, reveal. Calls onBurst once the halves are open, then
-- cleans up its own instances (everything is parented to `overlay`, which the
-- caller destroys when the reveal closes).
function RevealFx.Play(overlay: Frame, options: PlayOptions, onBurst: () -> ())
	local center = UDim2.fromScale(0.5, 0.42)

	-- Glow behind the geode, building in tier colour
	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = center
	glow.Size = UDim2.fromOffset(120, 120)
	glow.BackgroundColor3 = options.Color
	glow.BackgroundTransparency = 0.85
	glow.Parent = overlay
	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = UDim.new(1, 0)
	glowCorner.Parent = glow
	TweenService:Create(
		glow,
		TweenInfo.new(options.Suspense, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Size = UDim2.fromOffset(340, 340), BackgroundTransparency = 0.45 }
	):Play()

	-- The geode: a container holding the crystal interior and two rock halves
	-- that sit flush over it.
	local geode = Instance.new("Frame")
	geode.AnchorPoint = Vector2.new(0.5, 0.5)
	geode.Position = center
	geode.Size = UDim2.fromOffset(0, 0)
	geode.BackgroundTransparency = 1
	geode.Parent = overlay
	TweenService:Create(geode, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(GEODE_SIZE, GEODE_SIZE),
	}):Play()

	-- Crystal-lined interior, hidden under the halves until they open
	local interior = Instance.new("Frame")
	interior.AnchorPoint = Vector2.new(0.5, 0.5)
	interior.Position = UDim2.fromScale(0.5, 0.5)
	interior.Size = UDim2.fromOffset(GEODE_SIZE - 18, GEODE_SIZE - 18)
	interior.BackgroundColor3 = options.Color
	interior.BackgroundTransparency = 0.1
	interior.ZIndex = 2
	interior.Parent = geode
	local interiorCorner = Instance.new("UICorner")
	interiorCorner.CornerRadius = UDim.new(1, 0)
	interiorCorner.Parent = interior

	local fillRng = Random.new(7)
	if RevealFx.ShellStyle == "Chest" then
		interiorCorner.CornerRadius = UDim.new(0, 12)
		-- A chest is full of treasure, not lined with rock. Coins heaped toward
		-- the bottom so the pile has a shape instead of being scattered evenly.
		for i = 1, 22 do
			local coin = Instance.new("Frame")
			coin.AnchorPoint = Vector2.new(0.5, 0.5)
			local size = fillRng:NextInteger(14, 26)
			coin.Position = UDim2.fromScale(
				fillRng:NextNumber(0.14, 0.86),
				fillRng:NextNumber(0.42, 0.9) + fillRng:NextNumber(0, 0.08)
			)
			coin.Size = UDim2.fromOffset(size, size)
			coin.Rotation = fillRng:NextInteger(0, 179)
			coin.BackgroundColor3 = if i % 4 == 0
				then Color3.new(1, 1, 1):Lerp(options.Color, 0.5)
				else RevealFx.ChestBand:Lerp(Color3.new(1, 1, 1), fillRng:NextNumber(0, 0.35))
			coin.BorderSizePixel = 0
			coin.ZIndex = 2
			coin.Parent = interior
			local coinCorner = Instance.new("UICorner")
			coinCorner.CornerRadius = UDim.new(1, 0)
			coinCorner.Parent = coin
		end
	else
		-- Crystal teeth lining the cavity, so the open geode is jagged rather
		-- than a plain coloured disc.
		for i = 1, 14 do
			local angle = (i / 14) * math.pi * 2
			local tooth = Instance.new("Frame")
			tooth.AnchorPoint = Vector2.new(0.5, 0.5)
			tooth.Position = UDim2.new(0.5, math.cos(angle) * 62, 0.5, math.sin(angle) * 62)
			tooth.Size = UDim2.fromOffset(fillRng:NextInteger(10, 18), fillRng:NextInteger(22, 40))
			tooth.Rotation = math.deg(angle) + 90
			tooth.BackgroundColor3 = Color3.new(1, 1, 1):Lerp(options.Color, 0.55)
			tooth.BackgroundTransparency = 0.15
			tooth.BorderSizePixel = 0
			tooth.ZIndex = 2
			tooth.Parent = interior
		end
	end

	local firstHalf = makeHalf(geode, true) -- left, or the lid when hinged
	local secondHalf = makeHalf(geode, false)

	-- The 3D chest replaces the flat halves for chest-style reveals. Everything
	-- else — glow, seam, cracks, shards, flash — is shape-agnostic and carries on
	-- doing its job around it.
	local chest: ChestView.Chest? = nil
	if RevealFx.ShellStyle == "Chest" and RevealFx.Use3DChest then
		chest = ChestView.Create(geode, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1.9, 1.9), options.Color)
		firstHalf.Visible = false
		secondHalf.Visible = false
		-- The interior is the lining seen once the halves part. A real chest has
		-- its own inside, so this would only show through as a coloured disc.
		interior.Visible = false
	end

	-- The seam the crack runs along before it splits
	local seam = Instance.new("Frame")
	seam.AnchorPoint = Vector2.new(0.5, 0.5)
	seam.Position = UDim2.fromScale(0.5, 0.5)
	seam.Size = if RevealFx.SplitVertical then UDim2.fromOffset(GEODE_SIZE, 0) else UDim2.fromOffset(0, GEODE_SIZE)
	seam.BackgroundColor3 = Color3.new(1, 1, 1)
	seam.BackgroundTransparency = 1
	seam.BorderSizePixel = 0
	seam.ZIndex = 4
	seam.Parent = geode

	task.spawn(function()
		task.wait(0.3)
		local rng = Random.new()
		local elapsed = 0
		local crackCount = 0
		local step = 0.045
		while elapsed < options.Suspense do
			task.wait(step)
			elapsed += step
			local progress = elapsed / options.Suspense
			local amplitude = 2 + progress * 12
			geode.Position = center
				+ UDim2.fromOffset(rng:NextInteger(-amplitude, amplitude), rng:NextInteger(-amplitude, amplitude))
			geode.Rotation = rng:NextNumber(-progress * 8, progress * 8)
			if chest then
				-- Rattling harder as it builds. Anticipation is most of what
				-- makes the opening land.
				chest.Shake(rng:NextNumber(-progress * 2.5, progress * 2.5))
			end

			-- The fracture walks down the seam in jagged segments, with rising
			-- ticks — five milestones, so the pacing scales with suspense.
			local wantedCracks = math.floor(progress * 5)
			if wantedCracks > crackCount then
				crackCount = wantedCracks
				local along = (crackCount - 0.5) / 5
				local jitter = rng:NextInteger(-8, 8)
				local crack = Instance.new("Frame")
				crack.AnchorPoint = Vector2.new(0.5, 0.5)
				crack.Position = if RevealFx.SplitVertical
					then UDim2.new(along, 0, 0.5, jitter)
					else UDim2.new(0.5, jitter, along, 0)
				crack.Size = if RevealFx.SplitVertical
					then UDim2.fromOffset(GEODE_SIZE // 5 + 8, rng:NextInteger(3, 6))
					else UDim2.fromOffset(rng:NextInteger(3, 6), GEODE_SIZE // 5 + 8)
				crack.Rotation = rng:NextInteger(-14, 14)
				crack.BackgroundColor3 = Color3.new(1, 1, 1)
				crack.BackgroundTransparency = 0.15
				crack.BorderSizePixel = 0
				crack.ZIndex = 4
				crack.Parent = geode
				tick(overlay, 0.9 + crackCount * 0.12)
			end
		end

		-- Light leaking from the seam just before it gives: the tell that
		-- something bright is inside.
		seam.BackgroundTransparency = 0.2
		local gap = options.Charged and 26 or 12
		TweenService:Create(seam, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = if RevealFx.SplitVertical
				then UDim2.fromOffset(GEODE_SIZE, gap)
				else UDim2.fromOffset(gap, GEODE_SIZE),
		}):Play()
		if options.Charged then
			for _, half in { firstHalf, secondHalf } do
				local rock = half:FindFirstChild("Rock")
				if rock and rock:IsA("Frame") then
					TweenService:Create(rock, TweenInfo.new(0.3), { BackgroundColor3 = Color3.new(1, 1, 1) }):Play()
				end
			end
			task.wait(0.3)
		else
			task.wait(0.12)
		end

		-- SPLIT: the halves crack apart and tumble away, showing the cavity
		geode.Rotation = 0
		geode.Position = center
		play(overlay, THUD_SOUND, 0.75, 0.8)
		tick(overlay, 0.6)

		-- Sideways: both hemispheres fly apart. Hinged: the lid lifts up and back
		-- while the base only settles.
		--
		-- Position only, no spin. Each half is a clipped frame showing one half of
		-- a circle, and Roblox stops clipping any subtree that carries a rotation —
		-- so rotating a half mid-flight turned it back into a whole circle. Waiting
		-- until it had faded to rotate it just made the spin invisible, which is
		-- worse than not having it: the Back-eased fling, the flash and the shards
		-- already sell the break.
		if chest then
			-- The lid throws itself back on the same beat the halves would have
			-- flown apart, so thud, flash and shards all still land together.
			chest.Open(0.55)
		end
		local splitInfo = TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local firstTarget, secondTarget
		if RevealFx.SplitVertical then
			firstTarget = UDim2.fromOffset(-20, -210)
			secondTarget = UDim2.fromOffset(10, 110)
		else
			firstTarget = UDim2.fromOffset(-260, 90)
			secondTarget = UDim2.fromOffset(260, 70)
		end
		TweenService:Create(firstHalf, splitInfo, {
			Position = UDim2.fromScale(0.5, 0.5) + firstTarget,
		}):Play()
		TweenService:Create(secondHalf, splitInfo, {
			Position = UDim2.fromScale(0.5, 0.5) + secondTarget,
		}):Play()
		for _, half in { firstHalf, secondHalf } do
			local rock = half:FindFirstChild("Rock")
			if rock and rock:IsA("Frame") then
				TweenService:Create(rock, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
				local rockStroke = rock:FindFirstChildOfClass("UIStroke")
				if rockStroke then
					TweenService:Create(rockStroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
				end
			end
		end
		TweenService:Create(seam, TweenInfo.new(0.35), {
			Size = UDim2.fromOffset(GEODE_SIZE, GEODE_SIZE),
			BackgroundTransparency = 1,
		}):Play()

		-- Flash + shards thrown from the break
		local flash = Instance.new("Frame")
		flash.Size = UDim2.fromScale(1, 1)
		flash.BackgroundColor3 = Color3.new(1, 1, 1)
		flash.BackgroundTransparency = 0.25
		flash.BorderSizePixel = 0
		flash.ZIndex = 5
		flash.Parent = overlay
		TweenService:Create(flash, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		task.delay(0.45, function()
			flash:Destroy()
		end)

		for _ = 1, 14 do
			local shard = Instance.new("Frame")
			shard.AnchorPoint = Vector2.new(0.5, 0.5)
			shard.Position = center
			local size = rng:NextInteger(10, 26)
			shard.Size = UDim2.fromOffset(size, size)
			shard.Rotation = rng:NextInteger(0, 89)
			shard.BackgroundColor3 = if rng:NextNumber() < 0.5 then RevealFx.ShellColor else options.Color
			shard.BorderSizePixel = 0
			shard.Parent = overlay
			local shardCorner = Instance.new("UICorner")
			shardCorner.CornerRadius = UDim.new(0, 4)
			shardCorner.Parent = shard
			local angle = rng:NextNumber(0, math.pi * 2)
			local distance = rng:NextInteger(140, 280)
			TweenService:Create(shard, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = center + UDim2.fromOffset(math.cos(angle) * distance, math.sin(angle) * distance - 40),
				Rotation = shard.Rotation + rng:NextInteger(-180, 180),
				BackgroundTransparency = 1,
			}):Play()
			task.delay(0.6, function()
				shard:Destroy()
			end)
		end

		-- The open cavity blooms for a beat, then clears for the cards. Fade
		-- every piece rather than shrinking the container: the teeth and cracks
		-- are sized in offsets, so they would hang around at full size while
		-- their parent collapsed to nothing.
		TweenService:Create(interior, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(GEODE_SIZE + 40, GEODE_SIZE + 40),
		}):Play()
		task.delay(0.3, function()
			for _, descendant in geode:GetDescendants() do
				if descendant:IsA("Frame") then
					TweenService:Create(descendant, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
				end
			end
			task.delay(0.4, function()
				geode:Destroy()
			end)
		end)
		TweenService:Create(glow, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()

		task.wait(0.28)
		onBurst()
	end)
end

-- Falling confetti for Epic+ pulls.
function RevealFx.Confetti(overlay: Frame, tierColor: Color3, count: number)
	local rng = Random.new()
	local palette = { tierColor, Color3.fromRGB(255, 210, 90), Color3.fromRGB(120, 255, 200), Color3.fromRGB(255, 150, 220) }
	for _ = 1, count do
		local piece = Instance.new("Frame")
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = UDim2.new(rng:NextNumber(0.1, 0.9), 0, 0, -20)
		piece.Size = UDim2.fromOffset(rng:NextInteger(6, 11), rng:NextInteger(6, 11))
		piece.Rotation = rng:NextInteger(0, 179)
		piece.BackgroundColor3 = palette[rng:NextInteger(1, #palette)]
		piece.BorderSizePixel = 0
		piece.Parent = overlay
		TweenService:Create(piece, TweenInfo.new(rng:NextNumber(1.1, 1.9), Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(piece.Position.X.Scale + rng:NextNumber(-0.08, 0.08), 0, 1.1, 0),
			Rotation = piece.Rotation + rng:NextInteger(-360, 360),
		}):Play()
		task.delay(2, function()
			piece:Destroy()
		end)
	end
end

-- Slowly rotating sunburst rays behind a Legendary/Mythic card.
function RevealFx.Sunburst(overlay: Frame, position: UDim2, color: Color3): Frame
	local container = Instance.new("Frame")
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Position = position
	container.Size = UDim2.fromOffset(0, 0)
	container.BackgroundTransparency = 1
	container.ZIndex = 0
	container.Parent = overlay
	for i = 1, 8 do
		local ray = Instance.new("Frame")
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.fromOffset(340, 26)
		ray.Rotation = i * 22.5
		ray.BackgroundColor3 = color
		ray.BackgroundTransparency = 0.82
		ray.BorderSizePixel = 0
		ray.ZIndex = 0
		ray.Parent = container
	end
	TweenService:Create(
		container,
		TweenInfo.new(6, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
		{ Rotation = 360 }
	):Play()
	return container
end

return RevealFx
