--!nonstrict
-- Procedural Japanese-style architecture and nature: torii gates, pagodas, houses, shrines, lanterns,
-- sakura trees, bamboo, bonsai, zen gardens, koi ponds, bridges, bell towers, mountains.
-- Every model is built around its origin = centre of its footprint at floor level, all parts anchored,
-- with an invisible "Root" PrimaryPart. Used by WorldBuilder (map), BuildingService (player plots)
-- and BuildController (placement preview). If ReplicatedStorage.Assets.Buildings has a model with the
-- same name as a building id, that model is used instead (see ModelBuilder.GetOverride).

local JapaneseBuilder = {}

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

JapaneseBuilder.Colors = {
	Vermilion = c(205, 50, 35),
	Black = c(35, 30, 30),
	Wood = c(120, 80, 50),
	DarkWood = c(70, 45, 30),
	Roof = c(55, 58, 70),
	Stone = c(150, 150, 145),
	Plaster = c(245, 240, 228),
	Shoji = c(250, 246, 232),
	Gold = c(230, 185, 60),
	Sakura = { c(255, 183, 205), c(255, 160, 190), c(250, 205, 220), c(255, 140, 180) },
}
local COL = JapaneseBuilder.Colors


------------------------------------------------------------------------------------------------
-- Part helpers
------------------------------------------------------------------------------------------------
local function part(model: Model, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?, kind: string?, collide: boolean?): BasePart
	local p: BasePart
	if kind == "Wedge" then
		p = Instance.new("WedgePart")
	else
		local inst = Instance.new("Part")
		if kind == "Ball" then
			inst.Shape = Enum.PartType.Ball
		elseif kind == "Cylinder" then
			inst.Shape = Enum.PartType.Cylinder
		end
		p = inst
	end
	p.Anchored = true
	p.CanCollide = collide ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = model
	return p
end
JapaneseBuilder.Part = part

-- Vertical cylinder centred at `position`.
local function post(model: Model, position: Vector3, height: number, diameter: number, color: Color3, material: Enum.Material?, collide: boolean?): BasePart
	return part(model, CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(height, diameter, diameter), color, material, "Cylinder", collide)
end
JapaneseBuilder.Post = post

local function newModel(name: string, width: number, depth: number): Model
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Transparency = 1
	root.Size = Vector3.new(width, 0.2, depth)
	root.CFrame = CFrame.new(0, 0.1, 0)
	root.Parent = model
	model.PrimaryPart = root
	return model
end

