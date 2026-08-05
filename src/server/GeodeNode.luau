--!strict
-- Builds the geodes embedded in the mine wall and owns their shared visual
-- state (intact -> broken -> respawned). Per-player damage feedback lives on
-- the client (WorldFx) because mining progress is per-player: your cracks
-- should widen for you without touching what anyone else sees.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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

-- Every visible part of a geode plus the look it should snap back to when it
-- respawns. Restoring from this table (rather than remembering deltas) means a
-- half-mined geode can never get stuck looking chewed.
local restore: { [BasePart]: { [BasePart]: { Transparency: number, Size: Vector3 } } } = {}
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

	-- The opening: a dark hollow with the glow behind it
	part({
		Name = "Hollow",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.7, 5.4, 5.4),
		CFrame = CFrame.new(position + Vector3.new(0, 0, 3.05)) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(16, 14, 24),
		Material = Enum.Material.Slate,
	}, model)

	local core = part({
		Name = "Core",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3.6, 3.6, 3.6),
		Position = position + Vector3.new(0, 0, 2.2),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
	}, model)

	-- Cracks radiating out of the opening. WorldFx widens these per player as
	-- they chip away, so the geode visibly gives up.
	for v = 1, 5 do
		local angle = ((v - 1) / 5) * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
		local length = rng:NextNumber(2.6, 3.8)
		part({
			Name = "Vein" .. v,
			Size = Vector3.new(0.3, length, 0.4),
			CFrame = CFrame.new(position + Vector3.new(0, 0, 2.95))
				* CFrame.Angles(0, 0, -angle)
				* CFrame.new(0, 2.3 + length / 2, 0),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.5,
		}, model)
	end

	local crystal = CrystalShape.Build({
		Color = color,
		Scale = 0.62,
		Shards = 5,
		Segments = 2,
		Seed = index * 31 + 7,
		Sparkle = true,
	})
	crystal.Name = "Crystal"
	-- Point the shards out of the wall at the player, then let the client spin
	-- the whole cluster about that axis (free motion — no replication).
	crystal:PivotTo(CFrame.new(position + Vector3.new(0, 0, 2.6)) * CFrame.Angles(math.rad(90), 0, 0))
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

	local snapshot: { [BasePart]: { Transparency: number, Size: Vector3 } } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= hitbox then
			snapshot[descendant] = { Transparency = descendant.Transparency, Size = descendant.Size }
		end
	end
	restore[hitbox] = snapshot

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

-- The payoff frame: shockwave, shard burst, the rock vanishing.
function GeodeNode.Break(node: Node)
	local shock = part({
		Name = "Shockwave",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 3, 3),
		CFrame = CFrame.new(node.Origin + Vector3.new(0, 0, 3.4)) * CFrame.Angles(0, math.rad(90), 0),
		Color = node.Color,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
		CanQuery = false,
	}, node.Model)
	TweenService:Create(shock, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.4, 30, 30),
		Transparency = 1,
	}):Play()
	task.delay(0.7, function()
		shock:Destroy()
	end)

	local burst = Instance.new("ParticleEmitter")
	burst.Color = ColorSequence.new(node.Color)
	burst.LightEmission = 0.8
	burst.Lifetime = NumberRange.new(0.4, 0.9)
	burst.Speed = NumberRange.new(14, 30)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Size = NumberSequence.new(0.9, 0)
	burst.Rate = 0
	burst.Parent = node.Core
	burst:Emit(34)
	task.delay(1.4, function()
		burst:Destroy()
	end)

	node.Light.Brightness = 0
	for target in restore[node.Hitbox] do
		TweenService:Create(target, TweenInfo.new(0.22), {
			Transparency = 1,
			Size = target.Size * 0.55,
		}):Play()
	end
	local click = node.Hitbox:FindFirstChildOfClass("ClickDetector")
	if click then
		click.MaxActivationDistance = 0
	end
end

-- Respawning geodes reroll their colour. Costs nothing, and it means the wall
-- you have been staring at for twenty minutes keeps producing something you
-- have not seen in that exact spot before.
local PALETTE = {
	Color3.fromRGB(170, 110, 240),
	Color3.fromRGB(60, 220, 130),
	Color3.fromRGB(60, 120, 255),
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(150, 255, 245),
	Color3.fromRGB(255, 60, 80),
}

local function recolor(node: Node, color: Color3)
	node.Color = color
	node.Light.Color = color
	local rockColor = color:Lerp(Color3.fromRGB(52, 46, 66), 0.86)
	for _, descendant in node.Model:GetDescendants() do
		if descendant:IsA("BasePart") then
			if descendant.Material == Enum.Material.Neon then
				descendant.Color = color
			elseif descendant.Material == Enum.Material.Rock then
				descendant.Color = rockColor
			end
		elseif descendant:IsA("ParticleEmitter") then
			descendant.Color = ColorSequence.new(color)
		end
	end
end

function GeodeNode.Reset(node: Node)
	for target, look in restore[node.Hitbox] do
		target.Size = look.Size
		target.Transparency = look.Transparency
	end
	recolor(node, PALETTE[rng:NextInteger(1, #PALETTE)])
	node.Light.Brightness = 1.6
	local click = node.Hitbox:FindFirstChildOfClass("ClickDetector")
	if click then
		click.MaxActivationDistance = 32
	end
end

return GeodeNode
