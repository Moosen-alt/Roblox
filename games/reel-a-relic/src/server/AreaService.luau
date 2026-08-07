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

-- Below this and you are out of the world. The sea floor is at -6.4 and the
-- terrain block bottoms out around -16, so -60 is unambiguously "fell through"
-- while still being far above Roblox's own destroy height.
local VOID_Y = -60

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

	-- THE SAFETY NET. Invisible walls fence each area's patch of sea, but walls
	-- can be clipped through and the water is swimmable — and a player who ends
	-- up under the world would otherwise fall until Roblox destroyed them and
	-- respawned them at the HOME dock, however far they had sailed.
	--
	-- So: catch them well above that, and put them back on the dock of the area
	-- they are actually in. Cheap (one pass a second over the player list, the
	-- same shape as the Leaderboards loop) and it fails safe — an unknown area
	-- falls back to home rather than doing nothing.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and (root :: BasePart).Position.Y < VOID_Y then
					local data = ctx.Data.Get(player)
					local area = if data then math.clamp(data.AreaCurrent or 1, 1, Balance.MaxLayer) else 1
					if not teleport(player, area) then
						teleport(player, 1)
					end
				end
			end
		end
	end)

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