local function light(parent: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = parent
end

------------------------------------------------------------------------------------------------
-- Roof: hip roof with ridge, eaves and upturned corners. `cf` = centre of the eave line.
------------------------------------------------------------------------------------------------
function JapaneseBuilder.Roof(model: Model, cf: CFrame, width: number, depth: number, height: number, color: Color3?, flare: boolean?)
	local roofColor = color or COL.Roof
	local slate = Enum.Material.Slate
	part(model, cf, Vector3.new(width, 0.35, depth), COL.DarkWood, Enum.Material.Wood)
	local y = 0.17 + height / 2
	part(model, cf * CFrame.new(0, y, -depth / 4), Vector3.new(width, height, depth / 2), roofColor, slate, "Wedge")
	part(model, cf * CFrame.new(0, y, depth / 4) * CFrame.Angles(0, math.pi, 0), Vector3.new(width, height, depth / 2), roofColor, slate, "Wedge")
	part(model, cf * CFrame.new(-width / 4, y, 0) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(depth, height, width / 2), roofColor, slate, "Wedge")
	part(model, cf * CFrame.new(width / 4, y, 0) * CFrame.Angles(0, -math.pi / 2, 0), Vector3.new(depth, height, width / 2), roofColor, slate, "Wedge")
	local ridgeLength = math.max(width - depth, 0) + math.min(width, depth) * 0.15
	part(model, cf * CFrame.new(0, height + 0.25, 0), Vector3.new(ridgeLength, 0.5, 0.7), COL.Black, slate)
	if flare ~= false then
		-- upturned corner tips
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local yaw = math.atan2(sx, sz)
				local tipSize = math.max(0.8, math.min(width, depth) * 0.09)
				part(model, cf * CFrame.new(sx * (width / 2 - tipSize * 0.3), 0.35, sz * (depth / 2 - tipSize * 0.3)) * CFrame.Angles(0, yaw, 0),
					Vector3.new(tipSize * 0.6, tipSize * 1.2, tipSize * 1.6), roofColor, slate, "Wedge", false)
			end
		end
	end
end

------------------------------------------------------------------------------------------------
-- Nature & small decor
------------------------------------------------------------------------------------------------
function JapaneseBuilder.Torii(width: number?, height: number?): Model
	local w = width or 10
	local h = height or 10
	local model = newModel("Torii", w, 1.5)
	local pillar = math.max(0.7, w * 0.08)
	for _, sx in { -1, 1 } do
		post(model, Vector3.new(sx * w * 0.38, h / 2, 0), h, pillar, COL.Vermilion)
		post(model, Vector3.new(sx * w * 0.38, 0.4, 0), 0.8, pillar * 1.25, COL.Black)
	end
	-- nuki (lower beam) and gakuzuka (centre strut)
	part(model, CFrame.new(0, h * 0.72, 0), Vector3.new(w * 0.95, pillar * 0.7, pillar * 0.6), COL.Vermilion)
	part(model, CFrame.new(0, h * 0.8, 0), Vector3.new(pillar * 0.8, h * 0.16, pillar * 0.5), COL.Vermilion)
	-- shimaki (red) + kasagi (black top beam) with upturned ends
	part(model, CFrame.new(0, h * 0.9, 0), Vector3.new(w * 1.15, pillar * 0.6, pillar * 0.9), COL.Vermilion)
	part(model, CFrame.new(0, h * 0.9 + pillar * 0.6, 0), Vector3.new(w * 1.2, pillar * 0.6, pillar * 1.1), COL.Black)
	for _, sx in { -1, 1 } do
		part(model, CFrame.new(sx * w * 0.66, h * 0.9 + pillar * 0.75, 0) * CFrame.Angles(0, sx * -math.pi / 2, 0),
			Vector3.new(pillar * 1.1, pillar * 0.9, w * 0.12), COL.Black, nil, "Wedge")
	end
	return model
end

function JapaneseBuilder.StoneLantern(scale: number?): Model
	local s = scale or 1
	local model = newModel("StoneLantern", 2.4 * s, 2.4 * s)
	local stone = Enum.Material.Slate
	part(model, CFrame.new(0, 0.3 * s, 0), Vector3.new(2.2, 0.6, 2.2) * s, COL.Stone, stone)
	post(model, Vector3.new(0, 1.6 * s, 0), 2 * s, 0.8 * s, COL.Stone, stone)
	part(model, CFrame.new(0, 2.75 * s, 0), Vector3.new(2, 0.4, 2) * s, COL.Stone, stone)
	local box = part(model, CFrame.new(0, 3.55 * s, 0), Vector3.new(1.3, 1.2, 1.3) * s, c(255, 200, 110), Enum.Material.Neon)
	light(box, c(255, 180, 90), 14 * s, 1.6)
	for _, sx in { -1, 1 } do
		part(model, CFrame.new(sx * 0.55 * s, 3.55 * s, 0), Vector3.new(0.25, 1.2, 1.5) * s, COL.Stone, stone)
	end
	JapaneseBuilder.Roof(model, CFrame.new(0, 4.25 * s, 0), 2.8 * s, 2.8 * s, 0.9 * s, COL.Stone, true)
	part(model, CFrame.new(0, 5.4 * s, 0), Vector3.one * 0.5 * s, COL.Stone, stone, "Ball")
	return model
end

function JapaneseBuilder.PaperLantern(): Model
	local model = newModel("PaperLantern", 3, 3)
	post(model, Vector3.new(0, 3.5, 0), 7, 0.4, COL.DarkWood, Enum.Material.Wood)
	part(model, CFrame.new(0.7, 6.8, 0), Vector3.new(1.8, 0.25, 0.25), COL.DarkWood, Enum.Material.Wood)
	local lantern = part(model, CFrame.new(1.4, 5.6, 0), Vector3.new(1.3, 1.8, 1.3), COL.Vermilion, Enum.Material.SmoothPlastic, nil, false)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = lantern
	light(lantern, c(255, 120, 80), 12, 1.4)
	part(model, CFrame.new(1.4, 6.5, 0), Vector3.new(0.9, 0.2, 0.9), COL.Black, nil, nil, false)
	part(model, CFrame.new(1.4, 4.7, 0), Vector3.new(0.9, 0.2, 0.9), COL.Black, nil, nil, false)
	return model
end

function JapaneseBuilder.Sakura(scale: number?, seed: number?): Model
	-- Natural-looking cherry tree: thick leaning trunk, several branches, and a canopy made of many
	-- blossom clusters of very different sizes (big puffs + small ones) instead of a few equal balls.
	local s = scale or 1
	local rng = Random.new(seed or 7)
	local model = newModel("SakuraTree", 7 * s, 7 * s)
	local bark = c(78, 48, 42)
	local lean = rng:NextNumber(-8, 8)
	part(model, CFrame.new(0, 2.6 * s, 0) * CFrame.Angles(0, 0, math.rad(90 + lean)), Vector3.new(5.2 * s, 1.4 * s, 1.4 * s), bark, Enum.Material.Wood, "Cylinder")
	for i = 0, 2 do
		local a = math.rad(i * 120 + 40)
		part(model, CFrame.Angles(0, a, 0) * CFrame.new(0, 0.5 * s, -0.9 * s), Vector3.new(0.6 * s, 1 * s, 1.2 * s), bark, Enum.Material.Wood, "Wedge", false)
	end
	local topPos = Vector3.new(-math.sin(math.rad(lean)) * 5 * s, 5 * s, 0)
	local branchCount = rng:NextInteger(4, 6)
	local blossomIndex = 0
	local function blossom(position: Vector3, size: number)
		blossomIndex += 1
		local color = COL.Sakura[rng:NextInteger(1, #COL.Sakura)]
		local p = part(model, CFrame.new(position), Vector3.one * size, color, Enum.Material.Grass, "Ball", false)
		if blossomIndex == 1 then
			p.Name = "SakuraCrown" -- falling petals are rendered client-side (AmbienceController)
		end
	end
	for i = 1, branchCount do
		local yaw = i / branchCount * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local pitch = math.rad(rng:NextNumber(25, 50))
		local length = rng:NextNumber(3.5, 5.5) * s
		local direction = Vector3.new(math.cos(yaw) * math.cos(pitch), math.sin(pitch), math.sin(yaw) * math.cos(pitch))
		local startPos = topPos + Vector3.new(0, rng:NextNumber(-1, 0.5) * s, 0)
		local endPos = startPos + direction * length
		local mid = (startPos + endPos) / 2
		part(model, CFrame.lookAt(mid, endPos) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(length, 0.55 * s, 0.55 * s), bark, Enum.Material.Wood, "Cylinder", false)
		-- one big puff + several medium/small ones around the branch tip
		blossom(endPos + Vector3.new(0, 0.6 * s, 0), rng:NextNumber(3.2, 4.4) * s)
		for _ = 1, rng:NextInteger(3, 5) do
			local offset = Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(-1, 1.6), rng:NextNumber(-2, 2)) * s
			blossom(endPos + offset, rng:NextNumber(1, 2.6) * s)
		end
	end
	-- fill the centre of the crown and a few hanging tufts
	blossom(topPos + Vector3.new(0, 3.2 * s, 0), 4.2 * s)
	for _ = 1, 4 do
		local a = rng:NextNumber(0, math.pi * 2)
		blossom(topPos + Vector3.new(math.cos(a) * 2.5 * s, rng:NextNumber(0.5, 3) * s, math.sin(a) * 2.5 * s), rng:NextNumber(0.8, 1.8) * s)
	end
	return model
end

function JapaneseBuilder.Bamboo(width: number?, seed: number?): Model
	local w = width or 8
	local rng = Random.new(seed or 3)
	local model = newModel("BambooGrove", w, w)
	for _ = 1, math.floor(w * 0.9) do
		local x, z = rng:NextNumber(-w / 2 + 0.6, w / 2 - 0.6), rng:NextNumber(-w / 2 + 0.6, w / 2 - 0.6)
		local h = rng:NextNumber(12, 19)
		local green = c(rng:NextInteger(80, 110), rng:NextInteger(150, 180), rng:NextInteger(60, 80))
		post(model, Vector3.new(x, h / 2, z), h, 0.45, green, Enum.Material.SmoothPlastic, false)
		for y = 2.5, h - 1, 2.6 do
			post(model, Vector3.new(x, y, z), 0.18, 0.55, green:Lerp(c(255, 255, 220), 0.25), nil, false)
		end
		for i = 0, 2 do
			part(model, CFrame.new(x, h - i * 0.9, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), math.rad(-60)), Vector3.new(0.1, 1.6, 0.5), c(90, 170, 70), nil, "Wedge", false)
		end
	end
	return model
end

function JapaneseBuilder.Bonsai(): Model
	local model = newModel("Bonsai", 3.6, 3.6)
	part(model, CFrame.new(0, 0.5, 0), Vector3.new(3, 1, 2), c(40, 60, 110))
	part(model, CFrame.new(0, 1.05, 0), Vector3.new(2.7, 0.1, 1.7), c(70, 50, 35), Enum.Material.Ground)
	part(model, CFrame.new(-0.2, 1.7, 0) * CFrame.Angles(0, 0, math.rad(70)), Vector3.new(1.6, 0.35, 0.35), c(90, 60, 45), Enum.Material.Wood, "Cylinder", false)
	part(model, CFrame.new(0.3, 2.4, 0) * CFrame.Angles(0, 0, math.rad(120)), Vector3.new(1.2, 0.3, 0.3), c(90, 60, 45), Enum.Material.Wood, "Cylinder", false)
	for i, data in { { -0.6, 2.6, 1.6 }, { 0.6, 3, 1.4 }, { 0, 3.4, 1.2 } } do
		local canopy = part(model, CFrame.new(data[1], data[2], 0), Vector3.new(data[3] * 1.4, data[3] * 0.6, data[3]), c(60, 140 + i * 10, 60), Enum.Material.Grass, nil, false)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = canopy
	end
	return model
end

function JapaneseBuilder.ZenGarden(size: number?): Model
	local s = size or 12
	local model = newModel("ZenGarden", s, s)
	part(model, CFrame.new(0, 0.15, 0), Vector3.new(s, 0.3, s), c(235, 228, 210), Enum.Material.Sand)
	for i = 1, math.floor(s / 1.2) - 1 do
		part(model, CFrame.new(0, 0.31, -s / 2 + i * 1.2), Vector3.new(s - 1.2, 0.04, 0.18), c(205, 195, 175), Enum.Material.Sand, nil, false)
	end
	for _, side in { { 0, s / 2 }, { 0, -s / 2 }, { s / 2, 0 }, { -s / 2, 0 } } do
		local horizontal = side[1] == 0
		part(model, CFrame.new(side[1], 0.35, side[2]), horizontal and Vector3.new(s, 0.7, 0.5) or Vector3.new(0.5, 0.7, s), COL.DarkWood, Enum.Material.Wood)
	end
	for _, rock in { { -s * 0.22, -s * 0.15, 2.4 }, { s * 0.25, s * 0.18, 1.8 }, { s * 0.05, s * 0.3, 1.2 } } do
		part(model, CFrame.new(rock[1], rock[3] * 0.25, rock[2]), Vector3.one * rock[3], c(110, 110, 105), Enum.Material.Slate, "Ball")
		part(model, CFrame.new(rock[1], 0.32, rock[2]) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.1, rock[3] * 1.5, rock[3] * 1.5), c(80, 130, 60), Enum.Material.Grass, "Cylinder", false)
	end
	return model
