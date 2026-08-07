--!strict
-- Everything server-side about the Auto Swing pass.
--
-- The mining itself is not here, and that is the design: Auto Swing is a HOLD,
-- not an auto-clicker. The client repeats the swing while the button is down and
-- sends the same MineNode event a tap sends, so MiningService cannot tell the
-- difference and does not need to — every swing runs the identical range,
-- cooldown, capacity and per-player-availability checks. Nothing mines on your
-- behalf while you stand still, and because the server's mine cooldown paces the
-- swings either way, holding can never out-earn a very fast tapper.
--
-- What is left here is the two things the server does owe the pass: telling a
-- new owner how it works, once, and offering it to the person it is actually for.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Monetization = require(Shared.Config.Monetization)
local Remotes = require(Shared.Remotes)

local AutoMineService = {}

local ctx: any = nil

-- A pass whose whole benefit is an input change has to say so, or it reads as
-- broken: you buy it, nothing visibly happens, and you keep tapping.
local function maybeTip(player: Player)
	local data = ctx.Data.Get(player)
	if not data or data.Funnel.AutoSwingTip then
		return
	end
	if not ctx.Monetization.OwnsPass(player, "AutoMine") then
		return
	end
	data.Funnel.AutoSwingTip = true
	ctx.Data.MarkDirty(player)
	Remotes.Event("Notify"):FireClient(player, {
		Text = "Auto Swing is on — hold the button down to keep mining.",
		Color = Color3.fromRGB(120, 255, 200),
	})
end

-- The pass sells itself to exactly one person: someone who has just tapped a
-- rock several hundred times and knows precisely how that feels. Showing it
-- then is honest — it is an offer to stop doing the thing they are visibly
-- tired of — and it is worth far more than a permanent button they scrolled
-- past in their first minute. Once per player, ever.
local function maybeOffer(player: Player)
	local data = ctx.Data.Get(player)
	if not data or data.Funnel.AutoMineOffer then
		return
	end
	if data.Stats.GeodesMined < Balance.AutoMineOfferAfterGeodes then
		return
	end
	if Monetization.PassIdByKey("AutoMine") == 0 then
		return -- pass not created yet; don't advertise something unbuyable
	end
	if ctx.Monetization.OwnsPass(player, "AutoMine") then
		data.Funnel.AutoMineOffer = true -- they already have it; never offer later
		ctx.Data.MarkDirty(player)
		return
	end
	data.Funnel.AutoMineOffer = true
	ctx.Data.MarkDirty(player)
	Remotes.Event("Notify"):FireClient(player, {
		Text = ("%d geodes tapped out by hand. Auto Swing lets you just hold — see the Store."):format(
			data.Stats.GeodesMined
		),
		Color = Color3.fromRGB(255, 210, 90),
	})
end

function AutoMineService.Init(serviceCtx: any)
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

return AutoMineService
