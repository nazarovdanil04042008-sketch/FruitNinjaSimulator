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

local WorldBuilder = {}

local FONT = Enum.Font.FredokaOne

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

	-- Centrepiece: a giant watermelon with a giant katana stuck in it.
	disc(folder, Vector3.new(0, 1.5, -8), 16, 2, c(200, 190, 170), Enum.Material.Slate)
	part(folder, { Name = "GiantMelon", Shape = "Ball", Size = Vector3.one * 11, Position = Vector3.new(0, 7.5, -8), Color = c(40, 150, 50) })
	part(folder, { Name = "GiantMelonSlice", Shape = "Ball", Size = Vector3.one * 10.2, Position = Vector3.new(0, 7.7, -8.6), Color = c(255, 70, 90), CanCollide = false })
	local katana = ModelBuilder.Katana("Golden")
	ModelBuilder.AnchorAll(katana)
	katana:PivotTo(CFrame.new(1, 13, -8) * CFrame.Angles(0, math.rad(90), math.rad(-20)))
	katana:ScaleTo(4)
	katana.Parent = folder
	billboard(folder:FindFirstChild("GiantMelon") :: BasePart, "🍉 FRUIT NINJA SIMULATOR 🍉", "Slice fruit • Train • Hatch creatures!", c(255, 220, 70), 14)

	sign(folder, Vector3.new(0, 0, -30), Vector3.new(0, 0, 1), "⚔️ ARENAS ⬆", c(255, 120, 60))
	sign(folder, Vector3.new(30, 0, 0), Vector3.new(-1, 0, 0), "🥋 DOJO ➡", c(230, 70, 70))
	sign(folder, Vector3.new(-30, 0, 0), Vector3.new(1, 0, 0), "⬅ SHOPS 🛒", c(60, 150, 255))
	sign(folder, Vector3.new(0, 0, 32), Vector3.new(0, 0, -1), "🥚 HATCHERY ⬇", c(220, 100, 200))

	-- Roads
	local road = c(240, 215, 160)
	part(folder, { Name = "RoadNorth", Size = Vector3.new(16, 0.2, 110), Position = Vector3.new(0, 0.1, -90), Color = road, Material = Enum.Material.Sand })
	part(folder, { Name = "RoadCross", Size = Vector3.new(360, 0.2, 16), Position = Vector3.new(0, 0.1, -142), Color = road, Material = Enum.Material.Sand })
	part(folder, { Name = "RoadEast", Size = Vector3.new(120, 0.2, 16), Position = Vector3.new(95, 0.1, 0), Color = road, Material = Enum.Material.Sand })
	part(folder, { Name = "RoadWest", Size = Vector3.new(120, 0.2, 16), Position = Vector3.new(-95, 0.1, 0), Color = road, Material = Enum.Material.Sand })
	part(folder, { Name = "RoadSouth", Size = Vector3.new(16, 0.2, 100), Position = Vector3.new(0, 0.1, 85), Color = road, Material = Enum.Material.Sand })
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
		if isCosmic then
			part(folder, { Name = "Crystal", Size = Vector3.new(3, 14, 3), CFrame = CFrame.new(position + Vector3.new(0, 7, 0)) * CFrame.Angles(0, math.rad(45), math.rad(10)), Color = arena.AccentColor, Material = Enum.Material.Neon })
		else
			tree(folder, position, arena.Order == 2 and c(40, 170, 80) or c(70, 180, 60), fruitColors[i % #fruitColors + 1], 1.2)
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
		part(folder, { Name = "StallRoof", Size = Vector3.new(20, 1, 10), Position = base + Vector3.new(0, 13, -2), Color = color })
		for _, x in { -9, 9 } do
			part(folder, { Name = "StallPole", Size = Vector3.new(1, 12, 1), Position = base + Vector3.new(x, 7, 2.5), Color = c(250, 250, 250) })
		end
		local signBoard = part(folder, { Name = "StallSign", Size = Vector3.new(16, 3, 0.4), Position = base + Vector3.new(0, 15.5, 2.8), Color = c(30, 30, 40) })
		surfaceText(signBoard, title, c(255, 255, 255), { Enum.NormalId.Back, Enum.NormalId.Front })
		prompt(counter, "Open", title, { Action = "Open", Window = window })
		billboard(counter, title, subtitle, color, 5)
		return base
	end

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
		model:PivotTo(CFrame.lookAt(position + Vector3.new(0, 4.5, 0), o + Vector3.new(0, 4.5, -60)))
		model:ScaleTo(1.6)
		model.Parent = folder
		billboard(pedestal, rarity.Name, creatureDef.DisplayName, rarity.Color, 7)
	end
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
		local clear = (math.abs(x) < 60 and math.abs(z) < 60) -- spawn plaza
			or (z < -120 and z > -260 and math.abs(x) < 240) -- arenas
			or (math.abs(x - 190) < 60 and math.abs(z) < 60) -- dojo
			or (math.abs(x + 190) < 55 and math.abs(z) < 55) -- shops
			or (math.abs(x) < 55 and math.abs(z - 170) < 55) -- hatchery
			or (math.abs(x) < 12 or math.abs(z) < 12) -- roads
			or (math.abs(z + 142) < 12)
		if not clear then
			tree(folder, Vector3.new(x, 0, z), c(60 + rng:NextInteger(0, 40), 170, 60), fruitColors[rng:NextInteger(1, 4)], rng:NextNumber(0.9, 1.5))
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
	part(world, { Name = "Ground", Size = Vector3.new(700, 4, 700), Position = Vector3.new(0, -2, 0), Color = c(110, 200, 90), Material = Enum.Material.Grass })

	buildSpawn(world)
	for _, arena in Arenas.List do
		buildArena(world, arena)
	end
	buildDojo(world)
	buildShops(world)
	buildHatchery(world)
	buildScenery(world)
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
