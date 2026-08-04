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

local CrackService = {}

local ctx: any = nil
local rng = Random.new()

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
	return {
		Id = id,
		Base = baseName,
		Mut = mutName,
		Size = size,
		Layer = layer,
		Value = ctx.Data.CrystalValue(data, crystal),
		Tier = def and def.Tier or "Common",
		New = isNew,
	}
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
