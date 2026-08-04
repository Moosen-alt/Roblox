--!strict
-- Growth racks: socketed crystals produce coins and grow in size over time,
-- INCLUDING while offline (accrual = time since LastTick, capped). This is the
-- daily-return hook: the cap makes checking in daily strictly better than AFK.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Remotes = require(Shared.Remotes)

local RackService = {}

local ctx: any = nil

local function offlineCap(player: Player): number
	if ctx.Monetization.OwnsPass(player, "OvernightMiner") then
		return Balance.OfflineCapSecondsVip
	end
	return Balance.OfflineCapSeconds
end

local function accrualSeconds(player: Player, rack: { CrystalId: string, LastTick: number }): number
	return math.min(os.time() - rack.LastTick, offlineCap(player))
end

function RackService.PendingCoins(player: Player, data: any, rack: { CrystalId: string, LastTick: number }): number
	local crystal = data.Crystals[rack.CrystalId]
	if not crystal then
		return 0
	end
	local elapsed = accrualSeconds(player, rack)
	local rate = ctx.Data.CrystalValue(data, crystal) * Balance.RackCoinsPerValuePerSecond
	if elapsed > 1800 and ctx.Monetization.OwnsPass(player, "OvernightMiner") then
		rate *= Balance.OfflineRateVip
	end
	return math.floor(rate * elapsed)
end

local function settleRack(player: Player, data: any, rack: { CrystalId: string, LastTick: number }): number
	local crystal = data.Crystals[rack.CrystalId]
	if not crystal then
		return 0
	end
	local coins = RackService.PendingCoins(player, data, rack)
	local elapsed = accrualSeconds(player, rack)
	crystal.Size = math.min(crystal.Size + Balance.RackGrowthPerSecond * elapsed, Balance.MaxCrystalSize)
	rack.LastTick = os.time()
	return coins
end

function RackService.Socket(player: Player, crystalId: string): (boolean, string?)
	local data = ctx.Data.Get(player)
	if not data then
		return false, "Loading..."
	end
	if not data.Crystals[crystalId] then
		return false, "Crystal not found."
	end
	for _, rack in data.Racks do
		if rack.CrystalId == crystalId then
			return false, "Already socketed."
		end
	end
	for slot = 1, data.RackSlots do
		local key = tostring(slot)
		if not data.Racks[key] then
			data.Racks[key] = { CrystalId = crystalId, LastTick = os.time() }
			ctx.Data.MarkDirty(player)
			ctx.Analytics.FunnelStep(player, data, 4, "FirstSocket")
			return true, nil
		end
	end
	return false, "All rack slots are full."
end

function RackService.Unsocket(player: Player, slotIndex: number): (boolean, string?)
	local data = ctx.Data.Get(player)
	if not data then
		return false, "Loading..."
	end
	local key = tostring(slotIndex)
	local rack = data.Racks[key]
	if not rack then
		return false, "Empty slot."
	end
	local coins = settleRack(player, data, rack)
	if coins > 0 then
		ctx.Data.AddCoins(player, coins, true)
	end
	data.Racks[key] = nil
	ctx.Data.MarkDirty(player)
	return true, nil
end

function RackService.CollectAll(player: Player): number
	local data = ctx.Data.Get(player)
	if not data then
		return 0
	end
	local total = 0
	for _, rack in data.Racks do
		total += settleRack(player, data, rack)
	end
	if total > 0 then
		ctx.Data.AddCoins(player, total, true)
	end
	ctx.Data.MarkDirty(player)
	return total
end

-- Time Warp dev product: grant 8 hours of production+growth instantly.
function RackService.ApplyTimeWarp(player: Player)
	local data = ctx.Data.Get(player)
	if not data then
		return
	end
	local total = 0
	for _, rack in data.Racks do
		local crystal = data.Crystals[rack.CrystalId]
		if crystal then
			local rate = ctx.Data.CrystalValue(data, crystal) * Balance.RackCoinsPerValuePerSecond
			total += math.floor(rate * Balance.TimeWarpSeconds)
			crystal.Size = math.min(crystal.Size + Balance.RackGrowthPerSecond * Balance.TimeWarpSeconds, Balance.MaxCrystalSize)
		end
	end
	if total > 0 then
		ctx.Data.AddCoins(player, total, true)
		Remotes.Event("Notify"):FireClient(player, { Text = "Time Warp! +" .. total .. " coins of growth.", Color = Color3.fromRGB(120, 255, 200) })
	else
		Remotes.Event("Notify"):FireClient(player, { Text = "Time Warp had nothing to grow — display relics first!", Color = Color3.fromRGB(255, 200, 90) })
	end
	ctx.Data.MarkDirty(player)
end

-- Called on join: summarize what accrued while away (the welcome-back moment).
function RackService.OfflineSummary(player: Player, data: any): { OfflineSeconds: number, PendingCoins: number }
	local pending = 0
	for _, rack in data.Racks do
		pending += RackService.PendingCoins(player, data, rack)
	end
	local away = 0
	if data.LastSeen > 0 then
		away = math.min(os.time() - data.LastSeen, offlineCap(player))
	end
	return { OfflineSeconds = away, PendingCoins = pending }
end

function RackService.Init(serviceCtx: any)
	ctx = serviceCtx
	Remotes.Function("SocketCrystal").OnServerInvoke = function(player, crystalId)
		if typeof(crystalId) ~= "string" then
			return false, "Bad request."
		end
		return RackService.Socket(player, crystalId)
	end
	Remotes.Function("UnsocketCrystal").OnServerInvoke = function(player, slotIndex)
		local index = tonumber(slotIndex)
		if not index then
			return false, "Bad request."
		end
		return RackService.Unsocket(player, index)
	end
	Remotes.Function("CollectRacks").OnServerInvoke = function(player)
		return RackService.CollectAll(player)
	end
end

return RackService
