--!strict
-- Builds a collectible from an uploaded mesh, in the same shape the primitive
-- builders return: a Model, pivoted at its own centroid, ready to PivotTo.
--
-- The library templates (see server/AssetPreload) are real MeshParts, centred
-- on the world origin with an identity pivot. That makes everything here
-- arithmetic on a known frame: scale to the shared baseline, bake the authored
-- orientation fix into the parts, and hand back a model whose pivot still marks
-- the middle of what you see.

local Meshes = require(script.Parent.Config.Meshes)
local MeshAssets = require(script.Parent.MeshAssets)

local MeshBuild = {}

-- The primitive fish are roughly 3 studs nose to tail at Scale = 1, so a mesh
-- gets sized to match that by default and the config's Scale trims from there.
-- Without a shared baseline every uploaded model would need its scale found by
-- trial and error against a different reference.
local BASE_STUDS = 3

-- KIND names the library shelf. The library is keyed by (kind, name) because
-- two different things may share a name — "Prop/ChestBase" and
-- "World/ChestBase" are allowed to differ — so every caller says which one it
-- means. Required, not defaulted: a wrong guess here returns nil and renders
-- the primitive fallback, which is exactly the invisible failure this seam
-- exists to keep out.
function MeshBuild.Build(
	def: Meshes.MeshDef,
	name: string,
	color: Color3,
	scale: number,
	glow: number?,
	kind: string
): Model?
	local model = MeshAssets.Clone(kind, name)
	-- Not loaded: the caller falls back to its primitive builder, which is the
	-- behaviour this whole seam was designed around.
	if not model then
		return nil
	end
	model.Name = name

	-- Real MeshParts, so the bounding box is the real thing and the model can be
	-- sized against it. This is the part SpecialMesh could never do: its part
	-- stayed 1x1x1 no matter how large the mesh drew.
	local _, size = model:GetBoundingBox()
	local longest = math.max(size.X, size.Y, size.Z)
	if longest > 0 then
		model:ScaleTo((BASE_STUDS * scale * (def.Scale or 1)) / longest)
	end

	-- def.Rotation squares up a model authored on the wrong axes. It has to be
	-- baked into the PARTS — turn them about the pivot, then put the pivot's
	-- orientation back — because callers PivotTo these with their own animation
	-- CFrames, and anything carried on the pivot itself would be overwritten by
	-- the first one.
	local rotation = def.Rotation
	if rotation then
		model:PivotTo(CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z)))
		model.WorldPivot = CFrame.identity
	end

	-- Centroid pivot, matching the primitive builders: callers PivotTo these and
	-- expect the middle of the thing to land where they asked. def.Offset moves
	-- the visible middle off the pivot, for the rare model whose visual centre
	-- is not its bounding-box centre.
	local box = model:GetBoundingBox()
	model:PivotTo(CFrame.new((def.Offset or Vector3.zero) - box.Position))
	model.WorldPivot = CFrame.identity

	-- Anchored/CanCollide/CanQuery were set once on the library template and
	-- clone with it; only appearance is per-use. An untextured model gets tinted
	-- to the species colour so auras still read; a textured one already carries
	-- its own surface.
	local anchor: BasePart? = nil
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			anchor = anchor or part
			local textured = part:IsA("MeshPart") and part.TextureID ~= ""
			if not textured then
				part.Color = color
			end
		end
	end

	if glow and glow > 0 and anchor then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = glow
		light.Brightness = 0.7
		light.Shadows = false
		light.Parent = anchor
	end

	return model
end

return MeshBuild
