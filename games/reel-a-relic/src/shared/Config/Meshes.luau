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
} :: { [string]: MeshDef }
Meshes.Relic = {} :: { [string]: MeshDef }

-- Props are not collectibles — they are scenery and UI furniture, keyed by a
-- name this codebase chooses rather than one from Crystals.luau. The chest is
-- split into ChestBase and ChestLid so the lid can actually swing.
Meshes.Prop = {} :: { [string]: MeshDef }

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
