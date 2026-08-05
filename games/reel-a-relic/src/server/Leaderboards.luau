--!strict
-- Global leaderboards on physical boards: Top Recrystallizers + Rarest Finds.
-- OrderedDataStore writes on leave and every 2 minutes; boards refresh on a loop.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local FilmMode = require(script.Parent.FilmMode)

local Leaderboards = {}

local ctx: any = nil
local rebirthStore = nil :: OrderedDataStore?
local rarestStore = nil :: OrderedDataStore?
local nameCache: { [number]: string } = {}
local boardRebirths: BasePart? = nil
local boardRarest: BasePart? = nil

local function store(name: string): OrderedDataStore?
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(name)
	end)
	return ok and result or nil
end

function Leaderboards.Save(player: Player, data: any)
	-- A staged film-mode save must not reach the real boards either. The Mock
	-- ProfileStore only isolates the profile; these are separate OrderedDataStores
	-- keyed by the developer's own UserId, and both the periodic loop and the
	-- on-leave save would otherwise publish an endgame score to live players.
	if FilmMode.Active() then
		return
	end
	if rebirthStore and data.Rebirths > 0 then
		pcall(function()
			(rebirthStore :: OrderedDataStore):SetAsync(tostring(player.UserId), data.Rebirths)
		end)
	end
	if rarestStore and data.Stats.RarestValue > 0 then
		pcall(function()
			(rarestStore :: OrderedDataStore):SetAsync(tostring(player.UserId), data.Stats.RarestValue)
		end)
	end
end

local function userName(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local resolved = ok and name or ("User " .. userId)
	nameCache[userId] = resolved
	return resolved
end

local function renderBoard(board: BasePart?, dataStore: OrderedDataStore?, formatValue: (number) -> string)
	if not board or not dataStore then
		return
	end
	local ok, pages = pcall(function()
		return dataStore:GetSortedAsync(false, 15)
	end)
	if not ok then
		return
	end
	local gui = board:FindFirstChild("BoardGui")
	local list = gui and gui:FindFirstChild("List")
	if not list then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local top = (pages :: DataStorePages):GetCurrentPage()
	for rank, entry in top do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, 0, 0, 26)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamBold
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextScaled = true
		row.TextColor3 = rank <= 3 and Color3.fromRGB(255, 210, 90) or Color3.fromRGB(220, 220, 235)
		row.LayoutOrder = rank
		row.Text = ("%d. %s — %s"):format(rank, userName(tonumber(entry.key) or 0), formatValue(entry.value))
		row.Parent = list
	end
end

function Leaderboards.Init(serviceCtx: any, rebirthsBoard: BasePart, rarestBoard: BasePart)
	ctx = serviceCtx
	boardRebirths = rebirthsBoard
	boardRarest = rarestBoard
	rebirthStore = store("LB_Rebirths_v1")
	rarestStore = store("LB_Rarest_v1")

	task.spawn(function()
		while true do
			renderBoard(boardRebirths, rebirthStore, function(value)
				return tostring(value) .. " rebirths"
			end)
			renderBoard(boardRarest, rarestStore, function(value)
				return tostring(value) .. " value"
			end)
			-- periodic saves for long sessions
			for _, player in Players:GetPlayers() do
				local data = ctx.Data.Get(player)
				if data then
					Leaderboards.Save(player, data)
				end
			end
			task.wait(150)
		end
	end)
end

return Leaderboards
