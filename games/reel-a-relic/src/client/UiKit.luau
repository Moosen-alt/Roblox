--!strict
-- Tiny UI toolkit: dark cave theme, gold accents, mobile-first sizing.

local UiKit = {}

UiKit.Colors = {
	Bg = Color3.fromRGB(24, 22, 38),
	BgLight = Color3.fromRGB(36, 33, 56),
	BgLighter = Color3.fromRGB(48, 44, 74),
	Accent = Color3.fromRGB(255, 210, 90),
	Text = Color3.fromRGB(235, 233, 245),
	TextDim = Color3.fromRGB(160, 156, 185),
	Good = Color3.fromRGB(120, 255, 200),
	Bad = Color3.fromRGB(255, 120, 120),
	Buy = Color3.fromRGB(80, 200, 120),
	Robux = Color3.fromRGB(120, 170, 255),
}

function UiKit.Create(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className)
	for key, value in props do
		if key == "Parent" then
			continue
		end
		(instance :: any)[key] = value
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function UiKit.Corner(radius: number?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	return corner
end

function UiKit.Stroke(color: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or UiKit.Colors.BgLighter
	stroke.Thickness = thickness or 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return stroke
end

function UiKit.Pad(pixels: number): UIPadding
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, pixels)
	padding.PaddingBottom = UDim.new(0, pixels)
	padding.PaddingLeft = UDim.new(0, pixels)
	padding.PaddingRight = UDim.new(0, pixels)
	return padding
end

function UiKit.Label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = UiKit.Colors.Text,
		TextScaled = true,
		Size = UDim2.fromScale(1, 1),
	}
	for key, value in props do
		defaults[key] = value
	end
	return UiKit.Create("TextLabel", defaults)
end

function UiKit.Button(props: { [string]: any }): TextButton
	local defaults = {
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(30, 26, 20),
		TextScaled = true,
		BackgroundColor3 = UiKit.Colors.Accent,
		AutoButtonColor = true,
		Size = UDim2.fromOffset(140, 44),
	}
	for key, value in props do
		defaults[key] = value
	end
	local button = UiKit.Create("TextButton", defaults)
	UiKit.Corner(10).Parent = button
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = button
	return button
end

-- Standard modal panel with a title bar and close button. Returns panel + content.
function UiKit.Panel(parent: Instance, title: string, size: UDim2): (Frame, Frame, TextButton)
	local panel = UiKit.Create("Frame", {
		Name = title .. "Panel",
		Size = size,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = UiKit.Colors.Bg,
		Visible = false,
		Parent = parent,
	})
	UiKit.Corner(14).Parent = panel
	UiKit.Stroke(UiKit.Colors.BgLighter, 3).Parent = panel

	UiKit.Label({
		Name = "Title",
		Text = title,
		Font = Enum.Font.FredokaOne,
		TextColor3 = UiKit.Colors.Accent,
		Size = UDim2.new(1, -60, 0, 40),
		Position = UDim2.fromOffset(14, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})

	local close = UiKit.Create("TextButton", {
		Name = "Close",
		Text = "X",
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = UiKit.Colors.Text,
		BackgroundColor3 = UiKit.Colors.Bad,
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.new(1, -44, 0, 8),
		Parent = panel,
	})
	UiKit.Corner(10).Parent = close

	local content = UiKit.Create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -20, 1, -60),
		Position = UDim2.fromOffset(10, 50),
		Parent = panel,
	})
	return panel, content, close
end

function UiKit.Clear(container: Instance)
	for _, child in container:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

return UiKit
