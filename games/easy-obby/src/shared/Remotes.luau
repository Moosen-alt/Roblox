--!strict
-- Creates (server) or fetches (client) all RemoteEvents/RemoteFunctions.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EVENTS = {
	"StateSync", -- server -> client: sanitized profile snapshot
	"Notify", -- server -> client: toast messages { Text, Color? }
	"WelcomeReport", -- server -> client on join: offline earnings + streak summary
}

local FUNCTIONS = {
	"Rebirth", -- () -> ok, err
	"BuyTrail", -- (trailName) -> ok, err
	"EquipTrail", -- (trailName | "") -> ok, err
	"TeleportStage", -- (stageIndex) -> ok, err  (VIP)
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

-- Both lookups are by name only, and the `::` casts are compile-time fiction —
-- so a name listed in the wrong registry hands back the wrong class and dies
-- later at `.OnServerEvent`, deep inside a service, with a message that points
-- nowhere near the actual mistake. Check the class here instead, where the name
-- and the expectation are both in view.
local function typedRemote(name: string, className: string): Instance
	local folder = container()
	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing then
			if not existing:IsA(className) then
				error(
					("Remote %q is a %s but was requested as a %s — it is listed in the wrong table in Remotes.luau"):format(
						name,
						existing.ClassName,
						className
					),
					3
				)
			end
			return existing
		end
		local created = Instance.new(className)
		created.Name = name
		created.Parent = folder
		return created
	end
	local remote = folder:WaitForChild(name)
	if not remote:IsA(className) then
		error(("Remote %q is a %s but was requested as a %s"):format(name, remote.ClassName, className), 3)
	end
	return remote
end

function Remotes.Event(name: string): RemoteEvent
	return typedRemote(name, "RemoteEvent") :: RemoteEvent
end

function Remotes.Function(name: string): RemoteFunction
	return typedRemote(name, "RemoteFunction") :: RemoteFunction
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
