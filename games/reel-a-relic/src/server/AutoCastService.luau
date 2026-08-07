--!strict
-- Everything server-side about the Auto-Cast pass.
--
-- The fishing itself is not here, and that is the design: Auto-Cast is a HOLD,
-- not an auto-clicker. The client repeats the same MineNode report a click sends
-- while the button is down, so MiningService cannot tell the difference and does
-- not need to — the bite delay, the 1.2s strike window, one-angler-per-buoy,
-- area gating and hold capacity all apply identically. Nothing fishes on your
-- behalf while you stand still, and it can never out-fish a person, because the
-- wait is the mechanic and the wait is untouched.
--
-- What is left is telling a new owner how it works, once, and offering it to the
-- person it is actually for.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Monetization = require(Shared.Config.Monetization)
local Remotes = require(Shared.Remotes)

local AutoCastService = {}

local ctx: any = nil

-- A pass whose whole benefit is an input change has to say so, or it reads as
-- broken: you buy it, nothing visibly happens, and you keep clicking.
local function maybeTip(player: Player)
	local data = ctx.Data.Get(player)
	if not data or data.Funnel.AutoCastTip then
		return
	end
	if not ctx.Monetization.OwnsPass(player, "AutoCast") then
		return
	end
	data.Funnel.AutoCastTip = true
	ctx.Data.MarkDirty(player)
	Remotes.Event("Notify"):FireClient(player, {
		Text = "Auto-Cast is on — hold the button on a buoy and it casts and strikes for you.",
		Color = Color3.fromRGB(120, 255, 200),
	})
end

-- Offered once, to someone who has already clicked through a few hundred casts
-- and knows exactly what the pass is removing.
local function maybeOffer(player: Player)
	local data = ctx.Data.Get(player)
	if not data or data.Funnel.AutoCastOffer then
		return
	end
	if data.Stats.GeodesMined < Balance.AutoCastOfferAfterCatches then
		return
	end
	if Monetization.PassIdByKey("AutoCast") == 0 then
		return -- pass not created yet; don't advertise something unbuyable
	end
	if ctx.Monetization.OwnsPass(player, "AutoCast") then
		data.Funnel.AutoCastOffer = true
		ctx.Data.MarkDirty(player)
		return
	end
	data.Funnel.AutoCastOffer = true
	ctx.Data.MarkDirty(player)
	Remotes.Event("Notify"):FireClient(player, {
		Text = ("%d casts by hand. Auto-Cast lets you just hold — see the Store."):format(data.Stats.GeodesMined),
		Color = Color3.fromRGB(255, 210, 90),
	})
end

function AutoCastService.Init(serviceCtx: any)
	ctx = serviceCtx

	task.spawn(function()
		while true do
			task.wait(20)
			for _, player in Players:GetPlayers() do
				maybeTip(player)
				maybeOffer(player)
			end
		end
	end)
end

return AutoCastService
