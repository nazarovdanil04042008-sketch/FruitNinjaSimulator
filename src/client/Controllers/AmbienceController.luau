--!nonstrict
-- Client-only world life. Nothing here touches gameplay or the network:
--   * day / night cycle (synced for everyone through the server clock) with warm dusk and blue nights
--   * falling sakura petals and leaves around the player
--   * fireflies at night
--   * a flock of white cranes circling in the sky
--   * koi fish swimming in the lake
-- Everything uses small pooled anchored parts moved with one BulkMoveTo per frame (cheap on phones).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GameConfig = require(game:GetService("ReplicatedStorage").Shared.Config.GameConfig)

local AmbienceController = {}

local player = Players.LocalPlayer
local folder: Folder
local rng = Random.new()

local parts: { BasePart } = {}
local cframes: { CFrame } = {}

local function newPart(size: Vector3, color: Color3, material: Enum.Material?, ball: boolean?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if ball then
		p.Shape = Enum.PartType.Ball
	end
	p.Parent = folder
	return p
end

local function sphereMesh(p: BasePart)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
end

local function focusPosition(): Vector3
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		return root.Position
	end
	return workspace.CurrentCamera.CFrame.Position
end

------------------------------------------------------------------------------------------------
-- Day / night
------------------------------------------------------------------------------------------------
local DAY_AMBIENT = Color3.fromRGB(150, 150, 160)
local NIGHT_AMBIENT = Color3.fromRGB(85, 95, 140)
local DAY_INDOOR = Color3.fromRGB(90, 90, 100)
local NIGHT_INDOOR = Color3.fromRGB(65, 70, 105)
local DUSK_TINT = Color3.fromRGB(255, 225, 200)
local NIGHT_TINT = Color3.fromRGB(205, 215, 255)
local nightFactor = 0

local function clockNow(): number
	local cycle = GameConfig.DayNightCycle
	local phase = (workspace:GetServerTimeNow() % cycle) / cycle
	local dayShare = GameConfig.DayFraction
	if phase < dayShare then
		return 6 + phase / dayShare * 12 -- 06:00 -> 18:00
	end
	return (18 + (phase - dayShare) / (1 - dayShare) * 12) % 24 -- 18:00 -> 06:00
end

local function smooth(edge0: number, edge1: number, x: number): number
	local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
end

local function updateLighting()
	local clock = clockNow()
	-- 0 during the day, 1 at night, smooth at dusk (17:30-19:30) and dawn (4:30-6:30)
	local night = clock >= 12 and smooth(17.5, 19.5, clock) or 1 - smooth(4.5, 6.5, clock)
	local dusk = math.max(0, 1 - math.abs(clock - 18.3) / 1.5) + math.max(0, 1 - math.abs(clock - 5.7) / 1.2)
	nightFactor = night
	Lighting.ClockTime = clock
	Lighting.Brightness = 2.4 - night * 1.4
	Lighting.OutdoorAmbient = DAY_AMBIENT:Lerp(NIGHT_AMBIENT, night)
	Lighting.Ambient = DAY_INDOOR:Lerp(NIGHT_INDOOR, night)
	local cc = Lighting:FindFirstChild("FNS_Color")
	if cc and cc:IsA("ColorCorrectionEffect") then
		cc.TintColor = Color3.new(1, 1, 1):Lerp(DUSK_TINT, math.min(dusk, 1) * 0.8):Lerp(NIGHT_TINT, night * 0.6)
	end
end

------------------------------------------------------------------------------------------------
-- Falling petals / leaves
------------------------------------------------------------------------------------------------
type Petal = { Part: BasePart, Pos: Vector3, Fall: number, Phase: number, Spin: Vector3 }
local petals: { Petal } = {}
local PETAL_COUNT = 45
local PETAL_RADIUS = 45

local function resetPetal(petal: Petal, focus: Vector3, anywhere: boolean)
	local a = rng:NextNumber(0, math.pi * 2)
	local r = math.sqrt(rng:NextNumber()) * PETAL_RADIUS
	local y = anywhere and rng:NextNumber(1, 26) or rng:NextNumber(18, 28)
	petal.Pos = Vector3.new(focus.X + math.cos(a) * r, focus.Y - 3 + y, focus.Z + math.sin(a) * r)
	petal.Fall = rng:NextNumber(1.6, 3)
	petal.Phase = rng:NextNumber(0, 10)
end

local function buildPetals()
	local colors = { Color3.fromRGB(255, 183, 205), Color3.fromRGB(255, 160, 190), Color3.fromRGB(255, 210, 225), Color3.fromRGB(120, 180, 80) }
	for i = 1, PETAL_COUNT do
		local color = colors[(i % 9 == 0) and 4 or rng:NextInteger(1, 3)]
		local petal = { Part = newPart(Vector3.new(0.45, 0.06, 0.32), color), Pos = Vector3.zero, Fall = 2, Phase = 0,
			Spin = Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-3, 3), rng:NextNumber(-3, 3)) }
		resetPetal(petal, focusPosition(), true)
		table.insert(petals, petal)
	end
