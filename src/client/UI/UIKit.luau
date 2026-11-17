--!nonstrict
-- Small UI toolkit: instance creation, styled buttons, windows (one open at a time), toasts,
-- purchase confirmation dialog, progress bars, responsive scaling.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local Theme = require(script.Parent.Theme)
local Effects = require(script.Parent.Effects)

local UIKit = {}

local player = Players.LocalPlayer
local C = Theme.Colors

UIKit.Root = nil :: ScreenGui?
UIKit.Scale = 1

-- Every top-level panel gets its own UIScale (scaling around its AnchorPoint), kept in sync with the
-- screen size. Designed at Theme.ReferenceSize (1100x620) and scaled down for phones / up for big screens.
local autoScaled: { UIScale } = {}
function UIKit.AutoScale(gui: GuiObject): UIScale
	local scale = Instance.new("UIScale")
	scale.Name = "AutoScale"
	scale.Scale = UIKit.Scale
	scale.Parent = gui
	table.insert(autoScaled, scale)
	return scale
end

-- new("Frame", { Size = ..., Parent = ... }, { children })
function UIKit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(inst :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local new = UIKit.new

function UIKit.Corner(radius: number?): UICorner
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function UIKit.Stroke(thickness: number?, color: Color3?, transparency: number?): UIStroke
	return new("UIStroke", { Thickness = thickness or 2, Color = color or C.Stroke, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

function UIKit.TextStroke(thickness: number?): UIStroke
	return new("UIStroke", { Thickness = thickness or 2, Color = C.Stroke })
end

function UIKit.Gradient(top: Color3, bottom: Color3, rotation: number?): UIGradient
	return new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = rotation or 90 })
end

function UIKit.Padding(px: number): UIPadding
	return new("UIPadding", { PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px), PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px) })
end

function UIKit.List(padding: number?, horizontal: boolean?, align: Enum.HorizontalAlignment?): UIListLayout
	return new("UIListLayout", {
		Padding = UDim.new(0, padding or 8),
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Center,
		VerticalAlignment = horizontal and Enum.VerticalAlignment.Center or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function UIKit.Tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

function UIKit.Label(props: { [string]: any }): TextLabel
	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		Font = props.Font or Theme.Font,
		TextColor3 = props.Color or C.Text,
		TextScaled = props.TextScaled ~= false,
		TextSize = props.TextSize or 18,
		Text = props.Text or "",
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		TextXAlignment = props.AlignX or Enum.TextXAlignment.Center,
		TextYAlignment = props.AlignY or Enum.TextYAlignment.Center,
		TextWrapped = true,
		RichText = props.RichText or false,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
		Name = props.Name or "Label",
		Parent = props.Parent,
	})
	if props.Stroke ~= false then
		UIKit.TextStroke(props.StrokeThickness or 1.5).Parent = label
	end
	if props.MaxTextSize then
		new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize, Parent = label })
	end
	return label
end

