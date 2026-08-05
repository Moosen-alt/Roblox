--!strict
-- Creates (server) or fetches (client) all RemoteEvents/RemoteFunctions.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EVENTS = {
	"StateSync", -- server -> client: sanitized profile snapshot
	"ServerEvent", -- server -> client: {Name, EndsAt} or nil when an event starts/ends
	"Notify", -- server -> client: toast messages { Text, Color? }
	"WelcomeReport", -- server -> client on join: offline earnings + streak summary
	"CrackResult", -- server -> client: crystals from a crack (drives the reveal)
	"MineNode", -- client -> server: tapped a deposit node (Tools swallow ClickDetector clicks)
	"MineFx", -- server -> client: per-player mining feedback (damage, cracks, shake)
	"RareFind", -- server -> all clients: someone pulled a Legendary+ (social proof)
	"RebirthFx", -- server -> client: run the Recrystallize ritual
}

local FUNCTIONS = {
	"CrackGeode", -- (count) -> ok, err
	"SellCrystal", -- (crystalId | "all") -> ok, err
	"SocketCrystal", -- (crystalId) -> ok, err
	"UnsocketCrystal", -- (slotIndex) -> ok, err
	"CollectRacks", -- () -> coinsCollected
	"BuyUpgrade", -- ("Pickaxe"|"Backpack"|"RackSlot") -> ok, err
	"Rebirth", -- () -> ok, err
	"GetShopStock", -- () -> stock table (policy-filtered)
	"BuyShopItem", -- (itemIndex) -> ok, err
	"ToggleAutoCrack", -- () -> nowEnabled (pass owners can watch the full reveal again)
}

local Remotes = {}

local function container(): Folder
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder?
		if not folder then
			local newFolder = Instance.new("Folder")
			newFolder.Name = "Remotes"
			newFolder.Parent = ReplicatedStorage
			folder = newFolder
		end
		return folder :: Folder
	end
	return ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Remotes.Event(name: string): RemoteEvent
	local folder = container()
	if RunService:IsServer() then
		local remote = folder:FindFirstChild(name) :: RemoteEvent?
		if not remote then
			local newRemote = Instance.new("RemoteEvent")
			newRemote.Name = name
			newRemote.Parent = folder
			remote = newRemote
		end
		return remote :: RemoteEvent
	end
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.Function(name: string): RemoteFunction
	local folder = container()
	if RunService:IsServer() then
		local remote = folder:FindFirstChild(name) :: RemoteFunction?
		if not remote then
			local newRemote = Instance.new("RemoteFunction")
			newRemote.Name = name
			newRemote.Parent = folder
			remote = newRemote
		end
		return remote :: RemoteFunction
	end
	return folder:WaitForChild(name) :: RemoteFunction
end

function Remotes.Init()
	for _, name in EVENTS do
		Remotes.Event(name)
	end
	for _, name in FUNCTIONS do
		Remotes.Function(name)
	end
end

return Remotes