end

function JapaneseBuilder.KoiPond(size: number?): Model
	local s = size or 12
	local model = newModel("KoiPond", s, s)
	local radius = s / 2 - 0.8
	local water = part(model, CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.3, radius * 2, radius * 2), c(60, 150, 200), Enum.Material.Glass, "Cylinder", false)
	water.Transparency = 0.25
	part(model, CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.1, radius * 2, radius * 2), c(30, 70, 90), nil, "Cylinder", false)
	local stones = math.floor(radius * 3.2)
	for i = 0, stones - 1 do
		local a = i / stones * math.pi * 2
		part(model, CFrame.new(math.cos(a) * (radius + 0.3), 0.35, math.sin(a) * (radius + 0.3)), Vector3.one * (0.9 + (i % 3) * 0.2), c(140 + (i % 2) * 20, 140, 135), Enum.Material.Slate, "Ball")
	end
	for i, koi in { { 1.5, 0.8, c(255, 120, 30) }, { -1.8, -1, c(250, 250, 245) }, { 0.2, -2.2, c(255, 90, 40) } } do
		local fish = part(model, CFrame.new(koi[1], 0.38, koi[2]) * CFrame.Angles(0, i * 1.7, 0), Vector3.new(0.5, 0.25, 1.3), koi[3], nil, nil, false)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = fish
	end
	for _, pad in { { -1, 2, 1.4 }, { 2.3, -1.6, 1.1 } } do
		part(model, CFrame.new(pad[1], 0.37, pad[2]) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.05, pad[3], pad[3]), c(70, 160, 70), nil, "Cylinder", false)
	end
	return model
