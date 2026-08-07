--!strict
-- Player profiles (ProfileStore, session-locked) + the StateSync snapshot loop.
-- Every other service reads/writes profiles through here and calls MarkDirty.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FilmMode = require(script.Parent.FilmMode)
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
	-- Areas: bought once with coins, kept through every Set Sail. `AreaUnlocked`
	-- is the furthest you own, `AreaCurrent` is where your line is in the water.
	AreaUnlocked = 1,
	AreaCurrent = 1,
	-- Heaviest fish ever landed, keyed by species NAME ONLY — not species|aura.
	-- Anglers track "biggest bass", not "biggest shiny bass", and a best that
	-- splits six ways per species stops being a record anyone recognises.
	BestWeight = {} :: { [string]: number },
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

-- The one seam between "areas" and everything downstream. Value scaling, luck
-- creep, species gating, shop costs and the UI all read a content tier through
-- this function; changing what it returns moved the whole game from
-- rebirth-gated depth to coin-bought areas without touching a single call site.
--
-- The internal name stays `Layer` on purpose. This codebase already keeps
-- engine-side names through a re-theme — `Crystals` holds fish, `CrackService`
-- opens chests — and renaming ~50 call sites across a dozen files to say `Area`
-- would be a large diff that changes no behaviour and hides the ones that do.
function DataService.Layer(data: Profile): number
	return math.clamp(data.AreaCurrent, 1, Balance.MaxLayer)
end

-- What is on your boat: fish you have not sold plus chests you have not opened.
-- One number with one meaning, gated by one upgrade, and the reason to sail home.
function DataService.HoldCount(data: Profile): number
	local socketed: { [string]: boolean } = {}
	for _, rack in data.Racks do
		socketed[rack.CrystalId] = true
	end
	local held = data.Geodes
	for id in data.Crystals do
		if not socketed[id] then
			held += 1
		end
	end
	return held
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
	local tier = Balance.Backpack(data.Backpack)
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
	local pickaxe = Balance.Pickaxe(data.Pickaxe)
	local nextPickaxe = Balance.Pickaxe(data.Pickaxe + 1)
	local backpack = Balance.Backpack(data.Backpack)
	local nextBackpack = Balance.Backpack(data.Backpack + 1)
	-- Species counts per area drive the "8 / 12 in Kelp Forest" line. An area you
	-- can actually finish is a far better reason to keep casting than a single
	-- global counter that only ever creeps.
	local areas = {}
	for index = 1, Balance.MaxLayer do
		local species = Crystals.BasesInLayer(index, Crystals.FISH)
		local caught = 0
		for _, def in species do
			for _, mut in Crystals.MutationNames do
				if data.Collection[Crystals.IndexKey(def.Name, mut)] then
					caught += 1
					break -- one tick per species; auras are the Index's job
				end
			end
		end
		areas[index] = {
			Name = Balance.LayerNames[index],
			Cost = Balance.AreaCosts[index] or 0,
			Unlocked = index <= data.AreaUnlocked,
			Species = #species,
			Caught = caught,
		}
	end
	return {
		Coins = data.Coins,
		Geodes = data.Geodes,
		Hold = DataService.HoldCount(data),
		BackpackCapacity = backpack.Capacity,
		Areas = areas,
		AreaUnlocked = data.AreaUnlocked,
		AreaCurrent = data.AreaCurrent,
		BestWeight = data.BestWeight,
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
	-- Film mode loads from ProfileStore's mock store: a staged endgame save
	-- for recording must never be written to the real one.
	local store = if FilmMode.Active() then PlayerStore.Mock else PlayerStore
	local profile = store:StartSessionAsync("Player_" .. player.UserId, {})
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
	-- Studio-only, and only when Balance.FilmMode is on: hand this session an
	-- endgame save so marketing footage does not require a week of play.
	FilmMode.Apply(profile.Data)

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
