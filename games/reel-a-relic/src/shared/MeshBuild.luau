--!strict
-- Builds a collectible from an uploaded mesh, in the same shape the primitive
-- builders return: a Model, pivoted at its own centroid, ready to PivotTo.
--
-- Uses a Part + SpecialMesh rather than a MeshPart. MeshPart.MeshId cannot be
-- assigned at runtime (you need AssetService:CreateMeshPartAsync, which yields
-- and is awkward on the client), whereas SpecialMesh.MeshId is a plain writable
-- property that works identically on the server, on the client, and inside a
-- ViewportFrame — which is where most of these get drawn.

local Meshes = require(script.Parent.Config.Meshes)
local MeshAssets = require(script.Parent.MeshAssets)

local MeshBuild = {}

-- The primitive fish are roughly 3 studs nose to tail at Scale = 1, so a mesh
-- gets sized to match that by default and the config's Scale trims from there.
-- Without a shared baseline every uploaded model would need its scale found by
-- trial and error against a different reference.
local BASE_STUDS = 3

-- KIND is needed now that models are cloned out of the preloaded library rather
-- than addressed by id: the library is keyed by (kind, name) so two different
-- things may share a name. Defaults to Crystal, which is what every existing
-- caller in this game meant.
function MeshBuild.Build(
	def: Meshes.MeshDef,
	name: string,
	color: Color3,
	scale: number,
	glow: number?,
	kind: string?
): Model?
	local model = MeshAssets.Clone(kind or "Crystal", name)
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

	local rotation = def.Rotation or Vector3.zero
	local box = model:GetBoundingBox()
	model:PivotTo(
		CFrame.new((def.Offset or Vector3.zero) - box.Position)
			* CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
	)

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false -- a cast must never land on a decoration
			part.CanTouch = false
			part.Massless = true
			-- An untextured model gets tinted to the species colour so auras
			-- still read; a textured one already carries its own surface.
			local textured = false
			if part:IsA("MeshPart") then
				textured = part.TextureID ~= ""
			end
			if not textured then
				part.Color = color
			end
		end
	end

	if glow and glow > 0 and model.PrimaryPart then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = glow
		light.Brightness = 0.7
		light.Shadows = false
		light.Parent = model.PrimaryPart
	end

	-- Centroid pivot, matching the primitive builders: callers PivotTo these and
	-- expect the middle of the thing to land where they asked.
	local final = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(final.Position)
	return model
end

return MeshBuild
