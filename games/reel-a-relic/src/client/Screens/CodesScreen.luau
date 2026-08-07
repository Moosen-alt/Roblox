--!strict
-- The code box. One text field, one button, one line of feedback.
--
-- Kept deliberately plain. A player arriving here has a code in their hand from
-- a video or the group and wants it in the box — anything else on this screen is
-- in the way. The one piece of merchandising is the line telling them where new
-- codes get announced, because that is the entire point of having codes at all.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local ScreenManager = require(script.Parent.Parent.ScreenManager)
local UiKit = require(script.Parent.Parent.UiKit)

local CodesScreen = {}

function CodesScreen.Init(gui: ScreenGui)
	local panel, content, close = UiKit.Panel(gui, "Redeem a Code", UDim2.fromScale(0.46, 0.42))

	UiKit.Label({
		Text = "Type a code below to claim free coins and chests.",
		TextColor3 = UiKit.Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 40),
		Parent = content,
	})

	local box = UiKit.Create("TextBox", {
		Text = "",
		PlaceholderText = "Enter code...",
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = UiKit.Colors.Text,
		BackgroundColor3 = UiKit.Colors.Bg,
		ClearTextOnFocus = false,
		Size = UDim2.new(1, 0, 0, 54),
		Position = UDim2.fromOffset(0, 48),
		Parent = content,
	}) :: TextBox
	UiKit.Corner(10).Parent = box
	UiKit.Pad(10).Parent = box
	UiKit.Stroke(UiKit.Colors.BgLighter, 2).Parent = box

	local feedback = UiKit.Label({
		Text = "",
		Font = Enum.Font.GothamBold,
		TextColor3 = UiKit.Colors.Good,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 46),
		Position = UDim2.fromOffset(0, 170),
		Parent = content,
	}) :: TextLabel

	local button = UiKit.Create("TextButton", {
		Text = "REDEEM",
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(28, 24, 20),
		BackgroundColor3 = UiKit.Colors.Accent,
		Size = UDim2.new(1, 0, 0, 52),
		Position = UDim2.fromOffset(0, 112),
		Parent = content,
	}) :: TextButton
	UiKit.Corner(10).Parent = button
	UiKit.Pad(8).Parent = button

	UiKit.Label({
		Text = "New codes are posted in the group and on our socials — join to get them first!",
		Font = Enum.Font.Gotham,
		TextColor3 = UiKit.Colors.TextDim,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 220),
		Parent = content,
	})

	local busy = false
	local function submit()
		if busy then
			return
		end
		local input = box.Text
		if #input == 0 then
			feedback.TextColor3 = UiKit.Colors.Bad
			feedback.Text = "Type a code first!"
			return
		end
		busy = true
		button.Text = "..."
		-- The server owns every decision here: which codes exist, whether this
		-- one is spent, and what it pays. This only forwards the string.
		local ok, message = Remotes.Function("RedeemCode"):InvokeServer(input)
		busy = false
		button.Text = "REDEEM"
		feedback.TextColor3 = if ok then UiKit.Colors.Good else UiKit.Colors.Bad
		feedback.Text = message or (if ok then "Redeemed!" else "That code didn't work.")
		if ok then
			box.Text = ""
		end
	end

	button.Activated:Connect(submit)
	-- Enter submits too: on a phone the on-screen keyboard's Done key is the
	-- natural thing to press, and making it do nothing feels broken.
	box.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then
			submit()
		end
	end)

	ScreenManager.Register("Codes", panel, close, function()
		feedback.Text = ""
		box.Text = ""
	end)
end

return CodesScreen
