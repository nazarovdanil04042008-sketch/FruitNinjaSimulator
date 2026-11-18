--!nonstrict
-- World boss (client side) + the "live" info panel.
--   * Live panel (right side): boss countdown / "BOSS NOW! [Go]", current event with timer, active 2x boosts
--   * When the boss is active: the giant brainrot is rendered locally in the Boss Arena and animated
--     (breathing, turning to you, flinching when hit, jumping for ground slams)
--   * HP bar + big ATTACK button near the arena (PC: also left-click / F). Hits are sent to the server,
--     which decides damage; damage numbers pop up from the boss
--   * Slam warning: a red circle grows on the floor; if you're inside when it lands you get knocked back
--   * Results: rank, damage, coins, XP and egg reward

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage").Shared
local LiveOps = require(Shared.Config.LiveOps)
local Katanas = require(Shared.Config.Katanas)
local Eggs = require(Shared.Config.Eggs)
local ModelBuilder = require(Shared.Util.ModelBuilder)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Util.Net)

local UI = script.Parent.Parent.UI
local UIKit = require(UI.UIKit)
local Theme = require(UI.Theme)
local Effects = require(UI.Effects)
local State = require(script.Parent.State)
local FruitVisuals = require(script.Parent.FruitVisuals)

local BossController = {}

local C = Theme.Colors
local new = UIKit.new
local player = Players.LocalPlayer

local attackRemote: RemoteEvent
local gui: ScreenGui
local livePanel: Frame
local bossLine: TextLabel
local goButton: TextButton
local eventLine: TextLabel
local boostLine: TextLabel
local hpFrame: Frame
local hpName: TextLabel
local setHp: (number, string?) -> ()
local attackButton: TextButton

local bossModel: Model? = nil
local bossDef: LiveOps.BossDef? = nil
local bossBase: CFrame = CFrame.new()
local feetOffset = 0
local flinch = 0
local slamCircle: BasePart? = nil
local lastAttack = 0
local stunnedUntil = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

local function defById(id: string?): LiveOps.BossDef?
	for _, d in LiveOps.Bosses do
		if d.Id == id then
			return d
		end
	end
	return nil
end

