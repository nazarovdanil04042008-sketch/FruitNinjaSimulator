--!nonstrict
-- Client side of the slicing arena:
--   * fixed Fruit-Ninja style camera looking at the pad's fruit plane
--   * renders objects launched by the server (deterministic arcs synced with the server clock)
--   * swipe detection for mouse (hold + drag) and multi-touch, in screen space
--   * instant local feedback (halves, juice, katana effects, blade trail), server confirms rewards
--   * slicing HUD: hearts, round coins, combo / frenzy banners, leave button, round summary

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage").Shared
local GameConfig = require(Shared.Config.GameConfig)
local Arenas = require(Shared.Config.Arenas)
local Fruits = require(Shared.Config.Fruits)
local Katanas = require(Shared.Config.Katanas)
local Trajectory = require(Shared.Util.Trajectory)
local Format = require(Shared.Util.Format)
local Signal = require(Shared.Util.Signal)
local Net = require(Shared.Util.Net)

local UI = script.Parent.Parent.UI
local UIKit = require(UI.UIKit)
local Theme = require(UI.Theme)
local Effects = require(UI.Effects)
local State = require(script.Parent.State)
local FruitVisuals = require(script.Parent.FruitVisuals)

local SlicingController = {}
SlicingController.Active = false
SlicingController.ActiveChanged = Signal.new() -- (isActive)
SlicingController.IsBlocked = nil :: (() -> boolean)?

local C = Theme.Colors
local new = UIKit.new
local player = Players.LocalPlayer

type FruitObject = {
	Id: number,
	Def: Fruits.FruitDef,
	Launch: Trajectory.Launch,
	T0: number,
	Lifetime: number,
	Visual: FruitVisuals.Visual,
	Sliced: boolean,
	LastCFrame: CFrame,
	ScreenPos: Vector2,
}

local remotes: { [string]: RemoteEvent } = {}
local fruits: { [number]: FruitObject } = {}
local debris: { FruitVisuals.Debris } = {}
local pointers: { [any]: { Last: Vector2, Current: Vector2 } } = {}
local stageCenter = Vector3.zero
local currentArena: string? = nil
local hearts = 0
local roundCoins = 0
local stunUntil = 0
local frenzyUntil = 0
local tokens = 5
local tokensLast = 0
local lastResultCombo = 0
local recentScreen: { [number]: Vector2 } = {} -- where each sliced object was, for reward popups

-- UI
local bladeGui: ScreenGui
local hudGui: ScreenGui
local hudScale: UIScale
local heartsLabel: TextLabel
local coinsLabel: TextLabel
local frenzyLabel: TextLabel
local hintLabel: TextLabel
local flashFrame: Frame
local summary: Frame
local summaryBody: TextLabel
local segmentPool: { Frame } = {}
local poolIndex = 1

local SEGMENTS = 48

------------------------------------------------------------------------------------------------
-- Blade trail (pooled frames)
------------------------------------------------------------------------------------------------
local function drawSegment(a: Vector2, b: Vector2, color: Color3, width: number)
	local frame = segmentPool[poolIndex]
	poolIndex = poolIndex % SEGMENTS + 1
	local delta = b - a
	local length = delta.Magnitude
	local mid = (a + b) / 2
	frame.Position = UDim2.fromOffset(mid.X, mid.Y)
	frame.Size = UDim2.fromOffset(length + width * 0.5, width)
	frame.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 0
	frame.Visible = true
	frame:SetAttribute("Born", os.clock())
end

local function updateTrail()
	local now = os.clock()
	for _, frame in segmentPool do
		if frame.Visible then
			local age = now - (frame:GetAttribute("Born") :: number? or 0)
			if age > 0.16 then
				frame.Visible = false
			else
				frame.BackgroundTransparency = age / 0.16
			end
		end
	end
end

------------------------------------------------------------------------------------------------
-- Objects
------------------------------------------------------------------------------------------------
local function removeFruit(id: number)
	local fruit = fruits[id]
	if fruit then
		FruitVisuals.Destroy(fruit.Visual)
		fruits[id] = nil
	end
