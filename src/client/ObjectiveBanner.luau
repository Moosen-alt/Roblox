--!strict
-- Guided objective banner: shows new players exactly what to do next, driven
-- by the server-side onboarding funnel (each step also pays a coin reward).
-- Disappears forever once the loop is learned (first rebirth).
--
-- It lives bottom-left, tucked above the button row rather than across the
-- middle of the screen, and every step can be dismissed with the X. Dismissing
-- is per-step, so the next objective still gets one chance to be seen — a
-- tutorial you cannot turn off is worse than one nobody reads.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local State = require(script.Parent.State)
local UiKit = require(script.Parent.UiKit)

local _ = Shared

local ObjectiveBanner = {}

local STEPS = {
	{ key = "FirstGeode", text = "⛏️ Mine a geode from the glowing wall!" },
	{ key = "FirstCrack", text = "💥 Crack your geode at the Crack Station!" },
	{ key = "FirstRare", text = "💎 Keep cracking — find a Rare crystal!" },
	{ key = "FirstSocket", text = "🔮 Socket a crystal on a Growth Rack!" },
	{ key = "FirstRebirth", text = "✨ Save up coins and Recrystallize!" },
}

function ObjectiveBanner.Init(gui: ScreenGui)
	local dismissed: { [string]: boolean } = {}
	local currentKey: string? = nil

	local banner = UiKit.Create("Frame", {
		Name = "ObjectiveBanner",
		BackgroundColor3 = UiKit.Colors.Bg,
		BackgroundTransparency = 0.25,
		Size = UDim2.fromOffset(346, 34),
		Position = UDim2.new(0, 12, 1, -116),
		Visible = false,
		Parent = gui,
	}) :: Frame
	UiKit.Corner(10).Parent = banner
	UiKit.Stroke(UiKit.Colors.Accent, 1).Parent = banner

	local label = UiKit.Label({
		Text = "",
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(255, 240, 180),
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -42, 1, -10),
		Position = UDim2.fromOffset(10, 5),
		Parent = banner,
	})

	local close = UiKit.Create("TextButton", {
		Text = "✕",
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = UiKit.Colors.TextDim,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.new(1, -28, 0.5, -12),
		Parent = banner,
	}) :: TextButton
	UiKit.Pad(5).Parent = close
	close.Activated:Connect(function()
		if currentKey then
			dismissed[currentKey] = true
		end
		banner.Visible = false
	end)

	State.Changed:Connect(function(state)
		local funnel = state.Funnel or {}
		for _, step in STEPS do
			if not funnel[step.key] then
				currentKey = step.key
				label.Text = step.text
				banner.Visible = not dismissed[step.key]
				return
			end
		end
		currentKey = nil
		banner.Visible = false
	end)
end

return ObjectiveBanner