end

------------------------------------------------------------------------------------------------
-- Fireflies (night only)
------------------------------------------------------------------------------------------------
type Firefly = { Part: BasePart, Home: Vector3, Phase: number }
local fireflies: { Firefly } = {}

local function buildFireflies()
	for _ = 1, 24 do
		local p = newPart(Vector3.one * 0.3, Color3.fromRGB(255, 240, 120), Enum.Material.Neon, true)
		p.Transparency = 1
		table.insert(fireflies, { Part = p, Home = Vector3.zero, Phase = rng:NextNumber(0, 100) })
	end
end

------------------------------------------------------------------------------------------------
-- Cranes
------------------------------------------------------------------------------------------------
type Crane = { Body: BasePart, Head: BasePart, WingL: BasePart, WingR: BasePart, Offset: number, Radius: number, Height: number }
local cranes: { Crane } = {}
local flockCenter = Vector3.zero

local function buildCranes()
	for i = 1, 7 do
		local body = newPart(Vector3.new(0.9, 0.8, 2.6), Color3.fromRGB(245, 245, 245))
		sphereMesh(body)
		local head = newPart(Vector3.one * 0.45, Color3.fromRGB(220, 30, 40), nil, true)
		local wingL = newPart(Vector3.new(3, 0.12, 1.2), Color3.fromRGB(240, 240, 240))
		local wingR = newPart(Vector3.new(3, 0.12, 1.2), Color3.fromRGB(240, 240, 240))
		table.insert(cranes, { Body = body, Head = head, WingL = wingL, WingR = wingR, Offset = i * 0.55, Radius = 70 + (i % 3) * 8, Height = 55 + (i % 4) * 4 })
	end
end

------------------------------------------------------------------------------------------------
-- Koi
------------------------------------------------------------------------------------------------
type Koi = { Body: BasePart, Tail: BasePart, Speed: number, Radius: number, Phase: number, Wobble: number }
local koi: { Koi } = {}

