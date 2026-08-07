--!strict
-- The reel-in: the bar that appears when a fish is on.
--
-- A fish darts up and down a vertical bar. You steer a bracket by holding the
-- button — hold to rise, release to fall — and the meter fills while the fish is
-- inside it. Fill the meter and the fish is in the boat.
--
-- One input, so it plays identically with a finger and with a mouse. No aiming,
-- no precision tapping, nothing that needs two hands.
--
-- You cannot lose here. The meter drains while you are off the fish, but it can
-- never end the reel — the only two endings are "filled" and "ran out of time",
-- and both land the fish. How well you tracked it decides the bonus. That is the
-- same rule the rest of the game follows: an input always produces something,
-- and skill produces more.
--
-- It runs entirely on the client because a bar that stutters is worse than no
-- bar at all. The server hands over a difficulty, takes back a quality score,
-- and clamps it — see MiningService for what that trusts and what it doesn't.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Remotes = require(Shared.Remotes)
local State = require(script.Parent.State)
local UiKit = require(script.Parent.UiKit)

local ReelMinigame = {}

local gui: ScreenGui? = nil
local running = false

-- Held anywhere on screen, not just on the bar. Asking a player to keep a finger
-- inside a 40-pixel column while watching a fish move is a dexterity test the
-- rest of this design spent a lot of effort removing.
local holding = false

local function onInputBegan(_input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	holding = true
end

local function bar(parent: Instance): (Frame, Frame, Frame, Frame, TextLabel)
	-- Right of centre, anchored to its own middle, and only 260 tall. A 340-tall
	-- bar centred vertically runs into the bottom button row on a short phone,
	-- and a control the player is holding cannot afford to share space with six
	-- buttons that swallow the tap.
	local panel = UiKit.Create("Frame", {
		Name = "Reel",
		Size = UDim2.fromOffset(96, 260),
		Position = UDim2.new(1, -24, 0.5, -30),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = UiKit.Colors.Bg,
		BackgroundTransparency = 0.15,
		Parent = parent,
	})
	UiKit.Corner(16).Parent = panel
	UiKit.Stroke(UiKit.Colors.Accent, 2).Parent = panel

	local label = UiKit.Label({
		Text = "REEL IT IN!",
		Font = Enum.Font.FredokaOne,
		TextColor3 = UiKit.Colors.Accent,
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 6),
		Parent = panel,
	}) :: TextLabel

	-- The water column the fish swims in
	local track = UiKit.Create("Frame", {
		Name = "Track",
		Size = UDim2.fromOffset(44, 190),
		Position = UDim2.fromOffset(12, 38),
		BackgroundColor3 = Color3.fromRGB(24, 48, 78),
		Parent = panel,
	})
	UiKit.Corner(10).Parent = track
	track.ClipsDescendants = true

	-- The bracket you steer
	local zone = UiKit.Create("Frame", {
		Name = "Zone",
		Size = UDim2.new(1, -6, Balance.ReelZoneSize, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = UiKit.Colors.Good,
		BackgroundTransparency = 0.45,
		Parent = track,
	})
	UiKit.Corner(8).Parent = zone
	UiKit.Stroke(UiKit.Colors.Good, 2).Parent = zone

	local fish = UiKit.Create("Frame", {
		Name = "Fish",
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 210, 90),
		Parent = track,
	})
	UiKit.Corner(14).Parent = fish
	UiKit.Label({
		Text = "🐟",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = fish,
	})

	-- Progress meter, up the right-hand side
	local meterBack = UiKit.Create("Frame", {
		Name = "MeterBack",
		Size = UDim2.fromOffset(20, 190),
		Position = UDim2.fromOffset(64, 38),
		BackgroundColor3 = Color3.fromRGB(30, 30, 40),
		Parent = panel,
	})
	UiKit.Corner(8).Parent = meterBack
	local meter = UiKit.Create("Frame", {
		Name = "Meter",
		Size = UDim2.fromScale(1, 0),
		Position = UDim2.fromScale(0, 1),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = UiKit.Colors.Good,
		Parent = meterBack,
	})
	UiKit.Corner(8).Parent = meter

	-- The control, stated on the control. A player who does not know that holding
	-- raises the bracket has no way to discover it except by accident, and a
	-- mechanic you have to guess at is a mechanic most players never find.
	UiKit.Label({
		Text = "HOLD to raise",
		Font = Enum.Font.GothamBold,
		TextColor3 = UiKit.Colors.TextDim,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 1, -24),
		Parent = panel,
	})

	return panel, zone, fish, meter, label
end

