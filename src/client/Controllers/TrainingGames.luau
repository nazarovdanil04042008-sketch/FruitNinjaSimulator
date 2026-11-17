--!nonstrict
-- Interactive training mini-games (mouse, touch and keyboard friendly).
--   Speed    - Arrow Rush   : press the shown direction (red arrows = press the OPPOSITE)
--   Strength - Power Lift   : stop the moving needle inside the green zone
--   Agility  - Reflex       : tap targets before they vanish, avoid red decoys
--   Katana   - Dummy Slice  : swipe through flying dummies, avoid bombs
--   Special  - Gauntlet     : reflex targets + bombs + arrow prompts, faster
-- The server issues a token on start and validates time + score on finish (see TrainingService).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Training = require(Shared.Config.Training)
local Signal = require(Shared.Util.Signal)

local UI = script.Parent.Parent.UI
local UIKit = require(UI.UIKit)
local Theme = require(UI.Theme)
local Effects = require(UI.Effects)
local State = require(script.Parent.State)

local TrainingGames = {}
TrainingGames.Finished = Signal.new() -- (activityId, cooldown)
TrainingGames.ActiveChanged = Signal.new() -- (isActive)
TrainingGames.Active = false
TrainingGames.IsBlocked = nil :: (() -> boolean)? -- set by Main (e.g. while slicing)
TrainingGames._cleanup = nil :: (() -> ())?

local C = Theme.Colors
local new = UIKit.new
local player = Players.LocalPlayer

local AREA_SIZE = Vector2.new(600, 250)
local ACTION_NAME = "FNS_TrainingInput"

local gui: ScreenGui
local dim: Frame
local panel: Frame
local panelScale: UIScale
local titleLabel: TextLabel
local howToLabel: TextLabel
local scoreLabel: TextLabel
local setTimer: (number, string?) -> ()
local area: Frame
local bottom: Frame
local resultFrame: Frame
local resultTitle: TextLabel
local resultBody: TextLabel
local againButton: TextButton
local currentActivity: string? = nil
local cancelled = false

type Context = {
	Area: Frame,
	Bottom: Frame,
	Difficulty: number,
	Score: number,
	Time: number,
	AddScore: (self: Context, amount: number, at: Vector2?) -> (),
	OnKey: ((key: string) -> ())?,
	OnPress: (() -> ())?,
}

------------------------------------------------------------------------------------------------
-- Shared helpers
------------------------------------------------------------------------------------------------
local function popText(parent: GuiObject, position: Vector2, text: string, color: Color3)
	local label = UIKit.Label({ Text = text, Color = color, Size = UDim2.fromOffset(140, 34), Position = UDim2.fromOffset(position.X, position.Y), AnchorPoint = Vector2.new(0.5, 0.5), Parent = parent, ZIndex = 30, StrokeThickness = 2 })
	UIKit.Tween(label, 0.6, { Position = UDim2.fromOffset(position.X, position.Y - 40), TextTransparency = 1 })
	task.delay(0.6, function()
		label:Destroy()
	end)
end

local function flash(color: Color3)
	area.BackgroundColor3 = color
	UIKit.Tween(area, 0.3, { BackgroundColor3 = C.Background })
end

local function arrowButtons(ctx: Context, onDirection: (string) -> ())
	local dirs = { { "Left", "⬅️" }, { "Up", "⬆️" }, { "Down", "⬇️" }, { "Right", "➡️" } }
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 21, Parent = ctx.Bottom })
	UIKit.List(14, true).Parent = holder
	for i, entry in dirs do
		local b = UIKit.Button({ Text = entry[2], Color = C.Blue, Size = UDim2.fromOffset(110, 70), LayoutOrder = i, Parent = holder, ZIndex = 22, MaxTextSize = 40 })
		b.Activated:Connect(function()
			onDirection(entry[1])
		end)
	end
	ctx.OnKey = function(key)
		onDirection(key)
	end
end

