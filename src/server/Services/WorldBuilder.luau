--!nonstrict
-- Builds the whole game world from code on server start (if Workspace.FNS_World does not exist yet).
-- Everything here is decoration + interaction points (ProximityPrompts with attributes the client reads):
--   prompt attributes: Action = "Slice" (Arena = id) | "Train" (Activity = id) | "Open" (Window = name)
-- To hand-build/replace the map: run the game once, copy Workspace.FNS_World, stop, paste it into
-- Workspace and edit freely - the builder will then skip generation and use your copy.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Arenas = require(Shared.Config.Arenas)
local Training = require(Shared.Config.Training)
local Rarities = require(Shared.Config.Rarities)
local Creatures = require(Shared.Config.Creatures)
local Locations = require(Shared.Config.Locations)
local ModelBuilder = require(Shared.Util.ModelBuilder)
local JapaneseBuilder = require(Shared.Util.JapaneseBuilder)

local WorldBuilder = {}

local FONT = Enum.Font.FredokaOne
local LAKE_CENTER = require(Shared.Config.GameConfig).Lake.Center
local LAKE_RADIUS = require(Shared.Config.GameConfig).Lake.Radius

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function part(parent: Instance, props: { [string]: any }): BasePart
	local p: BasePart
	if props.Shape == "Cylinder" or props.Shape == "Ball" then
		local inst = Instance.new("Part")
		inst.Shape = props.Shape == "Ball" and Enum.PartType.Ball or Enum.PartType.Cylinder
		p = inst
	elseif props.Shape == "Wedge" then
		p = Instance.new("WedgePart")
	else
		p = Instance.new("Part")
	end
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = props.Size or Vector3.new(4, 1, 4)
	p.CFrame = props.CFrame or CFrame.new(props.Position or Vector3.zero)
	p.Color = props.Color or c(200, 200, 200)
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Name = props.Name or "Part"
	if props.Transparency then
		p.Transparency = props.Transparency
	end
	if props.CanCollide == false then
		p.CanCollide = false
	end
	p.CastShadow = props.CastShadow ~= false
	p.Parent = parent
	return p
end

-- Upright cylinder (Roblox cylinders point along X, so rotate them).
local function disc(parent: Instance, position: Vector3, diameter: number, height: number, color: Color3, material: Enum.Material?): BasePart
	return part(parent, {
		Shape = "Cylinder",
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material,
	})
end

local function surfaceText(board: BasePart, text: string, textColor: Color3, faces: { Enum.NormalId })
	for _, face in faces do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = FONT
		label.TextScaled = true
		label.Text = text
		label.TextColor3 = textColor
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = c(30, 30, 40)
		stroke.Parent = label
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0.04, 0)
		padding.PaddingRight = UDim.new(0.04, 0)
		padding.Parent = label
	end
end

