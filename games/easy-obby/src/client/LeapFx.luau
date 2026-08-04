--!strict
-- MEGA LEAP celebration: when a single sync advances the checkpoint by 3+
-- stages (a big soar or a Skip 10 purchase), slam a scaling banner, speed
-- lines, and confetti on screen. This moment is the game's clip fuel.

local TweenService = game:GetService("TweenService")

local State = require(script.Parent.State)
local UiKit = require(script.Parent.UiKit)

local LeapFx = {}

local gui: ScreenGui? = nil
local lastCheckpoint: number? = nil

local function celebrate(delta: number)
	local parent = gui
	if not parent then
		return
	end
	local rng = Random.new()

	-- Speed lines streaking horizontally
	for _ = 1, 10 do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		local y = rng:NextNumber(0.15, 0.85)
		local fromLeft = rng:NextNumber() < 0.5
		line.Position = UDim2.new(fromLeft and -0.2 or 1.2, 0, y, 0)
		line.Size = UDim2.fromOffset(rng:NextInteger(120, 260), rng:NextInteger(3, 6))
		line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		line.BackgroundTransparency = 0.35
		line.BorderSizePixel = 0
		line.Parent = parent
		TweenService:Create(line, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(fromLeft and 1.3 or -0.3, 0, y, 0),
			BackgroundTransparency = 1,
		}):Play()
		task.delay(0.5, function()
			line:Destroy()
		end)
	end

	-- The banner
	local banner = Instance.new("TextLabel")
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.38)
	banner.Size = UDim2.fromOffset(0, 0)
	banner.BackgroundTransparency = 1
	banner.Font = Enum.Font.FredokaOne
	banner.Text = ("MEGA LEAP!  +%d"):format(delta)
	banner.TextColor3 = UiKit.Colors.Accent
	banner.TextStrokeColor3 = Color3.fromRGB(40, 30, 10)
	banner.TextStrokeTransparency = 0.2
	banner.TextScaled = true
	banner.Rotation = -6
	banner.Parent = parent
	local slam = TweenService:Create(banner, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(460, 90),
	})
	slam:Play()
	slam.Completed:Once(function()
		task.wait(0.9)
		local fade = TweenService:Create(banner, TweenInfo.new(0.35), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.3),
		})
		fade:Play()
		fade.Completed:Once(function()
			banner:Destroy()
		end)
	end)

	-- Confetti scaled to the leap
	local palette = { UiKit.Colors.Accent, Color3.fromRGB(120, 255, 200), Color3.fromRGB(255, 150, 220), Color3.fromRGB(120, 200, 255) }
	for _ = 1, math.min(10 + delta * 2, 34) do
		local piece = Instance.new("Frame")
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = UDim2.new(rng:NextNumber(0.2, 0.8), 0, 0, -20)
		piece.Size = UDim2.fromOffset(rng:NextInteger(6, 11), rng:NextInteger(6, 11))
		piece.Rotation = rng:NextInteger(0, 179)
		piece.BackgroundColor3 = palette[rng:NextInteger(1, #palette)]
		piece.BorderSizePixel = 0
		piece.Parent = parent
		TweenService:Create(piece, TweenInfo.new(rng:NextNumber(1.0, 1.7), Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(piece.Position.X.Scale + rng:NextNumber(-0.08, 0.08), 0, 1.1, 0),
			Rotation = piece.Rotation + rng:NextInteger(-360, 360),
		}):Play()
		task.delay(1.8, function()
			piece:Destroy()
		end)
	end
end

function LeapFx.Init(screenGui: ScreenGui)
	gui = screenGui
	State.Changed:Connect(function(state)
		local checkpoint = state.Checkpoint
		if lastCheckpoint ~= nil and checkpoint > lastCheckpoint then
			local delta = checkpoint - lastCheckpoint
			if delta >= 3 then
				celebrate(delta)
			end
		end
		lastCheckpoint = checkpoint
	end)
end

return LeapFx
