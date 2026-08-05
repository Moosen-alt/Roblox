--!strict
-- The reveal engine: anticipation (shaking shell, spreading cracks, rising
-- ticks), burst (shard explosion + screen flash), and celebration extras
-- (confetti, rotating sunburst) for high-tier pulls. Suspense scales with the
-- best rarity in the batch — slot-machine timing, the clip moment.

local TweenService = game:GetService("TweenService")

local RevealFx = {}

-- Theme knobs (the fishing re-theme overrides these via sed)
RevealFx.ShellColor = Color3.fromRGB(130, 95, 60)
RevealFx.ShellStroke = Color3.fromRGB(255, 200, 60)

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

-- One hemisphere of the geode: a clipped frame showing exactly half of a
-- circle, so the two of them sit flush as one rock until they split.
local function makeHalf(parent: Frame, isLeft: boolean): Frame
	local half = Instance.new("Frame")
	half.AnchorPoint = Vector2.new(0.5, 0.5)
	half.Size = UDim2.fromOffset(GEODE_SIZE // 2, GEODE_SIZE)
	half.Position = UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(isLeft and -GEODE_SIZE // 4 or GEODE_SIZE // 4, 0)
	half.BackgroundTransparency = 1
	half.ClipsDescendants = true
	half.ZIndex = 3
	half.Parent = parent

	local rock = Instance.new("Frame")
	rock.Name = "Rock"
	rock.Size = UDim2.fromOffset(GEODE_SIZE, GEODE_SIZE)
	rock.Position = UDim2.fromOffset(isLeft and 0 or -GEODE_SIZE // 2, 0)
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
	-- Crystal teeth lining the cavity, so the open geode is jagged rather than
	-- a plain coloured disc.
	local toothRng = Random.new(7)
	for i = 1, 14 do
		local angle = (i / 14) * math.pi * 2
		local tooth = Instance.new("Frame")
		tooth.AnchorPoint = Vector2.new(0.5, 0.5)
		tooth.Position = UDim2.new(0.5, math.cos(angle) * 62, 0.5, math.sin(angle) * 62)
		tooth.Size = UDim2.fromOffset(toothRng:NextInteger(10, 18), toothRng:NextInteger(22, 40))
		tooth.Rotation = math.deg(angle) + 90
		tooth.BackgroundColor3 = Color3.new(1, 1, 1):Lerp(options.Color, 0.55)
		tooth.BackgroundTransparency = 0.15
		tooth.BorderSizePixel = 0
		tooth.ZIndex = 2
		tooth.Parent = interior
	end

	local leftHalf = makeHalf(geode, true)
	local rightHalf = makeHalf(geode, false)

	-- The seam the crack runs down before it splits
	local seam = Instance.new("Frame")
	seam.AnchorPoint = Vector2.new(0.5, 0.5)
	seam.Position = UDim2.fromScale(0.5, 0.5)
	seam.Size = UDim2.fromOffset(0, GEODE_SIZE)
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

			-- The fracture walks down the seam in jagged segments, with rising
			-- ticks — five milestones, so the pacing scales with suspense.
			local wantedCracks = math.floor(progress * 5)
			if wantedCracks > crackCount then
				crackCount = wantedCracks
				local crack = Instance.new("Frame")
				crack.AnchorPoint = Vector2.new(0.5, 0.5)
				crack.Position = UDim2.new(0.5, rng:NextInteger(-8, 8), (crackCount - 0.5) / 5, 0)
				crack.Size = UDim2.fromOffset(rng:NextInteger(3, 6), GEODE_SIZE // 5 + 8)
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
		TweenService:Create(seam, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(options.Charged and 26 or 12, GEODE_SIZE),
		}):Play()
		if options.Charged then
			for _, half in { leftHalf, rightHalf } do
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

		local splitInfo = TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(leftHalf, splitInfo, {
			Position = UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(-260, 90),
			Rotation = -55,
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(rightHalf, splitInfo, {
			Position = UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(260, 70),
			Rotation = 55,
			BackgroundTransparency = 1,
		}):Play()
		for _, half in { leftHalf, rightHalf } do
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
