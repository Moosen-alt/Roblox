--!strict
-- Guided objective banner: shows new players exactly what to do next, driven
-- by the server-side onboarding funnel (each step also pays a coin reward).
-- Disappears forever once the loop is learned (first rebirth).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local State = require(script.Parent.State)
local UiKit = require(script.Parent.UiKit)

local _ = Shared

local ObjectiveBanner = {}

local STEPS = {
	{ key = "FirstGeode", text = "⛏️ Objective: Mine a geode from the glowing wall!" },
	{ key = "FirstCrack", text = "💥 Objective: Crack your geode at the Crack Station!" },
	{ key = "FirstRare", text = "💎 Objective: Keep cracking — find a Rare crystal!" },
	{ key = "FirstSocket", text = "🔮 Objective: Socket a crystal on a Growth Rack!" },
	{ key = "FirstRebirth", text = "✨ Objective: Save up coins and Recrystallize!" },
}

function ObjectiveBanner.Init(gui: ScreenGui)
	local banner = UiKit.Create("TextLabel", {
		Text = "",
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 240, 180),
		BackgroundColor3 = UiKit.Colors.Bg,
		BackgroundTransparency = 0.25,
		Size = UDim2.fromOffset(540, 34),
		Position = UDim2.new(0.5, -270, 0, 284),
		Visible = false,
		Parent = gui,
	}) :: TextLabel
	UiKit.Corner(10).Parent = banner
	UiKit.Pad(6).Parent = banner

	State.Changed:Connect(function(state)
		local funnel = state.Funnel or {}
		for _, step in STEPS do
			if not funnel[step.key] then
				banner.Text = step.text
				banner.Visible = true
				return
			end
		end
		banner.Visible = false
	end)
end

return ObjectiveBanner
