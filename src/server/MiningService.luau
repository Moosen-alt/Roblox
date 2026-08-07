--!strict
-- Tap-to-mine loop. Deposit nodes are shared per server, but a geode you crack
-- open belongs to you: it disappears and regrows on YOUR timer while the player
-- beside you keeps mining the same rock.
--
-- That is not a cosmetic choice. A single global respawn timer caps the whole
-- server at (#nodes / NodeRespawnTime) breaks per second — 4.8/s with twelve
-- nodes — which fifteen tappers already exceed, and which a single Auto Miner
-- would eat outright. Per-player availability removes the ceiling entirely.
--
-- Because availability is per player, so are the break visuals: the server no
-- longer touches geode geometry at all. WorldFx runs the pop, the shockwave and
-- the local respawn on the miner's own client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Remotes = require(Shared.Remotes)
local GeodeNode = require(script.Parent.GeodeNode)

local MiningService = {}

local ctx: any = nil
-- Mining progress is per-player: deposit toughness scales with each miner's
-- own layer, so upgrades matter for everyone regardless of who shares the wall.
local progress: { [BasePart]: { [Player]: number } } = {}
-- os.clock() deadlines: until this passes, THIS player cannot mine THIS node.
local depletedUntil: { [BasePart]: { [Player]: number } } = {}
local lastTap: { [Player]: number } = {}
local nodeList: { BasePart } = {}

local function requiredHealth(layer: number): number
	return Balance.NodeBaseHealth * Balance.NodeHealthLayerGrowth ^ (math.max(layer, 1) - 1)
end

-- True when `player` may mine `node` right now — i.e. it is a real node and
-- they are not still waiting out their own respawn on it.
function MiningService.IsAvailable(node: BasePart, player: Player): boolean
	if not progress[node] then
		return false
	end
	local depleted = depletedUntil[node]
	return not depleted or (depleted[player] or 0) <= os.clock()
end

MiningService.Nodes = nodeList

local function depleteFor(node: BasePart, player: Player)
	local map = depletedUntil[node]
	if not map then
		map = {}
		depletedUntil[node] = map
	end
	map[player] = os.clock() + Balance.NodeRespawnTime
	local nodeProgress = progress[node]
	if nodeProgress then
		nodeProgress[player] = nil
	end
end

local function onNodeTapped(node: BasePart, player: Player): boolean
	local data = ctx.Data.Get(player)
	if not data then
		return false
	end
	local now = os.clock()
	if now - (lastTap[player] or 0) < Balance.MineCooldown then
		return false
	end
	lastTap[player] = now

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - node.Position).Magnitude > Balance.MineRange then
		return false
	end

	ctx.PickaxeVis.Swing(player)

	if data.Geodes >= ctx.Data.BackpackCapacity(data) then
		Remotes.Event("Notify"):FireClient(player, { Text = "Backpack full! Crack your geodes.", Color = Color3.fromRGB(255, 120, 120) })
		return false
	end

	local nodeProgress = progress[node]
	if not nodeProgress then
		return false
	end
	local depleted = depletedUntil[node]
	if depleted and (depleted[player] or 0) > now then
		return false -- this player already cracked it; theirs is still regrowing
	end
	local info = GeodeNode.Info[node]
	if not info then
		return false
	end
	local pickaxe = Balance.Pickaxe(data.Pickaxe)
	local required = requiredHealth(ctx.Data.Layer(data))
	local done = (nodeProgress[player] or 0) + pickaxe.Damage
	nodeProgress[player] = done
	local broke = done >= required

	-- Every bit of mining feedback is per-player, so it all runs on the miner's
	-- client: their cracks widen, their screen shakes, their geode pops.
	Remotes.Event("MineFx"):FireClient(player, {
		Node = node,
		Fraction = math.clamp(done / required, 0, 1),
		Damage = pickaxe.Damage,
		Color = info.Color,
		Broke = broke,
	})

	if broke then
		data.Geodes += 1
		data.Stats.GeodesMined += 1
		ctx.Data.MarkDirty(player)
		ctx.Analytics.FunnelStep(player, data, 1, "FirstGeode")
		if ctx.Monetization.OwnsPass(player, "AutoCrack") and data.Settings.AutoCrack ~= false then
			ctx.Crack.AutoCrack(player)
		end
		depleteFor(node, player)
	end
	return true
end

-- The one and only mining entry point. AutoMineService drives swings through
-- here so an automated tap runs every validation, reward, analytics step and
-- effect that a human tap does — there is no second code path to drift.
function MiningService.TryMine(player: Player, node: BasePart): boolean
	if not ctx or not progress[node] then
		return false
	end
	return onNodeTapped(node, player)
end

function MiningService.Init(serviceCtx: any, nodes: { BasePart })
	ctx = serviceCtx
	local nodeSet: { [Instance]: boolean } = {}
	for _, node in nodes do
		progress[node] = {}
		nodeSet[node] = true
		table.insert(nodeList, node)
		local click = node:FindFirstChildOfClass("ClickDetector")
		if click then
			click.MouseClick:Connect(function(player)
				onNodeTapped(node, player)
			end)
		end
	end
	-- Primary tap path: the equipped pickaxe Tool swallows clicks before
	-- ClickDetectors see them, so the client raycasts its tap and reports the
	-- node here. Same server-side validation (membership, distance, cooldown).
	Remotes.Event("MineNode").OnServerEvent:Connect(function(player, node)
		if typeof(node) == "Instance" and nodeSet[node] then
			onNodeTapped(node :: BasePart, player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastTap[player] = nil
		for _, nodeProgress in progress do
			nodeProgress[player] = nil
		end
		for _, depleted in depletedUntil do
			depleted[player] = nil
		end
	end)
end

return MiningService
