--!strict
-- Fishing loop (this game's replacement for tap-mining): click a fishing spot
-- to cast, wait for the bite flash, click again during the window to land a
-- treasure chest. One angler per spot at a time; better rods bite faster and
-- can hook a bonus chest.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Remotes = require(Shared.Remotes)

local MiningService = {}

local BITE_WINDOW = 1.2 -- seconds the flash stays catchable
local CLAIM_TIMEOUT = 20 -- seconds before an untended cast releases the spot

type SpotState = {
	OwnerUserId: number?,
	BiteAt: number?, -- os.clock() when the bite window opens
	Resolved: boolean,
	BaseColor: Color3,
}

local ctx: any = nil
local spots: { [BasePart]: SpotState } = {}
local rng = Random.new()

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

-- Catch celebration: pop sound, splash burst, floating "+N Chest!".
local function catchEffects(spot: BasePart, caught: number)
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
	billboard.Size = UDim2.fromScale(6, 1.6)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = caught > 1 and ("+" .. caught .. " Chests!") or "+1 Chest!"
	label.TextColor3 = Color3.fromRGB(255, 210, 90)
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

local function setIdle(spot: BasePart, state: SpotState)
	state.OwnerUserId = nil
	state.BiteAt = nil
	state.Resolved = true
	spot.Color = state.BaseColor
	spot.Transparency = 0.05
	spot.Size = Vector3.new(3, 2, 3)
end

local function setCast(spot: BasePart)
	spot.Transparency = 0.35
	TweenService:Create(spot, TweenInfo.new(0.3), { Size = Vector3.new(2.4, 1.6, 2.4) }):Play()
end

local function setBite(spot: BasePart)
	spot.Color = Color3.fromRGB(255, 255, 255)
	spot.Transparency = 0
	TweenService:Create(spot, TweenInfo.new(0.15), { Size = Vector3.new(4.2, 2.8, 4.2) }):Play()
	-- Audible cue so the timing window works by ear as well as by eye
	playSound(spot, "rbxasset://sounds/electronicpingshort.wav", 1.4, 0.8)
end

local function rodDamage(data: any): number
	local rod = Balance.Pickaxes[math.clamp(data.Pickaxe, 1, #Balance.Pickaxes)]
	return rod.Damage
end

local function landCatch(spot: BasePart, state: SpotState, player: Player)
	local data = ctx.Data.Get(player)
	if not data then
		setIdle(spot, state)
		return
	end
	local damage = rodDamage(data)
	local caught = 1
	if rng:NextNumber() < math.min(damage * 0.02, 0.6) then
		caught += 1 -- bonus chest on strong rods
	end
	local space = ctx.Data.BackpackCapacity(data) - data.Geodes
	if space <= 0 then
		Remotes.Event("Notify"):FireClient(player, { Text = "Boat full! Open your chests.", Color = Color3.fromRGB(255, 120, 120) })
		setIdle(spot, state)
		return
	end
	caught = math.min(caught, space)
	data.Geodes += caught
	data.Stats.GeodesMined += caught
	ctx.Data.MarkDirty(player)
	ctx.Analytics.FunnelStep(player, data, 1, "FirstGeode")
	catchEffects(spot, caught)
	if caught > 1 then
		Remotes.Event("Notify"):FireClient(player, {
			Text = "DOUBLE HOOK! +" .. caught .. " chests!",
			Color = Color3.fromRGB(120, 255, 200),
		})
	end
	if ctx.Monetization.OwnsPass(player, "AutoCrack") and data.Settings.AutoCrack ~= false then
		for _ = 1, caught do
			ctx.Crack.AutoCrack(player)
		end
	end
	setIdle(spot, state)
end

local function onSpotClicked(spot: BasePart, player: Player)
	local state = spots[spot]
	local data = ctx.Data.Get(player)
	if not state or not data then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - spot.Position).Magnitude > 60 then
		return
	end

	if state.OwnerUserId == nil then
		-- Cast: claim the spot and schedule a bite (better rods bite sooner).
		if data.Geodes >= ctx.Data.BackpackCapacity(data) then
			Remotes.Event("Notify"):FireClient(player, { Text = "Boat full! Open your chests.", Color = Color3.fromRGB(255, 120, 120) })
			return
		end
		state.OwnerUserId = player.UserId
		state.Resolved = false
		local speedup = math.clamp(1 - rodDamage(data) * 0.015, 0.5, 1)
		state.BiteAt = os.clock() + rng:NextNumber(1.5, 4.0) * speedup
		setCast(spot)
	elseif state.OwnerUserId == player.UserId then
		local now = os.clock()
		if state.BiteAt and now >= state.BiteAt and now <= state.BiteAt + BITE_WINDOW then
			landCatch(spot, state, player)
		end
		-- clicking early does nothing — wait for the splash
	end
	-- clicking someone else's claimed spot does nothing
end

function MiningService.Init(serviceCtx: any, nodes: { BasePart })
	ctx = serviceCtx
	for _, spot in nodes do
		spots[spot] = { OwnerUserId = nil, BiteAt = nil, Resolved = true, BaseColor = spot.Color }
		local click = spot:FindFirstChildOfClass("ClickDetector")
		if click then
			click.MouseClick:Connect(function(player)
				onSpotClicked(spot, player)
			end)
		end
	end
	-- Primary tap path: the equipped rod Tool swallows clicks before
	-- ClickDetectors see them, so the client raycasts its tap and reports the
	-- spot here. Same server-side validation (membership, distance, timing).
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
				if not owner then
					setIdle(spot, state)
				elseif now >= state.BiteAt and now <= state.BiteAt + BITE_WINDOW then
					if spot.Color ~= Color3.fromRGB(255, 255, 255) then
						setBite(spot)
					end
				elseif now > state.BiteAt + BITE_WINDOW then
					-- missed the window: fish escaped, auto-recast for the same angler
					if now > state.BiteAt + CLAIM_TIMEOUT then
						setIdle(spot, state)
					else
						spot.Color = state.BaseColor
						setCast(spot)
						local data = ctx.Data.Get(owner)
						local speedup = data and math.clamp(1 - rodDamage(data) * 0.015, 0.5, 1) or 1
						state.BiteAt = now + rng:NextNumber(1.5, 4.0) * speedup
					end
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