local ARROWS = { Up = "⬆️", Down = "⬇️", Left = "⬅️", Right = "➡️" }
local OPPOSITE = { Up = "Down", Down = "Up", Left = "Right", Right = "Left" }
local DIR_LIST = { "Up", "Down", "Left", "Right" }

-- Spawns tappable targets inside the area (used by Agility and Special).
local function makeTargetSpawner(ctx: Context, interval: number, lifetime: number, decoyChance: number, size: number)
	local nextSpawn = 0
	local targets: { { Button: TextButton, Expires: number, Born: number } } = {}
	local function spawn(t: number)
		local decoy = math.random() < decoyChance
		local x = math.random(size, AREA_SIZE.X - size)
		local y = math.random(size, AREA_SIZE.Y - size)
		local button = new("TextButton", {
			Text = decoy and "❌" or "🎯",
			TextScaled = true,
			Font = Theme.Font,
			AutoButtonColor = false,
			BackgroundColor3 = decoy and C.Red or C.Green,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(size, size),
			ZIndex = 25,
			Parent = ctx.Area,
		})
		UIKit.Corner(size // 2).Parent = button
		UIKit.Stroke(3, Color3.new(1, 1, 1)).Parent = button
		local scale = new("UIScale", { Scale = 0, Parent = button })
		UIKit.Tween(scale, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
		local entry = { Button = button, Expires = t + lifetime, Born = t }
		table.insert(targets, entry)
		button.Activated:Connect(function()
			if not button.Parent then
				return
			end
			if decoy then
				ctx:AddScore(-1, Vector2.new(x, y))
				flash(C.Red)
				Effects.Play("Error")
			else
				ctx:AddScore(1, Vector2.new(x, y))
				Effects.Play("Click", 1 + math.min(ctx.Score, 30) * 0.02)
			end
			button:Destroy()
		end)
	end
	return function(t: number)
		if t >= nextSpawn then
			nextSpawn = t + interval * (0.8 + math.random() * 0.4)
			spawn(t)
		end
		for i = #targets, 1, -1 do
			local entry = targets[i]
			if not entry.Button.Parent then
				table.remove(targets, i)
			elseif t >= entry.Expires then
				entry.Button:Destroy()
				table.remove(targets, i)
			else
				local life = (t - entry.Born) / (entry.Expires - entry.Born)
				entry.Button.BackgroundTransparency = life * 0.6
			end
		end
	end
end

------------------------------------------------------------------------------------------------
-- Games: each returns an update(dt, t) function. UI they create inside Area/Bottom is cleared afterwards.
------------------------------------------------------------------------------------------------
local Games: { [string]: (ctx: Context) -> (number, number) -> () } = {}

Games.Speed = function(ctx)
	local arrowLabel = UIKit.Label({ Text = "", Size = UDim2.fromOffset(160, 160), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = ctx.Area, ZIndex = 22, Stroke = false })
	local hint = UIKit.Label({ Text = "", Color = C.Red, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 1, -36), Parent = ctx.Area, ZIndex = 22 })
	local expected = "Up"
	local frozenUntil = 0
	local function nextArrow()
		local shown = DIR_LIST[math.random(1, 4)]
		local reversed = ctx.Difficulty > 0.15 and math.random() < 0.15 + ctx.Difficulty * 0.45
		expected = reversed and OPPOSITE[shown] or shown
		arrowLabel.Text = ARROWS[shown]
		arrowLabel.TextColor3 = reversed and C.Red or C.Text
		hint.Text = reversed and "OPPOSITE!" or ""
		local scale = arrowLabel:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = arrowLabel })
		scale.Scale = 0.6
		UIKit.Tween(scale, 0.1, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	nextArrow()
	arrowButtons(ctx, function(direction)
		if os.clock() < frozenUntil then
			return
		end
		if direction == expected then
			ctx:AddScore(1)
			Effects.Play("Click", 1 + math.min(ctx.Score, 40) * 0.015)
			nextArrow()
		else
			ctx:AddScore(-1)
			frozenUntil = os.clock() + 0.4
			flash(C.Red)
			Effects.Play("Error")
		end
	end)
	return function() end
end

Games.Strength = function(ctx)
	local barWidth = 520
	local bar = new("Frame", { BackgroundColor3 = C.PanelLight, Size = UDim2.fromOffset(barWidth, 46), Position = UDim2.new(0.5, 0, 0.62, 0), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 22, Parent = ctx.Area })
	UIKit.Corner(12).Parent = bar
	UIKit.Stroke(3).Parent = bar
	local zone = new("Frame", { BackgroundColor3 = C.Green, Size = UDim2.new(0.2, 0, 1, 0), ZIndex = 23, Parent = bar })
	UIKit.Corner(8).Parent = zone
	local perfect = new("Frame", { BackgroundColor3 = C.Coins, Size = UDim2.new(0.25, 0, 1, 0), Position = UDim2.fromScale(0.375, 0), ZIndex = 24, Parent = zone })
	UIKit.Corner(8).Parent = perfect
	local needle = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(0, 8, 1, 16), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), ZIndex = 26, Parent = bar })
	UIKit.Corner(4).Parent = needle
	UIKit.Stroke(2).Parent = needle
	local weight = UIKit.Label({ Text = "🏋️", Size = UDim2.fromOffset(90, 90), Position = UDim2.new(0.5, 0, 0.22, 0), AnchorPoint = Vector2.new(0.5, 0.5), Parent = ctx.Area, ZIndex = 22, Stroke = false })

	local reps = 0
	local phase = 0
	local zoneStart, zoneWidth = 0.4, 0.2
	local frozenUntil = 0
	local position = 0
	local function newZone()
		zoneWidth = math.max(0.09, 0.24 - ctx.Difficulty * 0.1 - reps * 0.008)
		zoneStart = 0.05 + math.random() * (0.9 - zoneWidth)
		zone.Position = UDim2.fromScale(zoneStart, 0)
		zone.Size = UDim2.fromScale(zoneWidth, 1)
	end
	newZone()
	local function press()
		if os.clock() < frozenUntil then
			return
		end
		if position >= zoneStart and position <= zoneStart + zoneWidth then
			local center = zoneStart + zoneWidth / 2
			local isPerfect = math.abs(position - center) <= zoneWidth * 0.125
			reps += 1
			ctx:AddScore(isPerfect and 2 or 1, Vector2.new(AREA_SIZE.X / 2, 60))
			Effects.Play("SliceHeavy", 0.8 + math.min(reps, 20) * 0.03)
			weight.Position = UDim2.new(0.5, 0, 0.12, 0)
			UIKit.Tween(weight, 0.25, { Position = UDim2.new(0.5, 0, 0.22, 0) }, Enum.EasingStyle.Bounce)
			if isPerfect then
				popText(ctx.Area, Vector2.new(AREA_SIZE.X / 2, 110), "PERFECT!", C.Coins)
			end
			newZone()
		else
			frozenUntil = os.clock() + 0.5
			flash(C.Red)
			popText(ctx.Area, Vector2.new(AREA_SIZE.X / 2, 110), "MISS", C.Red)
			Effects.Play("Error")
		end
	end
	local liftButton = UIKit.Button({ Text = "💪 LIFT!", Color = C.Red, Size = UDim2.fromOffset(300, 70), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = ctx.Bottom, ZIndex = 22, MaxTextSize = 36 })
	liftButton.Activated:Connect(press)
	ctx.OnPress = press
	return function(dt)
		if os.clock() < frozenUntil then
			return
		end
		local speed = 0.7 + ctx.Difficulty * 0.6 + reps * 0.04
		phase = (phase + dt * speed) % 2
		position = phase <= 1 and phase or 2 - phase
		needle.Position = UDim2.fromScale(position, 0.5)
	end
