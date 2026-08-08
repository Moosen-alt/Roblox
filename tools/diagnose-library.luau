--!nocheck
-- Runs inside the published place via tools/luau-exec.py. Loads every asset the
-- mesh config names, exactly the way AssetPreload does, and reports what each
-- one actually contains — part counts, names, sizes, whether anything carries a
-- texture. This is the ground truth that screenshots kept having to stand in
-- for: it proves what loads, what fails and why, and what there is to tint,
-- without spending a playtest.

local HttpService = game:GetService("HttpService")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Meshes = require(ReplicatedStorage.Shared.Config.Meshes)

local report = {
	game = game.Name,
	placeId = game.PlaceId,
	loaded = 0,
	attempted = 0,
	failures = {},
	-- Structure detail for the first few of each kind; totals for everything.
	sample = {},
	partCounts = {},
}

local DETAIL_PER_KIND = 3
local BUDGET_SECONDS = 150
local start = os.clock()

for _, kind in { "Fish", "Relic", "Crystal", "Prop", "World" } do
	local group = Meshes[kind]
	if type(group) ~= "table" then
		continue
	end
	local detailed = 0
	for name, def in group do
		if os.clock() - start > BUDGET_SECONDS then
			report.timedOut = true
			break
		end
		report.attempted += 1
		local key = kind .. "/" .. name
		local ok, result = pcall(function()
			return InsertService:LoadAsset(def.Mesh)
		end)
		if not ok then
			table.insert(report.failures, key .. " -> " .. tostring(result))
			continue
		end
		report.loaded += 1
		local parts = {}
		for _, descendant in result:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(parts, {
					name = descendant.Name,
					class = descendant.ClassName,
					size = string.format("%.1f x %.1f x %.1f", descendant.Size.X, descendant.Size.Y, descendant.Size.Z),
					material = descendant.Material.Name,
					textured = descendant:IsA("MeshPart") and descendant.TextureID ~= "" or false,
				})
			end
		end
		report.partCounts[key] = #parts
		if detailed < DETAIL_PER_KIND then
			detailed += 1
			report.sample[key] = parts
		end
		result:Destroy()
	end
end

-- print() truncates long lines; emit the JSON in numbered slices so the runner
-- can stitch them back together.
local blob = HttpService:JSONEncode(report)
local SLICE = 6000
local total = math.ceil(#blob / SLICE)
for index = 1, total do
	print(("JSON[%d/%d]%s"):format(index, total, blob:sub((index - 1) * SLICE + 1, index * SLICE)))
end