end

function JapaneseBuilder.Bridge(width: number?, length: number?): Model
	local w = width or 7
	local l = length or 16
	local model = newModel("Bridge", w, l)
	local segments = 10
	local rise = l * 0.18
	local function heightAt(t: number): number
		return math.sin(t * math.pi) * rise
	end
	for i = 0, segments - 1 do
		local t0, t1 = i / segments, (i + 1) / segments
		local z0, z1 = -l / 2 + t0 * l, -l / 2 + t1 * l
		local y0, y1 = heightAt(t0), heightAt(t1)
		local mid = Vector3.new(0, (y0 + y1) / 2 + 0.3, (z0 + z1) / 2)
		local cf = CFrame.lookAt(mid, mid + Vector3.new(0, y1 - y0, z1 - z0))
		part(model, cf, Vector3.new(w - 1, 0.5, (Vector3.new(0, y1 - y0, z1 - z0)).Magnitude + 0.1), COL.Wood, Enum.Material.WoodPlanks)
		for _, sx in { -1, 1 } do
			part(model, cf * CFrame.new(sx * (w / 2 - 0.4), 1.4, 0), Vector3.new(0.35, 0.35, (Vector3.new(0, y1 - y0, z1 - z0)).Magnitude + 0.1), COL.Vermilion, nil, nil, false)
			if i % 2 == 0 then
				post(model, Vector3.new(sx * (w / 2 - 0.4), y0 + 1, z0), 2, 0.4, COL.Vermilion, nil, false)
			end
		end
	end
	for _, sx in { -1, 1 } do
		post(model, Vector3.new(sx * (w / 2 - 0.4), 1, l / 2), 2, 0.4, COL.Vermilion, nil, false)
		part(model, CFrame.new(sx * (w / 2 - 0.4), 2.15, l / 2), Vector3.new(0.5, 0.3, 0.5), COL.Gold, Enum.Material.Metal, nil, false)
		part(model, CFrame.new(sx * (w / 2 - 0.4), 2.15, -l / 2), Vector3.new(0.5, 0.3, 0.5), COL.Gold, Enum.Material.Metal, nil, false)
	end
	return model
end