end

Games.Agility = function(ctx)
	local d = ctx.Difficulty
	return makeTargetSpawner(ctx, 0.55 - d * 0.15, 1.3 - d * 0.45, 0.18, math.floor(70 - d * 20))
end

Games.Katana = function(ctx)
	local d = ctx.Difficulty
	type Obj = { Frame: TextLabel, Pos: Vector2, Vel: Vector2, Radius: number, Bomb: boolean }
	local objects: { Obj } = {}
	local nextSpawn = 0
	local gravity = 420
	local fruits = { "🪵", "🎯", "🍉", "🍎", "🍊", "🍍" }
	local pointers: { [any]: Vector2 } = {}
	local connections = {}

	local function areaScale(): number
		return area.AbsoluteSize.X / AREA_SIZE.X
	end
	local function toLocal(screen: Vector2): Vector2
		return (screen - area.AbsolutePosition) / areaScale()
	end

	local function spawnObject()
		local bomb = math.random() < 0.14 + d * 0.1
		local radius = 34
		local x = math.random(60, AREA_SIZE.X - 60)
		local label = UIKit.Label({ Text = bomb and "💣" or fruits[math.random(1, #fruits)], Size = UDim2.fromOffset(radius * 2, radius * 2), AnchorPoint = Vector2.new(0.5, 0.5), Parent = ctx.Area, ZIndex = 24, Stroke = false })
		local targetX = math.random(80, AREA_SIZE.X - 80)
		local vy = -math.random(430, 520)
		local flight = 2 * -vy / gravity
		table.insert(objects, { Frame = label, Pos = Vector2.new(x, AREA_SIZE.Y + radius), Vel = Vector2.new((targetX - x) / flight, vy), Radius = radius, Bomb = bomb })
	end

	local function sliceSegment(a: Vector2, b: Vector2)
		local ab = b - a
		local lengthSq = ab:Dot(ab)
		if lengthSq < 9 then
			return
		end
		-- swipe trail
		local mid = (a + b) / 2
		local seg = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(mid.X, mid.Y),
			Size = UDim2.fromOffset(math.sqrt(lengthSq), 6), Rotation = math.deg(math.atan2(ab.Y, ab.X)), ZIndex = 28, Parent = ctx.Area })
		UIKit.Tween(seg, 0.18, { BackgroundTransparency = 1, Size = UDim2.fromOffset(math.sqrt(lengthSq), 1) })
		task.delay(0.2, function()
			seg:Destroy()
		end)
		for i = #objects, 1, -1 do
			local obj = objects[i]
			local tParam = math.clamp((obj.Pos - a):Dot(ab) / lengthSq, 0, 1)
			local closest = a + ab * tParam
			if (obj.Pos - closest).Magnitude <= obj.Radius + 10 then
				if obj.Bomb then
					ctx:AddScore(-2, obj.Pos)
					flash(C.Red)
					Effects.Play("Bomb")
				else
					ctx:AddScore(1, obj.Pos)
					Effects.Play("Slice", 0.9 + math.random() * 0.3)
				end
				obj.Frame:Destroy()
				table.remove(objects, i)
			end
		end
	end

	table.insert(connections, UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pointers[input.UserInputType == Enum.UserInputType.Touch and input or "mouse"] = toLocal(Vector2.new(input.Position.X, input.Position.Y))
		end
	end))
	table.insert(connections, UserInputService.InputChanged:Connect(function(input)
		local key = input.UserInputType == Enum.UserInputType.Touch and input or (input.UserInputType == Enum.UserInputType.MouseMovement and "mouse" or nil)
		if key and pointers[key] then
			local position = toLocal(Vector2.new(input.Position.X, input.Position.Y))
			sliceSegment(pointers[key], position)
			pointers[key] = position
		end
	end))
	table.insert(connections, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			pointers["mouse"] = nil
		elseif input.UserInputType == Enum.UserInputType.Touch then
			pointers[input] = nil
		end
	end))
	UIKit.Label({ Text = "Hold & drag to slice! 🔪", Font = Theme.BodyFont, Size = UDim2.fromScale(1, 0.6), Parent = ctx.Bottom, ZIndex = 22, MaxTextSize = 28 })

	local update = function(dt: number, t: number)
		if t >= nextSpawn then
			nextSpawn = t + (0.6 - d * 0.18) * (0.8 + math.random() * 0.4)
			spawnObject()
			if math.random() < 0.3 + d * 0.3 then
				spawnObject()
			end
		end
		for i = #objects, 1, -1 do
			local obj = objects[i]
			obj.Vel += Vector2.new(0, gravity * dt)
			obj.Pos += obj.Vel * dt
			obj.Frame.Position = UDim2.fromOffset(obj.Pos.X, obj.Pos.Y)
			obj.Frame.Rotation += dt * 120
			if obj.Pos.Y > AREA_SIZE.Y + 60 and obj.Vel.Y > 0 then
				obj.Frame:Destroy()
				table.remove(objects, i)
			end
		end
	end
	-- input connections are disconnected when the game ends (see close / Start)
	TrainingGames._cleanup = function()
		for _, conn in connections do
			conn:Disconnect()
		end
	end
	return update
