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
	Scale: number?, -- multiplier on the species' normal size (default 1)
	Offset: Vector3?, -- nudge if the model's origin is not its centre
	Rotation: Vector3?, -- degrees, X then Y then Z. See ORIENTATION above.
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
Meshes.Fish = {
	["Anchovy"] = { Mesh = 121171092141963, Scale = 1 },
	["Anglerfish"] = { Mesh = 86978658342639, Scale = 1 },
	["Barreleye"] = { Mesh = 97438542387533, Scale = 1 },
	["Blue Tang"] = { Mesh = 112484093307603, Scale = 1 },
	["Clownfish"] = { Mesh = 133544582733593, Scale = 1 },
	["Colossal Squid"] = { Mesh = 121255622798835, Scale = 1 },
	["Dumbo Octopus"] = { Mesh = 103956427559694, Scale = 1 },
	["Flounder"] = { Mesh = 79460045225568, Scale = 1 },
	["Frilled Shark"] = { Mesh = 78516639977769, Scale = 1 },
	["Garibaldi"] = { Mesh = 80242442828280, Scale = 1 },
	["Giant Isopod"] = { Mesh = 97381183399615, Scale = 1 },
	["Giant Sea Bass"] = { Mesh = 91447580894451, Scale = 1 },
	["Goblin Shark"] = { Mesh = 74063279991811, Scale = 1 },
	["Gulper Eel"] = { Mesh = 108400062799188, Scale = 1 },
	["Hammerhead"] = { Mesh = 107405624201854, Scale = 1 },
	["Hatchetfish"] = { Mesh = 118729921338991, Scale = 1 },
	["Kelp Bass"] = { Mesh = 108881124151455, Scale = 1 },
	["Lanternfish"] = { Mesh = 127693954000676, Scale = 1 },
	["Leopard Shark"] = { Mesh = 110207492074425, Scale = 1 },
	["Lionfish"] = { Mesh = 134873942004405, Scale = 1 },
	["Mackerel"] = { Mesh = 116221983997623, Scale = 1 },
	["Manta Ray"] = { Mesh = 78459337569713, Scale = 1 },
	["Megalodon"] = { Mesh = 112413024335932, Scale = 1 },
	["Moray Eel"] = { Mesh = 91902901790397, Scale = 1 },
	["Oarfish"] = { Mesh = 100572064963067, Scale = 1 },
	["Parrotfish"] = { Mesh = 89971934030485, Scale = 1 },
	["Red Snapper"] = { Mesh = 119602273109627, Scale = 1 },
	["Reef Shark"] = { Mesh = 85816007385693, Scale = 1 },
	["Sailfish"] = { Mesh = 120083050036774, Scale = 1 },
	["Sea Bass"] = { Mesh = 76445943452424, Scale = 1 },
	["Seahorse"] = { Mesh = 107490553351674, Scale = 1 },
	["Sheephead"] = { Mesh = 113110118412598, Scale = 1 },
	["Viperfish"] = { Mesh = 131328733349835, Scale = 1 },
} :: { [string]: MeshDef }
Meshes.Relic = {
	["Abalone Shell"] = { Mesh = 127064647598834, Scale = 1 },
	["Captain's Spyglass"] = { Mesh = 119699815333351, Scale = 1 },
	["Conch Shell"] = { Mesh = 121460576036221, Scale = 1 },
	["Coral Crown"] = { Mesh = 80759227689672, Scale = 1 },
	["Diver's Helmet"] = { Mesh = 115385589063173, Scale = 1 },
	["Galleon Bell"] = { Mesh = 100280888289309, Scale = 1 },
	["Glass Float"] = { Mesh = 103777146803386, Scale = 1 },
	["Golden Astrolabe"] = { Mesh = 120399699987033, Scale = 1 },
	["Hurricane Lamp"] = { Mesh = 103754047244337, Scale = 1 },
	["Mermaid's Mirror"] = { Mesh = 88163239279176, Scale = 1 },
	["Message in a Bottle"] = { Mesh = 125309269255533, Scale = 1 },
	["Oni Mask"] = { Mesh = 104462567041434, Scale = 1 },
	["Pirate Cutlass"] = { Mesh = 137385746525325, Scale = 1 },
	["Poseidon's Trident"] = { Mesh = 129579584333901, Scale = 1 },
	["Rusty Anchor"] = { Mesh = 95776638567257, Scale = 1 },
	["Shell Lei"] = { Mesh = 120336921119198, Scale = 1 },
	["Ship's Compass"] = { Mesh = 139609542054494, Scale = 1 },
	["Sonar Beacon"] = { Mesh = 116890143162461, Scale = 1 },
	["Submersible Porthole"] = { Mesh = 137244813316448, Scale = 1 },
	["Sunken Crown"] = { Mesh = 124258050565359, Scale = 1 },
	["Temple Bell"] = { Mesh = 89482190751483, Scale = 1 },
	["Whale Tooth Pendant"] = { Mesh = 138294552059695, Scale = 1 },
} :: { [string]: MeshDef }

