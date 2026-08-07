--!strict
-- Fishing loop: click a buoy to cast, wait for the lamp to flash, click again to
-- land it. One angler per buoy at a time; better rods bite sooner and bring up
-- more per catch.
--
-- A bite opens the REEL-IN minigame on the angler's client (see ReelMinigame):
-- a fish darting up a bar, a bracket you steer by holding, a meter that fills
-- while you keep them together. Skill is a BONUS, never a gate — the reel always
-- lands the fish, and how well you tracked it decides how many come up. Clicking
-- too EARLY, before the bite, is the one thing that costs you: it spooks the
-- fish and pushes the bite back.
--
-- What you land is rolled here, and it is the whole shape of the game:
--   * roughly seven times in eight, a FISH — straight into your hold, no
--     opening step. This is the collectible.
--   * otherwise a CHEST — carried back to the Chest station and opened there,
--     with the reveal animation, the odds panel and the policy gating intact.
--     Every chest is a guaranteed Rare+, which is what earns it the ceremony.
--
-- Spots belong to an area. A cast only registers at spots in the water the
-- player is actually fishing, so five areas share one service and one loop.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Remotes = require(Shared.Remotes)

local MiningService = {}

-- Seconds a hooked fish will wait for you before the line is considered
-- abandoned. Generous on purpose: nothing about being slow should cost a catch,
-- but a line nobody is ever coming back for has to free its buoy for the room.
local CLAIM_TIMEOUT = 20
-- A few studs of slack past the cast range, so shuffling on the spot or a bit of
-- position lag never yanks the line out of the water mid-fish.
local CLAIM_SLACK = 8

type SpotState = {
	OwnerUserId: number?,
	BiteAt: number?, -- os.clock() when the bite window opens
	-- os.clock() of the angler's last actual ACTION on this spot, and the only
	-- thing the idle timeout is measured from. It is deliberately not BiteAt,
	-- which the game itself moves — measuring from a deadline the game keeps
	-- pushing forward meant the claim renewed itself and never expired.
	ActedAt: number,
	Biting: boolean, -- the lamp is currently flashing; stops the flash re-firing
	HookedAt: number?, -- os.clock() the fish took the bait; nil until it does
	Resolved: boolean,
	BaseColor: Color3,
	Area: number,
}

local ctx: any = nil
local spots: { [BasePart]: SpotState } = {}
local spotsByArea: { [number]: { BasePart } } = {}
local rng = Random.new()

-- Every spot in one area, for Auto-Cast's "find me somewhere to fish" search.
MiningService.SpotsByArea = spotsByArea