end

Games.Special = function(ctx)
	local d = ctx.Difficulty
	local targets = makeTargetSpawner(ctx, 0.42 - d * 0.12, 1.05 - d * 0.35, 0.25, 58)
	local prompt = UIKit.Label({ Text = "", Size = UDim2.fromOffset(70, 70), Position = UDim2.new(1, -40, 0, 40), AnchorPoint = Vector2.new(0.5, 0.5), Parent = ctx.Area, ZIndex = 27, Stroke = false })
	local expected = "Up"
	local function nextArrow()
		expected = DIR_LIST[math.random(1, 4)]
		prompt.Text = ARROWS[expected]
	end
	nextArrow()
	arrowButtons(ctx, function(direction)
		if direction == expected then
			ctx:AddScore(2, Vector2.new(AREA_SIZE.X - 40, 80))
			Effects.Play("Click", 1.4)
			nextArrow()
		else
			ctx:AddScore(-1)
			flash(C.Red)
		end
	end)
	return targets
end

------------------------------------------------------------------------------------------------
-- Runner
------------------------------------------------------------------------------------------------
local function clearArea()
	for _, child in area:GetChildren() do
		if not child:IsA("UICorner") and not child:IsA("UIStroke") then
			child:Destroy()
		end
	end
	for _, child in bottom:GetChildren() do
		child:Destroy()
	end
