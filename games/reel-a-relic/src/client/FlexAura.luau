--!strict
-- Renders the rarest-find crystal above every player's head. The server just
-- publishes attributes; the crystal, the spin and the nameplate are all built
-- locally, so this is free at any player count.

local Players = game:GetService("Players")

local Crystals = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.Crystals)
local GemView = require(script.Parent.GemView)
local UiKit = require(script.Parent.UiKit)

local FlexAura = {}

local AURA_NAME = "RarestFindAura"
local VISIBLE_RANGE = 110 -- matches the billboard's MaxDistance

-- One shared loop gates every aura, rather than fifteen ViewportFrames each
-- spinning a twenty-part model every frame regardless of whether anyone can see
-- them. GemView skips work while its viewport is hidden, so flipping Visible
-- here is what actually buys the frames back.
local tracked: { [Player]: { Billboard: BillboardGui, Viewport: ViewportFrame, Head: BasePart } } = {}

local function gateVisibility()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local origin = camera.CFrame.Position
	for player, aura in tracked do
		if not aura.Billboard.Parent or not aura.Head.Parent then
			tracked[player] = nil
		else
			local near = (aura.Head.Position - origin).Magnitude <= VISIBLE_RANGE
			aura.Viewport.Visible = near
			aura.Billboard.Enabled = near
		end
	end
end

local function untrack(player: Player)
	tracked[player] = nil
end

local function clear(character: Model)
	local head = character:FindFirstChild("Head")
	local existing = head and head:FindFirstChild(AURA_NAME)
	if existing then
		existing:Destroy()
	end
end

local function build(player: Player, character: Model)
	clear(character)
	untrack(player)
	local base = player:GetAttribute("FlexBase")
	if typeof(base) ~= "string" or base == "" then
		return
	end
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local mutation = player:GetAttribute("FlexMut")
	local tier = player:GetAttribute("FlexTier")
	local color = player:GetAttribute("FlexColor")
	local crystalColor = typeof(color) == "Color3" and color or Color3.fromRGB(255, 210, 90)
	local tierColor = (typeof(tier) == "string" and Crystals.TierColors[tier]) or UiKit.Colors.Accent

	local billboard = Instance.new("BillboardGui")
	billboard.Name = AURA_NAME
	billboard.Size = UDim2.fromScale(4.4, 5)
	billboard.StudsOffset = Vector3.new(0, 3.4, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 110
	billboard.Parent = head

	local gem = GemView.Create({
		Parent = billboard,
		Size = UDim2.fromScale(1, 0.7),
		Position = UDim2.fromScale(0, 0),
		Color = crystalColor,
		Seed = #base * 23 + 5,
		Spin = 0.75,
		ZIndex = 1,
		-- The trophy over your head is whatever your rarest find WAS, and that is
		-- now as likely to be a relic as a fish.
		Name = base,
	})

	tracked[player] = { Billboard = billboard, Viewport = gem, Head = head }

	local prefix = (typeof(mutation) == "string" and mutation ~= "Normal") and (mutation .. " ") or ""
	UiKit.Label({
		Text = prefix .. base,
		Font = Enum.Font.FredokaOne,
		TextColor3 = tierColor,
		TextStrokeTransparency = 0.3,
		Size = UDim2.fromScale(1, 0.26),
		Position = UDim2.fromScale(0, 0.72),
		ZIndex = 2,
		Parent = billboard,
	})
end

local function watch(player: Player)
	local function refresh()
		local character = player.Character
		if character then
			build(player, character)
		end
	end
	player.CharacterAdded:Connect(function(character)
		-- Wait for the Head to exist before parenting the billboard to it
		character:WaitForChild("Head", 10)
		task.wait(0.2)
		build(player, character)
	end)
	player:GetAttributeChangedSignal("FlexBase"):Connect(refresh)
	player:GetAttributeChangedSignal("FlexMut"):Connect(refresh)
	refresh()
end

function FlexAura.Init()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(untrack)
	-- Twice a second is plenty: this only decides whether a decoration spins.
	task.spawn(function()
		while true do
			task.wait(0.5)
			gateVisibility()
		end
	end)
end

return FlexAura