end

local function clearAll()
	for id in fruits do
		removeFruit(id)
	end
	for _, d in debris do
		d.Part:Destroy()
	end
	table.clear(debris)
	table.clear(pointers)
	table.clear(recentScreen)
end

local function onSpawn(arenaId: string, padIndex: number, batch: { any })
	if not SlicingController.Active or arenaId ~= currentArena then
		return
	end
	local arena = Arenas.Get(arenaId)
	if not arena then
		return
	end
	stageCenter = Arenas.GetStageCenter(arena, padIndex)
	for _, data in batch do
		local def = Fruits.Get(data.F)
		if def and not fruits[data.Id] then
			local launch: Trajectory.Launch = { X0 = data.X0, Y0 = data.Y0, Z = data.Z, VX = data.VX, VY = data.VY, Spin = data.S }
			fruits[data.Id] = {
				Id = data.Id,
				Def = def,
				Launch = launch,
				T0 = data.T,
				Lifetime = Trajectory.Lifetime(launch),
				Visual = FruitVisuals.Build(def),
				Sliced = false,
				LastCFrame = CFrame.new(stageCenter + Trajectory.Position(launch, 0)),
				ScreenPos = Vector2.zero,
			}
		end
	end
end

local function cameraShake(intensity: number, duration: number)
	local camera = workspace.CurrentCamera
	local start = os.clock()
	local base = camera.CFrame
	task.spawn(function()
		while os.clock() - start < duration and SlicingController.Active do
			local fade = 1 - (os.clock() - start) / duration
			camera.CFrame = base * CFrame.new((math.random() - 0.5) * intensity * fade, (math.random() - 0.5) * intensity * fade, 0)
			RunService.RenderStepped:Wait()
		end
		if SlicingController.Active then
			camera.CFrame = base
		end
	end)
end

local function sliceFruit(fruit: FruitObject, direction: Vector2)
	fruit.Sliced = true
	recentScreen[fruit.Id] = fruit.ScreenPos
	local def = fruit.Def
	local position = fruit.LastCFrame.Position
	local katana = Katanas.Get(State.Profile and State.Profile.EquippedKatana)
	if def.Kind == "Bomb" then
		FruitVisuals.Explosion(position)
		Effects.Play("Bomb")
		stunUntil = os.clock() + GameConfig.BombStunTime
		flashFrame.BackgroundColor3 = C.Red
		flashFrame.BackgroundTransparency = 0.35
		UIKit.Tween(flashFrame, 0.5, { BackgroundTransparency = 1 })
		cameraShake(1.4, 0.4)
	else
		local worldDir = Vector3.new(direction.X, -direction.Y, 0)
		for _, d in FruitVisuals.Halves(def, fruit.LastCFrame, worldDir.Magnitude > 0 and worldDir.Unit or Vector3.new(1, 0, 0)) do
			table.insert(debris, d)
		end
		FruitVisuals.Juice(position, def.Juice, def.Kind == "Egg" and 10 or 16)
		FruitVisuals.KatanaEffect(katana.Effect, position)
		Effects.Play(def.Kind == "Golden" and "Coin" or "Slice", 0.85 + math.random() * 0.35)
		if def.Kind == "Egg" then
			Effects.Play("Hatch", 1.3)
		end
	end
	FruitVisuals.Destroy(fruit.Visual)
end

------------------------------------------------------------------------------------------------
-- Per-frame update
------------------------------------------------------------------------------------------------
local bulkParts: { BasePart } = {}
local bulkCFrames: { CFrame } = {}

local function distanceToSegment(p: Vector2, a: Vector2, b: Vector2): number
	local ab = b - a
	local lengthSq = ab:Dot(ab)
	if lengthSq < 1e-6 then
		return (p - a).Magnitude
	end
	local t = math.clamp((p - a):Dot(ab) / lengthSq, 0, 1)
	return (p - (a + ab * t)).Magnitude
