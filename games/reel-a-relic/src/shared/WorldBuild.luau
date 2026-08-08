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
local MeshAssets = require(script.Parent.MeshAssets)

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
	-- No entry, or the model is not in the preloaded library — still in
	-- moderation, or not loadable by this experience. The map is expected to
	-- look complete without it, so this is a normal return, not a warning.
	if not def then
		return nil
	end
	local model = MeshAssets.Clone("World", name)
	if not model then
		return nil
	end
	model.Name = name

	-- Real MeshParts, so the extents are measurable at runtime. The generated
	-- Size/Floor from the source OBJ stay as a fallback for anything the library
	-- hands back without a usable box.
	local _, size = model:GetBoundingBox()
	if size.Y <= 0 then
		size = def.Size or Vector3.one
	end

	local k = if place.Span
		then place.Span / math.max(size.X, size.Z, 0.001)
		else place.Height / math.max(size.Y, 0.001)
	k *= (def.Scale or 1)
	model:ScaleTo(k)

	-- Sit it ON the ground. Measured from the scaled model rather than assumed,
	-- which is the whole point of having real parts: the lowest vertex goes
	-- exactly on Position.Y, whether the model was authored grounded, centred,
	-- or below its own origin.
	local box, extents = model:GetBoundingBox()
	local rotation = def.Rotation or Vector3.zero
	local bottom = box.Position.Y - extents.Y * 0.5
	model:PivotTo(
		CFrame.new(
			place.Position.X - box.Position.X,
			place.Position.Y - bottom - (place.Sink or 0),
			place.Position.Z - box.Position.Z
		)
			* box.Rotation
			* CFrame.Angles(0, math.rad((place.Yaw or 0) + rotation.Y), 0)
	)

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			-- Decoration never blocks anything. The procedural geometry beneath
			-- is what players stand on and what casts land on; these are laid
			-- over the top, so a mesh overhanging a dock must not become a wall.
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			part.CastShadow = false
			if place.Transparency then
				part.Transparency = place.Transparency
			end
			local textured = false
			if part:IsA("MeshPart") then
				textured = part.TextureID ~= ""
			end
			local tint = place.Tint or def.Tint
			if tint and not textured then
				part.Color = tint
			end
			local material = place.Material or def.Material
			if material then
				part.Material = material
			end
		end
	end

	if place.Glow and place.Glow > 0 and model.PrimaryPart then
		local light = Instance.new("PointLight")
		light.Color = model.PrimaryPart.Color
		light.Range = place.Glow
		light.Brightness = 0.6
		light.Shadows = false
		light.Parent = model.PrimaryPart
	end

	return model
end

return WorldBuild