local function playSound(parent: Instance, id: string, pitch: number, volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.PlaybackSpeed = pitch
	sound.Volume = volume
	sound.Parent = parent
	sound:Play()
	task.delay(2, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

-- Catch celebration. The label names what actually came up, because "+1 Chest!"
-- when it was a fish is the kind of small lie that makes a whole loop feel fake.
local function catchEffects(spot: BasePart, text: string, color: Color3)
	playSound(spot, "rbxasset://sounds/snap.mp3", 1 + rng:NextNumber(-0.1, 0.2), 0.7)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(160, 220, 255))
	emitter.Lifetime = NumberRange.new(0.35, 0.7)
	emitter.Speed = NumberRange.new(8, 16)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.5, 0)
	emitter.Enabled = false
	emitter.Parent = spot
	emitter:Emit(18)
	task.delay(1.2, function()
		emitter:Destroy()
	end)

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(7, 1.6)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard
	billboard.Parent = spot
	TweenService:Create(billboard, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new(0, 7, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(0.9), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1, function()
		billboard:Destroy()
	end)
end

-- The angler whose line is in this spot, if they are still here. The spot stores
-- a UserId rather than a Player so a leaver can't keep a claim alive.
local function ownerOf(state: SpotState): Player?
	return if state.OwnerUserId then Players:GetPlayerByUserId(state.OwnerUserId) else nil
end

-- Only the LAMP changes. The buoy is a physical object floating in the sea; it
-- should not swell to twice its size because a fish is interested, which is what
-- the old single-neon-ball marker did for every state change.
-- The lantern is a CYLINDER lying on its side (X is its height), so the flash
-- swells its diameter and leaves its length alone. Scaling all three axes — the
-- old values, from when the lamp was a ball — would squash it into a disc every
-- time a fish bit.
local LAMP_IDLE = Vector3.new(1.1, 1.25, 1.25)
local LAMP_BITE = Vector3.new(1.1, 2.1, 2.1)

local function lampOf(spot: BasePart): (BasePart?, PointLight?)
	local model = spot.Parent
	local lamp = model and model:FindFirstChild("Lamp")
	if lamp and lamp:IsA("BasePart") then
		return lamp, lamp:FindFirstChildOfClass("PointLight")
	end
	return nil, nil
end

local function setIdle(spot: BasePart, state: SpotState)
	local owner = ownerOf(state)
	state.OwnerUserId = nil
	state.BiteAt = nil
	state.Biting = false
	state.HookedAt = nil
	state.Resolved = true
	local lamp, light = lampOf(spot)
	if lamp then
		lamp.Color = state.BaseColor
		lamp.Size = LAMP_IDLE
	end
	if light then
		light.Color = state.BaseColor
		light.Brightness = 1.2
		light.Range = 14
	end
	if owner then
		ctx.RodVis.Reel(owner)
	end
end

local function setCast(spot: BasePart, player: Player?)
	local lamp, light = lampOf(spot)
	-- Dimmed while the line is out: the lamp going quiet is the "waiting" state,
	-- so the flash later has something to be brighter than. The float's own
	-- colour never changes, so it is the reliable source for the lamp's base.
	if lamp then
		lamp.Color = spot.Color:Lerp(Color3.new(0, 0, 0), 0.4)
		lamp.Size = LAMP_IDLE
	end
	if light then
		light.Brightness = 0.5
	end
	if player then
		-- Land the bobber just off the buoy rather than inside it, so both are
		-- visible and the buoy stays the thing you click.
		ctx.RodVis.Cast(player, spot.Position + Vector3.new(0, 0.3, 2.6))
	end
end

local function setBite(spot: BasePart, player: Player?)
	local lamp, light = lampOf(spot)
	if lamp then
		lamp.Color = Color3.fromRGB(255, 255, 255)
		TweenService:Create(lamp, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = LAMP_BITE,
		}):Play()
	end
	if light then
		light.Color = Color3.fromRGB(255, 255, 255)
		light.Brightness = 5
		light.Range = 30
	end
	-- Audible cue so the timing window works by ear as well as by eye
	playSound(spot, "rbxasset://sounds/electronicpingshort.wav", 1.4, 0.8)
	if player then
		ctx.RodVis.Bite(player)
	end
end

local function rodDamage(data: any): number
	local rod = Balance.Pickaxe(data.Pickaxe)
	return rod.Damage
end

local function biteDelay(data: any?): number
	local speedup = if data then Balance.RodBiteFactor(rodDamage(data)) else 1
	return rng:NextNumber(Balance.BiteDelayMin, Balance.BiteDelayMax) * speedup
end

-- How many fish come up on one landing. The whole part of the rod's extra-catch
-- value is guaranteed, the fraction is a roll — so upgrading always moves this
-- number, however slightly, rather than stopping dead at a cap.
local function catchCount(data: any): number
	local extra = Balance.RodExtraCatch(rodDamage(data))
	local guaranteed = math.floor(extra)
	local chance = extra - guaranteed
	local total = 1 + guaranteed
	if rng:NextNumber() < chance then
		total += 1
	end
	return total
end