-- Big, juicy button with press animation and click sound.
function UIKit.Button(props: { [string]: any }): TextButton
	local color: Color3 = props.Color or C.Blue
	local button = new("TextButton", {
		Name = props.Name or "Button",
		AutoButtonColor = false,
		BackgroundColor3 = color,
		Size = props.Size or UDim2.fromOffset(140, 48),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Text = "",
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	UIKit.Corner(props.Radius or 12).Parent = button
	UIKit.Stroke(2.5).Parent = button
	UIKit.Gradient(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)).Parent = button
	local label = UIKit.Label({
		Name = "Text",
		Text = props.Text or "",
		Size = UDim2.new(1, -12, 1, -8),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = button,
		ZIndex = (props.ZIndex or 1) + 1,
		RichText = props.RichText,
		MaxTextSize = props.MaxTextSize or 30,
	})
	local scale = new("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		UIKit.Tween(scale, 0.12, { Scale = 1.05 })
	end)
	button.MouseLeave:Connect(function()
		UIKit.Tween(scale, 0.12, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		UIKit.Tween(scale, 0.07, { Scale = 0.92 })
	end)
	button.MouseButton1Up:Connect(function()
		UIKit.Tween(scale, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	if props.OnClick then
		local debounce = false
		button.Activated:Connect(function()
			if debounce then
				return
			end
			debounce = true
			Effects.Play("Click")
			task.spawn(props.OnClick)
			task.delay(0.15, function()
				debounce = false
			end)
		end)
	end
	return button
end

function UIKit.SetButton(button: TextButton, text: string, color: Color3?)
	local label = button:FindFirstChild("Text") :: TextLabel?
	if label then
		label.Text = text
	end
	if color then
		button.BackgroundColor3 = color
	end
end

-- Horizontal progress bar. Returns the outer frame and a setter.
function UIKit.ProgressBar(props: { [string]: any }): (Frame, (alpha: number, text: string?) -> ())
	local outer = new("Frame", {
		Name = props.Name or "Bar",
		BackgroundColor3 = C.Background,
		Size = props.Size or UDim2.new(1, 0, 0, 20),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	UIKit.Corner(10).Parent = outer
	UIKit.Stroke(2).Parent = outer
	local fill = new("Frame", { Name = "Fill", BackgroundColor3 = props.Color or C.Green, Size = UDim2.fromScale(0, 1), Parent = outer })
	UIKit.Corner(10).Parent = fill
	UIKit.Gradient(Color3.new(1, 1, 1), Color3.fromRGB(180, 180, 180)).Parent = fill
	local label = UIKit.Label({ Text = "", Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = outer, ZIndex = 2, MaxTextSize = 18 })
	local function set(alpha: number, text: string?)
		alpha = math.clamp(alpha, 0, 1)
		UIKit.Tween(fill, 0.25, { Size = UDim2.fromScale(alpha, 1) })
		fill.Visible = alpha > 0.001
		if text then
			label.Text = text
		end
	end
	return outer, set
end

------------------------------------------------------------------------------------------------
-- Windows
------------------------------------------------------------------------------------------------
export type Window = {
	Name: string,
	Frame: Frame,
	Content: Frame,
	IsOpen: boolean,
	OnOpen: (() -> ())?,
	OnClose: (() -> ())?,
}

local windows: { [string]: Window } = {}
local openWindow: Window? = nil
UIKit.WindowOpened = nil :: ((name: string?) -> ())? -- hook for the HUD

function UIKit.CreateWindow(name: string, title: string, color: Color3, size: Vector2?): Window
	local root = UIKit.Root :: ScreenGui
	local s = size or Vector2.new(720, 470)
	local frame = new("Frame", {
		Name = "Window_" .. name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(s.X, s.Y),
		BackgroundColor3 = C.Panel,
		Visible = false,
		ZIndex = 5,
		Parent = root,
	})
	UIKit.Corner(18).Parent = frame
	UIKit.Stroke(4).Parent = frame
	new("UIScale", { Name = "PopScale", Parent = frame })

	local header = new("Frame", { Name = "Header", BackgroundColor3 = color, Size = UDim2.new(1, 0, 0, 58), ZIndex = 6, Parent = frame })
	UIKit.Corner(18).Parent = header
	UIKit.Gradient(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)).Parent = header
	-- square off the bottom corners of the header
	new("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 1, -18), ZIndex = 6, Parent = header },
		{ UIKit.Gradient(Color3.fromRGB(205, 205, 205), Color3.fromRGB(170, 170, 170)) })
	UIKit.Label({ Text = title, Size = UDim2.new(1, -140, 0, 44), Position = UDim2.new(0, 20, 0, 7), AlignX = Enum.TextXAlignment.Left, Parent = header, ZIndex = 7, StrokeThickness = 2.5 })

	local window: Window
	UIKit.Button({
		Name = "Close",
		Text = "✖",
		Color = C.Red,
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.new(1, -54, 0, 6),
		Parent = header,
		ZIndex = 8,
		OnClick = function()
			UIKit.CloseWindow()
		end,
	})

	local content = new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 14, 0, 70),
		Size = UDim2.new(1, -28, 1, -84),
		ZIndex = 6,
		Parent = frame,
	})

	window = { Name = name, Frame = frame, Content = content, IsOpen = false }
	windows[name] = window
	return window
end

function UIKit.OpenWindow(name: string)
	local window = windows[name]
	if not window then
		return
	end
	if openWindow == window then
		UIKit.CloseWindow()
		return
	end
	if openWindow then
		UIKit.CloseWindow(true)
	end
	openWindow = window
	window.IsOpen = true
	window.Frame.Visible = true
	local scale = window.Frame:FindFirstChild("PopScale") :: UIScale
	scale.Scale = 0.6 * UIKit.Scale
	UIKit.Tween(scale, 0.25, { Scale = UIKit.Scale }, Enum.EasingStyle.Back)
	Effects.Play("Whoosh", 1.2)
	if window.OnOpen then
		task.spawn(window.OnOpen)
	end
	if UIKit.WindowOpened then
		UIKit.WindowOpened(name)
	end
end

function UIKit.CloseWindow(instant: boolean?)
	local window = openWindow
	if not window then
		return
	end
	openWindow = nil
	window.IsOpen = false
	if window.OnClose then
		task.spawn(window.OnClose)
	end
	if instant then
		window.Frame.Visible = false
	else
		local scale = window.Frame:FindFirstChild("PopScale") :: UIScale
		UIKit.Tween(scale, 0.12, { Scale = 0.7 * UIKit.Scale })
		task.delay(0.12, function()
			if openWindow ~= window then
				window.Frame.Visible = false
			end
		end)
	end
	if UIKit.WindowOpened then
		UIKit.WindowOpened(nil)
	end
end

function UIKit.IsWindowOpen(name: string): boolean
	return openWindow ~= nil and openWindow.Name == name
end

function UIKit.GetWindow(name: string): Window?
	return windows[name]
end

-- Scrolling grid that grows its canvas automatically.
function UIKit.Grid(parent: Instance, cellSize: Vector2, padding: number?): ScrollingFrame
	local scroll = new("ScrollingFrame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = C.SubText,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 6,
		Parent = parent,
	})
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(cellSize.X, cellSize.Y),
		CellPadding = UDim2.fromOffset(padding or 10, padding or 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroll,
	})
	UIKit.Padding(6).Parent = scroll
	return scroll
