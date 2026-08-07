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

local MeshBuild = {}

-- The primitive fish are roughly 3 studs nose to tail at Scale = 1, so a mesh
-- gets sized to match that by default and the config's Scale trims from there.
-- Without a shared baseline every uploaded model would need its scale found by
-- trial and error against a different reference.
local BASE_STUDS = 3

function MeshBuild.Build(def: Meshes.MeshDef, name: string, color: Color3, scale: number, glow: number?): Model
	local model = Instance.new("Model")
	model.Name = name

	local part = Instance.new("Part")
	part.Name = "Body"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false -- a cast must never land on a decoration
	part.CanTouch = false
	part.Massless = true
	part.Size = Vector3.new(1, 1, 1)
	part.Transparency = 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	-- A textured mesh supplies its own colour; an untextured one gets tinted to
	-- the species colour so auras still read.
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic

	local rotation = def.Rotation or Vector3.zero
	part.CFrame = CFrame.new(def.Offset or Vector3.zero)
		* CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = "rbxassetid://" .. def.Mesh
	if def.Texture and def.Texture > 0 then
		mesh.TextureId = "rbxassetid://" .. def.Texture
	end
	local size = BASE_STUDS * scale * (def.Scale or 1)
	mesh.Scale = Vector3.new(size, size, size)
	mesh.Parent = part
	part.Parent = model

	if glow and glow > 0 then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = glow
		light.Brightness = 0.7
		light.Shadows = false
		light.Parent = part
	end

	model.PrimaryPart = part
	-- Centroid pivot, matching the primitive builders: callers PivotTo these and
	-- expect the middle of the thing to land where they asked.
	local box = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(box.Position)
	return model
end

return MeshBuild
