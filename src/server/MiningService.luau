--!strict
-- Tap-to-mine loop. Deposit nodes are shared per server; each tap applies the
-- player's pickaxe damage. Depleted node -> geode into the tapper's backpack.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Remotes = require(Shared.Remotes)
local GeodeNode = require(script.Parent.GeodeNode)

local MiningService = {}

local ctx: any = nil
-- Mining progress is per-player: deposit toughness scales with each miner's
-- own layer, so upgrades matter for everyone regardless of who shares the wall.
local progress: { [BasePart]: { [Player]: number } } = {}
local lastTap: { [Player]: number } = {}
local rng = Random.new()

local function requiredHealth(layer: number): number
	return Balance.NodeBaseHealth * Balance.NodeHealthLayerGrowth ^ (math.max(layer, 1) - 1)
end

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

-- The geode-break moment everyone in the server sees: shockwave, shard burst,
-- pop, floating "+1".
local function popEffects(node: BasePart, info: GeodeNode.Node)
	playSound(node, "rbxasset://sounds/snap.mp3", 1 + rng:NextNumber(-0.1, 0.2), 0.7)
	GeodeNode.Break(info)

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(7, 1.9)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = "+1 GEODE!"
	label.TextColor3 = info.Color
	label.TextScaled = true
	label.TextStrokeTransparency = 0.2
	label.Parent = billboard
	billboard.Parent = node
	TweenService:Create(billboard, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new(0, 9, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(0.9), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1, function()
		billboard:Destroy()
	end)
end

local function respawnNode(node: BasePart, info: GeodeNode.Node)
	progress[node] = nil
	task.delay(Balance.NodeRespawnTime, function()
		progress[node] = {}
		GeodeNode.Reset(info)
		-- Tell every client to drop its local crack progress on this geode, so a
		-- half-mined deposit never respawns looking chewed.
		Remotes.Event("MineFx"):FireAllClients({ Node = node, Reset = true })
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

	local nodeProgress = progress[node]
	if not nodeProgress then
		return -- respawning
	end
	local info = GeodeNode.Info[node]
	if not info then
		return
	end
	local pickaxe = Balance.Pickaxes[math.clamp(data.Pickaxe, 1, #Balance.Pickaxes)]
	local required = requiredHealth(ctx.Data.Layer(data))
	local done = (nodeProgress[player] or 0) + pickaxe.Damage
	nodeProgress[player] = done
	local broke = done >= required

	-- Crack feedback is per-player, so it runs on the miner's client: their
	-- cracks widen, their screen shakes, their damage numbers fly.
	Remotes.Event("MineFx"):FireClient(player, {
		Node = node,
		Fraction = math.clamp(done / required, 0, 1),
		Damage = pickaxe.Damage,
		Color = info.Color,
		Broke = broke,
	})

	if broke then
		popEffects(node, info)
		data.Geodes += 1
		data.Stats.GeodesMined += 1
		ctx.Data.MarkDirty(player)
		ctx.Analytics.FunnelStep(player, data, 1, "FirstGeode")
		if ctx.Monetization.OwnsPass(player, "AutoCrack") and data.Settings.AutoCrack ~= false then
			ctx.Crack.AutoCrack(player)
		end
		respawnNode(node, info)
	end
end

function MiningService.Init(serviceCtx: any, nodes: { BasePart })
	ctx = serviceCtx
	local nodeSet: { [Instance]: boolean } = {}
	for _, node in nodes do
		progress[node] = {}
		nodeSet[node] = true
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
	end)
end

return MiningService