end

function UIKit.ClearChildren(parent: Instance, keepClass: { string }?)
	for _, child in parent:GetChildren() do
		local keep = false
		if child:IsA("UIGridStyleLayout") or child:IsA("UIPadding") or child:IsA("UICorner") or child:IsA("UIStroke") then
			keep = true
		end
		if keepClass and table.find(keepClass, child.ClassName) then
			keep = true
		end
		if not keep then
			child:Destroy()
		end
	end
end

------------------------------------------------------------------------------------------------
-- Toasts
------------------------------------------------------------------------------------------------
local toastHolder: Frame
local TOAST_COLORS = { info = C.Blue, success = C.Green, error = C.Red, rare = C.Purple }

function UIKit.Toast(text: string, kind: string?)
	if not toastHolder then
		return
	end
	local color = TOAST_COLORS[kind or "info"] or C.Blue
	local toast = new("Frame", { BackgroundColor3 = color, Size = UDim2.fromOffset(460, 44), ZIndex = 40, Parent = toastHolder })
	UIKit.Corner(14).Parent = toast
	UIKit.Stroke(3).Parent = toast
	UIKit.Gradient(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)).Parent = toast
	UIKit.Label({ Text = text, Size = UDim2.new(1, -20, 1, -8), Position = UDim2.fromOffset(10, 4), Parent = toast, ZIndex = 41, MaxTextSize = 24 })
	local scale = new("UIScale", { Scale = 0.5, Parent = toast })
	UIKit.Tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	if kind == "error" then
		Effects.Play("Error")
	end
	local count = 0
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			count += 1
		end
	end
	if count > 4 then
		for _, child in toastHolder:GetChildren() do
			if child:IsA("Frame") and child ~= toast then
				child:Destroy()
				break
			end
		end
	end
	task.delay(3.2, function()
		if toast.Parent then
			UIKit.Tween(scale, 0.2, { Scale = 0 })
			task.wait(0.21)
			toast:Destroy()
		end
	end)
