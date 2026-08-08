--!strict
-- Places a world-decoration mesh so it SITS on the ground at a chosen height.
--
-- Collectibles get MeshBuild: centred in a viewport at a fixed size, where the
-- only thing that matters is that they look right in a box. Scenery is the
-- opposite problem. A spire has to stand on the floor, a boulder has to rest on
-- it, and both have to be a believable size next to a player who is five studs
-- tall. Getting that wrong does not look like a bug, it looks like cheap art.
--
-- The catch is that a SpecialMesh does not tell you how big it draws. The Part
-- stays 1x1x1 whatever Scale is set to, so `GetBoundingBox` reports a one-stud
-- cube for a thirty-stud arch, and anything that positions from it is guessing.
-- That guess is what put the aquarium relics through the table.
--
-- So the extents are not measured at runtime — they are measured from the source
-- OBJ by tools/build-meshes.py and generated into Config/Meshes.luau, and this
-- module does exact arithmetic on them:
--
--     k          = wanted height / the model's own height
--     mesh.Offset = -middle * k         -- recentre a model authored off-origin
--     part.Y      = ground + (middle.Y - floor) * k
--
-- which puts the lowest vertex exactly on the ground, at any height, for a model
-- authored grounded, centred, or sunk below its own origin. All three are in the
-- pack.

local Meshes = require(script.Parent.Config.Meshes)

local WorldBuild = {}

export type Placement = {
	-- HOW BIG, by whichever dimension actually defines the thing.
	--
	-- Height is the right handle for almost everything: a spire, a boulder, a
	-- tree. It is the wrong handle for anything long and low, because scale is
	-- uniform — a bridge nineteen times wider than it is tall, asked to stand
	-- eleven studs, comes out two hundred and ten studs long and spans the whole
	-- cavern. Give those a Span instead and the height follows from it.
	Height: number, -- how tall it should stand, in studs
	Span: number?, -- if set, its LONGEST horizontal dimension instead; wins over Height
	Position: Vector3, -- where its BASE goes; Y is the ground it rests on
	Yaw: number?, -- degrees around Y. Free variety: these read the same all round.
	Sink: number?, -- studs to bury, for things half-swallowed by sand or rock
	Tint: Color3?, -- overrides the pack's colour, e.g. to match an area's palette
	Material: Enum.Material?,
	Glow: number?, -- PointLight range, for the ones that should light the dark
	Transparency: number?,
}

function WorldBuild.Build(name: string, place: Placement): Model?
	local def = Meshes.ForWorld(name)
	-- No entry means the mesh is not uploaded yet — the map is expected to look
	-- complete without it, so this is a normal return and not a warning.
	if not def or not def.Size or def.Size.Y <= 0 then
		return nil
	end
	local size = def.Size :: Vector3
	local middle = def.Middle or Vector3.zero
	local floor = def.Floor or -size.Y * 0.5

	local model = Instance.new("Model")
	model.Name = name

	local k = if place.Span
		then (place.Span / math.max(size.X, size.Z, 0.001)) * (def.Scale or 1)
		else (place.Height / size.Y) * (def.Scale or 1)

	local part = Instance.new("Part")
	part.Name = "Body"
	part.Anchored = true
	-- Decoration never blocks anything. The procedural geometry underneath is
	-- what players stand on and what casts land on; these are laid over the top,
	-- so a mesh that overhangs a dock must not become an invisible wall.
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	-- Sized to what it actually draws, even though the mesh ignores it. Roblox
	-- culls and streams by part size, so a thirty-stud arch on a one-stud part
	-- pops out of existence when you look slightly away from it.
	part.Size = Vector3.new(
		math.max(size.X * k, 0.05),
		math.max(size.Y * k, 0.05),
		math.max(size.Z * k, 0.05)
	)
	part.Color = place.Tint or def.Tint or Color3.fromRGB(160, 160, 160)
	part.Material = place.Material or def.Material or Enum.Material.SmoothPlastic
	part.Transparency = place.Transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	local rotation = def.Rotation or Vector3.zero
	-- Yaw only, by design. These models are authored upright, and the grounding
	-- arithmetic above is vertical — tipping one on its X or Z axis would move
	-- its lowest point somewhere this no longer knows about. Fix a wrong-way-up
	-- model in the source file, not here.
	part.CFrame = CFrame.new(place.Position + Vector3.new(0, (middle.Y - floor) * k - (place.Sink or 0), 0))
		* CFrame.Angles(0, math.rad((place.Yaw or 0) + rotation.Y), 0)

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = "rbxassetid://" .. def.Mesh
	if def.Texture and def.Texture > 0 then
		mesh.TextureId = "rbxassetid://" .. def.Texture
	end
	mesh.Scale = Vector3.new(k, k, k)
	-- Recentre a model whose author did not centre it, so Position means the
	-- middle of the thing rather than the middle of its exporter's idea of one.
	mesh.Offset = middle * -k
	mesh.Parent = part

	if place.Glow and place.Glow > 0 then
		local light = Instance.new("PointLight")
		light.Color = part.Color
		light.Range = place.Glow
		light.Brightness = 0.6
		light.Shadows = false
		light.Parent = part
	end

	part.Parent = model
	model.PrimaryPart = part
	model.WorldPivot = part.CFrame
	return model
end

return WorldBuild
