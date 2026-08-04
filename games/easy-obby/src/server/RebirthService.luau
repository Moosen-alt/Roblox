--!strict
-- Rebirth: reach the Finish pad, reset jump/checkpoint, keep coins and trails,
-- bank a permanent +25% jump-gain & coin multiplier. Infinite ladder.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Remotes = require(Shared.Remotes)

local RebirthService = {}

local ctx: any = nil

function RebirthService.Perform(player: Player, free: boolean): (boolean, string?)
	local data = ctx.Data.Get(player)
	if not data then
		return false, "Loading..."
	end
	if not free and data.Checkpoint < Balance.RebirthStage then
		return false, ("Reach stage %d to Rebirth!"):format(Balance.RebirthStage)
	end

	data.Rebirths += 1
	data.Checkpoint = 0
	data.JumpBonus = if ctx.Monetization.OwnsPass(player, "MegaStart") then Balance.MegaStartJump else 0
	ctx.Data.MarkDirty(player)
	ctx.Analytics.FunnelStep(player, data, 5, "FirstRebirth")
	ctx.Stages.ApplyStats(player)

	-- back to the start
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.CFrame = CFrame.new(0, 4, -14)
	end

	Remotes.Event("Notify"):FireClient(player, {
		Text = ("REBIRTH %d! Jump gain and coins now x%.2f. The tower awaits!"):format(
			data.Rebirths,
			1 + Balance.RebirthGainBonus * data.Rebirths
		),
		Color = Color3.fromRGB(255, 120, 255),
	})
	return true, nil
end

function RebirthService.Init(serviceCtx: any)
	ctx = serviceCtx
	Remotes.Function("Rebirth").OnServerInvoke = function(player)
		return RebirthService.Perform(player, false)
	end
end

return RebirthService
