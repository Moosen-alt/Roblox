--!strict
-- The aquarium tank, filled with the fish YOU have on display.
--
-- Racks are per player, so the tank has to be: what you see swimming is your own
-- socketed fish, not a shared decoration and not the player standing next to
-- you. That makes this client-side work by necessity — and by luck, because a
-- tank that costs the server nothing can afford to actually animate.
--
-- The point of it is simple: a number on a screen saying "4 / 8 tanks" is not a
-- reason to socket a fifth fish. Watching the tank get busier is.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crystals = require(Shared.Config.Crystals)
local FishShape = require(Shared.FishShape)
local RelicShape = require(Shared.RelicShape)
local State = require(script.Parent.State)

local AquariumView = {}

type Swimmer = {
	Model: Model,
	Center: Vector3,
	Radius: Vector3, -- how far it may drift on each axis
	Speed: number,
	Phase: number,
	Depth: number,
}

-- A relic on display is its own model — an anchor, a helmet, a trident — so the
-- tank needs the NAME, which a plain FishShape.Options does not carry. Bound per
-- rebuild rather than passed around, so the two builders keep the same shape and
-- the caller can pick between them with one variable.
local relicName = ""
local function relicModel(options: FishShape.Options): Model
	return RelicShape.Build({
		Name = relicName,
		Color = options.Color,
		Scale = (options.Scale or 1) * 1.5,
		Seed = options.Seed,
		Sparkle = options.Sparkle,
	})
end

local tank: BasePart? = nil
local swimmers: { Swimmer } = {}
-- Relics: parented and placed once, never animated per frame.
local display: { Model } = {}
local container: Folder? = nil
local rng = Random.new()
-- What the tank is currently showing, so an identical state push doesn't rebuild
-- eight models sixty times a second.
local signature = ""

local function clear()
	if container then
		container:Destroy()
		container = nil
	end
	table.clear(swimmers)
	table.clear(display)
end

-- One fish per occupied rack slot, spread across the tank's volume so they do
-- not stack into one spot when several are added at once.
local function rebuild(state: any)
	local water = tank
	if not water then
		return
	end
	clear()

	local folder = Instance.new("Folder")
	folder.Name = "AquariumFish"
	folder.Parent = water
	container = folder

	local slots: { string } = {}
	for slot in state.Racks do
		table.insert(slots, slot)
	end
	table.sort(slots)

	local size = water.Size
	for index, slot in slots do
		local rack = state.Racks[slot]
		local fish = rack and state.Crystals[rack.CrystalId]
		if fish then
			local def = Crystals.GetBase(fish.Base)
			local mutation = Crystals.GetMutation(fish.Mut)
			local isRelic = Crystals.IsRelic(fish.Base)
			relicName = fish.Base
			-- Typed explicitly: Luau will not call a union of two identically
			-- shaped function types, so the branch has to name what it returns.
			local build: (FishShape.Options) -> Model = if isRelic then relicModel else FishShape.Build
			local model = build({
				-- Aura tints the fish rather than replacing its colour, so a
				-- Gilded trout still looks like a trout.
				Color = if mutation and mutation.Color
					then (def and def.Color or Color3.new(1, 1, 1)):Lerp(mutation.Color, 0.55)
					else (def and def.Color or Color3.fromRGB(200, 200, 200)),
				-- Tank fish are small; the tank is ~9 studs across and has to hold
				-- eight of them without becoming a traffic jam.
				Scale = 0.26 * math.clamp(fish.Size or 1, 0.9, 2.2),
				Seed = index * 13 + #fish.Base,
				Sparkle = fish.Mut ~= "Normal",
			})
			model.Parent = folder

			-- Lanes: each fish gets its own height band and its own orbit, so
			-- eight of them read as a school rather than as one blur.
			--
			-- Relics do not swim. They sit on the gravel and turn slowly, which is
			-- how a display case works and how you can tell at a glance which half
			-- of your collection you have put on show.
			if isRelic then
				local spread = (index - 0.5) / math.max(#slots, 1) - 0.5
				model:PivotTo(
					CFrame.new(water.Position + Vector3.new(spread * size.X * 0.7, -size.Y * 0.36, 0))
				)
				table.insert(display, model)
			else
				local lane = (index - 0.5) / math.max(#slots, 1)
				table.insert(swimmers, {
					Model = model,
					Center = water.Position + Vector3.new(0, (lane - 0.5) * (size.Y * 0.55), 0),
					Radius = Vector3.new(size.X * 0.3, size.Y * 0.12, size.Z * 0.22),
					Speed = rng:NextNumber(0.35, 0.62),
					Phase = rng:NextNumber(0, math.pi * 2),
					Depth = rng:NextNumber(-0.6, 0.6),
				})
			end
		end
	end
end

-- Cheap identity for "what should be in the tank": rebuild only when the set of
-- displayed fish actually changes, not on every coin tick.
local function signatureOf(state: any): string
	local parts: { string } = {}
	for slot, rack in state.Racks do
		local fish = state.Crystals[rack.CrystalId]
		if fish then
			table.insert(parts, ("%s:%s|%s|%.2f"):format(slot, fish.Base, fish.Mut, fish.Size or 1))
		end
	end
	table.sort(parts)
	return table.concat(parts, ",")
end

function AquariumView.Init()
	local function adopt(instance: Instance)
		if instance:IsA("BasePart") and not tank then
			tank = instance
			signature = ""
			local state = State.Get()
			if state then
				signature = signatureOf(state)
				rebuild(state)
			end
		end
	end
	for _, tagged in CollectionService:GetTagged("AquariumTank") do
		adopt(tagged)
	end
	CollectionService:GetInstanceAddedSignal("AquariumTank"):Connect(adopt)

	State.Changed:Connect(function(state)
		if not tank or not state or not state.Racks or not state.Crystals then
			return
		end
		local next = signatureOf(state)
		if next ~= signature then
			signature = next
			rebuild(state)
		end
	end)

	local clock = 0
	RunService.RenderStepped:Connect(function(dt: number)
		if #swimmers == 0 then
			return
		end
		clock += dt
		for _, swimmer in swimmers do
			local t = clock * swimmer.Speed + swimmer.Phase
			-- A flattened figure-of-eight: it turns at the ends of the tank the
			-- way a fish does, instead of orbiting like a carousel horse.
			local x = math.sin(t) * swimmer.Radius.X
			local y = math.sin(t * 2.1) * swimmer.Radius.Y
			local z = math.sin(t * 0.7 + swimmer.Depth) * swimmer.Radius.Z
			-- Face along the path. The nose is +X, and the fish is moving in the
			-- direction the sine is heading, so cos gives the heading directly.
			local heading = if math.cos(t) >= 0 then 0 else math.pi
			swimmer.Model:PivotTo(
				CFrame.new(swimmer.Center + Vector3.new(x, y, z))
					* CFrame.Angles(0, heading, math.sin(t * 2.1) * 0.12)
			)
		end
	end)
end

return AquariumView
