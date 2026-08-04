--!strict
-- Tap-to-mine loop. Deposit nodes are shared per server; each tap applies the
-- player's pickaxe damage. Depleted node -> geode into the tapper's backpack.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Remotes = require(Shared.Remotes)

local MiningService = {}

local ctx: any = nil
local nodeHealth: { [BasePart]: number } = {}
local lastTap: { [Player]: number } = {}
local rng = Random.new()

local NODE_COLORS = {
	Color3.fromRGB(170, 110, 240),
	Color3.fromRGB(60, 220, 130),
	Color3.fromRGB(60, 120, 255),
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(150, 255, 245),
	Color3.fromRGB(255, 60, 80),
}

local function maxHealth(): number
	return Balance.NodeBaseHealth
end

local function respawnNode(node: BasePart)
	node.Transparency = 0.85
	local click = node:FindFirstChildOfClass("ClickDetector")
	if click then
		click.MaxActivationDistance = 0
	end
	task.delay(Balance.NodeRespawnTime, function()
		nodeHealth[node] = maxHealth()
		node.Color = NODE_COLORS[rng:NextInteger(1, #NODE_COLORS)]
		node.Transparency = 0.05
		node.Size = Vector3.new(6, 6, 3)
		if click then
			click.MaxActivationDistance = 26
		end
	end)
end

local function onNodeTapped(node: BasePart, player: Player)
	local data = ctx.Data.Get(player)
	if not data then
		return
	end
	local now = os.clock()
	if now - (lastTap[player] or 0) < Balance.MineCooldown then
		return
	end
	lastTap[player] = now

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - node.Position).Magnitude > 32 then
		return
	end

	ctx.PickaxeVis.Swing(player)

	if data.Geodes >= ctx.Data.BackpackCapacity(data) then
		Remotes.Event("Notify"):FireClient(player, { Text = "Backpack full! Crack your geodes.", Color = Color3.fromRGB(255, 120, 120) })
		return
	end

	local health = nodeHealth[node]
	if not health or health <= 0 then
		return
	end
	local pickaxe = Balance.Pickaxes[math.clamp(data.Pickaxe, 1, #Balance.Pickaxes)]
	health -= pickaxe.Damage
	nodeHealth[node] = health

	-- crunch feedback: node shrinks as it takes damage
	local fraction = math.clamp(health / maxHealth(), 0.35, 1)
	TweenService:Create(node, TweenInfo.new(0.12), { Size = Vector3.new(6 * fraction, 6 * fraction, 3) }):Play()

	if health <= 0 then
		data.Geodes += 1
		data.Stats.GeodesMined += 1
		ctx.Data.MarkDirty(player)
		ctx.Analytics.FunnelStep(player, data, 1, "FirstGeode")
		if ctx.Monetization.OwnsPass(player, "AutoCrack") then
			ctx.Crack.AutoCrack(player)
		end
		respawnNode(node)
	end
end

function MiningService.Init(serviceCtx: any, nodes: { BasePart })
	ctx = serviceCtx
	for _, node in nodes do
		nodeHealth[node] = maxHealth()
		local click = node:FindFirstChildOfClass("ClickDetector")
		if click then
			click.MouseClick:Connect(function(player)
				onNodeTapped(node, player)
			end)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		lastTap[player] = nil
	end)
end

return MiningService
