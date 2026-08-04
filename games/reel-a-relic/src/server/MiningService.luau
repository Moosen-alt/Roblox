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
	Remotes.Event("Notify"):FireClient(player, {
		Text = caught > 1 and ("DOUBLE HOOK! +" .. caught .. " chests!") or "+1 chest!",
		Color = Color3.fromRGB(120, 255, 200),
	})
	if ctx.Monetization.OwnsPass(player, "AutoCrack") then
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
