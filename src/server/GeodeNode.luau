--!strict
-- Builds the geodes embedded in the mine wall. That is all it does: mining is
-- per-player from the first tap to the respawn, so every bit of geode state —
-- widening cracks, the break, the regrow — lives on the client in WorldFx.
-- Nothing here mutates a geode after it is built.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrystalShape = require(Shared.CrystalShape)

local GeodeNode = {}

export type Node = {
	Index: number,
	Hitbox: BasePart,
	Model: Model,
	Rock: BasePart,
	Core: BasePart,
	Crystal: Model,
	Light: PointLight,
	Color: Color3,
	Origin: Vector3,
}

local info: { [BasePart]: Node } = {}

GeodeNode.Info = info

local rng = Random.new(20260805)

-- Decoration is invisible to queries by default. Only the hitbox opts back in,
-- so a tap can never land on a lump or a crystal tip and be thrown away —
-- whichever pixel the player hits, the same node gets mined.
local function part(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p
end

-- A geode: lumpy rock, cracked open on the side facing the player, glowing
-- crystals turning slowly in the hollow. Faces +Z.
function GeodeNode.Build(index: number, position: Vector3, color: Color3, parent: Instance): Node
	local model = Instance.new("Model")
	model.Name = "Geode" .. index

	local rockColor = color:Lerp(Color3.fromRGB(52, 46, 66), 0.86)

	local rock = part({
		Name = "Rock",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(7.4, 7.4, 7.4),
		Position = position,
		Color = rockColor,
		Material = Enum.Material.Rock,
		CanCollide = true, -- you should bump into a boulder, not walk through it
	}, model)

	-- Lumps break the perfect sphere so it reads as a rock, not a marble
	for lump = 1, 3 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local size = rng:NextNumber(3.2, 4.8)
		part({
			Name = "Lump" .. lump,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size, size),
			Position = position + Vector3.new(math.cos(angle) * 2.6, math.sin(angle) * 2.2, rng:NextNumber(-1.6, 0.4)),
			Color = rockColor,
			Material = Enum.Material.Rock,
		}, model)
	end

	-- The opening is a glow behind crystals, NOT a hole. An earlier pass put a
	-- near-black disc in front of the core to read as a cavity; from any distance
	-- that just made every geode a bright ring around a black centre — twelve
	-- donuts in a row. The halo sits behind, the core fills the middle, and the
	-- crystals sit in front of both.
	part({
		Name = "RimGlow",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, 5.8, 5.8),
		CFrame = CFrame.new(position + Vector3.new(0, 0, 2.9)) * CFrame.Angles(0, math.rad(90), 0),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.45,
	}, model)

	local core = part({
		Name = "Core",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(4, 4, 4),
		Position = position + Vector3.new(0, 0, 2.5),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.28,
	}, model)

	-- Cracks spreading from the opening. WorldFx widens these per player as they
	-- chip away, so the geode visibly gives up.
	--
	-- Fanned across one side at uneven angles, and short enough to stay on the
	-- rock. Five even spokes reaching past the edge turned every geode into a
	-- dartboard when you looked down the wall.
	for v = 1, 5 do
		local angle = math.rad(150) + (v - 1) * math.rad(42) + rng:NextNumber(-0.22, 0.22)
		local length = rng:NextNumber(0.9, 1.7)
		part({
			Name = "Vein" .. v,
			Size = Vector3.new(0.3, length, 0.4),
			CFrame = CFrame.new(position + Vector3.new(0, 0, 2.95))
				* CFrame.Angles(0, 0, -angle)
				* CFrame.new(0, 2.1 + length / 2, 0),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.72,
		}, model)
	end

	local crystal = CrystalShape.Build({
		Color = color,
		-- The crystals in the mouth are the geode's whole read from a distance,
		-- now that the cracks are subtle. Make them the thing you actually see.
		Scale = 1.15,
		Shards = 5,
		Segments = 2,
		Seed = index * 31 + 7,
		Sparkle = true,
	})
	crystal.Name = "Crystal"
	-- Point the shards out of the wall at the player, then let the client spin
	-- the whole cluster about that axis (free motion — no replication). The roll
	-- is random per geode: twelve identically-posed clusters read as wallpaper.
	crystal:PivotTo(
		CFrame.new(position + Vector3.new(0, 0, 2.6))
			* CFrame.Angles(math.rad(90), 0, rng:NextNumber(0, math.pi * 2))
	)
	crystal.Parent = model
	CollectionService:AddTag(crystal, "SpinCrystal")
	crystal:SetAttribute("SpinSpeed", rng:NextNumber(0.35, 0.7))

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 20
	light.Brightness = 1.6
	light.Parent = core

	-- One invisible box owns the tap: raycasts and clicks resolve here no matter
	-- which shard or lump the player actually aimed at.
	local hitbox = part({
		Name = "Hitbox",
		Size = Vector3.new(8.6, 8.6, 6),
		Position = position + Vector3.new(0, 0, 1),
		Transparency = 1,
		CanQuery = true,
	}, model)
	hitbox:SetAttribute("NodeIndex", index)

	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 32
	click.Parent = hitbox

	model.PrimaryPart = hitbox
	model.Parent = parent

	local node: Node = {
		Index = index,
		Hitbox = hitbox,
		Model = model,
		Rock = rock,
		Core = core,
		Crystal = crystal,
		Light = light,
		Color = color,
		Origin = position,
	}
	info[hitbox] = node
	return node
end

-- A geode still buried in the rock face: lumpy stone with mineral veins
-- showing through, and deliberately NO open cavity, no crystals and no light.
--
-- That restraint is the whole point. These are scenery, and if they looked like
-- the minable ones players would tap them and get nothing. Bright + cracked
-- open + full of crystals means "mine me"; dull stone with a hint of colour
-- means "there is more of this buried in here", which is the feeling the wall
-- should give without making a promise it cannot keep.
function GeodeNode.Buried(position: Vector3, color: Color3, scale: number, seed: number, parent: Instance)
	local localRng = Random.new(seed)
	local rockColor = color:Lerp(Color3.fromRGB(50, 44, 64), 0.9)
	local model = Instance.new("Model")
	model.Name = "BuriedGeode"

	local size = 4.6 * scale
	part({
		Name = "Rock",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size, size, size),
		Position = position,
		Color = rockColor,
		Material = Enum.Material.Rock,
	}, model)
	for lump = 1, 2 do
		local angle = localRng:NextNumber(0, math.pi * 2)
		local lumpSize = localRng:NextNumber(2, 3.4) * scale
		part({
			Name = "Lump" .. lump,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(lumpSize, lumpSize, lumpSize),
			Position = position
				+ Vector3.new(math.cos(angle) * 1.7 * scale, math.sin(angle) * 1.5 * scale, localRng:NextNumber(-1, 0.2)),
			Color = rockColor,
			Material = Enum.Material.Rock,
		}, model)
	end

	-- Mineral veins tracing the surface: dim, so they read as ore in stone
	-- rather than as an open, tappable geode.
	for v = 1, 3 do
		local angle = localRng:NextNumber(0, math.pi * 2)
		local length = localRng:NextNumber(1.6, 2.8) * scale
		part({
			Name = "Vein" .. v,
			Size = Vector3.new(0.22 * scale, length, 0.3 * scale),
			CFrame = CFrame.new(position + Vector3.new(0, 0, size * 0.42))
				* CFrame.Angles(0, 0, -angle)
				* CFrame.new(0, length * 0.35, 0),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.72,
		}, model)
	end

	model.Parent = parent
end

return GeodeNode