end

local function setActive(active: boolean)
	TrainingGames.Active = active
	ProximityPromptService.Enabled = not active
	TrainingGames.ActiveChanged:Fire(active)
end

local function close()
	gui.Enabled = false
	resultFrame.Visible = false
	ContextActionService:UnbindAction(ACTION_NAME)
	if TrainingGames._cleanup then
		TrainingGames._cleanup()
		TrainingGames._cleanup = nil
	end
	clearArea()
	currentActivity = nil
	setActive(false)
end

local function showResult(def: Training.TrainingDef, ok: boolean, grade: string?, extra: any)
	resultFrame.Visible = true
	if ok and type(extra) == "table" then
		resultTitle.Text = (grade or "Done!") .. "  " .. extra.Score .. " / " .. extra.Goal
		local gains = {}
		for stat, amount in extra.Gains or {} do
			table.insert(gains, "+" .. amount .. " " .. stat)
		end
		table.sort(gains)
		resultBody.Text = #gains > 0 and ("You gained: " .. table.concat(gains, ", ") .. "\nCooldown: " .. def.Cooldown .. "s") or "No gains this time — try again!"
		TrainingGames.Finished:Fire(def.Id, def.Cooldown)
		Effects.Play(extra.Score >= extra.Goal and "LevelUp" or "Coin")
	else
		resultTitle.Text = "Training failed"
		resultBody.Text = tostring(grade or "Please try again.")
	end
	UIKit.SetButton(againButton, "🔁 Again (" .. def.Cooldown .. "s)", C.Blue)
end

