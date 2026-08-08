--!strict
-- Places a world-decoration mesh so it SITS on the ground at a chosen height.
--
-- Collectibles get MeshBuild: centred in a viewport at a fixed size, where the
-- only thing that matters is that they look right in a box. Scenery is the
-- opposite problem. A spire has to stand on the floor, a boulder has to rest on
-- it, and both have to be a believable size next to a player who is five studs
-- tall. Getting that wrong does not look like a bug, it looks like cheap art.
--
-- The library templates (see server/AssetPreload) are real MeshParts, centred
-- on the world origin with an identity pivot, so the model is measured rather
-- than trusted: scale from its live bounding box, then set it down so the box's
-- lowest face lands exactly on Position.Y — whatever the model was authored
-- around. The extents generated into Config/Meshes from the source OBJ remain
-- only as the fallback for a template that comes back unmeasurable.

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

	local _, size = model:GetBoundingBox()
	if size.Y <= 0 then
		size = def.Size or Vector3.one
	end

	local k = if place.Span
		then place.Span / math.max(size.X, size.Z, 0.001)
		else place.Height / math.max(size.Y, 0.001)
	k *= (def.Scale or 1)
	model:ScaleTo(k)

	-- Sit it ON the ground, measured from the scaled model. The pivot is the
	-- origin of a centred template with identity orientation, so PivotTo is
	-- absolute arithmetic: the box keeps its height under a yaw-only turn, and
	-- whatever horizontal drift the template has left turns with the model
	-- instead of smearing it off its spot. The lowest face lands exactly on
	-- Position.Y whether the model was authored grounded, centred, or below its
	-- own origin.
	local box, extents = model:GetBoundingBox()
	local rotation = def.Rotation or Vector3.zero
	local yaw = CFrame.Angles(0, math.rad((place.Yaw or 0) + rotation.Y), 0)
	local drift = yaw:VectorToWorldSpace(Vector3.new(box.Position.X, 0, box.Position.Z))
	model:PivotTo(
		CFrame.new(
			place.Position.X - drift.X,
			place.Position.Y - (place.Sink or 0) + extents.Y * 0.5 - box.Position.Y,
			place.Position.Z - drift.Z
		) * yaw
	)

	-- Anchored/CanCollide/CanQuery were set once on the library template — the
	-- procedural geometry beneath is what players stand on and what casts land
	-- on — and clone with it. What is per-placement is appearance.
	local anchor: BasePart? = nil
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			anchor = anchor or part
			-- Decoration casts no shadows: there are dozens per area, and the
			-- ground already carries the scene's light.
			part.CastShadow = false
			if place.Transparency then
				part.Transparency = place.Transparency
			end
			local textured = part:IsA("MeshPart") and part.TextureID ~= ""
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

	if place.Glow and place.Glow > 0 and anchor then
		local light = Instance.new("PointLight")
		light.Color = anchor.Color
		light.Range = place.Glow
		light.Brightness = 0.6
		light.Shadows = false
		light.Parent = anchor
	end

	return model
end

return WorldBuild
