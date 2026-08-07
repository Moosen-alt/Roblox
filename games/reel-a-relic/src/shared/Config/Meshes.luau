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
	Texture: number?, -- optional; omit to tint the mesh with the species colour
	Scale: number?, -- multiplier on the species' normal size (default 1)
	Offset: Vector3?, -- nudge if the model's origin is not its centre
	Rotation: Vector3?, -- degrees, X then Y then Z. See ORIENTATION above.
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
	["ChestBase"] = { Mesh = 117569798192650, Scale = 1 },
	["ChestLid"] = { Mesh = 84305083533626, Scale = 1 },
} :: { [string]: MeshDef }

function Meshes.ForProp(name: string?): MeshDef?
	return if name then Meshes.Prop[name] else nil
end

function Meshes.ForFish(name: string?): MeshDef?
	return if name then Meshes.Fish[name] else nil
end

function Meshes.ForRelic(name: string?): MeshDef?
	return if name then Meshes.Relic[name] else nil
end

return Meshes