-- Massive tree: thick tapered trunk with roots, several long branches, big foliage clusters.
function JapaneseBuilder.BigTree(scale: number?, seed: number?, leafColors: { Color3 }?): Model
	local s = scale or 1
	local rng = Random.new(seed or 1)
	local model = newModel("BigTree", 10 * s, 10 * s)
	local bark = c(95, 65, 45)
	local leaves = leafColors or { c(70, 150, 60), c(85, 165, 70), c(60, 135, 55), c(100, 175, 80) }
	-- roots
	for i = 0, 4 do
		local a = math.rad(i * 72 + rng:NextNumber(-15, 15))
		part(model, CFrame.Angles(0, a, 0) * CFrame.new(0, 0.9 * s, -1.9 * s), Vector3.new(1 * s, 1.8 * s, 2.4 * s), bark, Enum.Material.Wood, "Wedge", false)
	end
	-- trunk (two tapered pieces with a slight lean)
	local lean = rng:NextNumber(-6, 6)
	part(model, CFrame.new(0, 5 * s, 0) * CFrame.Angles(0, 0, math.rad(90 + lean)), Vector3.new(10 * s, 2.8 * s, 2.8 * s), bark, Enum.Material.Wood, "Cylinder")
	local topY = 10 * s
	local topX = -math.sin(math.rad(lean)) * 10 * s
	part(model, CFrame.new(topX * 0.9, 13 * s, 0) * CFrame.Angles(0, 0, math.rad(90 - lean)), Vector3.new(7 * s, 2 * s, 2 * s), bark, Enum.Material.Wood, "Cylinder", false)
	-- branches + foliage clusters at their ends
	local branchCount = rng:NextInteger(5, 7)
	for i = 1, branchCount do
		local yaw = (i / branchCount) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local pitch = math.rad(rng:NextNumber(30, 55))
		local length = rng:NextNumber(6, 9) * s
		local startPos = Vector3.new(topX * 0.7, topY + rng:NextNumber(0, 5) * s, 0)
		local direction = Vector3.new(math.cos(yaw) * math.cos(pitch), math.sin(pitch), math.sin(yaw) * math.cos(pitch))
		local endPos = startPos + direction * length
		local mid = (startPos + endPos) / 2
		part(model, CFrame.lookAt(mid, endPos) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(length, 0.9 * s, 0.9 * s), bark, Enum.Material.Wood, "Cylinder", false)
		part(model, CFrame.new(endPos + Vector3.new(0, 1, 0) * s), Vector3.one * rng:NextNumber(6, 8) * s, leaves[rng:NextInteger(1, #leaves)], Enum.Material.Grass, "Ball", false)
		for _ = 1, rng:NextInteger(3, 5) do
			local size = rng:NextNumber(2, 4.5) * s
			local offset = Vector3.new(rng:NextNumber(-3.5, 3.5), rng:NextNumber(-1.5, 2.5), rng:NextNumber(-3.5, 3.5)) * s
			part(model, CFrame.new(endPos + offset), Vector3.one * size, leaves[rng:NextInteger(1, #leaves)], Enum.Material.Grass, "Ball", false)
		end
	end
	-- crown
	for k = 1, 3 do
		part(model, CFrame.new(topX + rng:NextNumber(-2, 2) * s, topY + 9 * s + k * 1.5 * s, rng:NextNumber(-2, 2) * s), Vector3.one * rng:NextNumber(7, 9) * s,
			leaves[rng:NextInteger(1, #leaves)], Enum.Material.Grass, "Ball", false)
	end
	return model
end

-- Round bush made of a few overlapping balls, optionally with flowers (azalea style).
function JapaneseBuilder.Bush(scale: number?, seed: number?, flowerColor: Color3?): Model
	local s = scale or 1
	local rng = Random.new(seed or 2)
	local model = newModel("Bush", 4 * s, 4 * s)
	local green = c(rng:NextInteger(55, 80), rng:NextInteger(130, 160), rng:NextInteger(50, 65))
	for _ = 1, 4 do
		local size = rng:NextNumber(1.8, 2.8) * s
		local pos = Vector3.new(rng:NextNumber(-1, 1) * s, size * 0.35, rng:NextNumber(-1, 1) * s)
		part(model, CFrame.new(pos), Vector3.one * size, green, Enum.Material.Grass, "Ball", false)
	end
	if flowerColor then
		for _ = 1, 9 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(0.6, 1.5) * s
			part(model, CFrame.new(math.cos(a) * r, rng:NextNumber(1, 2) * s, math.sin(a) * r), Vector3.one * 0.45 * s, flowerColor, nil, "Ball", false)
		end
	end
	return model
end

-- Cluster of reeds / cattails for lake shores.
function JapaneseBuilder.Reeds(radius: number?, seed: number?): Model
	local r = radius or 2.5
	local rng = Random.new(seed or 4)
	local model = newModel("Reeds", r * 2, r * 2)
	for _ = 1, math.floor(r * 6) do
		local x, z = rng:NextNumber(-r, r), rng:NextNumber(-r, r)
		local h = rng:NextNumber(3, 5.5)
		local tilt = CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), 0, math.rad(rng:NextNumber(-8, 8)))
		local base = CFrame.new(x, 0, z) * tilt
		part(model, base * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(h, 0.15, 0.15), c(110, 150, 70), nil, "Cylinder", false)
		if rng:NextNumber() < 0.5 then
			part(model, base * CFrame.new(0, h - 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.9, 0.32, 0.32), c(110, 70, 40), nil, "Cylinder", false)
		end
	end
	return model
end

-- Tall wooden post with a crossbar and two glowing red paper lanterns.
function JapaneseBuilder.RedLanternPost(height: number?): Model
	local h = height or 11
	local model = newModel("RedLanternPost", 2, 2)
	post(model, Vector3.new(0, h / 2, 0), h, 0.5, COL.DarkWood, Enum.Material.Wood)
	part(model, CFrame.new(0, h - 0.6, 0), Vector3.new(4.4, 0.35, 0.35), COL.DarkWood, Enum.Material.Wood, nil, false)
	part(model, CFrame.new(0, h + 0.1, 0), Vector3.new(1.2, 0.4, 1.2), COL.Black, nil, nil, false)
	for _, sx in { -1, 1 } do
		local lanternPos = Vector3.new(sx * 1.8, h - 2.1, 0)
		part(model, CFrame.new(lanternPos + Vector3.new(0, 0.95, 0)), Vector3.new(0.1, 0.6, 0.1), COL.Black, nil, nil, false)
		local lantern = part(model, CFrame.new(lanternPos), Vector3.new(1.3, 1.7, 1.3), c(220, 35, 30), Enum.Material.Neon, nil, false)
		lantern.Transparency = 0.05
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = lantern
		part(model, CFrame.new(lanternPos + Vector3.new(0, 0.9, 0)), Vector3.new(0.8, 0.15, 0.8), COL.Black, nil, nil, false)
		part(model, CFrame.new(lanternPos - Vector3.new(0, 0.9, 0)), Vector3.new(0.8, 0.15, 0.8), COL.Black, nil, nil, false)
		light(lantern, c(255, 90, 60), 14, 1.3)
	end
	return model
end

------------------------------------------------------------------------------------------------
-- Buildings
------------------------------------------------------------------------------------------------
-- Shoji wall panel facing -Z of `cf` (white paper with a dark wooden lattice).
local function shojiWall(model: Model, cf: CFrame, width: number, height: number)
	part(model, cf, Vector3.new(width, height, 0.25), COL.Shoji, Enum.Material.SmoothPlastic)
	local bars = math.max(2, math.floor(width / 1.6))
	for i = 0, bars do
		part(model, cf * CFrame.new(-width / 2 + i * width / bars, 0, -0.15), Vector3.new(0.15, height, 0.08), COL.DarkWood, Enum.Material.Wood, nil, false)
	end
	for j = 0, 3 do
		part(model, cf * CFrame.new(0, -height / 2 + j * height / 3, -0.15), Vector3.new(width, 0.15, 0.08), COL.DarkWood, Enum.Material.Wood, nil, false)
	end
end

-- Box room with corner posts, shoji walls and an opening on the -Z side.
local function room(model: Model, base: CFrame, w: number, d: number, h: number, doorWidth: number)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			post(model, (base * CFrame.new(sx * w / 2, h / 2, sz * d / 2)).Position, h, 0.6, COL.DarkWood, Enum.Material.Wood)
		end
	end
	shojiWall(model, base * CFrame.new(0, h / 2, d / 2) * CFrame.Angles(0, math.pi, 0), w, h)
	shojiWall(model, base * CFrame.new(-w / 2, h / 2, 0) * CFrame.Angles(0, -math.pi / 2, 0), d, h)
	shojiWall(model, base * CFrame.new(w / 2, h / 2, 0) * CFrame.Angles(0, math.pi / 2, 0), d, h)
	local side = (w - doorWidth) / 2
	if side > 0.2 then
		for _, sx in { -1, 1 } do
			shojiWall(model, base * CFrame.new(sx * (doorWidth / 2 + side / 2), h / 2, -d / 2), side, h)
		end
	end
	part(model, base * CFrame.new(0, h - 0.4, -d / 2), Vector3.new(doorWidth, 0.8, 0.3), COL.DarkWood, Enum.Material.Wood)
end

function JapaneseBuilder.Shrine(size: number?): Model
	local s = size or 12
	local model = newModel("Shrine", s, s)
	part(model, CFrame.new(0, 0.5, 0), Vector3.new(s, 1, s), COL.Stone, Enum.Material.Slate)
	for i = 1, 2 do
		part(model, CFrame.new(0, 0.25 * i, -s / 2 - 0.5 + i * 0.5), Vector3.new(4, 0.5 * i, 1), COL.Stone, Enum.Material.Slate)
	end
	local base = CFrame.new(0, 1.6, 0.8)
	part(model, base * CFrame.new(0, -0.3, 0), Vector3.new(s * 0.7, 0.4, s * 0.6), COL.Wood, Enum.Material.WoodPlanks)
	local w, d, h = s * 0.62, s * 0.5, 5
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			post(model, (base * CFrame.new(sx * w / 2, h / 2, sz * d / 2)).Position, h, 0.6, COL.Vermilion)
		end
	end
	part(model, base * CFrame.new(0, h / 2, d / 2), Vector3.new(w, h, 0.3), COL.Wood, Enum.Material.Wood)
	part(model, base * CFrame.new(0, h - 0.3, -d / 2), Vector3.new(w, 0.5, 0.4), COL.Vermilion)
	-- shimenawa rope with paper streamers
	part(model, base * CFrame.new(0, h - 0.9, -d / 2 - 0.3), Vector3.new(w * 0.8, 0.5, 0.5), c(225, 205, 150), Enum.Material.Fabric, "Cylinder", false)
	for i = -1, 1 do
		part(model, base * CFrame.new(i * w * 0.25, h - 1.6, -d / 2 - 0.35), Vector3.new(0.4, 1, 0.05), c(255, 255, 255), nil, nil, false)
	end
	-- offering box and bell
	part(model, base * CFrame.new(0, 0.6, -d / 2 + 0.2), Vector3.new(2.4, 1.2, 1.2), COL.DarkWood, Enum.Material.Wood)
	part(model, base * CFrame.new(0, h - 1.7, -d / 2 + 0.3), Vector3.one * 0.8, COL.Gold, Enum.Material.Metal, "Ball", false)
	JapaneseBuilder.Roof(model, base * CFrame.new(0, h, 0), w + 3, d + 3, 2.6, COL.Roof, true)
	-- two guardian lanterns
	for _, sx in { -1, 1 } do
		local lantern = JapaneseBuilder.StoneLantern(0.7)
		lantern:PivotTo(CFrame.new(sx * s * 0.38, 1, -s * 0.35))
		for _, child in lantern:GetChildren() do
			if child.Name ~= "Root" then
				child.Parent = model
			end
		end
		lantern:Destroy()
	end
	return model
end

function JapaneseBuilder.TeaHouse(size: number?): Model
	local s = size or 16
	local model = newModel("TeaHouse", s, s)
	-- raised deck (engawa)
	part(model, CFrame.new(0, 0.9, 0), Vector3.new(s - 0.5, 0.4, s - 0.5), COL.Wood, Enum.Material.WoodPlanks)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			post(model, Vector3.new(sx * (s / 2 - 0.8), 0.45, sz * (s / 2 - 0.8)), 0.9, 0.6, COL.Stone, Enum.Material.Slate)
		end
	end
	part(model, CFrame.new(0, 0.35, -s / 2 - 0.3), Vector3.new(3, 0.7, 1), COL.Stone, Enum.Material.Slate)
	local base = CFrame.new(0, 1.1, 1.2)
	room(model, base, s * 0.6, s * 0.55, 5, 3)
	-- tatami floor + low table + cushions
	part(model, base * CFrame.new(0, 0.05, 0), Vector3.new(s * 0.58, 0.1, s * 0.53), c(200, 190, 130), Enum.Material.Fabric, nil, false)
	part(model, base * CFrame.new(0, 0.6, 0.5), Vector3.new(2.4, 0.2, 1.6), COL.DarkWood, Enum.Material.Wood)
	for _, sx in { -1, 1 } do
		part(model, base * CFrame.new(sx * 2, 0.2, 0.5), Vector3.new(1.2, 0.3, 1.2), c(150, 60, 70), Enum.Material.Fabric, nil, false)
	end
	JapaneseBuilder.Roof(model, base * CFrame.new(0, 5, 0), s * 0.6 + 4, s * 0.55 + 4, 3, c(70, 90, 80), true)
	local lantern = JapaneseBuilder.PaperLantern()
	lantern:PivotTo(CFrame.new(s / 2 - 1.5, 1.1, -s / 2 + 1.5))
	for _, child in lantern:GetChildren() do
		if child.Name ~= "Root" then
			child.Parent = model
		end
	end
	lantern:Destroy()
	return model
end

function JapaneseBuilder.BellTower(size: number?): Model
	local s = size or 12
	local model = newModel("BellTower", s, s)
	part(model, CFrame.new(0, 1, 0), Vector3.new(s * 0.8, 2, s * 0.8), COL.Stone, Enum.Material.Slate)
	local h = 7
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			post(model, Vector3.new(sx * s * 0.3, 2 + h / 2, sz * s * 0.3), h, 0.7, COL.Vermilion)
		end
	end
	part(model, CFrame.new(0, 2 + h - 0.3, 0), Vector3.new(s * 0.65, 0.5, s * 0.65), COL.DarkWood, Enum.Material.Wood)
	local bell = post(model, Vector3.new(0, 2 + h - 2.2, 0), 3, 2.4, c(150, 110, 60), Enum.Material.Metal, false)
	bell.Name = "Bell"
	part(model, CFrame.new(0, 2 + h - 3.7, 0), Vector3.new(2.6, 0.4, 2.6), c(130, 95, 50), Enum.Material.Metal, nil, false)
	part(model, CFrame.new(0, 2 + h - 0.5, 0), Vector3.new(0.4, 0.8, 0.4), COL.Black, nil, nil, false)
	part(model, CFrame.new(2.4, 2 + h - 2.2, 0), Vector3.new(2.6, 0.5, 0.5), COL.Wood, Enum.Material.Wood, "Cylinder", false)
	JapaneseBuilder.Roof(model, CFrame.new(0, 2 + h, 0), s * 0.95, s * 0.95, 3.2, COL.Roof, true)
	return model
end

function JapaneseBuilder.Minka(width: number?, depth: number?): Model
	local w = width or 20
	local d = depth or 16
	local model = newModel("MinkaHouse", w, d)
	part(model, CFrame.new(0, 0.6, 0), Vector3.new(w - 0.5, 1.2, d - 0.5), COL.Stone, Enum.Material.Slate)
	part(model, CFrame.new(0, 1.3, 0), Vector3.new(w - 1, 0.3, d - 1), COL.Wood, Enum.Material.WoodPlanks)
	part(model, CFrame.new(0, 0.4, -d / 2 - 0.4), Vector3.new(4, 0.8, 1.2), COL.Stone, Enum.Material.Slate)
	local base = CFrame.new(0, 1.45, 1)
	room(model, base, w - 4, d - 5, 6, 4)
	-- veranda posts in front
	for i = -2, 2 do
		post(model, (CFrame.new(i * (w - 3) / 4, 1.45 + 3, -d / 2 + 1)).Position, 6, 0.45, COL.DarkWood, Enum.Material.Wood)
	end
	-- interior: tatami + paper lantern glow
	part(model, base * CFrame.new(0, 0.05, 0), Vector3.new(w - 4.2, 0.1, d - 5.2), c(200, 190, 130), Enum.Material.Fabric, nil, false)
	local glow = part(model, base * CFrame.new(0, 4.6, 0), Vector3.new(1.2, 1.2, 1.2), c(255, 210, 140), Enum.Material.Neon, "Ball", false)
	light(glow, c(255, 190, 120), 16, 1.2)
	JapaneseBuilder.Roof(model, base * CFrame.new(0, 6, -0.5), w + 2, d + 1, 4.5, c(90, 70, 50), true)
	return model
end

function JapaneseBuilder.Pagoda(baseSize: number?, tiers: number?): Model
	local b = baseSize or 14
	local n = tiers or 5
	local model = newModel("Pagoda", b, b)
	part(model, CFrame.new(0, 0.6, 0), Vector3.new(b, 1.2, b), COL.Stone, Enum.Material.Slate)
	local y = 1.2
	local wallHeight = b * 0.22
	for i = 0, n - 1 do
		local s = b * (0.62 - i * 0.07)
		part(model, CFrame.new(0, y + wallHeight / 2, 0), Vector3.new(s, wallHeight, s), COL.Vermilion, Enum.Material.SmoothPlastic)
		-- white bands + dark doors on each face
		part(model, CFrame.new(0, y + wallHeight * 0.85, 0), Vector3.new(s + 0.1, wallHeight * 0.15, s + 0.1), COL.Plaster)
		for f = 0, 3 do
			part(model, CFrame.Angles(0, f * math.pi / 2, 0) * CFrame.new(0, y + wallHeight * 0.4, -s / 2 - 0.05), Vector3.new(s * 0.3, wallHeight * 0.6, 0.1), COL.DarkWood, Enum.Material.Wood, nil, false)
		end
		y += wallHeight
		JapaneseBuilder.Roof(model, CFrame.new(0, y, 0), s + b * 0.45, s + b * 0.45, b * 0.08, COL.Roof, true)
		y += b * 0.08 + 0.4
		wallHeight *= 0.85
	end
	-- sōrin spire
	post(model, Vector3.new(0, y + b * 0.25, 0), b * 0.5, b * 0.05, COL.Gold, Enum.Material.Metal, false)
	for i = 1, 5 do
		post(model, Vector3.new(0, y + i * b * 0.07, 0), 0.25, b * 0.12, COL.Gold, Enum.Material.Metal, false)
	end
	part(model, CFrame.new(0, y + b * 0.52, 0), Vector3.one * b * 0.08, COL.Gold, Enum.Material.Metal, "Ball", false)
	return model
end

-- Big decorative mountain (e.g. a Fuji-like backdrop). Origin at its base centre.
function JapaneseBuilder.Mountain(width: number, height: number, depth: number?, color: Color3?): Model
	-- Two wedges seen side-on give a triangular silhouette from the +Z side (the side the arena camera
	-- looks at), plus a snow cap with little "drips" placed slightly in FRONT so it is always visible.
	local d = depth or 4
	local model = newModel("Mountain", width, d)
	local function triangle(w: number, h: number, baseY: number, z: number, thickness: number, col: Color3, material: Enum.Material?)
		part(model, CFrame.new(-w / 4, baseY + h / 2, z) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(thickness, h, w / 2), col, material, "Wedge", false)
		part(model, CFrame.new(w / 4, baseY + h / 2, z) * CFrame.Angles(0, -math.pi / 2, 0), Vector3.new(thickness, h, w / 2), col, material, "Wedge", false)
	end
	triangle(width, height, 0, 0, d, color or c(80, 100, 145), Enum.Material.Slate)
	local snow = c(250, 252, 255)
	local capHeight = height * 0.36
	local capWidth = width * capHeight / height
	triangle(capWidth, capHeight, height - capHeight + 0.02, d / 2 + 0.15, 0.3, snow, Enum.Material.Snow)
	-- jagged snow line: flattened white blobs hanging below the cap's lower edge
	for k = -2, 2 do
		local blobWidth = capWidth * (0.16 + (k % 2) * 0.06)
		local blobHeight = capHeight * (0.35 + ((k + 2) % 3) * 0.12)
		local x = k * capWidth * 0.17
		local y = height - capHeight + blobHeight * 0.1
		local blob = part(model, CFrame.new(x, y, d / 2 + 0.25), Vector3.new(blobWidth, blobHeight, 0.3), snow, Enum.Material.Snow, nil, false)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = blob
	end
	return model
end

------------------------------------------------------------------------------------------------
-- Building ids (Config/Buildings) -> model. Size passed in studs (cells * PlotGrid.Cell).
------------------------------------------------------------------------------------------------
local BUILDERS: { [string]: (w: number, d: number) -> Model } = {
	StoneLantern = function()
		return JapaneseBuilder.StoneLantern(0.8)
	end,
	PaperLantern = function()
		return JapaneseBuilder.PaperLantern()
	end,
	Bonsai = function()
		return JapaneseBuilder.Bonsai()
	end,
	BambooGrove = function(w)
		return JapaneseBuilder.Bamboo(w - 0.5)
	end,
	SakuraTree = function(w)
		return JapaneseBuilder.Sakura(w / 7, 11)
	end,
	ZenGarden = function(w)
		return JapaneseBuilder.ZenGarden(w - 0.4)
	end,
	KoiPond = function(w)
		return JapaneseBuilder.KoiPond(w - 0.4)
	end,
	ToriiGate = function(w)
		return JapaneseBuilder.Torii(w - 1, 9)
	end,
	Bridge = function(w, d)
		return JapaneseBuilder.Bridge(w - 0.5, d)
	end,
	Shrine = function(w)
		return JapaneseBuilder.Shrine(w - 0.5)
	end,
	TeaHouse = function(w)
		return JapaneseBuilder.TeaHouse(w - 0.5)
	end,
	BellTower = function(w)
		return JapaneseBuilder.BellTower(w - 0.5)
	end,
	MinkaHouse = function(w, d)
		return JapaneseBuilder.Minka(w - 0.5, d - 0.5)
	end,
	Pagoda = function(w)
		return JapaneseBuilder.Pagoda(w - 1, 5)
	end,
}

function JapaneseBuilder.Building(id: string, widthStuds: number, depthStuds: number): Model
	local builder = BUILDERS[id]
	local model = builder and builder(widthStuds, depthStuds) or JapaneseBuilder.StoneLantern(1)
	model.Name = id
	return model
end

return JapaneseBuilder