function TrainingGames.Start(activityId: string)
	if TrainingGames.Active then
		return
	end
	if TrainingGames.IsBlocked and TrainingGames.IsBlocked() then
		UIKit.Toast("Leave the slicing round first!", "error")
		return
	end
	local def = Training.Get(activityId)
	if not def then
		return
	end
	setActive(true)
	local ok, _, extra = State.Action("StartTraining", true, activityId)
	if not ok or type(extra) ~= "table" then
		setActive(false)
		return
	end
	UIKit.CloseWindow(true)
	currentActivity = activityId
	cancelled = false
	clearArea()
	resultFrame.Visible = false
	gui.Enabled = true
	panelScale.Scale = 0.6 * UIKit.Scale
	UIKit.Tween(panelScale, 0.25, { Scale = UIKit.Scale }, Enum.EasingStyle.Back)
	titleLabel.Text = def.Emoji .. " " .. def.DisplayName
	titleLabel.TextColor3 = def.Color
	howToLabel.Text = def.HowTo
	scoreLabel.Text = "Score: 0 / " .. def.Goal
	setTimer(1, def.Duration .. "s")

	-- Countdown
	local countdown = UIKit.Label({ Text = "", Size = UDim2.fromOffset(200, 140), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = area, ZIndex = 40, Color = C.Coins, StrokeThickness = 4 })
	for _, text in { "3", "2", "1", "GO!" } do
		if cancelled then
			return
		end
		countdown.Text = text
		Effects.Play("Click", text == "GO!" and 1.5 or 1)
		task.wait(text == "GO!" and 0.4 or 0.7)
	end
	countdown:Destroy()
	if cancelled then
		return
	end

	local ctx: Context = {
		Area = area,
		Bottom = bottom,
		Difficulty = extra.Difficulty or 0,
		Score = 0,
		Time = 0,
		AddScore = function(self: Context, amount: number, at: Vector2?)
			self.Score = math.max(0, self.Score + amount)
			scoreLabel.Text = "Score: " .. self.Score .. " / " .. def.Goal
			scoreLabel.TextColor3 = self.Score >= def.Goal and C.Green or C.Text
			if at then
				popText(area, at, (amount > 0 and "+" or "") .. amount, amount > 0 and C.Green or C.Red)
			end
		end,
	}
	ContextActionService:BindActionAtPriority(ACTION_NAME, function(_, inputState, input)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Sink
		end
		local key = input.KeyCode
		local map = {
			[Enum.KeyCode.Up] = "Up", [Enum.KeyCode.W] = "Up", [Enum.KeyCode.Down] = "Down", [Enum.KeyCode.S] = "Down",
			[Enum.KeyCode.Left] = "Left", [Enum.KeyCode.A] = "Left", [Enum.KeyCode.Right] = "Right", [Enum.KeyCode.D] = "Right",
		}
		if key == Enum.KeyCode.Space then
			if ctx.OnPress then
				ctx.OnPress()
			end
		elseif map[key] and ctx.OnKey then
			ctx.OnKey(map[key])
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right,
		Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Space)

	local update = Games[def.Id](ctx)
	local elapsed = 0
	local startClock = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		if cancelled then
			connection:Disconnect()
			return
		end
		elapsed = os.clock() - startClock
		ctx.Time = elapsed
		setTimer(1 - elapsed / def.Duration, string.format("%.1fs", math.max(0, def.Duration - elapsed)))
		update(dt, elapsed)
		if elapsed >= def.Duration then
			connection:Disconnect()
		end
	end)
	while connection.Connected do
		task.wait()
	end
	if cancelled then
		return
	end
	ContextActionService:UnbindAction(ACTION_NAME)
	if TrainingGames._cleanup then
		TrainingGames._cleanup()
		TrainingGames._cleanup = nil
	end
	clearArea()
	UIKit.Label({ Text = "Time! ⏱️", Size = UDim2.fromOffset(300, 80), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = area, ZIndex = 40, Color = C.Coins })
	task.wait(0.3)
	local finishedOk, grade, result = State.Action("FinishTraining", true, extra.Token, ctx.Score)
	showResult(def, finishedOk, grade, result)
