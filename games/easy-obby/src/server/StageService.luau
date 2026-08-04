--!strict
-- The +1 loop: touching pad N past your checkpoint grants +1 Jump Power and
-- coins PER STAGE ADVANCED — so soaring over 10 stages pays for all 10 (the
-- clip moment). Also owns character setup: jump/speed stats, respawn at
-- checkpoint, trail attach.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Remotes = require(Shared.Remotes)

local StageService = {}

local ctx: any = nil
local pads: { BasePart } = {}

function StageService.ApplyStats(player: Player)
	local data = ctx.Data.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not data or not humanoid then
		return
	end
	humanoid.UseJumpPower = true
	humanoid.JumpPower = ctx.Data.JumpPower(player, data)
	humanoid.WalkSpeed = ctx.Data.WalkSpeed(player, data)
end

local function coinsForStage(index: number): number
	return math.floor(Balance.CoinsPerStage * (1 + index * Balance.CoinsStageScale) + 0.5)
end

-- Advance to `target` stage, granting all per-stage rewards along the way.
-- Used by pad touches AND by Skip products.
function StageService.AdvanceTo(player: Player, target: number)
	local data = ctx.Data.Get(player)
	if not data then
		return
	end
	target = math.clamp(target, 0, Balance.Stages)
	local delta = target - data.Checkpoint
	if delta <= 0 then
		return
	end

	local jumpGain = math.floor(delta * Balance.JumpPerStage * ctx.Data.JumpGainMult(player, data) + 0.5)
	data.JumpBonus = math.min(data.JumpBonus + jumpGain, Balance.JumpBonusCap)

	local coins = 0
	for i = data.Checkpoint + 1, target do
		coins += coinsForStage(i)
	end
	data.Checkpoint = target
	data.Stats.TotalStagesCleared += delta
	data.Stats.BestStage = math.max(data.Stats.BestStage, target)
	ctx.Data.AddCoins(player, coins, true)
	ctx.Data.MarkDirty(player)
	StageService.ApplyStats(player)

	ctx.Analytics.FunnelStep(player, data, 1, "FirstStage")
	if target >= 10 then
		ctx.Analytics.FunnelStep(player, data, 2, "Stage10")
	end
	if target >= 50 then
		ctx.Analytics.FunnelStep(player, data, 3, "Stage50")
	end
	if target >= Balance.Stages then
		ctx.Analytics.FunnelStep(player, data, 4, "Finish")
		Remotes.Event("Notify"):FireClient(player, {
			Text = "FINISH! Open the Rebirth menu to bank a permanent bonus!",
			Color = Color3.fromRGB(255, 210, 90),
		})
	end
	if delta > 1 then
		Remotes.Event("Notify"):FireClient(player, {
			Text = ("MEGA LEAP! +%d stages, +%d Jump Power!"):format(delta, jumpGain),
			Color = Color3.fromRGB(120, 255, 200),
		})
	end
end

function StageService.TeleportToStage(player: Player, index: number): (boolean, string?)
	local data = ctx.Data.Get(player)
	if not data then
		return false, "Loading..."
	end
	if not ctx.Monetization.OwnsPass(player, "Vip") then
		return false, "Stage teleport is a VIP perk!"
	end
	index = math.clamp(index, 0, data.Checkpoint)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false, "No character."
	end
	local pad = if index == 0 then nil else pads[index]
	local position = if pad then pad.Position else Vector3.new(0, 0, -14)
	root.CFrame = CFrame.new(position + Vector3.new(0, 4, 0))
	return true, nil
end

local function onCharacterAdded(player: Player, character: Model)
	local data = ctx.Data.Get(player)
	if not data then
		task.delay(1, function()
			if player.Character == character then
				onCharacterAdded(player, character)
			end
		end)
		return
	end
	StageService.ApplyStats(player)
	ctx.Trails.Attach(player, character)
	-- respawn at checkpoint
	local root = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if root then
		local pad = data.Checkpoint > 0 and pads[data.Checkpoint] or nil
		local position = pad and pad.Position or Vector3.new(0, 0, -14)
		root.CFrame = CFrame.new(position + Vector3.new(0, 4, 0))
	end
end

function StageService.Init(serviceCtx: any, coursePads: { BasePart })
	ctx = serviceCtx
	pads = coursePads
	Players.RespawnTime = Balance.RespawnSeconds

	for index, pad in pads do
		pad.Touched:Connect(function(hit)
			local character = hit.Parent
			local player = character and Players:GetPlayerFromCharacter(character :: any)
			if player then
				StageService.AdvanceTo(player, index)
			end
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			onCharacterAdded(player, player.Character)
		end
	end

	Remotes.Function("TeleportStage").OnServerInvoke = function(player, index)
		local n = tonumber(index)
		if not n then
			return false, "Bad request."
		end
		return StageService.TeleportToStage(player, n)
	end
end

return StageService
