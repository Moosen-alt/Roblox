--!strict
-- MESH OVERRIDES: swap any hand-built model for an uploaded 3D mesh.
--
-- Everything in this game is built from Roblox primitives in code, because that
-- needs no asset pipeline. It also has a ceiling: primitives read as stylised,
-- never as sculpted. This file is the seam that lifts the ceiling, one
-- collectible at a time.
--
-- Add an entry and that species renders from the mesh. Leave it out and it falls
-- back to the primitive builder, unchanged. There is no all-or-nothing switch:
-- you can upload six fish this week and the other twenty-seven keep working.
--
--------------------------------------------------------------------------------
-- HOW TO ADD ONE
--------------------------------------------------------------------------------
--
--   1. Get the model as .obj or .fbx (Roblox accepts both).
--   2. Studio -> 3D Importer -> pick the file -> Import. It lands in Workspace.
--   3. Right-click the MeshPart -> Save to Roblox. Wait for moderation.
--   4. Select the MeshPart, copy its MeshId from Properties. It looks like
--      `rbxassetid://1234567890` — you want the NUMBER.
--   5. Add a row here, push. CI republishes automatically.
--
--        ["Anchovy"] = { Mesh = 1234567890, Scale = 1.0 },
--
--   6. Load the game and look at it in the Index. Adjust Scale, Offset and
--      Rotation until it sits like the primitive one did.
--
--------------------------------------------------------------------------------
-- ORIENTATION
--------------------------------------------------------------------------------
--
-- The primitive fish are built NOSE ALONG +X, upright, centred on the origin,
-- because the viewport camera and the billboard both look from +Z and a fish is
-- only recognisable side-on. Uploaded meshes almost never arrive that way —
-- Blender is Z-up, most exporters are Y-up, and modellers point things wherever
-- they like. `Rotation` fixes that per model without re-exporting anything:
-- degrees, applied X then Y then Z.
--
-- Two common corrections:
--   Z-up model (Blender default export)  -> Rotation = Vector3.new(-90, 0, 0)
--   Model facing -Z instead of +X        -> Rotation = Vector3.new(0, 90, 0)
--
--------------------------------------------------------------------------------
-- LICENSING — read this before uploading anything
--------------------------------------------------------------------------------
--
-- Uploading a model to Roblox is REDISTRIBUTION, and most "free" models on the
-- big marketplaces are not licensed for it. Roblox removes assets you do not
-- hold rights to, and repeat strikes put the account at risk — which would take
-- all three games down, not just one. So this is worth getting right once:
--
--   SAFE — public domain / CC0, explicitly fine to redistribute:
--     * Poly Haven          — everything is CC0. No attribution required.
--     * NASA 3D Resources   — US government work, public domain.
--
--   CHECK EVERY MODEL — per-model licences, and the free tier is often
--   personal/editorial use only, which does NOT cover a monetised game:
--     * Sketchfab, CGTrader, TurboSquid, Fab, Free3D, 3DExport, GrabCAD
--     Look for CC0 or CC-BY specifically. CC-BY needs a credit line — put it in
--     the game description. "Free to download" is not a licence.
--
--   BEST FOR ROBLOX — the Roblox Creator Store. Models there are licensed for
--   Roblox use by construction, and they insert straight into Studio with no
--   upload and no moderation wait. It sidesteps both problems at once, and for
--   fish specifically the selection is good. Start here.
--
-- Freepik and Threedio (icons8) both require attribution on their free tiers.
-- That is fine — it is one line in the description — but it is a requirement,
-- not a suggestion.

local Meshes = {}