end

function TrainingGames.Init()
	gui = new("ScreenGui", { Name = "FNS_Training", ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 20, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
	dim = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), Parent = gui })
	panel = new("Frame", { BackgroundColor3 = C.Panel, Size = UDim2.fromOffset(640, 470), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = gui })
	panelScale = new("UIScale", { Parent = panel })
	UIKit.Corner(18).Parent = panel
	UIKit.Stroke(4).Parent = panel
	titleLabel = UIKit.Label({ Text = "", Size = UDim2.new(1, -120, 0, 40), Position = UDim2.fromOffset(20, 8), AlignX = Enum.TextXAlignment.Left, Parent = panel, ZIndex = 2, StrokeThickness = 2.5 })
	howToLabel = UIKit.Label({ Text = "", Font = Theme.BodyFont, Color = C.SubText, Size = UDim2.new(1, -40, 0, 34), Position = UDim2.fromOffset(20, 48), AlignX = Enum.TextXAlignment.Left, Parent = panel, ZIndex = 2, MaxTextSize = 16, Stroke = false })
	UIKit.Button({ Text = "✖", Color = C.Red, Size = UDim2.fromOffset(46, 46), Position = UDim2.new(1, -56, 0, 8), Parent = panel, ZIndex = 3,
		OnClick = function()
			cancelled = true
			State.Action("CancelTraining", true)
			close()
		end })
	local _, timerSetter = UIKit.ProgressBar({ Size = UDim2.new(0, 400, 0, 24), Position = UDim2.fromOffset(20, 88), Color = C.Orange, Parent = panel })
	setTimer = timerSetter
	scoreLabel = UIKit.Label({ Text = "", Size = UDim2.fromOffset(180, 28), Position = UDim2.new(1, -200, 0, 86), Parent = panel, ZIndex = 2, MaxTextSize = 24 })
	area = new("Frame", { Name = "Area", BackgroundColor3 = C.Background, Size = UDim2.fromOffset(AREA_SIZE.X, AREA_SIZE.Y), Position = UDim2.fromOffset(20, 122), ClipsDescendants = true, ZIndex = 20, Parent = panel })
	UIKit.Corner(14).Parent = area
	bottom = new("Frame", { Name = "Bottom", BackgroundTransparency = 1, Size = UDim2.fromOffset(AREA_SIZE.X, 80), Position = UDim2.fromOffset(20, 380), ZIndex = 20, Parent = panel })

	resultFrame = new("Frame", { BackgroundColor3 = C.PanelLight, Size = UDim2.fromOffset(520, 260), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Visible = false, ZIndex = 50, Parent = panel })
	UIKit.Corner(18).Parent = resultFrame
	UIKit.Stroke(4).Parent = resultFrame
	resultTitle = UIKit.Label({ Text = "", Color = C.Coins, Size = UDim2.new(1, -30, 0, 50), Position = UDim2.fromOffset(15, 14), Parent = resultFrame, ZIndex = 51, StrokeThickness = 3 })
	resultBody = UIKit.Label({ Text = "", Font = Theme.BodyFont, Size = UDim2.new(1, -40, 0, 90), Position = UDim2.fromOffset(20, 70), Parent = resultFrame, ZIndex = 51, MaxTextSize = 22 })
	againButton = UIKit.Button({ Text = "Again", Color = C.Blue, Size = UDim2.fromOffset(220, 56), Position = UDim2.new(0.5, -230, 1, -74), Parent = resultFrame, ZIndex = 52,
		OnClick = function()
			local activity = currentActivity
			close()
			if activity then
				TrainingGames.Start(activity)
			end
		end })
	UIKit.Button({ Text = "Close", Color = C.Gray, Size = UDim2.fromOffset(220, 56), Position = UDim2.new(0.5, 10, 1, -74), Parent = resultFrame, ZIndex = 52, OnClick = close })
	dim.Active = true -- swallow clicks behind the panel
end

return TrainingGames
