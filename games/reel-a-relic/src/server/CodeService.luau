--!strict
-- Server side of redeem codes. Validates, pays, and remembers.
--
-- Everything here is server-authoritative on purpose. The client's entire job is
-- to send a string; it never learns which codes exist, never decides whether one
-- is valid, and never computes a reward. A client that could would be a client
-- that could mint coins.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Codes = require(Shared.Config.Codes)
local Remotes = require(Shared.Remotes)

local CodeService = {}

local ctx: any = nil

-- Longest real code is well under this. A cap stops someone sending a megabyte
-- string to make the server do pointless work on every keystroke.
local MAX_INPUT = 64

local function coinsFor(def: Codes.CodeDef, data: any): number
	if not def.Coins or def.Coins <= 0 then
		return 0
	end
	-- Scaled by the deepest water unlocked, exactly like a quest reward: a flat
	-- number is either irrelevant on day 30 or game-breaking on day 1.
	local layer = math.clamp(data.AreaUnlocked or 1, 1, Balance.MaxLayer)
	local scaled = Balance.CodeRewardBase * Balance.CodeRewardPerLayer ^ (layer - 1)
	return math.floor(scaled * def.Coins)
end

function CodeService.Redeem(player: Player, input: string): (boolean, string?)
	local data = ctx.Data.Get(player)
	if not data then
		return false, "Still loading — try again in a second."
	end
	if #input > MAX_INPUT then
		return false, "That's not a code."
	end

	local def = Codes.Find(input)
	if not def then
		return false, "That code doesn't exist. Check the spelling!"
	end
	if def.Expires and os.time() > def.Expires then
		-- Say it expired rather than "invalid". A player who typed it correctly
		-- from an old video should be told they were right and late, not wrong.
		return false, "That code has expired — follow the group for new ones!"
	end

	local key = Codes.Normalise(def.Code)
	data.Redeemed = data.Redeemed or {}
	if data.Redeemed[key] then
		return false, "You've already used that code."
	end
	data.Redeemed[key] = true

	local coins = coinsFor(def, data)
	if coins > 0 then
		-- applyMult false: a code pays what the panel said it would. Running it
		-- through the rebirth multiplier would make the same code pay wildly
		-- different amounts to two players who both typed the same thing.
		ctx.Data.AddCoins(player, coins, false)
	end
	local chests = def.Chests or 0
	if chests > 0 then
		data.Geodes += chests
	end
	ctx.Data.MarkDirty(player)
	ctx.Data.PushState(player)

	local parts = {}
	if coins > 0 then
		table.insert(parts, ("%d coins"):format(coins))
	end
	if chests > 0 then
		table.insert(parts, ("%d chest%s"):format(chests, if chests == 1 then "" else "s"))
	end
	local reward = if #parts > 0 then table.concat(parts, " + ") else "a thank you"
	Remotes.Event("Notify"):FireClient(player, {
		Text = ("CODE REDEEMED! +%s"):format(reward),
		Color = Color3.fromRGB(255, 214, 90),
	})
	return true, ("%s  +%s"):format(def.Note, reward)
end

function CodeService.Init(serviceCtx: any)
	ctx = serviceCtx

	Remotes.Function("RedeemCode").OnServerInvoke = function(player, input)
		if typeof(input) ~= "string" then
			return false, "Bad request."
		end
		return CodeService.Redeem(player, input)
	end
end

return CodeService
