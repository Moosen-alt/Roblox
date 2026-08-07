--!nocheck
--------------------------------------------------------------------------------
-- PASTE THIS INTO THE STUDIO COMMAND BAR.
--
-- What it does: you insert a pile of models from the Creator Store, select them
-- all in the Explorer, run this, and it prints ready-to-paste rows for
-- src/shared/Config/Meshes.luau — asset id, suggested scale, and a warning for
-- anything that will not work.
--
-- The point is that copying fifteen MeshIds out of the Properties panel by hand,
-- one at a time, and formatting them into Lua is the single most tedious part of
-- this job and the easiest place to fat-finger a digit. A wrong digit renders a
-- blank where a fish should be and looks exactly like a failed upload.
--
--------------------------------------------------------------------------------
-- HOW TO USE
--
--   1. Studio -> View -> Toolbox -> Creator Store. Search for what you need
--      (see MODELS.md for the shopping list) and insert them. They land in
--      Workspace.
--   2. Rename each inserted model to the EXACT species name from
--      Config/Crystals.luau — "Leopard Shark", "Manta Ray", "Anchovy". The name
--      is what this script keys on, and it is what the game looks up.
--      Anything left unnamed still prints, just with a TODO marker.
--   3. Select them all in the Explorer (click the first, shift-click the last).
--   4. View -> Command Bar, paste this whole file, press Enter.
--   5. Copy the printed rows into Config/Meshes.luau, push. CI republishes.
--
-- Nothing here modifies your place. It only reads the selection and prints.
--------------------------------------------------------------------------------

local Selection = game:GetService("Selection")

-- The primitive fish are ~3 studs nose to tail at Scale 1, and MeshBuild sizes
-- meshes against that same baseline. So the Scale we want is whatever makes the
-- imported model about 3 studs on its longest axis.
local TARGET_STUDS = 3

local function assetIdOf(instance: Instance): (number?, string?)
	if instance:IsA("MeshPart") then
		local id = instance.MeshId:match("%d+")
		return if id then tonumber(id) else nil, "MeshPart"
	elseif instance:IsA("SpecialMesh") then
		local id = instance.MeshId:match("%d+")
		return if id then tonumber(id) else nil, "SpecialMesh"
	end
	return nil, nil
end

-- Find the one mesh that matters inside whatever was selected. Creator Store
-- models are often a Model wrapping one MeshPart, sometimes several.
local function findMesh(root: Instance): (number?, string?, number)
	local best, bestKind, bestVolume = nil, nil, 0
	local candidates = if root:IsA("MeshPart") or root:IsA("SpecialMesh")
		then { root }
		else root:GetDescendants()
	for _, item in candidates do
		local id, kind = assetIdOf(item)
		if id then
			-- If a model contains several meshes, the biggest one is almost
			-- always the thing itself and the rest are trim.
			local part = if item:IsA("BasePart") then item else item.Parent
			local size = if part and part:IsA("BasePart") then part.Size else Vector3.one
			local volume = size.X * size.Y * size.Z
			if volume >= bestVolume then
				best, bestKind, bestVolume = id, kind, volume
			end
		end
	end
	return best, bestKind, bestVolume
end

local function longestAxis(instance: Instance): number
	if instance:IsA("Model") then
		local _, size = instance:GetBoundingBox()
		return math.max(size.X, size.Y, size.Z)
	elseif instance:IsA("BasePart") then
		return math.max(instance.Size.X, instance.Size.Y, instance.Size.Z)
	end
	return 0
end

local selection = Selection:Get()
if #selection == 0 then
	warn("[mesh-ids] Nothing selected. Select the inserted models in the Explorer first.")
	return
end

local rows, problems, meshCount = {}, {}, 0
for _, instance in selection do
	local id, kind = findMesh(instance)
	local name = instance.Name

	if not id then
		table.insert(
			problems,
			("  %-28s has no mesh in it. Creator Store models built from plain Parts cannot be used here — pick one whose Explorer shows a MeshPart."):format(
				name
			)
		)
		continue
	end

	meshCount += 1
	local reach = longestAxis(instance)
	-- MeshBuild multiplies TARGET_STUDS by this, so a model already 3 studs long
	-- wants 1.0 and a 30-stud one wants 0.1.
	local scale = if reach > 0 then TARGET_STUDS / reach else 1
	local rounded = math.floor(scale * 100 + 0.5) / 100

	local todo = if name:match("^Model") or name == "" then "  -- TODO rename: this key must match Config/Crystals.luau exactly" else ""
	table.insert(rows, ('\t["%s"] = { Mesh = %d, Scale = %s },%s'):format(name, id, tostring(rounded), todo))

	if kind == "SpecialMesh" then
		table.insert(
			problems,
			("  %-28s is a legacy SpecialMesh. It will work, but check it renders before committing."):format(name)
		)
	end
	if reach == 0 then
		table.insert(problems, ("  %-28s has no size — Scale is a guess. Tune it in game."):format(name))
	end
end

print(("\n[mesh-ids] %d of %d selected items have a usable mesh.\n"):format(meshCount, #selection))
print("-- Paste into src/shared/Config/Meshes.luau, under Meshes.Fish or Meshes.Relic:")
print(table.concat(rows, "\n"))

if #problems > 0 then
	print("\n[mesh-ids] Worth a look:")
	print(table.concat(problems, "\n"))
end

print([[

[mesh-ids] Reminders:
  * Keys must match Config/Crystals.luau EXACTLY, including apostrophes
    ("Ship's Compass") and spaces. CI fails the build on a name that matches
    nothing, so a typo cannot ship — but it also cannot be guessed for you.
  * Scale above is derived from the model's own size and is a starting point.
    Load the game, open the Index, and adjust.
  * If a fish faces the wrong way, add Rotation. The game builds fish nose
    along +X, upright. Blender exports are usually Z-up:
        Rotation = Vector3.new(-90, 0, 0)
    Facing backwards instead:
        Rotation = Vector3.new(0, 180, 0)
  * ONE MESH CAN SERVE SEVERAL SPECIES. Point five shark entries at the same
    asset id with different Scale and the species colours do the rest — see
    MODELS.md, which groups all 33 fish into about 15 meshes.
]])
