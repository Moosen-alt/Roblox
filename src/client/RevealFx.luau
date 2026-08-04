--!strict
-- The reveal engine: anticipation (shaking shell, spreading cracks, rising
-- ticks), burst (shard explosion + screen flash), and celebration extras
-- (confetti, rotating sunburst) for high-tier pulls. Suspense scales with the
-- best rarity in the batch — slot-machine timing, the clip moment.

local TweenService = game:GetService("TweenService")

local RevealFx = {}

-- Theme knobs (the fishing re-theme overrides these via sed)
RevealFx.ShellColor = Color3.fromRGB(120, 100, 150)
RevealFx.ShellStroke = Color3.fromRGB(80, 65, 105)

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

-- Anticipation + burst. Calls onBurst at the explosion moment, then cleans up
-- its own instances (everything is parented to `overlay`, which the caller
-- destroys when the reveal closes).
function RevealFx.Play(overlay: Frame, options: PlayOptions, onBurst: () -> ())
	local center = UDim2.fromScale(0.5, 0.42)

	-- Glow behind the shell, building in tier color
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

	-- The shell
	local shell = Instance.new("Frame")
	shell.AnchorPoint = Vector2.new(0.5, 0.5)
	shell.Position = center
	shell.Size = UDim2.fromOffset(0, 0)
	shell.Rotation = 45
	shell.BackgroundColor3 = RevealFx.ShellColor
	shell.Parent = overlay
	local shellCorner = Instance.new("UICorner")
	shellCorner.CornerRadius = UDim.new(0, 28)
	shellCorner.Parent = shell
	local stroke = Instance.new("UIStroke")
	stroke.Color = RevealFx.ShellStroke
	stroke.Thickness = 5
	stroke.Parent = shell
	TweenService:Create(shell, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(140, 140),
	}):Play()

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
			shell.Position = center + UDim2.fromOffset(rng:NextInteger(-amplitude, amplitude), rng:NextInteger(-amplitude, amplitude))
			shell.Rotation = 45 + rng:NextNumber(-progress * 10, progress * 10)

			-- Cracks spread at fixed progress milestones, with rising ticks
			local wantedCracks = math.floor(progress * 5)
			if wantedCracks > crackCount then
				crackCount = wantedCracks
				local crack = Instance.new("Frame")
				crack.AnchorPoint = Vector2.new(0.5, 0.5)
				crack.Position = UDim2.new(0.5, rng:NextInteger(-40, 40), 0.5, rng:NextInteger(-40, 40))
				crack.Size = UDim2.fromOffset(3, 20 + crackCount * 16)
				crack.Rotation = rng:NextInteger(0, 179)
				crack.BackgroundColor3 = Color3.new(1, 1, 1)
				crack.BackgroundTransparency = 0.15
				crack.BorderSizePixel = 0
				crack.Parent = shell
				tick(overlay, 0.9 + crackCount * 0.12)
			end
		end

		-- Optional white charge-up for big pulls
		if options.Charged then
			local charge = TweenService:Create(shell, TweenInfo.new(0.3), { BackgroundColor3 = Color3.new(1, 1, 1) })
			charge:Play()
			charge.Completed:Wait()
		end

		-- BURST: flash + shards, then hand off to the cards
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

		shell.Visible = false
		tick(overlay, 0.6)
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
		TweenService:Create(glow, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()

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
