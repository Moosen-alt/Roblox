--!strict
-- Trail cosmetics: the coin sink. "Rainbow" is the VIP-exclusive flex.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Remotes = require(Shared.Remotes)

local TrailService = {}

local ctx: any = nil

local function ownsTrail(player: Player, data: any, name: string): boolean
	if name == "Rainbow" then
		return ctx.Monetization.OwnsPass(player, "Vip")
	end
	return data.Trails[name] == true
end

function TrailService.Attach(player: Player, character: Model)
	local data = ctx.Data.Get(player)
	if not data then
		return
	end
	local existing = character:FindFirstChild("PlayerTrail", true)
	if existing then
		existing:Destroy()
	end
	local name = data.EquippedTrail
	if name == "" or not ownsTrail(player, data, name) then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, 1, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -1, 0)
	bottom.Parent = root

	local trail = Instance.new("Trail")
	trail.Name = "PlayerTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = 0.5
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Transparency = NumberSequence.new(0.2, 1)
	if name == "Rainbow" then
		trail.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 210, 90)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 255, 160)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(120, 200, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 120, 255)),
		})
	else
		local def = Balance.GetTrail(name)
		trail.Color = ColorSequence.new(def and def.Color or Color3.new(1, 1, 1))
	end
	trail.Parent = root
end

function TrailService.Buy(player: Player, name: string): (boolean, string?)
	local data = ctx.Data.Get(player)
	if not data then
		return false, "Loading..."
	end
	local def = Balance.GetTrail(name)
	if not def then
		return false, "Unknown trail."
	end
	if data.Trails[name] then
		return false, "Already owned!"
	end
	if data.Coins < def.Cost then
		return false, "Not enough coins."
	end
	data.Coins -= def.Cost
	data.Trails[name] = true
	ctx.Data.MarkDirty(player)
	return true, nil
end

function TrailService.Equip(player: Player, name: string): (boolean, string?)
	local data = ctx.Data.Get(player)
	if not data then
		return false, "Loading..."
	end
	if name ~= "" and not ownsTrail(player, data, name) then
		return false, "You don't own that trail."
	end
	data.EquippedTrail = name
	ctx.Data.MarkDirty(player)
	if player.Character then
		TrailService.Attach(player, player.Character)
	end
	return true, nil
end

function TrailService.Init(serviceCtx: any)
	ctx = serviceCtx
	Remotes.Function("BuyTrail").OnServerInvoke = function(player, name)
		if typeof(name) ~= "string" then
			return false, "Bad request."
		end
		return TrailService.Buy(player, name)
	end
	Remotes.Function("EquipTrail").OnServerInvoke = function(player, name)
		if typeof(name) ~= "string" then
			return false, "Bad request."
		end
		return TrailService.Equip(player, name)
	end
end

return TrailService