end

local function step(dt: number)
	local now = workspace:GetServerTimeNow()
	local camera = workspace.CurrentCamera
	table.clear(bulkParts)
	table.clear(bulkCFrames)

	-- Move objects
	for id, fruit in fruits do
		local t = now - fruit.T0
		if t > fruit.Lifetime + 0.4 or fruit.Sliced then
			if not fruit.Sliced and t > fruit.Lifetime + 0.4 then
				removeFruit(id)
			elseif fruit.Sliced then
				fruits[id] = nil
			end
			continue
		end
		local local3 = Trajectory.Position(fruit.Launch, math.max(t, 0))
		local spin = fruit.Launch.Spin * math.max(t, 0)
		local cf = CFrame.new(stageCenter + local3) * CFrame.Angles(spin * 0.6, spin, 0)
		fruit.LastCFrame = cf
		for i, part in fruit.Visual.Parts do
			table.insert(bulkParts, part)
			table.insert(bulkCFrames, cf * fruit.Visual.Offsets[i])
		end
	end

	-- Debris halves
	local g = GameConfig.Gravity
	for i = #debris, 1, -1 do
		local d = debris[i]
		d.Age += dt
		if d.Age >= d.Life then
			d.Part:Destroy()
			table.remove(debris, i)
		else
			d.Velocity -= Vector3.new(0, g * dt, 0)
			d.CFrame = (d.CFrame + d.Velocity * dt) * CFrame.Angles(d.Spin.X * dt, d.Spin.Y * dt, d.Spin.Z * dt)
			d.Part.Transparency = math.max(0, (d.Age / d.Life - 0.5) * 2)
			table.insert(bulkParts, d.Part)
			table.insert(bulkCFrames, d.CFrame)
		end
	end
	if #bulkParts > 0 then
		workspace:BulkMoveTo(bulkParts, bulkCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end

	-- Swipes
	local derived = State.Derived
	local katana = Katanas.Get(State.Profile and State.Profile.EquippedKatana)
	local viewport = camera.ViewportSize
	local pixelScale = viewport.Y / 1080
	local focal = (viewport.Y / 2) / math.tan(math.rad(camera.FieldOfView / 2))
	local hitBonus = (derived and derived.HitRadius or 16) * pixelScale
	local sliceRate = derived and derived.SliceRate or 8
	local clock = os.clock()
	tokens = math.min(math.max(5, sliceRate * 0.75), tokens + (clock - tokensLast) * sliceRate)
	tokensLast = clock
	local stunned = clock < stunUntil
	local ids = {}

	for _, pointer in pointers do
		local a, b = pointer.Last, pointer.Current
		local delta = b - a
		if delta.Magnitude >= 3 then
			drawSegment(a, b, stunned and C.Gray or katana.SwipeColor, math.clamp(delta.Magnitude * 0.12, 5, 12) * math.max(pixelScale, 0.6))
			if not stunned then
				for _, fruit in fruits do
					if fruit.Sliced or now < fruit.T0 or tokens < 1 then
						continue
					end
					local screen, onScreen = camera:WorldToScreenPoint(fruit.LastCFrame.Position)
					if not onScreen or screen.Z <= 0 then
						continue
					end
					local center = Vector2.new(screen.X, screen.Y)
					local radius = fruit.Def.Radius * focal / screen.Z + hitBonus
					if distanceToSegment(center, a, b) <= radius then
						fruit.ScreenPos = center
						tokens -= 1
						table.insert(ids, fruit.Id)
						sliceFruit(fruit, delta)
						if fruit.Def.Kind == "Bomb" then
							stunned = true
							break
						end
					end
				end
			end
			pointer.Last = b
		end
	end
	if #ids > 0 then
		remotes.Slice:FireServer(ids)
	end

	updateTrail()

	-- Keep the local character see-through so it never hides the fruit
	local character = player.Character
	if character then
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 0.75
			end
		end
	end

	if frenzyUntil > clock then
		frenzyLabel.Visible = true
		frenzyLabel.Text = string.format("🌟 FRUIT FRENZY %.1fs 🌟", frenzyUntil - clock)
	else
		frenzyLabel.Visible = false
	end
end

------------------------------------------------------------------------------------------------
-- Input
------------------------------------------------------------------------------------------------
local function pointerKey(input: InputObject): any
	if input.UserInputType == Enum.UserInputType.Touch then
		return input
	end
	return "mouse"
end

local function onInputBegan(input: InputObject, processed: boolean)
	if not SlicingController.Active or processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		local position = Vector2.new(input.Position.X, input.Position.Y)
		pointers[pointerKey(input)] = { Last = position, Current = position }
		if hintLabel.Visible then
			UIKit.Tween(hintLabel, 0.5, { TextTransparency = 1 })
			task.delay(0.5, function()
				hintLabel.Visible = false
			end)
		end
	end
end

local function onInputChanged(input: InputObject)
	if not SlicingController.Active then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		local pointer = pointers[pointerKey(input)]
		if pointer then
			pointer.Current = Vector2.new(input.Position.X, input.Position.Y)
		end
	end
end

local function onInputEnded(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		pointers[pointerKey(input)] = nil
	end
end

------------------------------------------------------------------------------------------------
-- Session lifecycle
------------------------------------------------------------------------------------------------
local function setHearts(value: number)
	hearts = value
	local text = ""
	for i = 1, GameConfig.SessionHearts do
		text ..= i <= value and "❤️" or "🖤"
	end
	heartsLabel.Text = text
end

-- Hide the mobile thumbstick / jump button while slicing (the character is frozen anyway),
-- otherwise swipes that start on them are swallowed as GUI input.
local function setTouchControls(enabled: boolean)
	pcall(function()
		GuiService.TouchControlsEnabled = enabled
	end)
end

local function restoreCamera()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	if character then
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 0
			end
		end
	end
end

local function onSessionStarted(arenaId: string, padIndex: number, startHearts: number)
	local arena = Arenas.Get(arenaId)
	if not arena then
		return
	end
	clearAll()
	UIKit.CloseWindow(true)
	summary.Visible = false
	currentArena = arenaId
	stageCenter = Arenas.GetStageCenter(arena, padIndex)
	roundCoins = 0
	stunUntil = 0
	frenzyUntil = 0
	lastResultCombo = 0
	coinsLabel.Text = "🪙 0"
	setHearts(startHearts)
	SlicingController.Active = true
	ProximityPromptService.Enabled = false
	setTouchControls(false)
	hudGui.Enabled = true
	hudScale.Scale = UIKit.Scale
	hintLabel.Visible = true
	hintLabel.TextTransparency = 0
	hintLabel.Text = UserInputService.TouchEnabled and "Swipe across the fruit! Avoid 💣" or "Hold the mouse & drag across the fruit! Avoid 💣"

	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 70
	UIKit.Tween(camera, 0.6, { CFrame = Arenas.GetCameraCFrame(arena, padIndex) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	RunService:UnbindFromRenderStep("FNS_Slicing") -- never bind twice
	RunService:BindToRenderStep("FNS_Slicing", Enum.RenderPriority.Camera.Value + 1, step)
	Effects.Banner("⚔️ " .. arena.DisplayName .. " ⚔️", arena.AccentColor, 1.2, 0.35)
	Effects.Play("Equip")
	SlicingController.ActiveChanged:Fire(true)
end

local function onSessionEnded(data: any)
	if not SlicingController.Active then
		return
	end
	SlicingController.Active = false
	RunService:UnbindFromRenderStep("FNS_Slicing")
	clearAll()
	for _, frame in segmentPool do
		frame.Visible = false
	end
	frenzyLabel.Visible = false
	restoreCamera()
	setTouchControls(true)
	ProximityPromptService.Enabled = true
	SlicingController.ActiveChanged:Fire(false)

	if type(data) == "table" and data.Reason ~= "Switched" then
		summary.Visible = true
		local title = data.Reason == "OutOfHearts" and "💥 Out of hearts!" or "Round complete!"
		summaryBody.Text = string.format("%s\n\n🪙 Coins: %s\n🍉 Objects sliced: %d\n🔥 Best combo: x%d\n🥚 Eggs collected: %d",
			title, Format.Commas(data.Coins or 0), data.Fruits or 0, data.BestCombo or 0, data.Eggs or 0)
		local scale = summary:FindFirstChildOfClass("UIScale") :: UIScale
		scale.Scale = 0.5 * UIKit.Scale
		UIKit.Tween(scale, 0.3, { Scale = UIKit.Scale }, Enum.EasingStyle.Back)
		Effects.Play(data.Reason == "OutOfHearts" and "Error" or "LevelUp")
	else
		hudGui.Enabled = false
	end
end

local function onSliceResult(results: { any }, frenzyRemaining: number)
	local camera = workspace.CurrentCamera
	local bestCombo = 0
	for _, result in results do
		if result.Kind == "Bomb" then
			setHearts(result.Hearts or hearts)
			Effects.Banner("💣 BOOM! -1 ❤️", C.Red, 0.9, 0.4)
			lastResultCombo = 0
		else
			roundCoins += result.Coins or 0
			local screen = recentScreen[result.Id] or camera.ViewportSize / 2
			recentScreen[result.Id] = nil
			if result.Kind == "Egg" then
				Effects.FloatText(screen, result.EggAdded and "🥚 +1 EGG!" or "🥚 Egg slots full!", C.Pink, 40)
			elseif (result.Coins or 0) > 0 then
				Effects.FloatText(screen, "+" .. Format.Short(result.Coins) .. " 🪙", result.Kind == "Golden" and C.Coins or Color3.fromRGB(255, 240, 150), result.Kind == "Golden" and 44 or 30)
			end
			bestCombo = math.max(bestCombo, result.Combo or 0)
		end
	end
	if bestCombo >= 3 and bestCombo > lastResultCombo then
		Effects.Banner("🔥 COMBO x" .. bestCombo .. "!", bestCombo >= 8 and C.Pink or C.Orange, 0.7, 0.22)
		Effects.Play("SliceHeavy", 1 + math.min(bestCombo, 15) * 0.04)
	end
	lastResultCombo = bestCombo
	coinsLabel.Text = "🪙 " .. Format.Commas(roundCoins)
	if frenzyRemaining and frenzyRemaining > 0 then
		local wasFrenzy = frenzyUntil > os.clock()
		frenzyUntil = os.clock() + frenzyRemaining
		if not wasFrenzy then
			Effects.Banner("🌟 FRUIT FRENZY! 🌟", Color3.fromRGB(80, 255, 230), 1.2, 0.3)
		end
	end
end

------------------------------------------------------------------------------------------------
-- Public
------------------------------------------------------------------------------------------------
function SlicingController.RequestStart(arenaId: string)
	if SlicingController.IsBlocked and SlicingController.IsBlocked() then
		UIKit.Toast("Finish your training first!", "error")
		return
	end
	local arena = Arenas.Get(arenaId)
	local profile = State.Profile
	if arena and profile and profile.Level < arena.RequiredLevel then
		UIKit.Toast("🔒 " .. arena.DisplayName .. " unlocks at level " .. arena.RequiredLevel .. "!", "error")
		return
	end
	summary.Visible = false
	remotes.SlicingStart:FireServer(arenaId)
end

function SlicingController.Stop()
	remotes.SlicingStop:FireServer()
end

local function buildUI()
	bladeGui = new("ScreenGui", { Name = "FNS_Blade", ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 15, Parent = player:WaitForChild("PlayerGui") })
	for _ = 1, SEGMENTS do
		local frame = new("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, BackgroundColor3 = Color3.new(1, 1, 1), Parent = bladeGui })
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = frame })
		table.insert(segmentPool, frame)
	end

	hudGui = new("ScreenGui", { Name = "FNS_SliceHUD", ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 12, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
	flashFrame = new("Frame", { BackgroundColor3 = C.Red, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, Parent = hudGui })

	local top = new("Frame", { BackgroundColor3 = C.Panel, BackgroundTransparency = 0.2, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(380, 56), Parent = hudGui })
	hudScale = new("UIScale", { Parent = top })
	UIKit.Corner(16).Parent = top
	UIKit.Stroke(3).Parent = top
	heartsLabel = UIKit.Label({ Text = "", Size = UDim2.fromOffset(150, 40), Position = UDim2.fromOffset(12, 8), Parent = top, Stroke = false })
	coinsLabel = UIKit.Label({ Text = "🪙 0", Color = C.Coins, Size = UDim2.fromOffset(200, 40), Position = UDim2.fromOffset(170, 8), AlignX = Enum.TextXAlignment.Left, Parent = top })

	frenzyLabel = UIKit.Label({ Text = "", Color = Color3.fromRGB(80, 255, 230), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 72), Size = UDim2.fromOffset(420, 40), Parent = hudGui, StrokeThickness = 2.5 })
	frenzyLabel.Visible = false
	hintLabel = UIKit.Label({ Text = "", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -100), Size = UDim2.new(0.7, 0, 0, 40), Parent = hudGui, StrokeThickness = 2.5 })

	local leave = UIKit.Button({ Text = "🚪 Leave", Color = C.Red, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16), Size = UDim2.fromOffset(150, 58), Parent = hudGui,
		OnClick = function()
			SlicingController.Stop()
		end })
	new("UIScale", { Parent = leave })
	-- keep the leave button scaled like the rest of the UI
	task.spawn(function()
		while true do
			(leave:FindFirstChildOfClass("UIScale") :: UIScale).Scale = UIKit.Scale
			task.wait(2)
		end
	end)

	summary = new("Frame", { BackgroundColor3 = C.Panel, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(420, 360), Visible = false, ZIndex = 20, Parent = hudGui })
	new("UIScale", { Parent = summary })
	UIKit.Corner(18).Parent = summary
	UIKit.Stroke(4).Parent = summary
	summaryBody = UIKit.Label({ Text = "", Size = UDim2.new(1, -40, 0, 220), Position = UDim2.fromOffset(20, 20), Parent = summary, ZIndex = 21, MaxTextSize = 26 })
	UIKit.Button({ Text = "🔁 Play Again", Color = C.Green, Size = UDim2.fromOffset(180, 58), Position = UDim2.new(0.5, -190, 1, -80), Parent = summary, ZIndex = 22,
		OnClick = function()
			local arena = currentArena
			summary.Visible = false
			hudGui.Enabled = false
			if arena then
				SlicingController.RequestStart(arena)
			end
		end })
	UIKit.Button({ Text = "Close", Color = C.Gray, Size = UDim2.fromOffset(180, 58), Position = UDim2.new(0.5, 10, 1, -80), Parent = summary, ZIndex = 22,
		OnClick = function()
			summary.Visible = false
			hudGui.Enabled = false
		end })
end

function SlicingController.Init()
	for _, name in { "SlicingStart", "SlicingStop", "Slice", "SpawnObjects", "SliceResult", "SessionStarted", "SessionEnded" } do
		remotes[name] = Net.Event(name)
	end
	buildUI()
	remotes.SpawnObjects.OnClientEvent:Connect(onSpawn)
	remotes.SessionStarted.OnClientEvent:Connect(onSessionStarted)
	remotes.SessionEnded.OnClientEvent:Connect(onSessionEnded)
	remotes.SliceResult.OnClientEvent:Connect(onSliceResult)
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputChanged:Connect(onInputChanged)
	UserInputService.InputEnded:Connect(onInputEnded)
	player.CharacterAdded:Connect(function()
		if SlicingController.Active then
			onSessionEnded(nil)
		end
	end)
end

return SlicingController
