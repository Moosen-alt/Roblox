--!strict
-- Areas: five separate stretches of water, bought once with coins and sailed
-- between from the Dock Master at the home port.
--
-- This is the game's progression spine. Rebirth ("Set Sail") still exists and
-- still grants the permanent coin multiplier, but it no longer decides what you
-- can catch — and, critically, it does NOT take areas back. Content you bought
-- stays bought. That separation is what makes an area worth saving for: a goal
-- you can lose is a threat, not a goal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Remotes = require(Shared.Remotes)
local Spotlight = require(script.Parent.Spotlight)

local AreaService = {}

local AREA_COLOR = Color3.fromRGB(120, 200, 255)

local ctx: any = nil
local origins: { Vector3 } = {}

-- Where each area's dock is, filled in by MapBuilder at startup.
function AreaService.SetOrigins(list: { Vector3 })
	origins = list
end

function AreaService.Cost(index: number): number
	return Balance.AreaCosts[index] or math.huge
end

local function teleport(player: Player, index: number): boolean
	local origin = origins[index]
	local character = player.Character
	if not origin or not character then
		return false
	end
	-- Land on the dock, a few studs back from the water, facing the spots.
	character:PivotTo(CFrame.new(origin + Vector3.new(0, 4, 12)))
	return true
end

function AreaService.Travel(player: Player, index: number): (boolean, string?)
	local data = ctx.Data.Get(player)
	if not data then
		return false, "Loading..."
	end
	if index < 1 or index > Balance.MaxLayer then
		return false, "No such area."
	end
	if index > data.AreaUnlocked then
		return false, "You haven't bought that area yet."
	end
	if not teleport(player, index) then
		return false, "Couldn't find your boat."
	end
	data.AreaCurrent = index
	ctx.Data.MarkDirty(player)
	Remotes.Event("Notify"):FireClient(player, {
		Text = "Now fishing: " .. Balance.LayerNames[index],
		Color = AREA_COLOR,
	})
	return true, nil
end

function AreaService.Buy(player: Player, index: number): (boolean, string?)
	local data = ctx.Data.Get(player)
	if not data then
		return false, "Loading..."
	end
	if index < 1 or index > Balance.MaxLayer then
		return false, "No such area."
	end
	if index <= data.AreaUnlocked then
		return false, "You already own that area."
	end
	-- Strictly one at a time. Letting a rich player skip straight to the Abyss
	-- would delete three areas of content they paid nothing to see.
	if index ~= data.AreaUnlocked + 1 then
		return false, "Unlock " .. Balance.LayerNames[data.AreaUnlocked + 1] .. " first."
	end
	local cost = AreaService.Cost(index)
	if data.Coins < cost then
		return false, ("Need %d coins to reach %s."):format(cost, Balance.LayerNames[index])
	end
	data.Coins -= cost
	data.AreaUnlocked = index
	ctx.Data.MarkDirty(player)
	ctx.Analytics.FunnelStep(player, data, 4, "FirstArea")

	-- Buying new water is the biggest single thing a player does with coins in
	-- this game. It gets the room's attention, and it is true: they really did.
	Spotlight.Pillar(player, AREA_COLOR)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			Remotes.Event("Notify"):FireClient(other, {
				Text = ("%s just opened up %s!"):format(player.DisplayName, Balance.LayerNames[index]),
				Color = AREA_COLOR,
			})
		end
	end
	AreaService.Travel(player, index)
	return true, nil
end

function AreaService.Init(serviceCtx: any)
	ctx = serviceCtx

	Remotes.Function("BuyArea").OnServerInvoke = function(player, index)
		if typeof(index) ~= "number" then
			return false, "Bad request."
		end
		return AreaService.Buy(player, math.floor(index))
	end

	Remotes.Function("TravelArea").OnServerInvoke = function(player, index)
		if typeof(index) ~= "number" then
			return false, "Bad request."
		end
		return AreaService.Travel(player, math.floor(index))
	end

	-- Put returning players back where they left off. Their character does not
	-- exist yet at profile-load time, so this waits for the spawn.
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.defer(function()
				local data = ctx.Data.Get(player)
				if data and data.AreaCurrent > 1 then
					teleport(player, math.clamp(data.AreaCurrent, 1, data.AreaUnlocked))
				end
			end)
		end)
	end)
end

return AreaService
