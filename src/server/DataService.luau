--!strict
-- Player profiles (ProfileStore, session-locked) + the StateSync snapshot loop.
-- Every other service reads/writes profiles through here and calls MarkDirty.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileStore = require(script.Parent.Packages.ProfileStore)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Crystals = require(Shared.Config.Crystals)
local RarityMath = require(Shared.RarityMath)
local Remotes = require(Shared.Remotes)

local TEMPLATE = {
	Coins = 0,
	TotalCoinsEarned = 0,
	Geodes = 0,
	Crystals = {} :: { [string]: { Base: string, Mut: string, Size: number, Layer: number } },
	NextCrystalId = 1,
	Racks = {} :: { [string]: { CrystalId: string, LastTick: number } },
	RackSlots = Balance.BaseRackSlots,
	Pickaxe = 1,
	Backpack = 1,
	Rebirths = 0,
	Collection = {} :: { [string]: boolean },
	CollectionCount = 0,
	Streak = { Count = 0, LastDay = 0, Best = 0 },
	Boosts = { Coins2xUntil = 0 },
	Purchases = {} :: { string },
	OwnedPasses = {} :: { [string]: boolean },
	StarterPackOwned = false,
	Stats = { GeodesMined = 0, GeodesCracked = 0, RarestValue = 0, RarestName = "" },
	Funnel = {} :: { [string]: boolean },
	PityCracks = 0,
	RareGiven = false,
	Settings = { AutoCrack = true },
	ShopSalt = 0,
	ShopWindow = { Seed = 0, Bought = {} :: { [string]: number } },
	LastSeen = 0,
}

export type Profile = typeof(TEMPLATE)

local DataService = {}
DataService.Template = TEMPLATE

local PlayerStore = ProfileStore.New("PlayerData_v1", TEMPLATE)
local profiles: { [Player]: any } = {}
local dirty: { [Player]: boolean } = {}
local lastPush: { [Player]: number } = {}

local ctx: any = nil -- service registry, set in Init

function DataService.Get(player: Player): Profile?
	local profile = profiles[player]
	return profile and profile.Data or nil
end

function DataService.GetRaw(player: Player): any
	return profiles[player]
end

function DataService.MarkDirty(player: Player)
	dirty[player] = true
end

function DataService.Layer(data: Profile): number
	return math.min(data.Rebirths + 1, Balance.MaxLayer)
end

function DataService.CoinMult(player: Player, data: Profile): number
	local mult = 1 + Balance.RebirthCoinBonus * data.Rebirths
	if ctx.Monetization.OwnsPass(player, "Coins2x") then
		mult *= 2
	end
	if ctx.Monetization.OwnsPass(player, "Vip") then
		mult *= 1 + Balance.VipCoinBonus
	end
	if data.Boosts.Coins2xUntil > os.time() then
		mult *= 2
	end
	return mult
end

function DataService.LuckMult(player: Player, data: Profile): number
	local passLuck = if ctx.Monetization.OwnsPass(player, "Luck2x") then 2 else 1
	local event = ctx.Events.Current()
	return RarityMath.EffectiveLuck(passLuck, event.LuckMult, DataService.Layer(data))
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

function DataService.CrystalValue(data: Profile, crystal: { Base: string, Mut: string, Size: number, Layer: number }): number
	return RarityMath.ComputeValue(crystal.Base, crystal.Mut, crystal.Size, crystal.Layer)
end