-- `quality` is how much of the reel was spent with the fish in the bracket, 0..1.
local function landCatch(spot: BasePart, state: SpotState, player: Player, quality: number)
	local data = ctx.Data.Get(player)
	if not data then
		setIdle(spot, state)
		return
	end
	local space = ctx.Data.BackpackCapacity(data) - ctx.Data.HoldCount(data)
	if space <= 0 then
		Remotes.Event("Notify"):FireClient(player, {
			Text = "Boat full! Sell your catch at the Aquarium.",
			Color = Color3.fromRGB(255, 120, 120),
		})
		setIdle(spot, state)
		return
	end

	-- A good reel is worth extra fish. That is the entire reward for skill here —
	-- it buys you MORE, it never decides whether you get anything.
	local bonus = math.floor(quality * Balance.ReelMaxBonus + 0.5)
	local caught = math.min(catchCount(data) + bonus, space)

	local chests = 0
	local fish: { any } = {}
	for _ = 1, caught do
		if rng:NextNumber() < Balance.CrateChance then
			chests += 1
		else
			local result = ctx.Crack.LandFish(player)
			if result then
				table.insert(fish, result)
			end
		end
	end
	if chests > 0 then
		data.Geodes += chests
	end
	data.Stats.GeodesMined += caught
	ctx.Data.MarkDirty(player)
	ctx.Analytics.FunnelStep(player, data, 1, "FirstGeode")

	-- Name the reel, always. Even a scrappy one gets "CAUGHT!", because the
	-- player did in fact catch it and being told so is the point.
	local rating = if quality >= 0.85
		then "PERFECT REEL!"
		elseif quality >= 0.6 then "GREAT REEL!"
		elseif quality >= 0.3 then "NICE REEL!"
		else "CAUGHT!"
	catchEffects(spot, rating, if quality >= 0.6 then Color3.fromRGB(255, 240, 120) else Color3.fromRGB(200, 230, 255))
	if chests > 0 then
		catchEffects(spot, chests > 1 and ("+" .. chests .. " Chests!") or "TREASURE CHEST!", Color3.fromRGB(255, 210, 90))
		Remotes.Event("Notify"):FireClient(player, {
			Text = "A chest! Open it at the Chest station.",
			Color = Color3.fromRGB(255, 210, 90),
		})
	end
	if #fish > 0 then
		local first = fish[1]
		local label = if #fish > 1
			then ("+%d Fish!"):format(#fish)
			else ("%s  %.1f lb"):format(first.Base, first.Weight)
		catchEffects(spot, label, first.Color or Color3.fromRGB(160, 220, 255))
	end
	if caught > 1 then
		-- Late rods land five or six at a time, and calling that a "double hook"
		-- reads as a string nobody updated.
		local shout = if caught == 2 then "DOUBLE HOOK!" elseif caught <= 4 then "BIG HAUL!" else "THE WHOLE SHOAL!"
		Remotes.Event("Notify"):FireClient(player, {
			Text = ("%s  +%d on the line!"):format(shout, caught),
			Color = Color3.fromRGB(120, 255, 200),
		})
	end

	if chests > 0 and ctx.Monetization.OwnsPass(player, "AutoCrack") and data.Settings.AutoCrack ~= false then
		for _ = 1, chests do
			ctx.Crack.AutoCrack(player)
		end
	end
	setIdle(spot, state)
end

local function onSpotClicked(spot: BasePart, player: Player): boolean
	local state = spots[spot]
	local data = ctx.Data.Get(player)
	if not state or not data then
		return false
	end
	-- Your line only reaches the water you have sailed to.
	if state.Area ~= ctx.Data.Layer(data) then
		return false
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - spot.Position).Magnitude > Balance.CastRange then
		return false
	end

	if state.OwnerUserId == nil then
		-- Cast: claim the spot and schedule a bite (better rods bite sooner).
		if ctx.Data.HoldCount(data) >= ctx.Data.BackpackCapacity(data) then
			Remotes.Event("Notify"):FireClient(player, {
				Text = "Boat full! Sell your catch at the Aquarium.",
				Color = Color3.fromRGB(255, 120, 120),
			})
			return false
		end
		state.OwnerUserId = player.UserId
		state.Resolved = false
		state.Biting = false
		state.HookedAt = nil
		state.ActedAt = os.clock()
		state.BiteAt = os.clock() + biteDelay(data)
		setCast(spot, player)
		return true
	elseif state.OwnerUserId == player.UserId then
		local now = os.clock()
		-- Any click on your own line counts as being present, so the idle timeout
		-- only fires on someone who has genuinely stopped fishing.
		state.ActedAt = now
		if state.HookedAt then
			-- Fish is on and the reel-in minigame owns it from here. Clicks are
			-- the minigame's input now, so this must not resolve the catch behind
			-- its back — with Auto-Cast holding the button, that would land every
			-- fish the instant it bit and the bar would never be played.
			return true
		end
		-- Clicking before the bite used to be silently ignored, which is
		-- indistinguishable from a broken game. It spooks the fish instead: the
		-- bite gets pushed back a moment, the line twitches, and the player can
		-- see that their click did something and what it cost.
		if state.BiteAt then
			state.BiteAt += Balance.SpookDelay
			ctx.RodVis.Spook(player)
		end
	end
	-- clicking someone else's claimed spot does nothing
	return false
end

-- True when this spot is free for `player` to claim right now.
function MiningService.IsFree(spot: BasePart, player: Player): boolean
	local state = spots[spot]
	return state ~= nil and (state.OwnerUserId == nil or state.OwnerUserId == player.UserId)
end

-- Does `player` have a fish on this line right now? Auto-Cast uses it to know
-- when to reel, and gets no better information than the flashing lamp already
-- gives a human looking at the same buoy.
function MiningService.IsBiting(spot: BasePart, player: Player): boolean
	local state = spots[spot]
	return state ~= nil and state.OwnerUserId == player.UserId and state.HookedAt ~= nil
end

-- The single entry point for a cast or a strike, human or automated. Auto-Cast
-- drives this so every check, reward and effect is literally the same code.
function MiningService.TryFish(player: Player, spot: BasePart): boolean
	if not ctx or not spots[spot] then
		return false
	end
	return onSpotClicked(spot, player)
end

