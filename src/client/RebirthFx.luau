--!strict
-- The Recrystallize ritual.
--
-- Rebirth asks a player to delete everything they spent an hour building. A
-- toast is not payment for that. This is: the cave charges up, the screen goes
-- white, and the number that comes back is permanent and bigger than before.
-- Handing over your progress has to FEEL like an upgrade or nobody does it
-- twice — and the second rebirth is where the long retention curve starts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local RevealFx = require(script.Parent.RevealFx)
local UiKit = require(script.Parent.UiKit)
local WorldFx = require(script.Parent.WorldFx)

local RebirthFx = {}

local PINK = Color3.fromRGB(255, 120, 255)
local gui: ScreenGui? = nil
local busy = false

local function ping(parent: Instance, pitch: number, volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	sound.PlaybackSpeed = pitch
	sound.Volume = volume
	sound.Parent = parent
	sound:Play()
	task.delay(2.5, function()
		sound:Destroy()
	end)
end

-- Rings racing outward from the middle of the screen, one per beat.
local function ring(overlay: Frame, delay: number)
	task.delay(delay, function()
		if not overlay.Parent then
			return
		end
		local circle = Instance.new("Frame")
		circle.AnchorPoint = Vector2.new(0.5, 0.5)
		circle.Position = UDim2.fromScale(0.5, 0.5)
		circle.Size = UDim2.fromOffset(40, 40)
		circle.BackgroundTransparency = 1
		circle.Parent = overlay
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = circle
		local stroke = Instance.new("UIStroke")
		stroke.Color = PINK
		stroke.Thickness = 6
		stroke.Transparency = 0.1
		stroke.Parent = circle
		TweenService:Create(circle, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(1200, 1200),
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.9), { Transparency = 1, Thickness = 1 }):Play()
		task.delay(1, function()
			circle:Destroy()
		end)
	end)
end

local function run(payload: { [string]: any })
	local screen = gui
	if not screen or busy then
		return
	end
	busy = true

	local overlay = UiKit.Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		Active = true,
		ZIndex = 30,
		Parent = screen,
	}) :: Frame

	-- Charge-up: three rings, three rising notes, the shake building under it
	for i = 0, 2 do
		ring(overlay, i * 0.28)
		task.delay(i * 0.28, function()
			if overlay.Parent then
				ping(overlay, 0.7 + i * 0.35, 0.5)
				WorldFx.Shake(0.5 + i * 0.5)
			end
		end)
	end

	task.delay(1.05, function()
		if not overlay.Parent then
			return
		end
		-- White-out
		local flash = UiKit.Create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0,
			ZIndex = 31,
			Parent = overlay,
		})
		TweenService:Create(flash, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
		WorldFx.Shake(2.2)
		RevealFx.Fanfare(overlay, 6)
		RevealFx.Confetti(overlay, PINK, 44)
		RevealFx.Sunburst(overlay, UDim2.fromScale(0.5, 0.44), PINK)
		task.delay(0.9, function()
			flash:Destroy()
		end)

		local card = UiKit.Create("Frame", {
			Size = UDim2.fromOffset(0, 0),
			Position = UDim2.fromScale(0.5, 0.44),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = UiKit.Colors.Bg,
			ZIndex = 32,
			Parent = overlay,
		})
		UiKit.Corner(18).Parent = card
		UiKit.Stroke(PINK, 4).Parent = card
		TweenService:Create(card, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(460, 250),
		}):Play()

		local lines = {
			{ Text = "RECRYSTALLIZED", Color = PINK, Font = Enum.Font.FredokaOne, Height = 52 },
			{ Text = "Rebirth #" .. tostring(payload.Rebirths or 1), Color = UiKit.Colors.Text, Font = Enum.Font.GothamBold, Height = 30 },
			{ Text = "Now mining: " .. tostring(payload.LayerName or "the deep"), Color = UiKit.Colors.Good, Font = Enum.Font.GothamBold, Height = 30 },
			{
				Text = ("+%d%% coins — permanently"):format(tonumber(payload.Bonus) or 0),
				Color = UiKit.Colors.Accent,
				Font = Enum.Font.FredokaOne,
				Height = 40,
			},
			{ Text = "Your crystals and collection were kept.", Color = UiKit.Colors.TextDim, Font = Enum.Font.Gotham, Height = 26 },
		}
		local y = 14
		for i, line in lines do
			local label = UiKit.Label({
				Text = line.Text,
				Font = line.Font,
				TextColor3 = line.Color,
				Size = UDim2.new(1, -24, 0, line.Height),
				Position = UDim2.fromOffset(12, y),
				TextTransparency = 1,
				ZIndex = 33,
				Parent = card,
			})
			y += line.Height + 4
			task.delay(0.2 + i * 0.11, function()
				if label.Parent then
					TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
					ping(card, 1.1 + i * 0.18, 0.35)
				end
			end)
		end

		task.delay(4.2, function()
			if overlay.Parent then
				local fade = TweenService:Create(overlay, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
				fade:Play()
				fade.Completed:Wait()
				overlay:Destroy()
			end
			busy = false
		end)
	end)
end

function RebirthFx.Init(screenGui: ScreenGui)
	gui = screenGui
	Remotes.Event("RebirthFx").OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" then
			run(payload)
		end
	end)
end

return RebirthFx
