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
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crystals = require(Shared.Config.Crystals)
local FishShape = require(Shared.FishShape)
local RelicShape = require(Shared.RelicShape)
local State = require(script.Parent.State)

local AquariumView = {}

type Swimmer = {
	Model: Model,
	Tank: BasePart,
	Center: Vector3,
	Radius: Vector3, -- how far it may drift on each axis
	Speed: number,
	Phase: number,
	Depth: number,
}

-- Both halves of the collection carry their own model now — 33 fish silhouettes
-- and 11 relics — so the builders take the same Options and the name selects the
-- shape inside each. (This used to bind a module-level `relicName` before every
-- call, back when only relics needed a name.)
local function relicModel(options: FishShape.Options): Model
	return RelicShape.Build({
		Name = options.Name or "",
		Color = options.Color,
		Scale = (options.Scale or 1) * 1.5,
		Seed = options.Seed,
		Sparkle = options.Sparkle,
	})
end

-- The gravel bed is 0.4 studs of sand on the tank floor and the water volume
-- starts a little under the glass, so the surface something actually RESTS on
-- sits half a stud above the bottom of the tagged water part. Tied to the tank
-- MapBuilder builds; if that changes, this does.
local GRAVEL_ABOVE_FLOOR = 0.5

-- Past this, a tank is somebody else's area and its fish can hold still.
local VIEW_DISTANCE = 160

-- Put a model down so its LOWEST POINT touches `floorY`.
--
-- The old code guessed a fixed drop from the tank centre and hoped every relic
-- was the same height. They are not — a Diver's Helmet is squat and a Trident is
-- tall — so anything taller than the guess sank through the gravel and the table
-- underneath it. Measure the model instead of assuming it: GetBoundingBox is in
-- world space and makes no assumption about where the pivot sits inside the
-- model, which matters because these are built by hand and theirs vary.
local function restOnFloor(model: Model, at: Vector3, floorY: number)
	model:PivotTo(CFrame.new(at))
	local box, size = model:GetBoundingBox()
	local lift = floorY - (box.Position.Y - size.Y * 0.5)
	model:PivotTo(model:GetPivot() + Vector3.new(0, lift, 0))
end

-- EVERY tagged tank, not one. Each area has its own Aquarium station now, so
-- there are five of these in the world — and this module used to latch onto the
-- first one it happened to find and ignore the rest. The symptom was an empty
-- tank in front of you while your fish swam in a tank two thousand studs away in
-- another area, which is a much stranger bug to look at than it is to fix.
local tanks: { BasePart } = {}
local swimmers: { Swimmer } = {}
-- Relics: parented and placed once, never animated per frame.
local display: { Model } = {}
local containers: { Folder } = {}
local rng = Random.new()
-- What the tank is currently showing, so an identical state push doesn't rebuild
-- eight models sixty times a second.
local signature = ""

local function clear()
	for _, folder in containers do
		folder:Destroy()
	end
	table.clear(containers)
	table.clear(swimmers)
	table.clear(display)
end

-- One fish per occupied rack slot, spread across the tank's volume so they do
-- not stack into one spot when several are added at once.
local function rebuild(state: any)
	clear()
	if #tanks == 0 then
		return
	end

	local slots: { string } = {}
	for slot in state.Racks do
		table.insert(slots, slot)
	end
	table.sort(slots)

	for _, water in tanks do
		local folder = Instance.new("Folder")
		folder.Name = "AquariumFish"
		folder.Parent = water
		table.insert(containers, folder)

		local size = water.Size
		for index, slot in slots do
			local rack = state.Racks[slot]
			local fish = rack and state.Crystals[rack.CrystalId]
			if fish then
				local def = Crystals.GetBase(fish.Base)
				local mutation = Crystals.GetMutation(fish.Mut)
				local isRelic = Crystals.IsRelic(fish.Base)
				-- Typed explicitly: Luau will not call a union of two identically
				-- shaped function types, so the branch has to name what it returns.
				local build: (FishShape.Options) -> Model = if isRelic then relicModel else FishShape.Build
				local model = build({
					-- The species/relic name IS the model now, so this is no longer
					-- decorative: without it every fish falls back to one shape.
					Name = fish.Base,
					-- Aura tints the fish rather than replacing its colour, so a
					-- Gilded snapper still looks like a snapper.
					Color = if mutation and mutation.Color
						then (def and def.Color or Color3.new(1, 1, 1)):Lerp(mutation.Color, 0.55)
						else (def and def.Color or Color3.fromRGB(200, 200, 200)),
					-- Tank fish are small; the tank is ~9 studs across and has to
					-- hold eight of them without becoming a traffic jam.
					Scale = 0.26 * math.clamp(fish.Size or 1, 0.9, 2.2),
					Seed = index * 13 + #fish.Base,
					Sparkle = fish.Mut ~= "Normal",
				})
				model.Parent = folder

				-- Relics do not swim. They sit on the gravel, which is how a
				-- display case works and how you can tell at a glance which half
				-- of your collection you have put on show.
				if isRelic then
					local spread = (index - 0.5) / math.max(#slots, 1) - 0.5
					-- Staggered in Z as well as X: a row of relics dead-centre
					-- hides the short ones behind the tall ones from the only
					-- angle the player ever looks at the tank from.
					local back = if index % 2 == 0 then size.Z * 0.18 else -size.Z * 0.16
					restOnFloor(
						model,
						water.Position + Vector3.new(spread * size.X * 0.7, 0, back),
						water.Position.Y - size.Y * 0.5 + GRAVEL_ABOVE_FLOOR
					)
					table.insert(display, model)
				else
					-- Lanes: each fish gets its own height band and its own orbit,
					-- so eight of them read as a school rather than as one blur.
					local lane = (index - 0.5) / math.max(#slots, 1)
					table.insert(swimmers, {
						Model = model,
						Tank = water,
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
		if not instance:IsA("BasePart") then
			return
		end
		table.insert(tanks, instance)
		local state = State.Get()
		if state then
			signature = signatureOf(state)
			rebuild(state)
		end
	end
	for _, tagged in CollectionService:GetTagged("AquariumTank") do
		adopt(tagged)
	end
	CollectionService:GetInstanceAddedSignal("AquariumTank"):Connect(adopt)

	State.Changed:Connect(function(state)
		if #tanks == 0 or not state or not state.Racks or not state.Crystals then
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
		-- Only the tank you are actually standing at needs to animate. There are
		-- five of them now, each holding up to eight fish, and the four you are
		-- not looking at are typically hundreds of studs away in another area.
		local camera = Workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else Vector3.zero
		for _, swimmer in swimmers do
			if (swimmer.Tank.Position - eye).Magnitude > VIEW_DISTANCE then
				continue
			end
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
