--!strict
-- Geode cracking: the reveal moment. All rolls go through shared RarityMath so
-- the client odds panel is provably the same math. Includes the first-session
-- pity roll (Nth lifetime crack guaranteed Rare+).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Crystals = require(Shared.Config.Crystals)
local RarityMath = require(Shared.RarityMath)
local Remotes = require(Shared.Remotes)
local Spotlight = require(script.Parent.Spotlight)

local CrackService = {}

export type CrackedCrystal = {
	Id: string,
	Base: string,
	Mut: string,
	Size: number,
	Layer: number,
	Value: number,
	Tier: string,
	New: boolean,
}

local ctx: any = nil
local rng = Random.new()

-- Mutations that earn a server-wide callout even on a lower-tier base: a
-- Celestial Quartz is a better story than a plain Opal.
local LOUD_MUTATIONS: { [string]: boolean } = { Radioactive = true, Celestial = true }

local function tierRank(tier: string): number
	for i, name in Crystals.Tiers do
		if name == tier then
			return i
		end
	end
	return 1
end

-- Social proof: broadcast anything genuinely rare. Nothing here is fabricated —
-- the callout fires only on rolls that actually cleared the bar.
local function announceRare(player: Player, crystal: CrackedCrystal)
	local rank = tierRank(crystal.Tier)
	if rank < 5 and not LOUD_MUTATIONS[crystal.Mut] then
		return
	end
	local color = Crystals.TierColors[crystal.Tier] or Color3.fromRGB(255, 210, 90)
	local mutation = Crystals.GetMutation(crystal.Mut)
	if mutation and mutation.Color and LOUD_MUTATIONS[crystal.Mut] then
		color = mutation.Color
	end
	local label = (crystal.Mut ~= "Normal" and (crystal.Mut .. " ") or "") .. crystal.Base
	Remotes.Event("RareFind"):FireAllClients({
		Player = player.DisplayName,
		Label = label,
		Tier = crystal.Tier,
		Rank = rank,
		Color = color,
		Value = crystal.Value,
	})
	Spotlight.Pillar(player, color)
end

local function rollOne(player: Player, data: any): CrackedCrystal
	local layer = ctx.Data.Layer(data)
	local luck = ctx.Data.LuckMult(player, data)
	local event = ctx.Events.Current()

	data.PityCracks += 1
	local baseName
	if not data.RareGiven and data.PityCracks >= Balance.PityForcedRareCrack then
		baseName = RarityMath.RollRarePlus(layer, luck, rng)
		data.RareGiven = true
	else
		baseName = RarityMath.RollBase(layer, luck, rng)
	end
	local mutName = RarityMath.RollMutation(event.MutationMult, rng)
	local size = 0.9 + rng:NextNumber() * 0.3

	local id = tostring(data.NextCrystalId)
	data.NextCrystalId += 1
	local crystal = { Base = baseName, Mut = mutName, Size = size, Layer = layer }
	data.Crystals[id] = crystal
	data.Stats.GeodesCracked += 1

	local key = Crystals.IndexKey(baseName, mutName)
	local isNew = not data.Collection[key]
	if isNew then
		data.Collection[key] = true
		data.CollectionCount += 1
	end

	local value = ctx.Data.CrystalValue(data, crystal)
	if value > data.Stats.RarestValue then
		data.Stats.RarestValue = value
		data.Stats.RarestName = (mutName ~= "Normal" and (mutName .. " ") or "") .. baseName
		-- New personal best: swap the crystal floating over their head
		ctx.Flex.Set(player, baseName, mutName, value)
	end

	local def = Crystals.GetBase(baseName)
	return {
		Id = id,
		Base = baseName,
		Mut = mutName,
		Size = size,
		Layer = layer,
		Value = value,
		Tier = def and def.Tier or "Common",
		New = isNew,
	}
end

-- Manual crack from the Crack Station UI. count is clamped by passes.
function CrackService.Crack(player: Player, count: number?): ({ CrackedCrystal }?, string?)
	local data = ctx.Data.Get(player)
	if not data then
		return nil, "Loading..."
	end
	local wanted = math.clamp(tonumber(count) or 1, 1, 3)
	if wanted > 1 and not ctx.Monetization.OwnsPass(player, "TripleCrack") then
		wanted = 1
	end
	wanted = math.min(wanted, data.Geodes)
	if wanted < 1 then
		return nil, "No geodes! Mine the wall first."
	end
	data.Geodes -= wanted
	local results = {}
	for _ = 1, wanted do
		table.insert(results, rollOne(player, data))
	end
	ctx.Data.MarkDirty(player)
	ctx.Analytics.FunnelStep(player, data, 2, "FirstCrack")
	for _, crystal in results do
		if Crystals.TierColors[crystal.Tier] and (crystal.Tier ~= "Common" and crystal.Tier ~= "Uncommon") then
			ctx.Analytics.FunnelStep(player, data, 3, "FirstRare")
			break
		end
	end
	-- Let the reveal animation land before the server-wide callout
	task.delay(2.4, function()
		if player.Parent then
			for _, crystal in results do
				announceRare(player, crystal)
			end
		end
	end)
	return results, nil
