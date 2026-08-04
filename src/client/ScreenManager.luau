--!strict
-- One modal screen open at a time; screens register a panel + optional OnOpen.

local ScreenManager = {}

type Entry = { Panel: Frame, OnOpen: (() -> ())? }

local screens: { [string]: Entry } = {}
local openName: string? = nil

function ScreenManager.Register(name: string, panel: Frame, closeButton: TextButton, onOpen: (() -> ())?)
	screens[name] = { Panel = panel, OnOpen = onOpen }
	closeButton.Activated:Connect(function()
		ScreenManager.Close()
	end)
end

function ScreenManager.Open(name: string)
	local entry = screens[name]
	if not entry then
		return
	end
	for otherName, other in screens do
		other.Panel.Visible = otherName == name
	end
	openName = name
	if entry.OnOpen then
		entry.OnOpen()
	end
end

function ScreenManager.Close()
	for _, entry in screens do
		entry.Panel.Visible = false
	end
	openName = nil
end

function ScreenManager.Toggle(name: string)
	if openName == name then
		ScreenManager.Close()
	else
		ScreenManager.Open(name)
	end
end

function ScreenManager.IsOpen(name: string): boolean
	return openName == name
end

return ScreenManager