local function nearArena(range: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local center = LiveOps.BossArena
	return Vector2.new(root.Position.X - center.X, root.Position.Z - center.Z).Magnitude <= range
end

------------------------------------------------------------------------------------------------
-- Boss model
------------------------------------------------------------------------------------------------
local function removeBoss()
	if bossModel then
		bossModel:Destroy()
		bossModel = nil
	end
	if slamCircle then
		slamCircle:Destroy()
		slamCircle = nil
	end
	bossDef = nil
end

local function ensureBoss()
	local active = workspace:GetAttribute("FNS_BossActive") == true
	if not active then
		removeBoss()
		return
	end
	local d = defById(workspace:GetAttribute("FNS_BossId"))
	if not d or (bossDef and bossDef.Id == d.Id and bossModel) then
		return
	end
	removeBoss()
	bossDef = d
	local model = ModelBuilder.Creature(d.CreatureId)
	ModelBuilder.AnchorAll(model)
	model:ScaleTo(d.Scale)
	local box, size = model:GetBoundingBox()
	feetOffset = model:GetPivot().Position.Y - (box.Position.Y - size.Y / 2)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
		end
	end
	-- red menacing aura + name tag
	local root = model.PrimaryPart :: BasePart
	local aura = Instance.new("PointLight")
	aura.Color = d.Color
	aura.Range = 40
	aura.Brightness = 3
	aura.Parent = root
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromScale(18, 3)
	tag.StudsOffsetWorldSpace = Vector3.new(0, size.Y * 0.62, 0)
	tag.MaxDistance = 400
	tag.Parent = root
	UIKit.Label({ Text = "👹 " .. d.DisplayName, Color = Color3.fromRGB(255, 90, 80), Parent = tag, StrokeThickness = 3 })
	bossBase = CFrame.new(LiveOps.BossArena + Vector3.new(0, 0.8 + feetOffset, 0))
	model:PivotTo(bossBase)
	model.Name = "FNS_Boss"
	model.Parent = workspace
	bossModel = model
end

------------------------------------------------------------------------------------------------
-- Attacking
------------------------------------------------------------------------------------------------
local function attack()
	if not bossModel or os.clock() < stunnedUntil then
		return
	end
	if os.clock() - lastAttack < 1 / LiveOps.BossHitsPerSecond then
		return
	end
	if not nearArena(LiveOps.BossAttackRange) then
		UIKit.Toast("Get closer to the boss!", "error")
		return
	end
	lastAttack = os.clock()
	attackRemote:FireServer()
	flinch = 1
	local katana = Katanas.Get(State.Profile and State.Profile.EquippedKatana)
	local root = bossModel.PrimaryPart
	if root then
		local hitPos = root.Position + Vector3.new(math.random(-5, 5), math.random(-4, 6), math.random(-5, 5))
		FruitVisuals.KatanaEffect(katana.Effect, hitPos)
		FruitVisuals.Juice(hitPos, bossDef and bossDef.Color or Color3.new(1, 0, 0), 10)
	end
	Effects.Play("Slice", 0.8 + math.random() * 0.4)
end

------------------------------------------------------------------------------------------------
-- Per-frame
------------------------------------------------------------------------------------------------
local function step(dt: number)
	if not bossModel then
		return
	end
	local t = os.clock()
	-- face the local player, breathe, flinch when hit, jump before a slam
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local yaw = 0
	if root then
		local direction = root.Position - bossBase.Position
		yaw = math.atan2(-direction.X, -direction.Z)
	end
	flinch = math.max(0, flinch - dt * 6)
	local slamAt = workspace:GetAttribute("FNS_BossSlamAt") or 0
	local untilSlam = slamAt - now()
	local jump = 0
	if untilSlam > 0 and untilSlam < 0.6 then
		jump = math.sin((0.6 - untilSlam) / 0.6 * math.pi) * 8
	end
	local breathe = math.sin(t * 2) * 0.6
	bossModel:PivotTo(bossBase * CFrame.new(0, breathe + jump, 0) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(-flinch * 8), 0, math.sin(t * 40) * flinch * 0.05))

	-- slam telegraph circle
	local radius = workspace:GetAttribute("FNS_BossSlamRadius") or 18
	if untilSlam > 0 then
		if not slamCircle then
			local circle = Instance.new("Part")
			circle.Name = "FNS_SlamWarning"
			circle.Shape = Enum.PartType.Cylinder
			circle.Anchored = true
			circle.CanCollide = false
			circle.CanQuery = false
			circle.CanTouch = false
			circle.Material = Enum.Material.Neon
			circle.Color = Color3.fromRGB(255, 40, 40)
			circle.Parent = workspace
			slamCircle = circle
		end
		local progress = 1 - math.clamp(untilSlam / 1.6, 0, 1)
		local size = radius * 2 * (0.3 + progress * 0.7)
		slamCircle.Size = Vector3.new(0.2, size, size)
		slamCircle.CFrame = CFrame.new(LiveOps.BossArena + Vector3.new(0, 1.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
		slamCircle.Transparency = 0.35 + math.sin(t * 20) * 0.15
	elseif slamCircle then
		slamCircle:Destroy()
		slamCircle = nil
		if nearArena(LiveOps.BossArenaRadius + 30) then
			Effects.Play("Bomb", 0.6)
			FruitVisuals.Explosion(LiveOps.BossArena + Vector3.new(0, 2, 0))
		end
	end
end

local function updatePanels()
	local serverTime = now()
	local active = workspace:GetAttribute("FNS_BossActive") == true
	if active then
		local ends = workspace:GetAttribute("FNS_BossEnds") or 0
		bossLine.Text = "👹 BOSS NOW! " .. Format.Time(ends - serverTime)
		bossLine.TextColor3 = Color3.fromRGB(255, 110, 100)
		goButton.Visible = not nearArena(LiveOps.BossArenaRadius + 20)
	else
		local nextAt = workspace:GetAttribute("FNS_BossNextAt") or 0
		bossLine.Text = "👹 Boss in " .. Format.Time(math.max(0, nextAt - serverTime))
		bossLine.TextColor3 = C.Text
		goButton.Visible = false
	end

	local eventId = workspace:GetAttribute("FNS_EventId") or ""
	local eventEnds = workspace:GetAttribute("FNS_EventEnds") or 0
	local eventDef
	for _, e in LiveOps.Events do
		if e.Id == eventId then
			eventDef = e
		end
	end
	if eventDef and eventEnds > serverTime then
		eventLine.Text = eventDef.Emoji .. " " .. eventDef.DisplayName .. " " .. Format.Time(eventEnds - serverTime)
		eventLine.TextColor3 = eventDef.Color
		eventLine.Visible = true
	else
		eventLine.Visible = false
	end

	local boosts = State.Profile and State.Profile.Boosts or {}
	local parts = {}
	for kind, expires in boosts do
		if expires > serverTime then
			table.insert(parts, "⚡ 2x " .. kind .. " " .. Format.Time(expires - serverTime))
		end
	end
	boostLine.Text = table.concat(parts, "\n")
	boostLine.Visible = #parts > 0

	-- HP bar + attack button when near the fight
	local near = active and nearArena(150)
	hpFrame.Visible = near
	attackButton.Visible = active and nearArena(LiveOps.BossAttackRange)
	if near then
		local hp = workspace:GetAttribute("FNS_BossHP") or 0
		local maxHp = math.max(1, workspace:GetAttribute("FNS_BossMaxHP") or 1)
		local d = defById(workspace:GetAttribute("FNS_BossId"))
		hpName.Text = "👹 " .. (d and d.DisplayName or "Boss")
		setHp(hp / maxHp, Format.Commas(hp) .. " / " .. Format.Commas(maxHp))
	end
end

------------------------------------------------------------------------------------------------
-- Server events
------------------------------------------------------------------------------------------------
local function onBossEvent(kind: string, data: any)
	if kind == "Spawned" then
		Effects.Banner("👹 WORLD BOSS APPEARED! 👹", Color3.fromRGB(255, 80, 70), 2.2, 0.3)
		Effects.Play("Bomb", 0.5)
	elseif kind == "Hit" then
		if bossModel and bossModel.PrimaryPart then
			local screen, onScreen = workspace.CurrentCamera:WorldToScreenPoint(bossModel.PrimaryPart.Position + Vector3.new(math.random(-6, 6), math.random(0, 8), 0))
			if onScreen then
				Effects.FloatText(Vector2.new(screen.X, screen.Y), (data.Crit and "CRIT " or "") .. "-" .. Format.Short(data.Damage), data.Crit and C.Coins or Color3.fromRGB(255, 120, 110), data.Crit and 44 or 32)
			end
		end
	elseif kind == "Knockback" then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			root.AssemblyLinearVelocity = data.Direction * 90 + Vector3.new(0, 55, 0)
		end
		stunnedUntil = os.clock() + 1.5
		Effects.Banner("💫 SLAMMED! Stay out of the red circle!", C.Red, 1.2, 0.4)
	elseif kind == "Result" then
		local title = data.Defeated and ("🏆 Boss defeated! Rank #" .. data.Rank .. " of " .. data.Players) or "💨 The boss escaped..."
		Effects.Banner(title, data.Defeated and C.Coins or C.SubText, 2.5, 0.3)
		local egg = data.Egg and Eggs.Get(data.Egg)
		UIKit.Toast(string.format("Damage %s • +%s coins • +%s XP%s", Format.Short(data.Damage), Format.Short(data.Coins), Format.Short(data.Xp), egg and (" • 🥚 " .. egg.DisplayName) or ""), "success")
		Effects.Play(data.Defeated and "LevelUp" or "Error")
	elseif kind == "Defeated" or kind == "Escaped" then
		removeBoss()
	end
end

------------------------------------------------------------------------------------------------
-- UI
------------------------------------------------------------------------------------------------
local function buildUI()
	gui = new("ScreenGui", { Name = "FNS_Live", ResetOnSpawn = false, DisplayOrder = 11, IgnoreGuiInset = false, Parent = player:WaitForChild("PlayerGui") })

	livePanel = new("Frame", { BackgroundColor3 = C.Panel, BackgroundTransparency = 0.2, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 190), Size = UDim2.fromOffset(250, 0),
		AutomaticSize = Enum.AutomaticSize.Y, Parent = gui })
	UIKit.AutoScale(livePanel)
	UIKit.Corner(14).Parent = livePanel
	UIKit.Stroke(3).Parent = livePanel
	UIKit.Padding(8).Parent = livePanel
	UIKit.List(6).Parent = livePanel
	bossLine = UIKit.Label({ Text = "👹 Boss in --:--", Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 1, Parent = livePanel, MaxTextSize = 22 })
	goButton = UIKit.Button({ Text = "⚔️ Go fight!", Color = C.Red, Size = UDim2.new(1, 0, 0, 42), LayoutOrder = 2, Parent = livePanel, MaxTextSize = 22,
		OnClick = function()
			State.Action("Teleport", true, "Boss")
		end })
	goButton.Visible = false
	eventLine = UIKit.Label({ Text = "", Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 3, Parent = livePanel, MaxTextSize = 20 })
	boostLine = UIKit.Label({ Text = "", Font = Theme.BodyFont, Size = UDim2.new(1, 0, 0, 0), TextScaled = false, TextSize = 16, LayoutOrder = 4, Parent = livePanel })
	boostLine.AutomaticSize = Enum.AutomaticSize.Y

	hpFrame = new("Frame", { BackgroundColor3 = C.Panel, BackgroundTransparency = 0.15, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64), Size = UDim2.fromOffset(560, 74), Visible = false, Parent = gui })
	UIKit.AutoScale(hpFrame)
	UIKit.Corner(14).Parent = hpFrame
	UIKit.Stroke(3, C.Red).Parent = hpFrame
	hpName = UIKit.Label({ Text = "", Color = Color3.fromRGB(255, 110, 100), Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(10, 4), Parent = hpFrame, MaxTextSize = 24 })
	local _, setter = UIKit.ProgressBar({ Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 36), Color = C.Red, Parent = hpFrame })
	setHp = setter

	attackButton = UIKit.Button({ Text = "⚔️ ATTACK", Color = C.Red, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -170), Size = UDim2.fromOffset(190, 90), Parent = gui, MaxTextSize = 34, Radius = 22 })
	attackButton.Visible = false
	attackButton.Activated:Connect(attack)
end

function BossController.Init()
	attackRemote = Net.Event("BossAttack")
	buildUI()
	Net.Event("BossEvent").OnClientEvent:Connect(onBossEvent)
	for _, name in { "FNS_BossActive", "FNS_BossId" } do
		workspace:GetAttributeChangedSignal(name):Connect(ensureBoss)
	end
	ensureBoss()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not bossModel then
			return
		end
		if input.KeyCode == Enum.KeyCode.F or (input.UserInputType == Enum.UserInputType.MouseButton1 and nearArena(LiveOps.BossAttackRange)) then
			attack()
		end
	end)
	RunService.RenderStepped:Connect(step)
	task.spawn(function()
		while true do
			updatePanels()
			task.wait(0.25)
		end
	end)
end

return BossController