function DataService.BackpackCapacity(data: Profile): number
	local tier = Balance.Backpacks[math.clamp(data.Backpack, 1, #Balance.Backpacks)]
	return tier.Capacity
end

function DataService.RebirthCost(data: Profile): number
	return math.floor(Balance.RebirthBaseCost * Balance.RebirthCostGrowth ^ data.Rebirths)
end

-- Sanitized snapshot pushed to the owning client (drives all UI).
local function buildSnapshot(player: Player, data: Profile): { [string]: any }
	local layer = DataService.Layer(data)
	local event = ctx.Events.Current()
	local crystals = {}
	for id, crystal in data.Crystals do
		crystals[id] = {
			Base = crystal.Base,
			Mut = crystal.Mut,
			Size = crystal.Size,
			Layer = crystal.Layer,
			Value = DataService.CrystalValue(data, crystal),
		}
	end
	local now = os.time()
	local racks = {}
	for slot, rack in data.Racks do
		local crystal = data.Crystals[rack.CrystalId]
		if crystal then
			racks[slot] = {
				CrystalId = rack.CrystalId,
				Pending = ctx.Racks.PendingCoins(player, data, rack),
				Elapsed = now - rack.LastTick,
			}
		end
	end
	local passes = {}
	for key in require(Shared.Config.Monetization).Gamepasses :: any do
		passes[key] = ctx.Monetization.OwnsPass(player, key)
	end
	local pickaxe = Balance.Pickaxes[math.clamp(data.Pickaxe, 1, #Balance.Pickaxes)]
	local nextPickaxe = Balance.Pickaxes[data.Pickaxe + 1]
	local backpack = Balance.Backpacks[math.clamp(data.Backpack, 1, #Balance.Backpacks)]
	local nextBackpack = Balance.Backpacks[data.Backpack + 1]
	return {
		Coins = data.Coins,
		Geodes = data.Geodes,
		BackpackCapacity = backpack.Capacity,
		Pickaxe = { Level = data.Pickaxe, Name = pickaxe.Name, Damage = pickaxe.Damage },
		NextPickaxe = nextPickaxe and { Name = nextPickaxe.Name, Damage = nextPickaxe.Damage, Cost = nextPickaxe.Cost } or nil,
		Backpack = { Level = data.Backpack, Name = backpack.Name },
		NextBackpack = nextBackpack and { Name = nextBackpack.Name, Capacity = nextBackpack.Capacity, Cost = nextBackpack.Cost } or nil,
		Crystals = crystals,
		Racks = racks,
		RackSlots = data.RackSlots,
		NextRackSlotCost = Balance.RackSlotCosts[data.RackSlots - Balance.BaseRackSlots + 1],
		Rebirths = data.Rebirths,
		Layer = layer,
		LayerName = Balance.LayerNames[layer],
		RebirthCost = DataService.RebirthCost(data),
		CoinMult = DataService.CoinMult(player, data),
		LuckMult = DataService.LuckMult(player, data),
		MutationMult = event.MutationMult,
		Event = event.Name and { Name = event.Name, EndsAt = event.EndsAt } or nil,
		Collection = data.Collection,
		CollectionCount = data.CollectionCount,
		TotalIndex = Crystals.TotalIndexEntries(),
		Streak = { Count = data.Streak.Count, Best = data.Streak.Best },
		Passes = passes,
		AutoCrackEnabled = data.Settings.AutoCrack ~= false,
		StarterPackOwned = data.StarterPackOwned,
		Boost2xUntil = data.Boosts.Coins2xUntil,
		Stats = data.Stats,
		Funnel = data.Funnel,
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

	-- leaderstats for the Roblox player list
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = profile.Data.Rebirths
	rebirths.Parent = leaderstats
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = profile.Data.Coins
	coins.Parent = leaderstats
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

	-- Push loop: immediately when dirty (debounced), every 2s otherwise.
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for player, profile in profiles do
			local since = now - (lastPush[player] or 0)
			if (dirty[player] and since > 0.25) or since > 2 then
				DataService.PushState(player)
				local stats = player:FindFirstChild("leaderstats")
				if stats then
					local rebirths = stats:FindFirstChild("Rebirths") :: IntValue?
					local coins = stats:FindFirstChild("Coins") :: IntValue?
					if rebirths then
						rebirths.Value = profile.Data.Rebirths
					end
					if coins then
						coins.Value = profile.Data.Coins
					end
				end
			end
		end
	end)
end

return DataService
