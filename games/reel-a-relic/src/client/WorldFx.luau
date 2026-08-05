--!strict
-- Client-side world juice: relics that turn, buoys that ride the swell, and
-- camera shake for the moments that earn it.
--
-- All of it is local. Nothing here replicates, which is why a dozen bobbing
-- buoys and two turning landmark relics cost the server nothing at all.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local WorldFx = {}

local rng = Random.new()
local shake = 0

-- Shake decays fast and is capped, so a lucky streak gives a lively screen
-- rather than an unplayable one.
function WorldFx.Shake(amount: number)
	shake = math.min(shake + amount, 2.2)
end

-- PVInstance, not Model: this drives relic clusters and single buoys alike.
type Spinner = { Object: PVInstance, Base: CFrame, Speed: number, Bob: number, BobSpeed: number, Phase: number }

local spinners: { Spinner } = {}
local spinnerOf: { [PVInstance]: Spinner } = {}

local function trackSpinner(instance: Instance)
	if not instance:IsA("PVInstance") then
		return
	end
	local object = instance :: PVInstance
	if spinnerOf[object] then
		return
	end
	local spinner: Spinner = {
		Object = object,
		Base = object:GetPivot(),
		Speed = (object:GetAttribute("SpinSpeed") :: number?) or 0.4,
		Bob = (object:GetAttribute("BobHeight") :: number?) or 0,
		BobSpeed = (object:GetAttribute("BobSpeed") :: number?) or 0.6,
		Phase = rng:NextNumber(0, math.pi * 2),
	}
	spinnerOf[object] = spinner
	table.insert(spinners, spinner)
end

local function untrackSpinner(instance: Instance)
	if not instance:IsA("PVInstance") then
		return
	end
	local spinner = spinnerOf[instance :: PVInstance]
	if not spinner then
		return
	end
	spinnerOf[instance :: PVInstance] = nil
	local index = table.find(spinners, spinner)
	if index then
		table.remove(spinners, index)
	end
end

function WorldFx.Init()
	for _, tagged in CollectionService:GetTagged("SpinCrystal") do
		trackSpinner(tagged)
	end
	CollectionService:GetInstanceAddedSignal("SpinCrystal"):Connect(trackSpinner)
	CollectionService:GetInstanceRemovedSignal("SpinCrystal"):Connect(untrackSpinner)

	local clock = 0
	RunService.RenderStepped:Connect(function(dt: number)
		clock += dt
		for _, spinner in spinners do
			if spinner.Object.Parent then
				local lift = spinner.Bob > 0
					and math.sin(clock * spinner.BobSpeed + spinner.Phase) * spinner.Bob
					or 0
				spinner.Object:PivotTo(
					spinner.Base * CFrame.new(0, lift, 0) * CFrame.Angles(0, clock * spinner.Speed * math.pi, 0)
				)
			end
		end
	end)

	-- Shake is applied after the camera script has written its CFrame, or it
	-- gets overwritten the same frame.
	RunService:BindToRenderStep("WorldFxShake", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		if shake <= 0.0005 then
			return
		end
		shake = math.max(shake - dt * 6, 0)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local magnitude = shake * 0.012
		camera.CFrame = camera.CFrame
			* CFrame.Angles(
				rng:NextNumber(-magnitude, magnitude),
				rng:NextNumber(-magnitude, magnitude),
				rng:NextNumber(-magnitude, magnitude)
			)
	end)
end

return WorldFx