function MiningService.Init(serviceCtx: any, nodes: { BasePart })
	ctx = serviceCtx
	for _, spot in nodes do
		local area = (spot:GetAttribute("Area") :: number?) or 1
		spots[spot] = {
			OwnerUserId = nil,
			BiteAt = nil,
			ActedAt = 0,
			Biting = false,
			HookedAt = nil,
			Resolved = true,
			BaseColor = spot.Color,
			Area = area,
		}
		local list = spotsByArea[area]
		if not list then
			list = {}
			spotsByArea[area] = list
		end
		table.insert(list, spot)
		local click = spot:FindFirstChildOfClass("ClickDetector")
		if click then
			click.MouseClick:Connect(function(player)
				onSpotClicked(spot, player)
			end)
		end
	end
	-- Primary tap path: the equipped rod Tool swallows clicks before
	-- ClickDetectors see them, so the client raycasts its tap and reports the
	-- spot here. Same server-side validation (membership, area, distance, timing).
	Remotes.Event("MineNode").OnServerEvent:Connect(function(player, spot)
		if typeof(spot) == "Instance" and spots[spot :: any] then
			onSpotClicked(spot :: BasePart, player)
		end
	end)

	-- The reel-in runs on the client, because a bar that stutters is worse than
	-- no bar, and 60fps tracking cannot survive a round trip per frame.
	--
	-- What that means for trust, stated plainly: a modified client can report a
	-- flawless reel it did not play. The server therefore checks everything that
	-- MATTERS here — that this player really has a fish on this spot, that the
	-- spot is in their area and in range (onSpotClicked already established it,
	-- and setIdle revokes it the moment they stray) — and clamps the one thing it
	-- cannot verify to the range it was allowed to be in. The prize for lying is
	-- at most ReelMaxBonus extra common fish on a catch they had already earned,
	-- which is not worth spending server frames to prevent.
	Remotes.Event("ReelResult").OnServerEvent:Connect(function(player, payload)
		if typeof(payload) ~= "table" then
			return
		end
		local spot = payload.Node
		if typeof(spot) ~= "Instance" then
			return
		end
		local state = spots[spot :: any]
		if not state or state.OwnerUserId ~= player.UserId or not state.HookedAt then
			return -- no fish of theirs on this line; nothing to land
		end
		local quality = math.clamp(tonumber(payload.Quality) or 0, 0, 1)
		state.ActedAt = os.clock()
		landCatch(spot :: BasePart, state, player, quality)
	end)

	-- One loop drives bite flashes, missed-window recasts, and claim expiry.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		accumulator = 0
		local now = os.clock()
		for spot, state in spots do
			if state.OwnerUserId and state.BiteAt then
				local owner = Players:GetPlayerByUserId(state.OwnerUserId)
				-- Walk away and your line comes with you. Without this a cast held
				-- its buoy from anywhere on the map — including from another area —
				-- and kept auto-recasting at water the angler had long since left.
				local data = owner and ctx.Data.Get(owner)
				local character = owner and owner.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				-- Once a fish is ON, the range check stops applying. The player is
				-- looking at the reel bar, not at their feet, and releasing the
				-- spot underneath them would throw away a fight they are actively
				-- playing and never tell them why. Backing up while you fight
				-- something is also just what fishing looks like. The idle timeout
				-- still bounds it, and the reel itself times out sooner.
				local strayed = state.HookedAt == nil
					and (
						not root
						or (root.Position - spot.Position).Magnitude > Balance.CastRange + CLAIM_SLACK
						or (data ~= nil and state.Area ~= ctx.Data.Layer(data))
					)

				if not owner or strayed then
					setIdle(spot, state)
				elseif now - state.ActedAt > CLAIM_TIMEOUT then
					-- Still standing there, but has not touched it in a while.
					setIdle(spot, state)
				elseif now >= state.BiteAt and not state.Biting then
					-- The fish takes the bait, once, and then STAYS on until the
					-- player reels it in. There is no escape branch any more:
					-- losing a catch to a tenth of a second is the single most
					-- punishing thing this loop could do to an eight-year-old,
					-- and it bought nothing that the perfect-strike bonus does
					-- not buy better.
					--
					-- A flag, not a colour comparison: the buoy's own colour no
					-- longer changes on a bite (its lamp does), so the old
					-- "is it white yet" check would have re-fired the flash and
					-- its ping ten times a second.
					state.Biting = true
					state.HookedAt = now
					setBite(spot, owner)
					Remotes.Event("ReelStart"):FireClient(owner, { Node = spot, Area = state.Area })
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		for spot, state in spots do
			if state.OwnerUserId == player.UserId then
				setIdle(spot, state)
			end
		end
	end)
end

return MiningService