export type MeshDef = {
	Mesh: number, -- Roblox asset id (the number, not the rbxassetid:// string)
	Scale: number?, -- multiplier on the crystal's normal size (default 1)
	Offset: Vector3?, -- nudge if the model's origin is not its centre
	Rotation: Vector3?, -- degrees, X then Y then Z
	-- MEASURED, not guessed. Filled in by tools/build-meshes.py, which reads the
	-- source OBJ; never edit these by hand.
	--
	-- A SpecialMesh leaves its Part 1x1x1 no matter how big the mesh draws, so
	-- `GetBoundingBox` reports the part and not the model you can see. Everything
	-- that has to sit a world prop ON something — rather than through it, which
	-- is how the aquarium relics went wrong — needs the real extents, and the
	-- only place they exist is the source file.
	Size: Vector3?, -- native extents in mesh units, before Scale
	Floor: number?, -- native lowest Y; what has to land on the ground
	Middle: Vector3?, -- native centre, for models authored off-origin
	-- Also generated: the world pack ships a material and colour per model, and
	-- transcribing sixty-nine of those by hand is how one ends up a shade off
	-- with nobody noticing.
	Material: Enum.Material?,
	Tint: Color3?,
}

-- Keyed by the exact Name in Config/Crystals.luau.
Meshes.Crystal = {
	["Amethyst"] = { Mesh = 92583408964793, Scale = 1 },
	["Diamond"] = { Mesh = 78952983628622, Scale = 1 },
	["Emerald"] = { Mesh = 98546010452110, Scale = 1 },
	["Opal"] = { Mesh = 80277452297193, Scale = 1 },
	["Quartz"] = { Mesh = 113033354243136, Scale = 1 },
	["Ruby"] = { Mesh = 99957108703251, Scale = 1 },
	["Sapphire"] = { Mesh = 118255444108074, Scale = 1 },
	["Topaz"] = { Mesh = 92414990957174, Scale = 1 },
} :: { [string]: MeshDef }

-- Props are not collectibles — they are scenery and UI furniture, keyed by a
-- name this codebase chooses rather than one from Crystals.luau. The chest is
-- split into ChestBase and ChestLid so the lid can actually swing.
Meshes.Prop = {
	["ChestBase"] = { Mesh = 73620068125097, Scale = 1 },
	["ChestLid"] = { Mesh = 131543048004444, Scale = 1 },
	["GeodeHalfA"] = { Mesh = 93767624394202, Scale = 0.674 },
	["GeodeHalfB"] = { Mesh = 83706691568376, Scale = 0.674 },
} :: { [string]: MeshDef }

-- World decoration: rocks, spires, arches, landmarks. Not collectibles and not
-- UI — scenery placed by MapBuilder to give each layer a face of its own.
--
-- Absent or unuploaded means the layer simply renders as it always has, on the
-- procedural geometry alone. That is the whole reason decoration lives behind
-- its own table: the map must never depend on an asset that might be in
-- moderation.
Meshes.World = {
	["Amber Cluster"] = { Mesh = 126343695026058, Scale = 1, Size = Vector3.new(3.098, 2.705, 1.872), Floor = -0.1481, Middle = Vector3.new(-0.1581, 1.204, -0.1087), Material = Enum.Material.Neon, Tint = Color3.fromRGB(255, 170, 55) },
	["Amber Pillar"] = { Mesh = 95364474303428, Scale = 1, Size = Vector3.new(1.521, 8.35, 1.56), Floor = 0, Middle = Vector3.new(0.03961, 4.175, 0), Material = Enum.Material.Sandstone, Tint = Color3.fromRGB(160, 110, 54) },
	["Ashen Gate"] = { Mesh = 101535301124921, Scale = 1, Size = Vector3.new(7, 6, 1.6), Floor = 0, Middle = Vector3.new(0, 3, 0), Material = Enum.Material.Slate, Tint = Color3.fromRGB(100, 90, 130) },
	["Basalt Gate"] = { Mesh = 112116585124241, Scale = 1, Size = Vector3.new(7, 7, 1.8), Floor = 0, Middle = Vector3.new(0, 3.5, 0), Material = Enum.Material.Basalt, Tint = Color3.fromRGB(52, 46, 58) },
	["Basalt Spire Cluster"] = { Mesh = 103363314173012, Scale = 1, Size = Vector3.new(3.92, 7, 1.639), Floor = 0, Middle = Vector3.new(-0.04, 3.5, 0.0134), Material = Enum.Material.Basalt, Tint = Color3.fromRGB(48, 42, 50) },
	["Broken Plank Bridge"] = { Mesh = 139633458342809, Scale = 1, Size = Vector3.new(9, 0.5089, 3.36), Floor = -0.2547, Middle = Vector3.new(0, -0.0002209, 0), Material = Enum.Material.WoodPlanks, Tint = Color3.fromRGB(105, 74, 48) },
	["Broken Rift Bridge"] = { Mesh = 119071075207566, Scale = 1, Size = Vector3.new(10, 0.5218, 3.16), Floor = -0.2611, Middle = Vector3.new(0, -0.0002209, 0), Material = Enum.Material.Slate, Tint = Color3.fromRGB(72, 60, 58) },
	["Cave Boulder A"] = { Mesh = 127912618011165, Scale = 1, Size = Vector3.new(4.843, 3.113, 3.886), Floor = -1.58, Middle = Vector3.new(0.06117, -0.02328, -0.1473), Material = Enum.Material.Slate, Tint = Color3.fromRGB(70, 64, 92) },
	["Cave Boulder B"] = { Mesh = 95013049554131, Scale = 1, Size = Vector3.new(3.763, 4.317, 3.401), Floor = -2.042, Middle = Vector3.new(-0.07189, 0.1168, 0.0829), Material = Enum.Material.Rock, Tint = Color3.fromRGB(82, 76, 104) },
	["Cinder Spires"] = { Mesh = 82428337923473, Scale = 1, Size = Vector3.new(3.92, 7, 1.639), Floor = 0, Middle = Vector3.new(-0.04, 3.5, 0.0134), Material = Enum.Material.Slate, Tint = Color3.fromRGB(100, 90, 130) },
	["Cosmic Ring"] = { Mesh = 103698859838027, Scale = 1, Size = Vector3.new(5.24, 3.25, 5.16), Floor = 1.375, Middle = Vector3.new(0, 3, 0), Material = Enum.Material.Neon, Tint = Color3.fromRGB(135, 100, 255) },
	["Crystal Arch"] = { Mesh = 126534106034620, Scale = 1, Size = Vector3.new(7, 7.675, 1.5), Floor = 0, Middle = Vector3.new(0, 3.837, 0), Material = Enum.Material.Slate, Tint = Color3.fromRGB(76, 68, 100) },
	["Drowned Pillar"] = { Mesh = 92819093586376, Scale = 1, Size = Vector3.new(2.1, 8.5, 1.4), Floor = 0, Middle = Vector3.new(0, 4.25, 0), Material = Enum.Material.Slate, Tint = Color3.fromRGB(100, 90, 130) },
	["Ember Crystal Cluster"] = { Mesh = 103227041124452, Scale = 1, Size = Vector3.new(5.632, 4.803, 3.549), Floor = -0.6506, Middle = Vector3.new(-0.03562, 1.751, -0.02806), Material = Enum.Material.Neon, Tint = Color3.fromRGB(255, 95, 35) },
	["Floating Crystal Ring"] = { Mesh = 76527006285935, Scale = 1, Size = Vector3.new(5.24, 3.25, 5.16), Floor = 1.375, Middle = Vector3.new(0, 3, 0), Material = Enum.Material.Neon, Tint = Color3.fromRGB(150, 100, 255) },
	["Frost Boulder"] = { Mesh = 89175754879265, Scale = 1, Size = Vector3.new(5.22, 3.294, 3.833), Floor = -1.756, Middle = Vector3.new(0.01725, -0.1089, -0.03424), Material = Enum.Material.Glacier, Tint = Color3.fromRGB(180, 220, 240) },
	["Frozen Arch"] = { Mesh = 83124592572307, Scale = 1, Size = Vector3.new(6, 6.1, 1.3), Floor = 0, Middle = Vector3.new(0, 3.05, 0), Material = Enum.Material.Ice, Tint = Color3.fromRGB(160, 215, 245) },
	["Frozen Pillar"] = { Mesh = 105738261356824, Scale = 1, Size = Vector3.new(1.3, 7, 1.126), Floor = 0, Middle = Vector3.new(0, 3.5, 0), Material = Enum.Material.Ice, Tint = Color3.fromRGB(190, 235, 255) },
	["Gilded Ruin"] = { Mesh = 84587884048707, Scale = 1, Size = Vector3.new(7, 6, 1.6), Floor = 0, Middle = Vector3.new(0, 3, 0), Material = Enum.Material.Slate, Tint = Color3.fromRGB(100, 90, 130) },
	["Glacier Shards"] = { Mesh = 98096908202393, Scale = 1, Size = Vector3.new(2.8, 5.35, 1.2), Floor = 1.4, Middle = Vector3.new(0, 4.075, 0), Material = Enum.Material.Slate, Tint = Color3.fromRGB(100, 90, 130) },
	["Hero Crystal Cluster"] = { Mesh = 102783224246936, Scale = 1, Size = Vector3.new(6.427, 5.317, 4.35), Floor = -0.6287, Middle = Vector3.new(-0.004441, 2.03, -0.07343), Material = Enum.Material.Neon, Tint = Color3.fromRGB(170, 110, 240) },
	["Hydrothermal Vent"] = { Mesh = 100138343153094, Scale = 1, Size = Vector3.new(2.997, 7.578, 1.967), Floor = -2.5, Middle = Vector3.new(-0.01842, 1.289, -0.2106), Material = Enum.Material.Basalt, Tint = Color3.fromRGB(62, 54, 60) },
	["Ice Crystal Cluster"] = { Mesh = 88179758410571, Scale = 1, Size = Vector3.new(5.252, 5.115, 3.66), Floor = -0.6412, Middle = Vector3.new(-0.02002, 1.917, 0.08115), Material = Enum.Material.Neon, Tint = Color3.fromRGB(130, 220, 255) },
	["Ice Spire Cluster"] = { Mesh = 134333074279344, Scale = 1, Size = Vector3.new(2.8, 5.35, 1.2), Floor = 1.4, Middle = Vector3.new(0, 4.075, 0), Material = Enum.Material.Ice, Tint = Color3.fromRGB(170, 225, 255) },
	["Icicle Ceiling Strip"] = { Mesh = 106194877400856, Scale = 1, Size = Vector3.new(6.475, 2.2, 0.4875), Floor = 0, Middle = Vector3.new(0.01238, 1.1, 0), Material = Enum.Material.Ice, Tint = Color3.fromRGB(185, 230, 255) },
	["Lava Fissure Rock"] = { Mesh = 102170394358533, Scale = 1, Size = Vector3.new(3.62, 2.175, 3.31), Floor = -1.035, Middle = Vector3.new(-0.02157, 0.0527, -0.09014), Material = Enum.Material.Basalt, Tint = Color3.fromRGB(55, 48, 52) },
	["Meteor Chunk A"] = { Mesh = 109052224251768, Scale = 1, Size = Vector3.new(4.469, 3.144, 3.72), Floor = -1.487, Middle = Vector3.new(-0.06904, 0.08506, -0.01387), Material = Enum.Material.Rock, Tint = Color3.fromRGB(66, 58, 84) },
	["Meteor Chunk B"] = { Mesh = 107031374387276, Scale = 1, Size = Vector3.new(4.72, 3.216, 3.778), Floor = -1.579, Middle = Vector3.new(-0.04617, 0.02875, -0.02386), Material = Enum.Material.Rock, Tint = Color3.fromRGB(54, 50, 72) },
	["Mine Boulder"] = { Mesh = 108682528139793, Scale = 1, Size = Vector3.new(4.868, 3.228, 4.116), Floor = -1.625, Middle = Vector3.new(0.009554, -0.01105, -0.1081), Material = Enum.Material.Rock, Tint = Color3.fromRGB(102, 78, 56) },
	["Obsidian Boulder"] = { Mesh = 123318334368423, Scale = 1, Size = Vector3.new(4.811, 2.991, 4.152), Floor = -1.493, Middle = Vector3.new(-0.06991, 0.001947, -0.009769), Material = Enum.Material.Slate, Tint = Color3.fromRGB(100, 90, 130) },
	["Old Mine Support"] = { Mesh = 110057472014097, Scale = 1, Size = Vector3.new(6, 6.025, 0.7), Floor = 0, Middle = Vector3.new(0, 3.013, 0), Material = Enum.Material.Wood, Tint = Color3.fromRGB(112, 84, 58) },
	["Prismatic Core Cluster"] = { Mesh = 105758051499205, Scale = 1, Size = Vector3.new(6.383, 5.536, 4.185), Floor = -0.6749, Middle = Vector3.new(-0.01288, 2.093, -0.08277), Material = Enum.Material.Neon, Tint = Color3.fromRGB(200, 120, 255) },
	["Radiant Cluster"] = { Mesh = 92515924939554, Scale = 1, Size = Vector3.new(5.055, 4.499, 3.51), Floor = -0.6143, Middle = Vector3.new(-0.08319, 1.635, 0.04062), Material = Enum.Material.Slate, Tint = Color3.fromRGB(100, 90, 130) },
	["Ruined Stone Arch"] = { Mesh = 82726266755091, Scale = 1, Size = Vector3.new(7, 6, 1.7), Floor = 0, Middle = Vector3.new(0, 3, 0), Material = Enum.Material.Sandstone, Tint = Color3.fromRGB(130, 96, 64) },
	["Shattered Monolith"] = { Mesh = 137791662333329, Scale = 1, Size = Vector3.new(2.1, 8.5, 1.4), Floor = 0, Middle = Vector3.new(0, 4.25, 0), Material = Enum.Material.Slate, Tint = Color3.fromRGB(100, 90, 130) },
	["Stalagmite Cluster"] = { Mesh = 75181055587609, Scale = 1, Size = Vector3.new(3.6, 5, 1.8), Floor = -2.5, Middle = Vector3.new(0, 0, 0.1), Material = Enum.Material.Rock, Tint = Color3.fromRGB(72, 68, 90) },
	["Star Monolith"] = { Mesh = 84087413567390, Scale = 1, Size = Vector3.new(2.1, 8.5, 1.4), Floor = 0, Middle = Vector3.new(0, 4.25, 0), Material = Enum.Material.Slate, Tint = Color3.fromRGB(55, 48, 88) },
	["Star Pillar"] = { Mesh = 89165921201910, Scale = 1, Size = Vector3.new(2.4, 8.035, 2.364), Floor = 0, Middle = Vector3.new(0, 4.018, 0), Material = Enum.Material.Neon, Tint = Color3.fromRGB(105, 210, 255) },
	["Verdant Crystals"] = { Mesh = 121593256394266, Scale = 1, Size = Vector3.new(5.558, 4.498, 3.365), Floor = -0.6587, Middle = Vector3.new(0.07923, 1.59, 0.05524), Material = Enum.Material.Slate, Tint = Color3.fromRGB(100, 90, 130) },
} :: { [string]: MeshDef }

function Meshes.ForProp(name: string?): MeshDef?
	return if name then Meshes.Prop[name] else nil
end

function Meshes.ForWorld(name: string?): MeshDef?
	return if name then Meshes.World[name] else nil
end

function Meshes.ForCrystal(name: string?): MeshDef?
	return if name then Meshes.Crystal[name] else nil
end

return Meshes