end

------------------------------------------------------------------------------------------------
-- Confirmation dialog
------------------------------------------------------------------------------------------------
local confirmFrame: Frame
local confirmCallback: (() -> ())? = nil

function UIKit.Confirm(title: string, body: string, confirmText: string, onConfirm: () -> ())
	confirmCallback = onConfirm
	local titleLabel = confirmFrame:FindFirstChild("Title") :: TextLabel
	local bodyLabel = confirmFrame:FindFirstChild("Body") :: TextLabel
	titleLabel.Text = title
	bodyLabel.Text = body
	UIKit.SetButton(confirmFrame:FindFirstChild("Yes") :: TextButton, confirmText)
	confirmFrame.Visible = true
	local scale = confirmFrame:FindFirstChild("PopScale") :: UIScale
	scale.Scale = 0.5 * UIKit.Scale
	UIKit.Tween(scale, 0.22, { Scale = UIKit.Scale }, Enum.EasingStyle.Back)
end

local function buildConfirm(root: ScreenGui)
	confirmFrame = new("Frame", {
		Name = "Confirm",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 230),
		BackgroundColor3 = C.PanelLight,
		Visible = false,
		ZIndex = 60,
		Parent = root,
	})
	UIKit.Corner(18).Parent = confirmFrame
	UIKit.Stroke(4).Parent = confirmFrame
	new("UIScale", { Name = "PopScale", Parent = confirmFrame })
	UIKit.Label({ Name = "Title", Text = "Confirm", Size = UDim2.new(1, -20, 0, 44), Position = UDim2.fromOffset(10, 12), Parent = confirmFrame, ZIndex = 61, StrokeThickness = 2.5 })
	UIKit.Label({ Name = "Body", Text = "", Font = Theme.BodyFont, Size = UDim2.new(1, -40, 0, 80), Position = UDim2.fromOffset(20, 60), Parent = confirmFrame, ZIndex = 61, MaxTextSize = 22 })
	UIKit.Button({ Name = "Yes", Text = "Buy", Color = C.Green, Size = UDim2.fromOffset(170, 54), Position = UDim2.new(0.5, -180, 1, -70), Parent = confirmFrame, ZIndex = 62,
		OnClick = function()
			confirmFrame.Visible = false
			local cb = confirmCallback
			confirmCallback = nil
			if cb then
				cb()
			end
		end })
	UIKit.Button({ Name = "No", Text = "Cancel", Color = C.Red, Size = UDim2.fromOffset(170, 54), Position = UDim2.new(0.5, 10, 1, -70), Parent = confirmFrame, ZIndex = 62,
		OnClick = function()
			confirmFrame.Visible = false
			confirmCallback = nil
		end })
end

------------------------------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------------------------------
function UIKit.Init()
	local root = new("ScreenGui", {
		Name = "FNS_UI",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10,
		Parent = player:WaitForChild("PlayerGui"),
	})
	UIKit.Root = root

	local function rescale()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local inset = GuiService:GetGuiInset()
		local size = camera.ViewportSize - Vector2.new(0, inset.Y)
		local ref = Theme.ReferenceSize
		local scale = math.clamp(math.min(size.X / ref.X, size.Y / ref.Y), 0.5, 1.4)
		UIKit.Scale = scale
		for _, s in autoScaled do
			s.Scale = scale
		end
		for _, window in windows do
			local pop = window.Frame:FindFirstChild("PopScale") :: UIScale?
			if pop then
				pop.Scale = scale
			end
		end
		local pop = confirmFrame and confirmFrame:FindFirstChild("PopScale") :: UIScale?
		if pop then
			pop.Scale = scale
		end
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		rescale()
		if workspace.CurrentCamera then
			workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
		end
	end)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	toastHolder = new("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(460, 260),
		ZIndex = 40,
		Parent = root,
	}, { UIKit.List(6) })
	UIKit.AutoScale(toastHolder)

	buildConfirm(root)
	rescale()
end

return UIKit