-- Props are not collectibles — they are scenery and UI furniture, keyed by a
-- name this codebase chooses rather than one from Crystals.luau. The chest is
-- split into ChestBase and ChestLid so the lid can actually swing.
Meshes.Prop = {
	["ChestBase"] = { Mesh = 117569798192650, Scale = 1, Rotation = Vector3.new(0, 180, 0) },
	["ChestLid"] = { Mesh = 84305083533626, Scale = 1, Rotation = Vector3.new(0, 180, 0) },
} :: { [string]: MeshDef }

-- World decoration: kelp, coral, buoys, docks, landmarks. Not collectibles and
-- not UI — scenery placed by MapBuilder to give each area a face of its own.
--
-- Absent or unuploaded means the area simply renders as it always has, on the
-- procedural geometry alone. That is the whole reason decoration lives behind
-- its own table: the map must never depend on an asset that might be in
-- moderation.
Meshes.World = {
	["Abyss Crystal Cluster"] = { Mesh = 88464272470792, Scale = 1, Size = Vector3.new(5.079, 4.475, 3.129), Floor = -0.6558, Middle = Vector3.new(-0.2376, 1.582, -0.04301), Material = Enum.Material.Neon, Tint = Color3.fromRGB(150, 255, 235) },
	["Abyss Spires"] = { Mesh = 106471878342245, Scale = 1, Size = Vector3.new(3.92, 7, 1.639), Floor = 0, Middle = Vector3.new(-0.04, 3.5, 0.0134), Material = Enum.Material.Slate, Tint = Color3.fromRGB(48, 45, 62) },
	["Beach Rock A"] = { Mesh = 81070296586096, Scale = 1, Size = Vector3.new(4.248, 2.463, 3.005), Floor = -1.28, Middle = Vector3.new(-0.1075, -0.04811, 0.06888), Material = Enum.Material.Sandstone, Tint = Color3.fromRGB(195, 178, 145) },
	["Biolum Mushroom Cluster"] = { Mesh = 84694811062435, Scale = 1, Size = Vector3.new(3.4, 2.28, 2.65), Floor = 0, Middle = Vector3.new(-0.05, 1.14, -0.275), Material = Enum.Material.Neon, Tint = Color3.fromRGB(140, 100, 255) },
	["Broken Metal Bridge"] = { Mesh = 128488352091109, Scale = 1, Size = Vector3.new(9, 0.515, 3.16), Floor = -0.2577, Middle = Vector3.new(0, -0.0002209, 0), Material = Enum.Material.DiamondPlate, Tint = Color3.fromRGB(82, 84, 98) },
	["Can Buoy"] = { Mesh = 140052778135213, Scale = 1, Size = Vector3.new(1.36, 3.98, 1.36), Floor = 0, Middle = Vector3.new(0, 1.99, 0), Material = Enum.Material.Metal, Tint = Color3.fromRGB(95, 105, 120) },
	["Cold Shore Boulder"] = { Mesh = 108666960364655, Scale = 1, Size = Vector3.new(5.05, 3.049, 4.05), Floor = -1.553, Middle = Vector3.new(-0.06425, -0.02863, 0.06884), Material = Enum.Material.Rock, Tint = Color3.fromRGB(100, 112, 105) },
	["Coral Fan"] = { Mesh = 128638136408548, Scale = 1, Size = Vector3.new(4.204, 4, 0.24), Floor = 0, Middle = Vector3.new(0, 2, 0), Material = Enum.Material.SmoothPlastic, Tint = Color3.fromRGB(255, 145, 220) },
	["Coral Head"] = { Mesh = 99512566685246, Scale = 1, Size = Vector3.new(2.96, 3.496, 1.16), Floor = -0.01628, Middle = Vector3.new(0.1, 1.732, 0.1), Material = Enum.Material.SmoothPlastic, Tint = Color3.fromRGB(255, 125, 150) },
	["Drift Log"] = { Mesh = 126987886164070, Scale = 1, Size = Vector3.new(6.041, 1.579, 1.447), Floor = -0.2192, Middle = Vector3.new(0, 0.5703, 0.1036), Material = Enum.Material.Wood, Tint = Color3.fromRGB(95, 72, 54) },
	["Driftwood"] = { Mesh = 109235365932935, Scale = 1, Size = Vector3.new(6.041, 1.579, 1.447), Floor = -0.2192, Middle = Vector3.new(0, 0.5703, 0.1036), Material = Enum.Material.Wood, Tint = Color3.fromRGB(120, 86, 55) },
	["Hydrothermal Vent Cluster"] = { Mesh = 117311320531873, Scale = 1, Size = Vector3.new(2.997, 7.578, 1.967), Floor = -2.5, Middle = Vector3.new(-0.01842, 1.289, -0.2106), Material = Enum.Material.Basalt, Tint = Color3.fromRGB(70, 65, 76) },
	["Kelp Rock Cluster"] = { Mesh = 112813337741910, Scale = 1, Size = Vector3.new(6.1, 7.987, 3.075), Floor = -0.9725, Middle = Vector3.new(0, 3.021, 0.1388), Material = Enum.Material.Rock, Tint = Color3.fromRGB(90, 105, 92) },
	["Lantern Buoy"] = { Mesh = 78718823998383, Scale = 1, Size = Vector3.new(1.5, 3.5, 1.427), Floor = 0, Middle = Vector3.new(0, 1.75, 0), Material = Enum.Material.Slate, Tint = Color3.fromRGB(190, 90, 255) },
	["Metal Dock Segment"] = { Mesh = 120552368590037, Scale = 1, Size = Vector3.new(6, 3.025, 4), Floor = -2.75, Middle = Vector3.new(0, -1.238, 0), Material = Enum.Material.DiamondPlate, Tint = Color3.fromRGB(80, 82, 96) },
	["Old Wood Dock"] = { Mesh = 88675995301052, Scale = 1, Size = Vector3.new(6, 3.025, 4), Floor = -2.75, Middle = Vector3.new(0, -1.238, 0), Material = Enum.Material.Wood, Tint = Color3.fromRGB(105, 82, 60) },
	["Palm Tree"] = { Mesh = 99925129880846, Scale = 1, Size = Vector3.new(6.5, 6.274, 5.513), Floor = 0, Middle = Vector3.new(0, 3.137, 0), Material = Enum.Material.Grass, Tint = Color3.fromRGB(70, 170, 90) },
	["Pine Tree"] = { Mesh = 99094106242063, Scale = 1, Size = Vector3.new(3.879, 6, 3.939), Floor = 0, Middle = Vector3.new(0.06031, 3, 0), Material = Enum.Material.Grass, Tint = Color3.fromRGB(50, 110, 70) },
	["Reed Patch"] = { Mesh = 135384892593450, Scale = 1, Size = Vector3.new(3.96, 2.9, 0.8585), Floor = 0, Middle = Vector3.new(0.18, 1.45, 0.0005966), Material = Enum.Material.Grass, Tint = Color3.fromRGB(90, 185, 100) },
	["Reef Rock"] = { Mesh = 130942262054159, Scale = 1, Size = Vector3.new(4.374, 2.812, 3.694), Floor = -1.457, Middle = Vector3.new(-0.19, -0.05055, -0.103), Material = Enum.Material.Sandstone, Tint = Color3.fromRGB(215, 168, 155) },
	["Ring Buoy"] = { Mesh = 125963009418615, Scale = 1, Size = Vector3.new(2.48, 2.884, 2.442), Floor = 0.966, Middle = Vector3.new(0, 2.408, 0), Material = Enum.Material.SmoothPlastic, Tint = Color3.fromRGB(255, 180, 55) },
	["Sandstone Dock Segment"] = { Mesh = 88974751177204, Scale = 1, Size = Vector3.new(6, 3.025, 4), Floor = -2.75, Middle = Vector3.new(0, -1.238, 0), Material = Enum.Material.Sandstone, Tint = Color3.fromRGB(220, 170, 145) },
	["Sea Creature Skull"] = { Mesh = 140532906196177, Scale = 1, Size = Vector3.new(2.4, 2.15, 2.07), Floor = 0.1, Middle = Vector3.new(0, 1.175, 0.085), Material = Enum.Material.Sand, Tint = Color3.fromRGB(205, 200, 185) },
	["Sea Urchin"] = { Mesh = 73588658819482, Scale = 1, Size = Vector3.new(2.663, 2.029, 2.666), Floor = 0, Middle = Vector3.new(0, 1.014, 0), Material = Enum.Material.SmoothPlastic, Tint = Color3.fromRGB(120, 70, 170) },
	["Tall Kelp Patch"] = { Mesh = 70758180426613, Scale = 1, Size = Vector3.new(6.1, 7.032, 0.5781), Floor = -0.01797, Middle = Vector3.new(0, 3.498, 0.009067), Material = Enum.Material.Grass, Tint = Color3.fromRGB(60, 150, 90) },
	["Tiki Buoy"] = { Mesh = 71962793843365, Scale = 1, Size = Vector3.new(1.6, 2.55, 1.6), Floor = 0, Middle = Vector3.new(0, 1.275, 0), Material = Enum.Material.Wood, Tint = Color3.fromRGB(155, 95, 60) },
	["Trench Basalt Spires"] = { Mesh = 137027280726629, Scale = 1, Size = Vector3.new(3.92, 7, 1.639), Floor = 0, Middle = Vector3.new(-0.04, 3.5, 0.0134), Material = Enum.Material.Basalt, Tint = Color3.fromRGB(55, 58, 72) },
	["Trench Boulder"] = { Mesh = 90443832869084, Scale = 1, Size = Vector3.new(4.674, 4.017, 4.02), Floor = -1.998, Middle = Vector3.new(0.05768, 0.01001, 0.1135), Material = Enum.Material.Basalt, Tint = Color3.fromRGB(50, 52, 68) },
	["Whale Rib Bones"] = { Mesh = 138869319384204, Scale = 1, Size = Vector3.new(5, 2.884, 2.114), Floor = 0.075, Middle = Vector3.new(0, 1.517, 0.1955), Material = Enum.Material.Sand, Tint = Color3.fromRGB(205, 200, 185) },
	["Wood Dock Segment"] = { Mesh = 118962856470986, Scale = 1, Size = Vector3.new(6, 3.025, 4), Floor = -2.75, Middle = Vector3.new(0, -1.238, 0), Material = Enum.Material.WoodPlanks, Tint = Color3.fromRGB(185, 145, 95) },
} :: { [string]: MeshDef }

function Meshes.ForProp(name: string?): MeshDef?
	return if name then Meshes.Prop[name] else nil
end

function Meshes.ForWorld(name: string?): MeshDef?
	return if name then Meshes.World[name] else nil
end

function Meshes.ForFish(name: string?): MeshDef?
	return if name then Meshes.Fish[name] else nil
end

function Meshes.ForRelic(name: string?): MeshDef?
	return if name then Meshes.Relic[name] else nil
end

return Meshes