local function billboard(adornee: BasePart, title: string, subtitle: string?, color: Color3, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(10, 3.2)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.MaxDistance = 160
	gui.LightInfluence = 0
	gui.Parent = adornee
	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.fromScale(1, subtitle and 0.62 or 1)
	titleLabel.Font = FONT
	titleLabel.TextScaled = true
	titleLabel.Text = title
	titleLabel.TextColor3 = color
	titleLabel.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = c(20, 20, 30)
	stroke.Parent = titleLabel
	if subtitle then
		local sub = titleLabel:Clone()
		sub.Text = subtitle
		sub.TextColor3 = c(255, 255, 255)
		sub.Size = UDim2.fromScale(1, 0.38)
		sub.Position = UDim2.fromScale(0, 0.62)
		sub.Parent = gui
	end
end

local function prompt(parent: BasePart, actionText: string, objectText: string, attributes: { [string]: string })
	local p = Instance.new("ProximityPrompt")
	p.ActionText = actionText
	p.ObjectText = objectText
	p.HoldDuration = 0
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	for key, value in attributes do
		p:SetAttribute(key, value)
	end
	p.Parent = parent
	return p
end

local function sign(parent: Instance, position: Vector3, facing: Vector3, text: string, color: Color3)
	part(parent, { Name = "SignPost", Size = Vector3.new(0.8, 9, 0.8), Position = position + Vector3.new(0, 4.5, 0), Color = c(120, 80, 50), Material = Enum.Material.Wood })
	local board = part(parent, {
		Name = "SignBoard",
		Size = Vector3.new(12, 3.2, 0.6),
		CFrame = CFrame.lookAt(position + Vector3.new(0, 8, 0), position + Vector3.new(0, 8, 0) + facing),
		Color = color,
	})
	surfaceText(board, text, c(255, 255, 255), { Enum.NormalId.Front, Enum.NormalId.Back })
end

-- Places a JapaneseBuilder model (origin = footprint centre on the floor) and parents it.
local function place(parent: Instance, model: Model, cf: CFrame): Model
	model:PivotTo(cf)
	model.Parent = parent
	return model
end

local function torii(parent: Instance, position: Vector3, yaw: number, width: number?, height: number?)
	return place(parent, JapaneseBuilder.Torii(width or 14, height or 13), CFrame.new(position) * CFrame.Angles(0, math.rad(yaw), 0))
end

local function lantern(parent: Instance, position: Vector3, scale: number?)
	return place(parent, JapaneseBuilder.StoneLantern(scale or 1), CFrame.new(position))
end

local sakuraSeed = 0
local function sakura(parent: Instance, position: Vector3, scale: number?)
	sakuraSeed += 1
	return place(parent, JapaneseBuilder.Sakura(scale or 1.2, sakuraSeed), CFrame.new(position) * CFrame.Angles(0, sakuraSeed * 1.3, 0))
end

local function tree(parent: Instance, position: Vector3, leafColor: Color3, fruitColor: Color3?, scale: number)
	part(parent, { Name = "Trunk", Shape = "Cylinder", Size = Vector3.new(8 * scale, 1.6 * scale, 1.6 * scale),
		CFrame = CFrame.new(position + Vector3.new(0, 4 * scale, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = c(120, 80, 45), Material = Enum.Material.Wood })
	local leaves = part(parent, { Name = "Leaves", Shape = "Ball", Size = Vector3.one * 8 * scale, Position = position + Vector3.new(0, 9 * scale, 0), Color = leafColor, Material = Enum.Material.Grass })
	if fruitColor then
		for i = 0, 3 do
			local a = math.rad(i * 90 + 45)
			part(parent, { Name = "TreeFruit", Shape = "Ball", Size = Vector3.one * 1.1 * scale, CanCollide = false,
				Position = leaves.Position + Vector3.new(math.cos(a) * 3.6 * scale, -0.5 * scale, math.sin(a) * 3.6 * scale), Color = fruitColor })
		end
	end
end

------------------------------------------------------------------------------------------------
-- Areas
------------------------------------------------------------------------------------------------
local function buildSpawn(world: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Spawn"
	folder.Parent = world

	disc(folder, Vector3.new(0, 0.3, 0), 70, 0.6, c(235, 225, 200), Enum.Material.Slate)
	disc(folder, Vector3.new(0, 0.45, 0), 52, 0.6, c(255, 240, 210), Enum.Material.SmoothPlastic)

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "FNS_Spawn"
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(12, 1, 12)
	spawnLocation.CFrame = CFrame.new(0, 0.6, 16)
	spawnLocation.Color = c(255, 200, 70)
	spawnLocation.Material = Enum.Material.Neon
	spawnLocation.Duration = 0
	spawnLocation.TopSurface = Enum.SurfaceType.Smooth
	spawnLocation.Parent = folder

	-- Centrepiece: a black stone medallion with glowing kanji and two katanas stuck in a rock.
	-- Everything here is solid, so players can't walk through the swords.
	local dais = disc(folder, Vector3.new(0, 1.2, -6), 26, 1.2, c(45, 45, 50), Enum.Material.Slate)
	dais.Name = "CenterDais"
	disc(folder, Vector3.new(0, 2, -6), 20, 0.8, c(30, 30, 34), Enum.Material.Slate)
	local medallionCF = CFrame.new(0, 13.6, -10) * CFrame.Angles(0, math.rad(90), 0)
	part(folder, { Name = "MedallionRim", Shape = "Cylinder", Size = Vector3.new(1.6, 23.6, 23.6), CFrame = medallionCF, Color = c(255, 190, 60), Material = Enum.Material.Neon })
	local medallion = part(folder, { Name = "Medallion", Shape = "Cylinder", Size = Vector3.new(2.2, 22, 22), CFrame = medallionCF, Color = c(18, 18, 22), Material = Enum.Material.Slate })
	local glowLight = Instance.new("PointLight")
	glowLight.Color = c(255, 170, 60)
	glowLight.Range = 24
	glowLight.Brightness = 2
	glowLight.Parent = medallion
	local KANJI = { "刀", "果", "斬", "力", "速", "心", "道", "龍" } -- sword, fruit, slash, power, speed, heart, way, dragon
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.LightInfluence = 0
		gui.Brightness = 2.5
		gui.Parent = medallion
		local function glyph(text: string, size: number, x: number, y: number, color: Color3)
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.AnchorPoint = Vector2.new(0.5, 0.5)
			label.Position = UDim2.fromScale(x, y)
			label.Size = UDim2.fromScale(size, size)
			label.Font = Enum.Font.GothamBlack
			label.TextScaled = true
			label.Text = text
			label.TextColor3 = color
			label.Parent = gui
			local stroke = Instance.new("UIStroke")
			stroke.Color = c(255, 90, 20)
			stroke.Thickness = 4
			stroke.Transparency = 0.2
			stroke.Parent = label
		end
		glyph("忍", 0.5, 0.5, 0.5, c(255, 225, 120)) -- shinobi / ninja
		for k, kanji in KANJI do
			local a = (k - 1) / #KANJI * math.pi * 2
			glyph(kanji, 0.13, 0.5 + math.sin(a) * 0.38, 0.5 - math.cos(a) * 0.38, c(255, 200, 90))
		end
	end
	-- the rock and the two crossed katanas
	local rock = part(folder, { Name = "SwordRock", Size = Vector3.new(13, 7, 9), Position = Vector3.new(0, 4.6, -2.5), Color = c(35, 35, 40), Material = Enum.Material.Slate })
	local rockMesh = Instance.new("SpecialMesh")
	rockMesh.MeshType = Enum.MeshType.Sphere
	rockMesh.Parent = rock
	for _, data in { { 7, -1.6, -25, "Golden" }, { -7, -3.2, 25, "Diamond" } } do
		local sword = ModelBuilder.Katana(data[4])
		ModelBuilder.AnchorAll(sword)
		sword:ScaleTo(4)
		sword:PivotTo(CFrame.new(data[1], 24.5, data[2]) * CFrame.Angles(0, 0, math.pi + math.rad(data[3])))
		for _, d in sword:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = true
				d.CanQuery = true
			end
		end
		sword.Parent = folder
	end
	billboard(medallion, "🍉 FRUIT NINJA SIMULATOR 🍉", "Slice fruit • Train • Hatch creatures!", c(255, 220, 70), 15)

	sign(folder, Vector3.new(0, 0, -30), Vector3.new(0, 0, 1), "⚔️ ARENAS ⬆", c(255, 120, 60))
	sign(folder, Vector3.new(30, 0, 0), Vector3.new(-1, 0, 0), "🥋 DOJO ➡", c(230, 70, 70))
	sign(folder, Vector3.new(-30, 0, 0), Vector3.new(1, 0, 0), "⬅ SHOPS 🛒", c(60, 150, 255))
	sign(folder, Vector3.new(0, 0, 32), Vector3.new(0, 0, -1), "🥚 HATCHERY ⬇", c(220, 100, 200))

	-- Japanese plaza: torii at every exit, stone lanterns, pagoda, bell tower, koi pond, zen garden
	torii(folder, Vector3.new(0, 0.6, -36), 0)
	torii(folder, Vector3.new(0, 0.6, 36), 0)
	torii(folder, Vector3.new(36, 0.6, 0), 90)
	torii(folder, Vector3.new(-36, 0.6, 0), 90)
	for i = 0, 7 do
		local a = math.rad(i * 45 + 22.5)
		lantern(folder, Vector3.new(math.cos(a) * 31, 0.6, math.sin(a) * 31), 1.1)
	end
	place(folder, JapaneseBuilder.Pagoda(18, 5), CFrame.new(-50, 0, -50) * CFrame.Angles(0, math.rad(45), 0))
	place(folder, JapaneseBuilder.BellTower(12), CFrame.new(50, 0, -50) * CFrame.Angles(0, math.rad(-45), 0))
	place(folder, JapaneseBuilder.ZenGarden(18), CFrame.new(-50, 0, 50))
	for _, pos in { Vector3.new(-30, 0, -50), Vector3.new(-50, 0, -28), Vector3.new(30, 0, -52), Vector3.new(52, 0, -28),
		Vector3.new(30, 0, 52), Vector3.new(-30, 0, 52), Vector3.new(-52, 0, 28), Vector3.new(52, 0, 26) } do
		sakura(folder, pos, 2)
	end

	-- Stone roads
	local road = c(175, 170, 160)
	part(folder, { Name = "RoadNorth", Size = Vector3.new(16, 0.2, 110), Position = Vector3.new(0, 0.1, -90), Color = road, Material = Enum.Material.Cobblestone })
	part(folder, { Name = "RoadCross", Size = Vector3.new(360, 0.2, 16), Position = Vector3.new(0, 0.1, -142), Color = road, Material = Enum.Material.Cobblestone })
	part(folder, { Name = "RoadEast", Size = Vector3.new(120, 0.2, 16), Position = Vector3.new(95, 0.1, 0), Color = road, Material = Enum.Material.Cobblestone })
	part(folder, { Name = "RoadWest", Size = Vector3.new(120, 0.2, 16), Position = Vector3.new(-95, 0.1, 0), Color = road, Material = Enum.Material.Cobblestone })
	part(folder, { Name = "RoadSouth", Size = Vector3.new(16, 0.2, 100), Position = Vector3.new(0, 0.1, 85), Color = road, Material = Enum.Material.Cobblestone })
end

local function buildArena(world: Instance, arena: Arenas.ArenaDef)
	local folder = Instance.new("Folder")
	folder.Name = "Arena_" .. arena.Id
	folder.Parent = world
	local o = arena.Origin
	local isCosmic = arena.Order == 3
	local floorMaterial = isCosmic and Enum.Material.Slate or Enum.Material.Grass

	-- Floor with a launch trench in front of the pads (fruits fly up out of it).
	local trenchNear = Arenas.PadOffsetZ - Arenas.StageForward + 6 -- local z of trench edge nearest to the pads
	local trenchFar = Arenas.PadOffsetZ - Arenas.StageForward - 6
	local nearDepth = 40 - trenchNear
	part(folder, { Name = "FloorFront", Size = Vector3.new(110, 1, nearDepth), Position = o + Vector3.new(0, 0.5, trenchNear + nearDepth / 2), Color = arena.FloorColor, Material = floorMaterial })
	local farDepth = trenchFar + 26
	part(folder, { Name = "FloorBack", Size = Vector3.new(110, 1, farDepth), Position = o + Vector3.new(0, 0.5, -26 + farDepth / 2), Color = arena.FloorColor, Material = floorMaterial })
	part(folder, { Name = "TrenchBottom", Size = Vector3.new(110, 1, trenchNear - trenchFar), Position = o + Vector3.new(0, -8, (trenchNear + trenchFar) / 2), Color = c(30, 25, 40) })
	for _, z in { trenchNear, trenchFar } do
		part(folder, { Name = "TrenchEdge", Size = Vector3.new(110, 0.4, 0.6), Position = o + Vector3.new(0, 1.1, z), Color = arena.AccentColor, Material = Enum.Material.Neon, CanCollide = false })
	end
	-- carve the terrain out of the trench so fruit fly up from a real pit
	workspace.Terrain:FillBlock(CFrame.new(o + Vector3.new(0, -4, (trenchNear + trenchFar) / 2)), Vector3.new(112, 8, trenchNear - trenchFar), Enum.Material.Air)
	-- Trench walls so you can't see under the map
	part(folder, { Name = "TrenchWallNear", Size = Vector3.new(110, 9, 0.5), Position = o + Vector3.new(0, -3.5, trenchNear - 0.25), Color = c(50, 40, 60) })
	part(folder, { Name = "TrenchWallFar", Size = Vector3.new(110, 9, 0.5), Position = o + Vector3.new(0, -3.5, trenchFar + 0.25), Color = c(50, 40, 60) })

	-- Walls
	local wallColor = arena.AccentColor:Lerp(c(255, 255, 255), 0.25)
	local backdrop = part(folder, { Name = "Backdrop", Size = Vector3.new(110, 34, 2), Position = o + Vector3.new(0, 17, -27), Color = arena.BackdropColor, Material = isCosmic and Enum.Material.Neon or Enum.Material.SmoothPlastic })
	if isCosmic then
		backdrop.Transparency = 0.1
	end
	part(folder, { Name = "WallLeft", Size = Vector3.new(2, 14, 68), Position = o + Vector3.new(-56, 7, 7), Color = wallColor })
	part(folder, { Name = "WallRight", Size = Vector3.new(2, 14, 68), Position = o + Vector3.new(56, 7, 7), Color = wallColor })
	part(folder, { Name = "WallFrontL", Size = Vector3.new(40, 10, 2), Position = o + Vector3.new(-36, 5, 41), Color = wallColor })
	part(folder, { Name = "WallFrontR", Size = Vector3.new(40, 10, 2), Position = o + Vector3.new(36, 5, 41), Color = wallColor })
	part(folder, { Name = "PillarL", Size = Vector3.new(3, 18, 3), Position = o + Vector3.new(-16.5, 9, 41), Color = arena.AccentColor })
	part(folder, { Name = "PillarR", Size = Vector3.new(3, 18, 3), Position = o + Vector3.new(16.5, 9, 41), Color = arena.AccentColor })
	local beam = part(folder, { Name = "ArchBeam", Size = Vector3.new(36, 4, 3), Position = o + Vector3.new(0, 19, 41), Color = arena.AccentColor })
	surfaceText(beam, arena.DisplayName:upper(), c(255, 255, 255), { Enum.NormalId.Back, Enum.NormalId.Front })

	-- Big backdrop title
	local title = part(folder, { Name = "BackdropTitle", Size = Vector3.new(60, 7, 0.5), Position = o + Vector3.new(0, 29, -25.8), Color = arena.BackdropColor, Transparency = 1, CanCollide = false })
	surfaceText(title, "🍉 " .. arena.DisplayName .. " 🍍", c(255, 255, 255), { Enum.NormalId.Back })

	-- Japanese entrance: big torii + lanterns
	torii(folder, o + Vector3.new(0, 0, 50), 0, 26, 20)
	for _, sx in { -1, 1 } do
		lantern(folder, o + Vector3.new(sx * 20, 0, 47), 1.4)
	end
	if arena.Order == 1 then
		-- Mount Fuji and a red sun painted on the backdrop
		local sun = part(folder, { Name = "Sun", Shape = "Cylinder", Size = Vector3.new(0.4, 16, 16), CFrame = CFrame.new(o + Vector3.new(22, 25, -25.8)) * CFrame.Angles(0, math.rad(90), 0), Color = c(235, 60, 50), Material = Enum.Material.Neon, CanCollide = false })
		sun.Transparency = 0.1
		place(folder, JapaneseBuilder.Mountain(70, 24, 2), CFrame.new(o + Vector3.new(-6, 4, -25)))
	end

	-- Level gate (client makes it passable once the player's level is high enough)
	if arena.RequiredLevel > 1 then
		local gate = part(folder, { Name = "FNS_Gate", Size = Vector3.new(30, 17, 1), Position = o + Vector3.new(0, 8.5, 41), Color = c(255, 80, 80), Material = Enum.Material.ForceField })
		gate:SetAttribute("RequiredLevel", arena.RequiredLevel)
		gate:SetAttribute("ArenaId", arena.Id)
		local label = part(folder, { Name = "GateLabel", Size = Vector3.new(26, 5, 0.2), Position = o + Vector3.new(0, 9, 42), Transparency = 1, CanCollide = false })
		label:SetAttribute("GateFor", arena.Id)
		surfaceText(label, "🔒 LEVEL " .. arena.RequiredLevel .. " REQUIRED", c(255, 230, 230), { Enum.NormalId.Back, Enum.NormalId.Front })
	end

	-- Slicing pads
	for i = 1, arena.PadCount do
		local position = Arenas.GetPadPosition(arena, i)
		local pad = disc(folder, position + Vector3.new(0, 0.2, 0), 8, 0.5, arena.AccentColor, Enum.Material.Neon)
		pad.Name = "SlicePad" .. i
		disc(folder, position + Vector3.new(0, 0.05, 0), 9.5, 0.4, c(255, 255, 255))
		prompt(pad, "Start Slicing", arena.DisplayName, { Action = "Slice", Arena = arena.Id })
		if i == 1 or i == arena.PadCount then
			billboard(pad, "⚔️ SLICE HERE", "Step on a pad & press E / tap", c(255, 230, 90), 6)
		end
	end

	-- Decoration around the arena
	local fruitColors = { c(220, 40, 40), c(255, 140, 20), c(255, 225, 70), c(240, 40, 150) }
	for i = 0, 5 do
		local side = i % 2 == 0 and -1 or 1
		local z = -20 + (i // 2) * 25
		local position = o + Vector3.new(side * 64, 0, z)
		if arena.Order == 1 then
			sakura(folder, position, 2.3)
		elseif arena.Order == 2 then
			place(folder, JapaneseBuilder.Bamboo(10, i), CFrame.new(position))
		elseif isCosmic then
			part(folder, { Name = "Crystal", Size = Vector3.new(3, 14, 3), CFrame = CFrame.new(position + Vector3.new(0, 7, 0)) * CFrame.Angles(0, math.rad(45), math.rad(10)), Color = arena.AccentColor, Material = Enum.Material.Neon })
		else
			tree(folder, position, arena.Order == 2 and c(40, 170, 80) or c(70, 180, 60), fruitColors[i % #fruitColors + 1], 2)
		end
	end
end

local function buildDojo(world: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Dojo"
	folder.Parent = world
	local o = Training.DojoOrigin

	part(folder, { Name = "DojoFloor", Size = Vector3.new(100, 1, 80), Position = o + Vector3.new(0, 0.5, -10), Color = c(200, 150, 100), Material = Enum.Material.WoodPlanks })
	part(folder, { Name = "DojoMat", Size = Vector3.new(80, 0.2, 30), Position = o + Vector3.new(0, 1.1, -30), Color = c(150, 200, 120), Material = Enum.Material.Fabric })
	for _, x in { -48, 48 } do
		for _, z in { -48, 28 } do
			part(folder, { Name = "DojoPillar", Size = Vector3.new(3, 22, 3), Position = o + Vector3.new(x, 11, z), Color = c(200, 40, 40), Material = Enum.Material.Wood })
		end
	end
	part(folder, { Name = "DojoRoofBeam", Size = Vector3.new(104, 3, 3), Position = o + Vector3.new(0, 23, 28), Color = c(40, 30, 30), Material = Enum.Material.Wood })
	part(folder, { Name = "DojoRoofBeamBack", Size = Vector3.new(104, 3, 3), Position = o + Vector3.new(0, 23, -48), Color = c(40, 30, 30), Material = Enum.Material.Wood })
	local banner = part(folder, { Name = "DojoBanner", Size = Vector3.new(40, 6, 0.5), Position = o + Vector3.new(0, 18, 28.5), Color = c(40, 30, 30) })
	surfaceText(banner, "🥋 TRAINING DOJO 🥋", c(255, 220, 120), { Enum.NormalId.Back, Enum.NormalId.Front })

	for _, def in Training.List do
		local base = disc(folder, def.Station + Vector3.new(0, 1.2, 0), 10, 0.6, def.Color, Enum.Material.Neon)
		base.Name = "Station_" .. def.Id
		local dummy = part(folder, { Name = "Dummy", Size = Vector3.new(2, 5, 2), Position = def.Station + Vector3.new(0, 4, -3), Color = c(190, 140, 90), Material = Enum.Material.Wood })
		part(folder, { Name = "DummyHead", Shape = "Ball", Size = Vector3.one * 2.2, Position = def.Station + Vector3.new(0, 7.5, -3), Color = c(220, 180, 120), Material = Enum.Material.Fabric })
		prompt(base, "Train", def.DisplayName, { Action = "Train", Activity = def.Id })
		billboard(dummy, def.Emoji .. " " .. def.DisplayName, def.RequiredTrainingLevel > 1 and ("Training Lv. " .. def.RequiredTrainingLevel) or "Press E / tap to train", def.Color, 6.5)
	end

	-- Japanese touches: entrance torii, tiled roof over the training floor, lanterns
	torii(folder, o + Vector3.new(-56, 0, 0), 90, 16, 15)
	local roof = Instance.new("Model")
	roof.Name = "DojoRoof"
	JapaneseBuilder.Roof(roof, CFrame.new(o + Vector3.new(0, 24.5, -10)), 112, 88, 12, c(55, 58, 70), true)
	roof.Parent = folder
	for _, x in { -40, 40 } do
		for _, z in { -46, 24 } do
			lantern(folder, o + Vector3.new(x, 1, z), 1)
		end
	end

	-- Belt shop inside the dojo
	local counter = part(folder, { Name = "BeltCounter", Size = Vector3.new(14, 3.5, 4), Position = o + Vector3.new(0, 2.75, 12), Color = c(120, 70, 40), Material = Enum.Material.Wood })
	prompt(counter, "Open", "Belt Shop", { Action = "Open", Window = "Belts" })
	billboard(counter, "🥋 BELT SHOP", "Higher belts = faster training", c(255, 200, 90), 6)
	part(folder, { Name = "BeltRack", Size = Vector3.new(16, 7, 1), Position = o + Vector3.new(0, 4.5, 16), Color = c(80, 50, 30), Material = Enum.Material.Wood })
	local beltColors = { c(245, 245, 245), c(255, 225, 40), c(255, 140, 20), c(60, 190, 60), c(40, 120, 255), c(150, 60, 220), c(120, 70, 35), c(25, 25, 25) }
	for i, color in beltColors do
		part(folder, { Name = "BeltDisplay", Size = Vector3.new(1.4, 0.3, 0.3), Position = o + Vector3.new(-6.5 + (i - 1) * 1.85, 5, 15.4), Color = color, Material = Enum.Material.Fabric })
	end
end

local function buildShops(world: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Shops"
	folder.Parent = world
	local o = Vector3.new(-190, 0, 0)
	part(folder, { Name = "ShopFloor", Size = Vector3.new(90, 1, 70), Position = o + Vector3.new(0, 0.5, -10), Color = c(230, 230, 240), Material = Enum.Material.Marble })

	local function stall(offset: Vector3, title: string, subtitle: string, window: string, color: Color3)
		local base = o + offset
		local counter = part(folder, { Name = window .. "Counter", Size = Vector3.new(16, 3.5, 4), Position = base + Vector3.new(0, 2.75, 0), Color = color })
		part(folder, { Name = "StallBack", Size = Vector3.new(18, 12, 1), Position = base + Vector3.new(0, 7, -6), Color = color:Lerp(c(255, 255, 255), 0.5) })
		local roof = Instance.new("Model")
		roof.Name = "StallRoof"
		JapaneseBuilder.Roof(roof, CFrame.new(base + Vector3.new(0, 13, -2)), 24, 14, 4, c(60, 60, 70), true)
		roof.Parent = folder
		for _, x in { -11, 11 } do
			place(folder, JapaneseBuilder.PaperLantern(), CFrame.new(base + Vector3.new(x, 0, 4)) * CFrame.Angles(0, x > 0 and math.pi or 0, 0))
		end
		for _, x in { -9, 9 } do
			part(folder, { Name = "StallPole", Size = Vector3.new(1, 12, 1), Position = base + Vector3.new(x, 7, 2.5), Color = c(250, 250, 250) })
		end
		local signBoard = part(folder, { Name = "StallSign", Size = Vector3.new(16, 3, 0.4), Position = base + Vector3.new(0, 11.4, 3.2), Color = c(30, 30, 40) })
		surfaceText(signBoard, title, c(255, 255, 255), { Enum.NormalId.Back, Enum.NormalId.Front })
		prompt(counter, "Open", title, { Action = "Open", Window = window })
		billboard(counter, title, subtitle, color, 5)
		return base
	end

	torii(folder, o + Vector3.new(48, 0, 0), 90)
	local katanaBase = stall(Vector3.new(-20, 0, -25), "⚔️ KATANA SHOP", "Stronger blades = more coins", "Katanas", c(255, 140, 50))
	local displayKatanas = { "Iron", "Golden", "Diamond", "Fire" }
	for i, id in displayKatanas do
		local model = ModelBuilder.Katana(id)
		ModelBuilder.AnchorAll(model)
		model:PivotTo(CFrame.new(katanaBase + Vector3.new(-6 + (i - 1) * 4, 7, -5.3)) * CFrame.Angles(0, 0, math.rad(15)))
		model:ScaleTo(1.3)
		model.Parent = folder
	end
	stall(Vector3.new(20, 0, -25), "✨ TRAIL SHOP", "Trails make you faster", "Trails", c(160, 90, 255))
end

local function buildHatchery(world: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Hatchery"
	folder.Parent = world
	local o = Vector3.new(0, 0, 170)
	disc(folder, o + Vector3.new(0, 0.3, 0), 90, 0.6, c(255, 220, 240), Enum.Material.SmoothPlastic)
	disc(folder, o + Vector3.new(0, 0.5, 0), 70, 0.6, c(255, 240, 250), Enum.Material.SmoothPlastic)

	torii(folder, o + Vector3.new(0, 0, -36), 0, 16, 14)
	for i = 0, 9 do
		local a = math.rad(i * 36 + 18)
		if math.abs(math.cos(a)) < 0.95 or math.sin(a) > 0 then
			sakura(folder, o + Vector3.new(math.cos(a) * 52, 0, math.sin(a) * 52 + 4), 2)
		end
	end

	-- Incubator
	local incubator = disc(folder, o + Vector3.new(-16, 2, 10), 12, 3, c(255, 150, 200), Enum.Material.SmoothPlastic)
	incubator.Name = "Incubator"
	local egg = ModelBuilder.Egg(c(250, 245, 230), c(255, 200, 120), nil, 7)
	ModelBuilder.AnchorAll(egg)
	egg:PivotTo(CFrame.new(o + Vector3.new(-16, 7.5, 10)))
	egg.Parent = folder
	prompt(incubator, "Open", "My Eggs", { Action = "Open", Window = "Eggs" })
	billboard(incubator, "🥚 MY EGGS", "Slice eggs in arenas to collect them!", c(255, 200, 120), 11)

	-- Creature index / museum
	local museum = disc(folder, o + Vector3.new(16, 2, 10), 12, 3, c(140, 200, 255), Enum.Material.SmoothPlastic)
	museum.Name = "IndexPedestal"
	prompt(museum, "Open", "Creature Index", { Action = "Open", Window = "Index" })
	billboard(museum, "📖 CREATURE INDEX", "Discover all " .. #Creatures.List .. " creatures!", c(140, 200, 255), 11)
	local book = part(folder, { Name = "Book", Size = Vector3.new(5, 1, 4), CFrame = CFrame.new(o + Vector3.new(16, 4.2, 10)) * CFrame.Angles(math.rad(-20), 0, 0), Color = c(120, 60, 200) })
	book.CanCollide = false

	-- Pet management
	local petPad = disc(folder, o + Vector3.new(0, 1.5, 22), 10, 2, c(140, 255, 180), Enum.Material.SmoothPlastic)
	petPad.Name = "PetPedestal"
	prompt(petPad, "Open", "My Creatures", { Action = "Open", Window = "Pets" })
	billboard(petPad, "🐾 MY CREATURES", "Equip creatures for bonuses", c(140, 255, 180), 7)

	-- Showcase pedestals (common to legendary; rarer ones stay a mystery!)
	for i = 1, 5 do
		local rarity = Rarities.List[i]
		local creatureDef = Creatures.ByRarity[rarity.Name][1]
		local angle = math.rad(-60 + (i - 1) * 30)
		local position = o + Vector3.new(math.sin(angle) * 30, 0, -math.cos(angle) * 30 + 10)
		local pedestal = disc(folder, position + Vector3.new(0, 1.5, 0), 6, 3, rarity.Color, Enum.Material.SmoothPlastic)
		local model = ModelBuilder.Creature(creatureDef.Id)
		ModelBuilder.AnchorAll(model)
		model:ScaleTo(1.6)
		model:PivotTo(CFrame.lookAt(position + Vector3.new(0, 4.5, 0), o + Vector3.new(0, 4.5, -60)))
		local box, boxSize = model:GetBoundingBox()
		model:PivotTo(model:GetPivot() + Vector3.new(0, 3 - (box.Position.Y - boxSize.Y / 2), 0))
		model.Parent = folder
		billboard(pedestal, rarity.Name, creatureDef.DisplayName, rarity.Color, 7)
	end
end

local function buildVillage(world: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Village"
	folder.Parent = world
	part(folder, { Name = "VillageRoad", Size = Vector3.new(305, 0.2, 14), Position = Vector3.new(-155, 0.1, 122), Color = c(175, 170, 160), Material = Enum.Material.Cobblestone })
	part(folder, { Name = "VillageLane", Size = Vector3.new(220, 0.2, 10), Position = Vector3.new(-194, 0.1, 200), Color = c(175, 170, 160), Material = Enum.Material.Cobblestone })
	part(folder, { Name = "VillageLinkA", Size = Vector3.new(10, 0.2, 80), Position = Vector3.new(-79, 0.1, 160), Color = c(175, 170, 160), Material = Enum.Material.Cobblestone })
	local gate = torii(folder, Vector3.new(-30, 0, 122), 90, 18, 16)
	local gatePost = gate.PrimaryPart :: BasePart
	billboard(gatePost, "🏯 NINJA VILLAGE", "Build your own Japanese base!", c(255, 120, 90), 19)
	for x = -50, -300, -28 do
		lantern(folder, Vector3.new(x, 0, 113), 1)
		lantern(folder, Vector3.new(x - 14, 0, 131), 1)
	end
	for _, x in { -138, -194, -250 } do
		sakura(folder, Vector3.new(x, 0, 165), 1.1)
		sakura(folder, Vector3.new(x, 0, 235), 1.1)
	end
end

local function buildLake(world: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Lake"
	folder.Parent = world
	local terrain = workspace.Terrain
	local center = LAKE_CENTER
	-- terrain water (real waves + reflections) on a sandy bed
	terrain:FillCylinder(CFrame.new(center.X, -6.5, center.Z), 3, LAKE_RADIUS + 2, Enum.Material.Sand)
	terrain:FillCylinder(CFrame.new(center.X, -2.5, center.Z), 5, LAKE_RADIUS, Enum.Material.Water)
	-- stone shore
	local stones = math.floor(LAKE_RADIUS * 2.2)
	local rng = Random.new(5)
	for i = 0, stones - 1 do
		local a = i / stones * math.pi * 2
		local r = LAKE_RADIUS + rng:NextNumber(-0.5, 1)
		if math.abs(math.sin(a) * r) < 6.5 then
			continue -- leave room for the bridge ends
		end
		part(folder, { Name = "ShoreStone", Shape = "Ball", Size = Vector3.one * rng:NextNumber(1.4, 2.6),
			Position = Vector3.new(center.X + math.cos(a) * r, 0.1, center.Z + math.sin(a) * r), Color = c(130 + rng:NextInteger(0, 30), 130, 125), Material = Enum.Material.Slate })
	end
	-- lily pads and lotus flowers
	for i = 1, 16 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(5, LAKE_RADIUS - 3)
		local pos = Vector3.new(center.X + math.cos(a) * r, 0.05, center.Z + math.sin(a) * r)
		if math.abs(pos.Z - center.Z) > 7 then
			local size = rng:NextNumber(2, 3.2)
			part(folder, { Name = "LilyPad", Shape = "Cylinder", Size = Vector3.new(0.1, size, size), CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), Color = c(70, 160, 70), CanCollide = false })
			if i % 3 == 0 then
				for p = 0, 4 do
					part(folder, { Name = "Lotus", Shape = "Wedge", Size = Vector3.new(0.2, 0.9, 0.6), CanCollide = false,
						CFrame = CFrame.new(pos + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, math.rad(p * 72), 0) * CFrame.new(0, 0, 0.3) * CFrame.Angles(math.rad(-25), 0, 0), Color = c(255, 160, 200) })
				end
				part(folder, { Name = "LotusCore", Shape = "Ball", Size = Vector3.one * 0.5, Position = pos + Vector3.new(0, 0.5, 0), Color = c(255, 220, 90), Material = Enum.Material.Neon, CanCollide = false })
			end
		end
	end
	-- big arched red bridge across the lake (east-west)
	place(folder, JapaneseBuilder.Bridge(10, LAKE_RADIUS * 2 + 12), CFrame.new(center) * CFrame.Angles(0, math.rad(90), 0))
	for _, sx in { -1, 1 } do
		lantern(folder, center + Vector3.new(sx * (LAKE_RADIUS + 9), 0, 8), 1.2)
		lantern(folder, center + Vector3.new(sx * (LAKE_RADIUS + 9), 0, -8), 1.2)
	end
	for _, a in { 0.6, 2.2, 3.9, 5.3 } do
		sakura(folder, center + Vector3.new(math.cos(a) * (LAKE_RADIUS + 9), 0, math.sin(a) * (LAKE_RADIUS + 9)), 2.2)
	end
end

local function buildDecorHouses(world: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "DecorHouses"
	folder.Parent = world
	place(folder, JapaneseBuilder.Minka(24, 18), CFrame.new(-105, 0, -80) * CFrame.Angles(0, math.rad(25), 0))
	place(folder, JapaneseBuilder.TeaHouse(18), CFrame.new(105, 0, -80) * CFrame.Angles(0, math.rad(-30), 0))
	place(folder, JapaneseBuilder.Shrine(14), CFrame.new(-105, 0, 70) * CFrame.Angles(0, math.rad(200), 0))
	for _, pos in { Vector3.new(-90, 0, -100), Vector3.new(-125, 0, -62), Vector3.new(90, 0, -100), Vector3.new(122, 0, -64), Vector3.new(-90, 0, 88), Vector3.new(-122, 0, 55) } do
		sakura(folder, pos, 2.1)
	end
end

-- Low wooden fence along a straight line, skipping gaps (distances along the line).
local function fence(parent: Instance, from: Vector3, to: Vector3, gaps: { { number } }?)
	local direction = to - from
	local length = direction.Magnitude
	local unit = direction.Unit
	local spacing = 8
	local wood = c(125, 85, 55)
	local function inGap(d: number): boolean
		for _, gap in gaps or {} do
			if d >= gap[1] and d <= gap[2] then
				return true
			end
		end
		return false
	end
	local segmentStart: number? = nil
	local function closeSegment(d: number)
		if segmentStart and d - segmentStart > 1 then
			local mid = from + unit * ((segmentStart + d) / 2)
			for _, y in { 0.9, 1.7 } do
				part(parent, { Name = "FenceRail", Size = Vector3.new(0.25, 0.25, d - segmentStart), CFrame = CFrame.lookAt(mid + Vector3.new(0, y, 0), mid + Vector3.new(0, y, 0) + unit), Color = wood, Material = Enum.Material.Wood })
			end
		end
		segmentStart = nil
	end
	local d = 0
	while d <= length do
		if inGap(d) then
			closeSegment(d - spacing)
		else
			if not segmentStart then
				segmentStart = d
			end
			part(parent, { Name = "FencePost", Size = Vector3.new(0.5, 2.3, 0.5), Position = from + unit * d + Vector3.new(0, 1.15, 0), Color = wood:Lerp(c(0, 0, 0), 0.15), Material = Enum.Material.Wood })
		end
		d += spacing
	end
	closeSegment(math.min(d - spacing, length))
end

local function buildFences(world: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Fences"
	folder.Parent = world
	-- north road (x = 0, z -40 .. -134)
	for _, sx in { -1, 1 } do
		fence(folder, Vector3.new(sx * 9, 0, -40), Vector3.new(sx * 9, 0, -132))
		-- east / west roads (z = 0)
		fence(folder, Vector3.new(sx * 42, 0, 9), Vector3.new(sx * 132, 0, 9))
		fence(folder, Vector3.new(sx * 42, 0, -9), Vector3.new(sx * 132, 0, -9))
		-- south road (x = 0, z 42 .. 118)
		fence(folder, Vector3.new(sx * 9, 0, 42), Vector3.new(sx * 9, 0, 114))
	end
	-- cross road in front of the arenas: gaps for the three arena entrances and the north road
	fence(folder, Vector3.new(-230, 0, -133), Vector3.new(230, 0, -133), { { 44, 76 }, { 205, 255 }, { 384, 416 } })
end

local function buildScenery(world: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Scenery"
	folder.Parent = world
	local rng = Random.new(42)
	local fruitColors = { c(220, 40, 40), c(255, 140, 20), c(255, 225, 70), nil :: Color3? }
	for _ = 1, 46 do
		local x = rng:NextNumber(-300, 300)
		local z = rng:NextNumber(-280, 300)
		local clear = (math.abs(x) < 72 and math.abs(z) < 72) -- spawn plaza + pagoda / pond / garden
			or (z < -120 and z > -260 and math.abs(x) < 240) -- arenas
			or (math.abs(x - 190) < 60 and math.abs(z) < 60) -- dojo
			or (math.abs(x + 190) < 55 and math.abs(z) < 55) -- shops
			or (math.abs(x) < 55 and math.abs(z - 170) < 55) -- hatchery
			or (math.abs(x) < 12 or math.abs(z) < 12) -- roads
			or (math.abs(z + 142) < 12)
			or (x < -70 and x > -315 and z > 105 and z < 268) -- ninja village
			or (math.abs(z - 122) < 12 and x < 10) -- village road
			or ((Vector2.new(x, z) - Vector2.new(LAKE_CENTER.X, LAKE_CENTER.Z)).Magnitude < LAKE_RADIUS + 12) -- lake
			or (math.abs(x + 105) < 22 and math.abs(z + 80) < 22) or (math.abs(x - 105) < 20 and math.abs(z + 80) < 20)
			or (math.abs(x + 105) < 18 and math.abs(z - 70) < 18) -- decorative houses
		if not clear then
			local kind = rng:NextInteger(1, 3)
			if kind == 1 then
				sakura(folder, Vector3.new(x, 0, z), rng:NextNumber(1.9, 2.7))
			elseif kind == 2 then
				place(folder, JapaneseBuilder.Bamboo(9, rng:NextInteger(1, 999)), CFrame.new(x, 0, z))
			else
				tree(folder, Vector3.new(x, 0, z), c(60 + rng:NextInteger(0, 40), 170, 60), fruitColors[rng:NextInteger(1, 4)], rng:NextNumber(1.6, 2.4))
			end
		end
	end
	-- Map border (invisible walls so nobody falls off)
	for _, data in { { Vector3.new(0, 25, -330), Vector3.new(700, 50, 2) }, { Vector3.new(0, 25, 330), Vector3.new(700, 50, 2) }, { Vector3.new(-330, 25, 0), Vector3.new(2, 50, 700) }, { Vector3.new(330, 25, 0), Vector3.new(2, 50, 700) } } do
		part(folder, { Name = "Border", Position = data[1], Size = data[2], Transparency = 1 })
	end
end

local function setupLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.4
	Lighting.OutdoorAmbient = c(150, 150, 160)
	Lighting.Ambient = c(90, 90, 100)
	Lighting.GlobalShadows = true
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.25
		atmosphere.Haze = 0.6
		atmosphere.Color = c(200, 230, 255)
		atmosphere.Decay = c(120, 170, 230)
		atmosphere.Parent = Lighting
	end
	if not Lighting:FindFirstChild("FNS_Color") then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "FNS_Color"
		cc.Saturation = 0.15
		cc.Contrast = 0.05
		cc.Parent = Lighting
	end
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.ShadowSoftness = 0.25
	pcall(function()
		Lighting.Technology = Enum.Technology.Future -- may only be settable in Studio; see docs
	end)
	if not Lighting:FindFirstChildOfClass("SunRaysEffect") then
		local rays = Instance.new("SunRaysEffect")
		rays.Intensity = 0.06
		rays.Spread = 0.8
		rays.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.4
		bloom.Size = 20
		bloom.Threshold = 1.6
		bloom.Parent = Lighting
	end
end

function WorldBuilder.Init()
	setupLighting()
	if workspace:FindFirstChild("FNS_World") then
		return -- a saved / hand-edited copy exists: use it as-is
	end

	-- A brand-new Baseplate place has a 2048x16x2048 "Baseplate" and a "SpawnLocation": replace them.
	local default = workspace:FindFirstChild("Baseplate")
	if default and default:IsA("BasePart") and default.Size.X >= 2000 then
		default:Destroy()
	end
	for _, d in workspace:GetChildren() do
		if d:IsA("SpawnLocation") then
			d.Enabled = false
		end
	end

	local world = Instance.new("Model")
	world.Name = "FNS_World"
	-- Ground: real Terrain grass (with animated grass blades). A hidden safety floor sits below it.
	local terrain = workspace.Terrain
	terrain:FillBlock(CFrame.new(0, -4, 0), Vector3.new(700, 8, 700), Enum.Material.Grass)
	terrain:SetMaterialColor(Enum.Material.Grass, c(96, 168, 72))
	terrain:SetMaterialColor(Enum.Material.Cobblestone, c(150, 145, 138))
	terrain:SetMaterialColor(Enum.Material.Sand, c(214, 196, 150))
	terrain:SetMaterialColor(Enum.Material.Ground, c(120, 100, 75))
	terrain.WaterColor = c(40, 120, 130)
	terrain.WaterTransparency = 0.55
	terrain.WaterReflectance = 0.6
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 8
	local okDecoration = pcall(function()
		terrain.Decoration = true
	end)
	if not okDecoration then
		warn("[WorldBuilder] Enable grass blades manually: Workspace > Terrain > Properties > Decoration = true")
	end
	if not terrain:FindFirstChildOfClass("Clouds") then
		local clouds = Instance.new("Clouds")
		clouds.Cover = 0.55
		clouds.Density = 0.6
		clouds.Parent = terrain
	end
	local safety = part(world, { Name = "SafetyFloor", Size = Vector3.new(700, 2, 700), Position = Vector3.new(0, -9, 0), Color = c(96, 168, 72), Material = Enum.Material.Grass })
	safety.Transparency = 1

	buildSpawn(world)
	for _, arena in Arenas.List do
		buildArena(world, arena)
	end
	buildDojo(world)
	buildShops(world)
	buildHatchery(world)
	buildVillage(world)
	buildLake(world)
	buildDecorHouses(world)
	buildFences(world)
	buildScenery(world)
	-- Under flat floors (plazas, arenas, dojo, shops...) use bare terrain so grass blades can't poke through
	for _, d in world:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Root" and d.Transparency < 1 and d.Position.Y > -1 and d.Position.Y < 2.5 then
			local isDisc = d:IsA("Part") and d.Shape == Enum.PartType.Cylinder
			local width = isDisc and d.Size.Y or d.Size.X
			local depth = isDisc and d.Size.Z or d.Size.Z
			local thin = isDisc and d.Size.X <= 2 or d.Size.Y <= 2
			if thin and width * depth > 100 then
				local yaw = select(2, d.CFrame:ToOrientation())
				workspace.Terrain:FillBlock(CFrame.new(d.Position.X, -2, d.Position.Z) * CFrame.Angles(0, yaw, 0), Vector3.new(width, 4, depth), Enum.Material.Ground)
			end
		end
	end
	-- Paint every road part into cobblestone terrain (looks like real paving and hides grass blades)
	for _, d in world:GetDescendants() do
		if d:IsA("BasePart") and (d.Name:sub(1, 4) == "Road" or d.Name == "VillageRoad" or d.Name == "VillageLane" or d.Name == "VillageLinkA") then
			workspace.Terrain:FillBlock(CFrame.new(d.Position.X, -2, d.Position.Z), Vector3.new(d.Size.X, 4, d.Size.Z), Enum.Material.Cobblestone)
			d:Destroy()
		end
	end
	world.Parent = workspace

	-- Location markers (handy for future features / debugging)
	local markers = Instance.new("Folder")
	markers.Name = "Locations"
	markers.Parent = world
	for _, loc in Locations.List do
		local marker = Instance.new("Part")
		marker.Name = loc.Id
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanQuery = false
		marker.Transparency = 1
		marker.Size = Vector3.one
		marker.Position = loc.Position
		marker.Parent = markers
	end
end

function WorldBuilder.Start() end

return WorldBuilder
