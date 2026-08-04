--!strict
-- Player profiles (ProfileStore, session-locked) + the StateSync snapshot loop.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileStore = require(script.Parent.Packages.ProfileStore)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Monetization = require(Shared.Config.Monetization)
local Remotes = require(Shared.Remotes)

local TEMPLATE = {
	Coins = 0,
	TotalCoinsEarned = 0,
	JumpBonus = 0,
	Checkpoint = 0,
	Rebirths = 0,
	Trails = {} :: { [string]: boolean },
	EquippedTrail = "",
	Streak = { Count = 0, LastDay = 0, Best = 0 },
	Purchases = {} :: { string },
	OwnedPasses = {} :: { [string]: boolean },
	Stats = { BestStage = 0, TotalStagesCleared = 0 },
	Funnel = {} :: { [string]: boolean },
	LastSeen = 0,
}

export type Profile = typeof(TEMPLATE)

local DataService = {}
DataService.Template = TEMPLATE

local PlayerStore = ProfileStore.New("ObbyPlayerData_v1", TEMPLATE)
local profiles: { [Player]: any } = {}
local dirty: { [Player]: boolean } = {}
local lastPush: { [Player]: number } = {}

local ctx: any = nil

function DataService.Get(player: Player): Profile?
	local profile = profiles[player]
	return profile and profile.Data or nil
end

function DataService.MarkDirty(player: Player)
	dirty[player] = true
end

function DataService.CoinMult(player: Player, data: Profile): number
	local mult = 1 + Balance.RebirthGainBonus * data.Rebirths
	if ctx.Monetization.OwnsPass(player, "Coins2x") then
		mult *= 2
	end
	if ctx.Monetization.OwnsPass(player, "Vip") then
		mult *= 1 + Balance.VipCoinBonus
	end
	return mult
end

function DataService.JumpGainMult(player: Player, data: Profile): number
	local mult = 1 + Balance.RebirthGainBonus * data.Rebirths
	if ctx.Monetization.OwnsPass(player, "JumpGain2x") then
		mult *= 2
	end
	return mult
end

function DataService.AddCoins(player: Player, amount: number, applyMult: boolean?)
	local data = DataService.Get(player)
	if not data or amount <= 0 then
		return
	end
	local granted = amount
	if applyMult then
		granted = math.floor(amount * DataService.CoinMult(player, data) + 0.5)
	end
	data.Coins += granted
	data.TotalCoinsEarned += granted
	DataService.MarkDirty(player)
end

function DataService.JumpPower(player: Player, data: Profile): number
	return math.min(Balance.BaseJumpPower + data.JumpBonus, Balance.BaseJumpPower + Balance.JumpBonusCap)
end

function DataService.WalkSpeed(player: Player, data: Profile): number
	local speed = Balance.BaseWalkSpeed + data.JumpBonus * Balance.SpeedPerJumpBonus
	if ctx.Monetization.OwnsPass(player, "SpeedCoil") then
		speed += Balance.SpeedCoilBonus
	end
	return math.min(speed, Balance.WalkSpeedCap)
end

local function buildSnapshot(player: Player, data: Profile): { [string]: any }
	local passes = {}
	for key in Monetization.Gamepasses :: any do
		passes[key] = ctx.Monetization.OwnsPass(player, key)
	end
	return {
		Coins = data.Coins,
		JumpPower = DataService.JumpPower(player, data),
		WalkSpeed = DataService.WalkSpeed(player, data),
		JumpBonus = data.JumpBonus,
		Checkpoint = data.Checkpoint,
		Rebirths = data.Rebirths,
		RebirthReady = data.Checkpoint >= Balance.RebirthStage,
		CoinMult = DataService.CoinMult(player, data),
		JumpGainMult = DataService.JumpGainMult(player, data),
		Trails = data.Trails,
		EquippedTrail = data.EquippedTrail,
		Streak = { Count = data.Streak.Count, Best = data.Streak.Best },
		Passes = passes,
		Stats = data.Stats,
	}
end

function DataService.PushState(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	lastPush[player] = os.clock()
	dirty[player] = nil
	Remotes.Event("StateSync"):FireClient(player, buildSnapshot(player, data))
end

local function onPlayerAdded(player: Player)
	local profile = PlayerStore:StartSessionAsync("Player_" .. player.UserId, {})
	if profile == nil then
		player:Kick("Your data is loaded on another server. Rejoin in a moment!")
		return
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Data session ended. Please rejoin!")
	end)
	if not player:IsDescendantOf(Players) then
		profile:EndSession()
		return
	end
	profiles[player] = profile

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local stage = Instance.new("IntValue")
	stage.Name = "Stage"
	stage.Value = profile.Data.Checkpoint
	stage.Parent = leaderstats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = profile.Data.Rebirths
	rebirths.Parent = leaderstats
	leaderstats.Parent = player

	ctx.OnProfileLoaded(player, profile.Data)
	DataService.PushState(player)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		profile.Data.LastSeen = os.time()
		ctx.OnProfileReleasing(player, profile.Data)
		profile:EndSession()
		profiles[player] = nil
	end
	dirty[player] = nil
	lastPush[player] = nil
end

function DataService.Init(serviceCtx: any)
	ctx = serviceCtx
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for player, profile in profiles do
			local since = now - (lastPush[player] or 0)
			if (dirty[player] and since > 0.25) or since > 2 then
				DataService.PushState(player)
				local stats = player:FindFirstChild("leaderstats")
				if stats then
					local stage = stats:FindFirstChild("Stage") :: IntValue?
					local rebirths = stats:FindFirstChild("Rebirths") :: IntValue?
					if stage then
						stage.Value = profile.Data.Checkpoint
					end
					if rebirths then
						rebirths.Value = profile.Data.Rebirths
					end
				end
			end
		end
	end)
end

return DataService
