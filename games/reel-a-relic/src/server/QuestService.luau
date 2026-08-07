--!strict
-- DAILY QUESTS: three things to do today.
--
-- The game already rewards you for playing. What it had no version of was a
-- REASON to open the app — a small, finishable, visible list. That is the
-- strongest honest retention lever a simulator has, and the one thing this one
-- was missing: streaks reward the login, events reward being lucky enough to be
-- online, but neither gives a returning player something to aim at.
--
-- Three rules this file keeps to, because the audience is largely children:
--
--   1. Every quest is something the player was going to do anyway. Naming it and
--      paying for it is the whole design; inventing busywork is not.
--   2. Nothing expires mid-session and nothing punishes a miss. Yesterday's
--      unclaimed quests simply roll over into today's three.
--   3. Nothing is finishable only by spending Robux. A quest a kid cannot
--      complete without paying is an advert wearing a checklist's clothes.

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Remotes = require(Shared.Remotes)

local QuestService = {}

local ctx: any = nil

local function today(): number
	-- The same boundary StreakService uses, so a player never has two different
	-- "days" running at once.
	return os.time() // 86400
end

-- Deterministic per (player, day): the same three quests survive a rejoin, a
-- server hop and a crash. Rolling fresh on every load would let a player reroll
-- an unwanted quest by rejoining, which turns a checklist into a slot machine.
local function rollFor(userId: number, day: number): { string }
	local rng = Random.new(userId * 1000003 + day)
	local pool = table.clone(Balance.QuestPool)
	local picked: { string } = {}
	-- Sample without replacement so a player never gets the same quest twice.
	for _ = 1, math.min(Balance.QuestCount, #pool) do
		local index = rng:NextInteger(1, #pool)
		table.insert(picked, pool[index].Id)
		table.remove(pool, index)
	end
	return picked
end

local function defOf(id: string): Balance.QuestDef?
	for _, def in Balance.QuestPool do
		if def.Id == id then
			return def
		end
	end
	return nil
end

-- Reward scales with the deepest water the player has unlocked, so a day-30
-- player's quests stay worth doing without a day-1 player's being unfinishable.
local function rewardFor(def: Balance.QuestDef, data: any): number
	local layer = math.clamp(data.AreaUnlocked or 1, 1, Balance.MaxLayer)
	local scaled = Balance.QuestRewardBase * Balance.QuestRewardPerLayer ^ (layer - 1)
	return math.floor(scaled * def.Reward)
end

-- Roll today's list if the stored one is stale. Safe to call on every report.
local function refresh(data: any, userId: number): boolean
	local day = today()
	local quests = data.Quests
	if quests.Day == day and #quests.Ids > 0 then
		return false
	end
	quests.Day = day
	quests.Ids = rollFor(userId, day)
	quests.Progress = {}
	quests.Claimed = {}
	for index = 1, #quests.Ids do
		quests.Progress[index] = 0
		quests.Claimed[index] = false
	end
	return true
end

function QuestService.Refresh(player: Player)
	local data = ctx.Data.Get(player)
	if not data then
		return
	end
	if refresh(data, player.UserId) then
		ctx.Data.MarkDirty(player)
		ctx.Data.PushState(player)
	end
end

-- Called from the gameplay services when something quest-worthy happens.
-- `amount` may be more than one: a good reel lands several fish at once, and
-- counting that as one catch would make the quest feel broken.
function QuestService.Report(player: Player, kind: string, amount: number)
	if amount <= 0 then
		return
	end
	local data = ctx.Data.Get(player)
	if not data or not data.Quests then
		return
	end
	refresh(data, player.UserId)

	local changed = false
	for index, id in data.Quests.Ids do
		local def = defOf(id)
		if def and def.Kind == kind and not data.Quests.Claimed[index] then
			local current = data.Quests.Progress[index] or 0
			if current < def.Target then
				data.Quests.Progress[index] = math.min(current + amount, def.Target)
				changed = true
				-- Tell them the moment it completes, not when they next open the
				-- panel. A finished quest nobody noticed is a wasted reward.
				if data.Quests.Progress[index] >= def.Target then
					Remotes.Event("Notify"):FireClient(player, {
						Text = "QUEST DONE! " .. def.Text:format(def.Target) .. " — claim it!",
						Color = Color3.fromRGB(255, 214, 90),
					})
				end
			end
		end
	end
	if changed then
		ctx.Data.MarkDirty(player)
		ctx.Data.PushState(player)
	end
end

function QuestService.Claim(player: Player, index: number): (boolean, string?)
	local data = ctx.Data.Get(player)
	if not data or not data.Quests then
		return false, "Loading..."
	end
	refresh(data, player.UserId)
	local id = data.Quests.Ids[index]
	local def = if id then defOf(id) else nil
	if not def then
		return false, "No such quest."
	end
	if data.Quests.Claimed[index] then
		return false, "Already claimed."
	end
	if (data.Quests.Progress[index] or 0) < def.Target then
		return false, "Not finished yet."
	end

	data.Quests.Claimed[index] = true
	local reward = rewardFor(def, data)
	-- applyMult false: quest pay is a flat, predictable reward. Running it
	-- through the coin multiplier would make the same checklist pay wildly
	-- different amounts either side of a Set Sail, which reads as a bug.
	ctx.Data.AddCoins(player, reward, false)
	ctx.Data.MarkDirty(player)
	ctx.Data.PushState(player)
	Remotes.Event("Notify"):FireClient(player, {
		Text = ("+%d coins — quest complete!"):format(reward),
		Color = Color3.fromRGB(255, 214, 90),
	})
	return true, nil
end

-- What the client needs to draw the panel: text, progress, target, reward.
function QuestService.Describe(data: any): { any }
	if not data or not data.Quests then
		return {}
	end
	local list = {}
	for index, id in data.Quests.Ids do
		local def = defOf(id)
		if def then
			table.insert(list, {
				Text = def.Text:format(def.Target),
				Progress = math.min(data.Quests.Progress[index] or 0, def.Target),
				Target = def.Target,
				Claimed = data.Quests.Claimed[index] == true,
				Reward = rewardFor(def, data),
				Index = index,
			})
		end
	end
	return list
end

function QuestService.Init(serviceCtx: any)
	ctx = serviceCtx

	Remotes.Function("ClaimQuest").OnServerInvoke = function(player, index)
		if typeof(index) ~= "number" then
			return false, "Bad request."
		end
		return QuestService.Claim(player, math.floor(index))
	end

	-- Roll over for anyone who stays online across the daily boundary, so a
	-- player who never logs out still gets tomorrow's list.
	task.spawn(function()
		local lastDay = today()
		while true do
			task.wait(60)
			local day = today()
			if day ~= lastDay then
				lastDay = day
				for _, player in Players:GetPlayers() do
					QuestService.Refresh(player)
				end
			end
		end
	end)
end

return QuestService
