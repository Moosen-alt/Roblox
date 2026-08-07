--!strict
-- Fishing loop: click a spot to cast, wait for the bite flash, click again
-- inside the window to land it. One angler per spot at a time; better rods bite
-- sooner and can hook a second catch.
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

local BITE_WINDOW = 1.2 -- seconds the flash stays catchable
-- Backstop only. A cast now resolves within about five seconds either way — bite
-- and land, or bite and miss — so nothing should ever reach this. It stays
-- because a spot silently stuck as "claimed" would be invisible to everyone and
-- would cost that buoy for the rest of the server's life.
local CLAIM_TIMEOUT = 20
-- A few studs of slack past the cast range, so shuffling on the spot or a bit of
-- position lag never yanks the line out of the water mid-fish.
local CLAIM_SLACK = 8

type SpotState = {
	OwnerUserId: number?,
	BiteAt: number?, -- os.clock() when the bite window opens
	-- os.clock() of the angler's last actual ACTION on this spot. Deliberately
	-- separate from BiteAt: a missed window pushes BiteAt forward to auto-recast,
	-- so measuring the claim timeout from BiteAt meant the claim renewed itself
	-- every few seconds and never expired. One cast held a spot forever, from
	-- anywhere on the map, until the player left the server.
	ActedAt: number,
	Biting: boolean, -- the lamp is currently flashing; stops the flash re-firing
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
local LAMP_IDLE = Vector3.new(1, 1, 1)
local LAMP_BITE = Vector3.new(1.9, 1.9, 1.9)

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
	return rng:NextNumber(1.5, 4.0) * speedup
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

local function landCatch(spot: BasePart, state: SpotState, player: Player)
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

	local caught = math.min(catchCount(data), space)

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
		state.ActedAt = os.clock()
		state.BiteAt = os.clock() + biteDelay(data)
		setCast(spot, player)
		return true
	elseif state.OwnerUserId == player.UserId then
		local now = os.clock()
		-- Any click on your own line counts as being present, so the idle timeout
		-- only fires on someone who has genuinely stopped fishing.
		state.ActedAt = now
		if state.BiteAt and now >= state.BiteAt and now <= state.BiteAt + BITE_WINDOW then
			landCatch(spot, state, player)
			return true
		end
		-- clicking early does nothing — wait for the splash
	end
	-- clicking someone else's claimed spot does nothing
	return false
end

-- True when this spot is free for `player` to claim right now.
function MiningService.IsFree(spot: BasePart, player: Player): boolean
	local state = spots[spot]
	return state ~= nil and (state.OwnerUserId == nil or state.OwnerUserId == player.UserId)
end

-- Is `player`'s claimed spot flashing right now? Auto-Cast needs to know when to
-- strike; it does not get to strike outside the same window a human has to hit.
function MiningService.IsBiting(spot: BasePart, player: Player): boolean
	local state = spots[spot]
	if not state or state.OwnerUserId ~= player.UserId or not state.BiteAt then
		return false
	end
	local now = os.clock()
	return now >= state.BiteAt and now <= state.BiteAt + BITE_WINDOW
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
				local strayed = not root
					or (root.Position - spot.Position).Magnitude > Balance.CastRange + CLAIM_SLACK
					or (data ~= nil and state.Area ~= ctx.Data.Layer(data))

				if not owner or strayed then
					setIdle(spot, state)
				elseif now - state.ActedAt > CLAIM_TIMEOUT then
					-- Still standing there, but has not touched it in a while.
					setIdle(spot, state)
				elseif now >= state.BiteAt and now <= state.BiteAt + BITE_WINDOW then
					-- A flag, not a colour comparison. The buoy's own colour no
					-- longer changes on a bite (its lamp does), so the old
					-- "is it white yet" check would have re-fired the flash and
					-- its sound ten times a second for the whole window.
					if not state.Biting then
						state.Biting = true
						setBite(spot, owner)
					end
				elseif now > state.BiteAt + BITE_WINDOW then
					-- Missed it: the fish is gone, and so is the cast. The rod used
					-- to re-cast itself here, which meant one click produced an
					-- endless series of swings the player never asked for. One
					-- click, one cast — the game does not swing the rod on its own.
					-- Wanting it to is exactly what the Auto-Cast pass is for, and
					-- even that only fires while the player is holding the button.
					playSound(spot, "rbxasset://sounds/snap.mp3", 0.6, 0.4)
					setIdle(spot, state)
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