end

-- Auto-Crack gamepass: crack immediately as geodes are mined; result goes to a
-- lightweight client toast instead of the full reveal.
function CrackService.AutoCrack(player: Player)
	local data = ctx.Data.Get(player)
	if not data or data.Geodes < 1 then
		return
	end
	data.Geodes -= 1
	local result = rollOne(player, data)
	ctx.Data.MarkDirty(player)
	Remotes.Event("CrackResult"):FireClient(player, { result }, true)
	announceRare(player, result)
end

-- Deterministic grant used by the Starter Pack (guaranteed Emerald, no RNG).
function CrackService.GrantFixedCrystal(player: Player, baseName: string, size: number): CrackedCrystal?
	local data = ctx.Data.Get(player)
	if not data then
		return nil
	end
	local layer = ctx.Data.Layer(data)
	local id = tostring(data.NextCrystalId)
	data.NextCrystalId += 1
	local crystal = { Base = baseName, Mut = "Normal", Size = size, Layer = layer }
	data.Crystals[id] = crystal
	local key = Crystals.IndexKey(baseName, "Normal")
	if not data.Collection[key] then
		data.Collection[key] = true
		data.CollectionCount += 1
	end
	ctx.Data.MarkDirty(player)
	local def = Crystals.GetBase(baseName)
	return {
		Id = id,
		Base = baseName,
		Mut = "Normal",
		Size = size,
		Layer = layer,
		Value = ctx.Data.CrystalValue(data, crystal),
		Tier = def and def.Tier or "Rare",
		New = false,
	}
end

-- Premium shop geode: rolls with boosted luck, granted straight to inventory.
function CrackService.RollWithLuck(player: Player, luckMult: number): CrackedCrystal?
	local data = ctx.Data.Get(player)
	if not data then
		return nil
	end
	local layer = ctx.Data.Layer(data)
	local passLuck = ctx.Data.LuckMult(player, data)
	local luck = passLuck * luckMult
	local event = ctx.Events.Current()
	local baseName = RarityMath.RollBase(layer, luck, rng)
	local mutName = RarityMath.RollMutation(event.MutationMult, rng)
	local size = 0.9 + rng:NextNumber() * 0.3
	local id = tostring(data.NextCrystalId)
	data.NextCrystalId += 1
	local crystal = { Base = baseName, Mut = mutName, Size = size, Layer = layer }
	data.Crystals[id] = crystal
	data.Stats.GeodesCracked += 1
	local key = Crystals.IndexKey(baseName, mutName)
	local isNew = not data.Collection[key]
	if isNew then
		data.Collection[key] = true
		data.CollectionCount += 1
	end
	ctx.Data.MarkDirty(player)
	local def = Crystals.GetBase(baseName)
	local result: CrackedCrystal = {
		Id = id,
		Base = baseName,
		Mut = mutName,
		Size = size,
		Layer = layer,
		Value = ctx.Data.CrystalValue(data, crystal),
		Tier = def and def.Tier or "Common",
		New = isNew,
	}
	announceRare(player, result)
	return result
end

function CrackService.SellCrystal(player: Player, idOrAll: string): (boolean, string?)
	local data = ctx.Data.Get(player)
	if not data then
		return false, "Loading..."
	end
	local socketed: { [string]: boolean } = {}
	for _, rack in data.Racks do
		socketed[rack.CrystalId] = true
	end
	local total = 0
	if idOrAll == "all" then
		for id, crystal in data.Crystals do
			if not socketed[id] then
				total += ctx.Data.CrystalValue(data, crystal)
				data.Crystals[id] = nil
			end
		end
	else
		local crystal = data.Crystals[idOrAll]
		if not crystal then
			return false, "Crystal not found."
		end
		if socketed[idOrAll] then
			return false, "Unsocket it from the rack first."
		end
		total = ctx.Data.CrystalValue(data, crystal)
		data.Crystals[idOrAll] = nil
	end
	if total <= 0 then
		return false, "Nothing to sell."
	end
	ctx.Data.AddCoins(player, total, true)
	return true, nil
end

function CrackService.Init(serviceCtx: any)
	ctx = serviceCtx
	Remotes.Function("CrackGeode").OnServerInvoke = function(player, count)
		return CrackService.Crack(player, count :: any)
	end
	Remotes.Function("SellCrystal").OnServerInvoke = function(player, idOrAll)
		if typeof(idOrAll) ~= "string" then
			return false, "Bad request."
		end
		return CrackService.SellCrystal(player, idOrAll)
	end
	Remotes.Function("ToggleAutoCrack").OnServerInvoke = function(player)
		local data = ctx.Data.Get(player)
		if not data then
			return false
		end
		data.Settings.AutoCrack = data.Settings.AutoCrack == false
		ctx.Data.MarkDirty(player)
		return data.Settings.AutoCrack
	end
end

return CrackService