-- `area` sets how hard the fish fights. Returns the quality of the reel (0..1)
-- and whether the PLAYER steered it rather than Auto-Cast.
local function play(area: number, autoPlay: boolean): (number, boolean)
	local screen = gui
	if not screen then
		return 0, false
	end
	local panel, zone, fish, meter, label = bar(screen)

	local rng = Random.new()
	local speed = Balance.ReelFishSpeed(area)
	local turnEvery = Balance.ReelFishTurn(area)

	local fishAt = 0.5
	local fishTarget = rng:NextNumber(0.1, 0.9)
	local sinceTurn = 0
	local zoneAt = 0.5
	local zoneVel = 0
	local progress = 0
	local elapsed = 0
	local onFish = 0
	-- Set the moment the player gives any input, which hands control back from
	-- Auto-Cast and makes the result theirs rather than the pass's.
	local touched = false

	panel.Size = UDim2.fromOffset(0, 0)
	TweenService:Create(panel, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(96, 260),
	}):Play()

	while progress < 1 and elapsed < Balance.ReelTimeout do
		local dt = RunService.RenderStepped:Wait()
		elapsed += dt

		-- Fish: swims toward a target it re-picks every so often. Deeper water
		-- picks new targets sooner and swims to them faster.
		sinceTurn += dt
		if sinceTurn >= turnEvery then
			sinceTurn = 0
			fishTarget = rng:NextNumber(0.08, 0.92)
		end
		local toTarget = fishTarget - fishAt
		local step = math.min(math.abs(toTarget), speed * dt)
		fishAt += (if toTarget >= 0 then step else -step)
		fishAt = math.clamp(fishAt, 0, 1)

		-- Bracket: hold to rise, release to fall, with drag so it settles.
		--
		-- Auto-Cast steers ONLY while the player isn't. Handing a paying player an
		-- autopilot for the best mechanic in the game would sell them less game
		-- than the free version — the pass exists to remove the repetitive part
		-- (casting, and re-casting, and re-casting), not the fun part. Touch the
		-- screen and you take the wheel back mid-reel, and your result counts as
		-- your own.
		if holding then
			touched = true
		end
		local wantUp = if (autoPlay and not touched) then (fishAt > zoneAt) else holding
		zoneVel += (if wantUp then Balance.ReelRise else -Balance.ReelGravity) * dt
		zoneVel -= zoneVel * math.min(Balance.ReelDrag * dt, 1)
		zoneAt += zoneVel * dt
		if zoneAt <= 0 or zoneAt >= 1 then
			zoneAt = math.clamp(zoneAt, 0, 1)
			zoneVel = 0
		end

		local caught = math.abs(fishAt - zoneAt) <= Balance.ReelZoneSize * 0.5
		if caught then
			onFish += dt
			progress = math.min(progress + Balance.ReelFillRate * dt, 1)
		else
			progress = math.max(progress - Balance.ReelDrainRate * dt, 0)
		end

		-- The UI works in "0 at the top" screen space; the sim works in
		-- "0 at the bottom" water space, because up should mean up.
		fish.Position = UDim2.fromScale(0.5, 1 - fishAt)
		zone.Position = UDim2.fromScale(0.5, 1 - zoneAt)
		zone.BackgroundColor3 = if caught then UiKit.Colors.Good else UiKit.Colors.BgLighter
		meter.Size = UDim2.fromScale(1, progress)
		meter.BackgroundColor3 = if progress > 0.8 then UiKit.Colors.Accent else UiKit.Colors.Good
		label.Text = if caught then "REELING!" else "STAY ON IT!"
		label.TextColor3 = if caught then UiKit.Colors.Good else UiKit.Colors.Accent
	end

	TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.fromOffset(0, 0),
	}):Play()
	task.delay(0.2, function()
		panel:Destroy()
	end)

	-- Quality is the share of the reel spent on the fish. Timing out with the
	-- meter half full still lands the catch; it just is not worth a bonus.
	return math.clamp(if elapsed > 0 then onFish / elapsed else 0, 0, 1), touched
end

function ReelMinigame.Init(screenGui: ScreenGui)
	gui = screenGui

	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(function()
		holding = false
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		holding = false
	end)

	Remotes.Event("ReelStart").OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or running then
			return
		end
		local node = payload.Node
		if typeof(node) ~= "Instance" then
			return
		end
		running = true
		holding = false
		local playerState = State.Get()
		local auto = playerState ~= nil
			and playerState.Passes ~= nil
			and playerState.Passes.AutoCast == true
		local quality, playedIt = play(tonumber(payload.Area) or 1, auto)
		if auto and not playedIt then
			-- Auto-Cast reeled it, not the player: capped at an ordinary standard
			-- whatever the simulated bracket happened to manage. The pass buys
			-- away the work, never the reward for doing it well. A player who
			-- grabbed the wheel mid-reel keeps their own score.
			quality = math.min(quality, Balance.ReelAutoQuality)
		end
		running = false
		Remotes.Event("ReelResult"):FireServer({ Node = node, Quality = quality })
	end)
end

function ReelMinigame.Active(): boolean
	return running
end

return ReelMinigame
