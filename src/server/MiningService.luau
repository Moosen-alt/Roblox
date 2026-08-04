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
-- Mining progress is per-player: deposit toughness scales with each miner's
-- own layer, so upgrades matter for everyone regardless of who shares the wall.
local progress: { [BasePart]: { [Player]: number } } = {}
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

-- The juicy geode-break moment: pop sound, color burst, floating "+1".
local function popEffects(node: BasePart)
	playSound(node, "rbxasset://sounds/snap.mp3", 1 + rng:NextNumber(-0.1, 0.2), 0.7)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(node.Color)
	emitter.Lifetime = NumberRange.new(0.35, 0.7)
	emitter.Speed = NumberRange.new(8, 16)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.5, 0)
	emitter.Enabled = false
	emitter.Parent = node
	emitter:Emit(16)
	task.delay(1.2, function()
		emitter:Destroy()
	end)

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(6, 1.6)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = "+1 Geode!"
	label.TextColor3 = node.Color
	label.TextScaled = true
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard
	billboard.Parent = node
	TweenService:Create(billboard, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new(0, 8, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(0.9), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1, function()
		billboard:Destroy()
	end)
end

local function respawnNode(node: BasePart)
	progress[node] = nil
	node.Transparency = 0.85
	local click = node:FindFirstChildOfClass("ClickDetector")
	if click then
		click.MaxActivationDistance = 0
	end
	task.delay(Balance.NodeRespawnTime, function()
		progress[node] = {}
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

	local nodeProgress = progress[node]
	if not nodeProgress then
		return -- respawning
	end
	local pickaxe = Balance.Pickaxes[math.clamp(data.Pickaxe, 1, #Balance.Pickaxes)]
	local required = requiredHealth(ctx.Data.Layer(data))
	local done = (nodeProgress[player] or 0) + pickaxe.Damage
	nodeProgress[player] = done

	-- crunch feedback: hit tick + node shrinks as it takes damage
	playSound(node, "rbxasset://sounds/electronicpingshort.wav", 0.9 + rng:NextNumber(0, 0.25), 0.4)
	local fraction = math.clamp(1 - done / required, 0.35, 1)
	TweenService:Create(node, TweenInfo.new(0.12), { Size = Vector3.new(6 * fraction, 6 * fraction, 3) }):Play()

	if done >= required then
		popEffects(node)
		data.Geodes += 1
		data.Stats.GeodesMined += 1
		ctx.Data.MarkDirty(player)
		ctx.Analytics.FunnelStep(player, data, 1, "FirstGeode")
		if ctx.Monetization.OwnsPass(player, "AutoCrack") and data.Settings.AutoCrack ~= false then
			ctx.Crack.AutoCrack(player)
		end
		respawnNode(node)
	end
end

function MiningService.Init(serviceCtx: any, nodes: { BasePart })
	ctx = serviceCtx
	for _, node in nodes do
		progress[node] = {}
		local click = node:FindFirstChildOfClass("ClickDetector")
		if click then
			click.MouseClick:Connect(function(player)
				onNodeTapped(node, player)
			end)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		lastTap[player] = nil
		for _, nodeProgress in progress do
			nodeProgress[player] = nil
		end
	end)
end

return MiningService