local function buildKoi()
	local colors = { Color3.fromRGB(255, 120, 30), Color3.fromRGB(250, 250, 245), Color3.fromRGB(235, 60, 40), Color3.fromRGB(255, 170, 60) }
	local lake = GameConfig.Lake
	for i = 1, 10 do
		local color = colors[(i - 1) % #colors + 1]
		local body = newPart(Vector3.new(0.7, 0.45, 2), color)
		sphereMesh(body)
		local tail = Instance.new("WedgePart")
		tail.Anchored = true
		tail.CanCollide = false
		tail.CanQuery = false
		tail.CanTouch = false
		tail.CastShadow = false
		tail.Size = Vector3.new(0.08, 0.6, 0.7)
		tail.Color = color:Lerp(Color3.new(1, 1, 1), 0.2)
		tail.Parent = folder
		table.insert(koi, { Body = body, Tail = tail, Speed = rng:NextNumber(0.12, 0.25) * (i % 2 == 0 and 1 or -1),
			Radius = rng:NextNumber(5, lake.Radius - 4), Phase = rng:NextNumber(0, math.pi * 2), Wobble = rng:NextNumber(0, 10) })
	end
end

------------------------------------------------------------------------------------------------
-- Frame update
------------------------------------------------------------------------------------------------
local function step(dt: number)
	table.clear(parts)
	table.clear(cframes)
	local t = os.clock()
	local focus = focusPosition()
	local camera = workspace.CurrentCamera
	local cameraPos = camera.CFrame.Position

	-- petals
	for _, petal in petals do
		local sway = Vector3.new(math.sin(t * 1.3 + petal.Phase) * 1.2, -petal.Fall, math.cos(t * 0.9 + petal.Phase) * 0.8)
		petal.Pos += sway * dt
		local flat = Vector2.new(petal.Pos.X - focus.X, petal.Pos.Z - focus.Z)
		if petal.Pos.Y < focus.Y - 4 or flat.Magnitude > PETAL_RADIUS + 5 then
			resetPetal(petal, focus, flat.Magnitude > PETAL_RADIUS + 5)
		end
		local spin = petal.Spin * t
		table.insert(parts, petal.Part)
		table.insert(cframes, CFrame.new(petal.Pos) * CFrame.Angles(spin.X, spin.Y, spin.Z))
	end

	-- fireflies
	local fireflyAlpha = nightFactor
	for i, fly in fireflies do
		if fireflyAlpha < 0.05 then
			fly.Part.Transparency = 1
		else
			if (fly.Home - focus).Magnitude > 40 then
				fly.Home = focus + Vector3.new(rng:NextNumber(-30, 30), 0, rng:NextNumber(-30, 30))
			end
			local p = fly.Phase + t * 0.4
			local pos = fly.Home + Vector3.new(math.sin(p * 1.3) * 4, -1.5 + math.sin(p * 0.7 + i) * 1.5 + 2, math.cos(p) * 4)
			local blink = (math.sin(t * 3 + fly.Phase) + 1) / 2
			fly.Part.Transparency = 1 - fireflyAlpha * (0.3 + blink * 0.7)
			table.insert(parts, fly.Part)
			table.insert(cframes, CFrame.new(pos))
		end
	end

	-- cranes circle above the player's area
	flockCenter = flockCenter:Lerp(Vector3.new(focus.X, 0, focus.Z), math.min(1, dt * 0.15))
	for i, crane in cranes do
		local angle = t * 0.12 + crane.Offset
		local pos = flockCenter + Vector3.new(math.cos(angle) * crane.Radius, crane.Height + math.sin(t * 0.5 + i) * 2, math.sin(angle) * crane.Radius)
		local forward = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		local body = CFrame.lookAt(pos, pos + forward) * CFrame.Angles(0, 0, math.rad(-12))
		local flap = math.sin(t * 5 + i * 1.3) * 0.55
		table.insert(parts, crane.Body)
		table.insert(cframes, body)
		table.insert(parts, crane.Head)
		table.insert(cframes, body * CFrame.new(0, 0.35, -1.5))
		table.insert(parts, crane.WingL)
		table.insert(cframes, body * CFrame.new(-0.4, 0.1, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(-1.5, 0, 0))
		table.insert(parts, crane.WingR)
		table.insert(cframes, body * CFrame.new(0.4, 0.1, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(1.5, 0, 0))
	end

	-- koi (only animated when you are near the lake)
	local lake = GameConfig.Lake
	if (cameraPos - lake.Center).Magnitude < 220 then
		for _, fish in koi do
			local a = fish.Phase + t * fish.Speed
			local r = fish.Radius + math.sin(t * 0.3 + fish.Wobble) * 2
			local pos = lake.Center + Vector3.new(math.cos(a) * r, -0.9, math.sin(a) * r)
			local direction = Vector3.new(-math.sin(a), 0, math.cos(a)) * (fish.Speed > 0 and 1 or -1)
			local body = CFrame.lookAt(pos, pos + direction) * CFrame.Angles(0, math.sin(t * 6 + fish.Wobble) * 0.15, 0)
			table.insert(parts, fish.Body)
			table.insert(cframes, body)
			table.insert(parts, fish.Tail)
			table.insert(cframes, body * CFrame.new(0, 0, 1.2) * CFrame.Angles(0, math.sin(t * 9 + fish.Wobble) * 0.5 + math.pi / 2, 0))
		end
	end

	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function AmbienceController.Init()
	folder = Instance.new("Folder")
	folder.Name = "FNS_Ambience"
	folder.Parent = workspace
	buildPetals()
	buildFireflies()
	buildCranes()
	buildKoi()
	RunService.RenderStepped:Connect(step)
	task.spawn(function()
		while true do
			updateLighting()
			task.wait(0.25)
		end
	end)
end

return AmbienceController
