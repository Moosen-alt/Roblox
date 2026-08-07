--!strict
-- Credits. Small, quiet, and genuinely present.
--
-- The CC-BY assets in this game are licensed for commercial use on the single
-- condition that their creators are named, so this screen is what makes that
-- licence apply. It is reached from the Store rather than the main bar — nobody
-- opens a game to read credits — but it is one tap from a button that is always
-- on screen, which is what "reasonable to the medium" means for a game.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Credits = require(Shared.Config.Credits)
local ScreenManager = require(script.Parent.Parent.ScreenManager)
local UiKit = require(script.Parent.Parent.UiKit)

local CreditsScreen = {}

function CreditsScreen.Init(gui: ScreenGui)
	local panel, content, close = UiKit.Panel(gui, "Credits", UDim2.fromScale(0.55, 0.6))

	UiKit.Label({
		Text = "Made with the help of these creators — thank you!",
		TextColor3 = UiKit.Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 30),
		Parent = content,
	})

	local list = UiKit.Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -76),
		Position = UDim2.fromOffset(0, 34),
		Parent = content,
	})
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	for order, entry in Credits.Entries do
		local row = UiKit.Create("Frame", {
			BackgroundColor3 = UiKit.Colors.BgLighter,
			Size = UDim2.new(1, 0, 0, 58),
			LayoutOrder = order,
			Parent = list,
		})
		UiKit.Corner(10).Parent = row
		UiKit.Label({
			Text = entry.Work,
			Font = Enum.Font.GothamBold,
			TextColor3 = UiKit.Colors.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -20, 0, 22),
			Position = UDim2.fromOffset(12, 8),
			Parent = row,
		})
		-- Creator and licence on one line, because the licence is meaningless
		-- without the name and the name is not enough without the licence.
		UiKit.Label({
			Text = ("by %s  •  %s%s"):format(
				entry.Creator,
				entry.License,
				if entry.Source then "  •  " .. entry.Source else ""
			),
			Font = Enum.Font.Gotham,
			TextColor3 = UiKit.Colors.Accent,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -20, 0, 20),
			Position = UDim2.fromOffset(12, 30),
			Parent = row,
		})
	end

	UiKit.Label({
		Text = Credits.Footer,
		Font = Enum.Font.Gotham,
		TextColor3 = UiKit.Colors.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.new(0, 0, 1, -34),
		Parent = content,
	})

	ScreenManager.Register("Credits", panel, close)
end

return CreditsScreen
