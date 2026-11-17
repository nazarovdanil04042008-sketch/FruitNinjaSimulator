--!nonstrict
-- Procedural models (no uploaded meshes required). Used by the server (katana / belt on characters)
-- and the client (creature pets, viewport previews, egg models).

local Config = script.Parent.Parent.Config
local Rarities = require(Config.Rarities)
local Creatures = require(Config.Creatures)
local Katanas = require(Config.Katanas)

local ModelBuilder = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local function makePart(props: { [string]: any }): BasePart
	local part: BasePart
	if props.Shape == "Ball" then
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		part = p
	elseif props.Shape == "Cylinder" then
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		part = p
	elseif props.Shape == "Wedge" then
		part = Instance.new("WedgePart")
	else
		part = Instance.new("Part")
	end
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Color = props.Color or Color3.new(1, 1, 1)
	part.Size = props.Size or Vector3.one
	part.Name = props.Name or "Part"
	if props.Transparency then
		part.Transparency = props.Transparency
	end
	return part
end

-- Attach `part` to `root` at a local offset and weld it.
local function attach(model: Model, root: BasePart, part: BasePart, offset: CFrame)
	part.CFrame = root.CFrame * offset
	part.Parent = model
	if part ~= root then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end
end

local function addSparkles(parent: Instance, color: Color3, rate: number, size: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Speed = NumberRange.new(1, 2.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new(0.2, 1)
	emitter.Parent = parent
	return emitter
end

------------------------------------------------------------------------------------------------
-- Katana
------------------------------------------------------------------------------------------------
function ModelBuilder.Katana(katanaId: string): Model
	local def = Katanas.Get(katanaId)
	-- Custom katana: Assets/Katanas/<Id> with its PrimaryPart = handle and the blade pointing up (+Y)
	local override = ModelBuilder.GetOverride("Katanas", def.Id)
	if override and override.PrimaryPart then
		local handle = override.PrimaryPart
		for _, d in override:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.CanCollide = false
				d.CanQuery = false
				d.Massless = true
				if d ~= handle then
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = handle
					weld.Part1 = d
					weld.Parent = d
				end
			elseif d:IsA("Script") or d:IsA("LocalScript") then
				d:Destroy()
			end
		end
		override.Name = "Katana_" .. def.Id
		return override
	end
	local model = Instance.new("Model")
	model.Name = "Katana_" .. def.Id

	local handle = makePart({ Name = "Handle", Size = Vector3.new(0.28, 1.4, 0.28), Color = Color3.fromRGB(30, 25, 30), Material = Enum.Material.Fabric })
	handle.CFrame = CFrame.new()
	handle.Parent = model
	model.PrimaryPart = handle

	local guardColor = def.Order >= 5 and def.BladeColor or Color3.fromRGB(220, 180, 60)
	attach(model, handle, makePart({ Name = "Guard", Size = Vector3.new(0.75, 0.12, 0.55), Color = guardColor, Material = Enum.Material.Metal }), CFrame.new(0, 0.76, 0))
	local blade = makePart({ Name = "Blade", Size = Vector3.new(0.1, 3.8, 0.34), Color = def.BladeColor, Material = def.BladeMaterial })
	attach(model, handle, blade, CFrame.new(0, 2.72, 0))
	local tip = makePart({ Name = "Tip", Shape = "Wedge", Size = Vector3.new(0.1, 0.5, 0.34), Color = def.BladeColor, Material = def.BladeMaterial })
	attach(model, handle, tip, CFrame.new(0, 4.86, 0))
	attach(model, handle, makePart({ Name = "Pommel", Size = Vector3.new(0.34, 0.14, 0.34), Color = guardColor, Material = Enum.Material.Metal }), CFrame.new(0, -0.74, 0))

	if def.Effect == "Fire" then
		local fire = Instance.new("Fire")
		fire.Size = 2.5
		fire.Heat = 4
		fire.Color = Color3.fromRGB(255, 140, 30)
		fire.SecondaryColor = Color3.fromRGB(255, 40, 0)
		fire.Parent = blade
	elseif def.Effect == "Lightning" or def.Effect == "Cosmic" or def.Effect == "Mythic" then
		addSparkles(blade, def.SwipeColor, def.Effect == "Mythic" and 14 or 8, 0.35)
		local light = Instance.new("PointLight")
		light.Color = def.BladeColor
		light.Range = 8
		light.Brightness = 1.5
		light.Parent = blade
	elseif def.Effect == "Shine" then
		addSparkles(blade, Color3.new(1, 1, 1), 3, 0.25)
	end

	return model
end

------------------------------------------------------------------------------------------------
-- Asset overrides: put your own models in ReplicatedStorage.Assets.<Category>.<Id>
-- (with Rojo: assets/<Category>/<Id>.rbxm). The game uses them instead of the procedural ones.
------------------------------------------------------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")

function ModelBuilder.GetOverride(category: string, id: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild(category)
	local source = folder and folder:FindFirstChild(id)
	if source and source:IsA("Model") then
		return source:Clone()
	end
	return nil
end

-- Normalises a user-made model: scales it so its largest dimension equals `targetSize`, adds an
-- invisible Root (centre, or bottom-centre when `pivotAtBottom`) and welds every part to it.
function ModelBuilder.PrepareOverride(model: Model, targetSize: number, pivotAtBottom: boolean?, horizontalOnly: boolean?): Model
	local _, size = model:GetBoundingBox()
	local maxDim = horizontalOnly and math.max(size.X, size.Z) or math.max(size.X, size.Y, size.Z)
	if maxDim > 0.01 then
		model:ScaleTo(model:GetScale() * targetSize / maxDim)
	end
	local cf, newSize = model:GetBoundingBox()
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Transparency = 1
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Massless = true
	root.CFrame = CFrame.new(cf.Position - (pivotAtBottom and Vector3.new(0, newSize.Y / 2, 0) or Vector3.zero))
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = d
			weld.Parent = d
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy() -- never run scripts that came with downloaded models
		end
	end
	root.Parent = model
	model.PrimaryPart = root
	return model
end

------------------------------------------------------------------------------------------------
-- Creature: fruit "brainrot" character - fruit body, huge cartoon eyes with eyebrows, open mouth
-- with teeth, human arms with white gloves, human legs in chunky sneakers, plus accessories.
------------------------------------------------------------------------------------------------
local SKIN = Color3.fromRGB(255, 206, 165)

local function addAccessory(model: Model, root: BasePart, name: string, size: number, hs: number, color2: Color3)
	local top = size * 0.5 * hs
	local face = -size * 0.47
	if name == "Crown" then
		local gold = Color3.fromRGB(255, 205, 40)
		attach(model, root, makePart({ Name = "Crown", Shape = "Cylinder", Size = Vector3.new(size * 0.22, size * 0.55, size * 0.55), Color = gold, Material = Enum.Material.Foil }),
			CFrame.new(0, top + size * 0.02, 0) * CFrame.Angles(0, 0, math.rad(90)))
		for i = 0, 4 do
			local a = math.rad(i * 72)
			attach(model, root, makePart({ Name = "CrownSpike", Shape = "Wedge", Size = Vector3.new(size * 0.08, size * 0.2, size * 0.1), Color = gold, Material = Enum.Material.Foil }),
				CFrame.Angles(0, a, 0) * CFrame.new(0, top + size * 0.22, -size * 0.24))
		end
		attach(model, root, makePart({ Name = "Gem", Shape = "Ball", Size = Vector3.one * size * 0.1, Color = Color3.fromRGB(255, 40, 80), Material = Enum.Material.Neon }), CFrame.new(0, top + size * 0.04, -size * 0.28))
	elseif name == "Halo" then
		attach(model, root, makePart({ Name = "Halo", Shape = "Cylinder", Size = Vector3.new(size * 0.06, size * 0.8, size * 0.8), Color = Color3.fromRGB(255, 240, 150), Material = Enum.Material.Neon }),
			CFrame.new(0, top + size * 0.35, 0) * CFrame.Angles(0, 0, math.rad(90)))
		attach(model, root, makePart({ Name = "HaloHole", Shape = "Cylinder", Size = Vector3.new(size * 0.07, size * 0.62, size * 0.62), Color = Color3.new(0, 0, 0), Transparency = 1 }),
			CFrame.new(0, top + size * 0.35, 0) * CFrame.Angles(0, 0, math.rad(90)))
	elseif name == "Horns" then
		for side = -1, 1, 2 do
			attach(model, root, makePart({ Name = "Horn", Shape = "Wedge", Size = Vector3.new(size * 0.12, size * 0.42, size * 0.2), Color = Color3.fromRGB(240, 235, 220) }),
				CFrame.new(side * size * 0.25, top + size * 0.05, 0) * CFrame.Angles(0, 0, math.rad(-side * 25)))
		end
	elseif name == "Shades" then
		attach(model, root, makePart({ Name = "Shades", Size = Vector3.new(size * 0.85, size * 0.22, size * 0.08), Color = Color3.new(0.04, 0.04, 0.05), Material = Enum.Material.Glass }),
			CFrame.new(0, size * 0.13 * hs, face - size * 0.12))
		attach(model, root, makePart({ Name = "ShadesShine", Size = Vector3.new(size * 0.12, size * 0.05, size * 0.02), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon }),
			CFrame.new(-size * 0.22, size * 0.18 * hs, face - size * 0.17) * CFrame.Angles(0, 0, math.rad(20)))
	elseif name == "Bow" then
		for side = -1, 1, 2 do
			attach(model, root, makePart({ Name = "Bow", Shape = "Wedge", Size = Vector3.new(size * 0.1, size * 0.22, size * 0.24), Color = color2 }),
				CFrame.new(side * size * 0.14, top + size * 0.04, -size * 0.12) * CFrame.Angles(0, side * math.rad(90), 0))
		end
		attach(model, root, makePart({ Name = "BowKnot", Shape = "Ball", Size = Vector3.one * size * 0.12, Color = color2 }), CFrame.new(0, top + size * 0.04, -size * 0.12))
	elseif name == "Cap" then
		local capColor = Color3.fromRGB(220, 40, 45)
		attach(model, root, makePart({ Name = "Cap", Shape = "Ball", Size = Vector3.one * size * 0.78, Color = capColor }), CFrame.new(0, top - size * 0.12, 0))
		attach(model, root, makePart({ Name = "CapBrim", Size = Vector3.new(size * 0.55, size * 0.05, size * 0.38), Color = capColor }), CFrame.new(0, top - size * 0.14, -size * 0.42) * CFrame.Angles(math.rad(-8), 0, 0))
	elseif name == "Chef" then
		attach(model, root, makePart({ Name = "ChefBand", Shape = "Cylinder", Size = Vector3.new(size * 0.3, size * 0.55, size * 0.55), Color = Color3.new(1, 1, 1) }),
			CFrame.new(0, top + size * 0.08, 0) * CFrame.Angles(0, 0, math.rad(90)))
		attach(model, root, makePart({ Name = "ChefPuff", Shape = "Ball", Size = Vector3.one * size * 0.7, Color = Color3.new(1, 1, 1) }), CFrame.new(0, top + size * 0.42, 0))
	elseif name == "Headphones" then
		attach(model, root, makePart({ Name = "Band", Size = Vector3.new(size * 1.05, size * 0.08, size * 0.12), Color = Color3.fromRGB(30, 30, 35) }), CFrame.new(0, top + size * 0.02, 0))
		for side = -1, 1, 2 do
			attach(model, root, makePart({ Name = "EarCup", Shape = "Cylinder", Size = Vector3.new(size * 0.16, size * 0.36, size * 0.36), Color = color2 }),
				CFrame.new(side * size * 0.5, size * 0.1 * hs, 0))
		end
	elseif name == "Mustache" then
		for side = -1, 1, 2 do
			attach(model, root, makePart({ Name = "Mustache", Shape = "Wedge", Size = Vector3.new(size * 0.06, size * 0.1, size * 0.22), Color = Color3.fromRGB(40, 25, 20) }),
				CFrame.new(side * size * 0.11, -size * 0.04 * hs, face - size * 0.04) * CFrame.Angles(0, side * math.rad(90), math.rad(side * 10)))
		end
	elseif name == "Bowtie" then
		for side = -1, 1, 2 do
			attach(model, root, makePart({ Name = "Bowtie", Shape = "Wedge", Size = Vector3.new(size * 0.08, size * 0.16, size * 0.18), Color = Color3.fromRGB(200, 30, 40) }),
				CFrame.new(side * size * 0.1, -size * 0.45 * hs, -size * 0.3) * CFrame.Angles(0, side * math.rad(90), 0))
		end
	elseif name == "Headband" then
		local red = Color3.fromRGB(200, 25, 35)
		attach(model, root, makePart({ Name = "Headband", Shape = "Cylinder", Size = Vector3.new(size * 0.16, size * 1.04, size * 1.04), Color = red, Material = Enum.Material.Fabric }),
			CFrame.new(0, size * 0.3 * hs, 0) * CFrame.Angles(0, 0, math.rad(90)))
		attach(model, root, makePart({ Name = "Plate", Size = Vector3.new(size * 0.3, size * 0.13, size * 0.05), Color = Color3.fromRGB(190, 195, 205), Material = Enum.Material.Metal }),
			CFrame.new(0, size * 0.3 * hs, -size * 0.52))
		for side = -1, 1, 2 do
			attach(model, root, makePart({ Name = "Tail", Size = Vector3.new(size * 0.06, size * 0.4, size * 0.1), Color = red, Material = Enum.Material.Fabric }),
				CFrame.new(side * size * 0.08, size * 0.15 * hs, size * 0.55) * CFrame.Angles(math.rad(25), 0, math.rad(side * 15)))
		end
	elseif name == "Cape" then
		attach(model, root, makePart({ Name = "Cape", Size = Vector3.new(size * 0.9, size * 1.1, size * 0.05), Color = Color3.fromRGB(150, 20, 40), Material = Enum.Material.Fabric }),
			CFrame.new(0, -size * 0.2, size * 0.5) * CFrame.Angles(math.rad(12), 0, 0))
	end
end

function ModelBuilder.Creature(creatureId: string): Model
	local def = Creatures.Get(creatureId)
	if def then
		local override = ModelBuilder.GetOverride("Creatures", creatureId)
		if override then
			override.Name = def.Id
			return ModelBuilder.PrepareOverride(override, def.Body.Size * 1.9, false)
		end
	end
	local model = Instance.new("Model")
	if not def then
		model.Name = "UnknownCreature"
		local p = makePart({ Name = "Body", Shape = "Ball", Size = Vector3.one * 1.5 })
		p.Parent = model
		model.PrimaryPart = p
		return model
	end
	model.Name = def.Id
	local rarity = Rarities.Get(def.Rarity)
	local body = def.Body
	local size = body.Size * 1.15

	local bodyMaterial = Enum.Material.SmoothPlastic
	if rarity.Material and rarity.Material ~= Enum.Material.ForceField and rarity.Material ~= Enum.Material.Neon then
		bodyMaterial = rarity.Material
	end

	local root = makePart({ Name = "Body", Shape = "Ball", Size = Vector3.one * size, Color = body.Color, Material = bodyMaterial })
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root

	local hs = 1
	if body.Shape == "Long" or body.Shape == "Tall" then
		root.Shape = Enum.PartType.Block
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = body.Shape == "Long" and Vector3.new(0.75, 1.45, 0.75) or Vector3.new(0.95, 1.3, 0.95)
		mesh.Parent = root
		hs = body.Shape == "Long" and 1.45 or 1.3
	elseif body.Shape == "Spiky" then
		for ring = 0, 1 do
			for i = 0, 7 do
				local angle = math.rad(i * 45 + ring * 22.5)
				attach(model, root, makePart({ Name = "Spike", Shape = "Wedge", Size = Vector3.new(size * 0.1, size * 0.22, size * 0.16), Color = body.Color:Lerp(Color3.new(0, 0, 0), 0.25) }),
					CFrame.Angles(0, angle, 0) * CFrame.new(0, -size * 0.15 + ring * size * 0.3, size * 0.47) * CFrame.Angles(math.rad(70), 0, 0))
			end
		end
	elseif body.Shape == "Star" then
		for i = 0, 4 do
			local angle = math.rad(i * 72)
			attach(model, root, makePart({ Name = "StarPoint", Shape = "Wedge", Size = Vector3.new(size * 0.22, size * 0.45, size * 0.3), Color = body.Color }),
				CFrame.Angles(0, 0, angle) * CFrame.new(0, size * 0.55, 0))
		end
	end
	local top = size * 0.5 * hs

	-- Leaves / stem on top (several leaves for a fuller look)
	if body.Shape ~= "Star" then
		attach(model, root, makePart({ Name = "Stem", Size = Vector3.new(size * 0.08, size * 0.22, size * 0.08), Color = Color3.fromRGB(100, 70, 40) }), CFrame.new(0, top + size * 0.06, 0))
		local leafCount = body.Shape == "Spiky" and 5 or 2
		for i = 1, leafCount do
			local yaw = math.rad(i * (360 / leafCount) + 20)
			attach(model, root, makePart({ Name = "Leaf", Shape = "Wedge", Size = Vector3.new(size * 0.06, size * (body.Shape == "Spiky" and 0.5 or 0.24), size * 0.3), Color = body.Color2 }),
				CFrame.Angles(0, yaw, 0) * CFrame.new(0, top + size * 0.08, size * 0.12) * CFrame.Angles(math.rad(-35), 0, 0))
		end
	end

	-- Eyes: big whites, black pupils, white highlights, mismatched sizes for the brainrot stare
	local eyeY = size * 0.12 * hs
	local face = -size * 0.42
	for side = -1, 1, 2 do
		local eyeSize = size * (side == -1 and 0.4 or 0.33)
		local eyeX = side * size * 0.21
		attach(model, root, makePart({ Name = "Eye", Shape = "Ball", Size = Vector3.one * eyeSize, Color = Color3.new(1, 1, 1) }), CFrame.new(eyeX, eyeY, face))
		local pupilOffset = side == -1 and Vector3.new(eyeSize * 0.08, -eyeSize * 0.05, 0) or Vector3.new(-eyeSize * 0.1, eyeSize * 0.04, 0)
		attach(model, root, makePart({ Name = "Pupil", Shape = "Ball", Size = Vector3.one * eyeSize * 0.5, Color = Color3.fromRGB(15, 15, 20) }),
			CFrame.new(Vector3.new(eyeX, eyeY, face - eyeSize * 0.32) + pupilOffset))
		attach(model, root, makePart({ Name = "Shine", Shape = "Ball", Size = Vector3.one * eyeSize * 0.16, Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon }),
			CFrame.new(Vector3.new(eyeX + eyeSize * 0.08, eyeY + eyeSize * 0.1, face - eyeSize * 0.52) + pupilOffset))
		-- eyebrows: one raised, one angry
		attach(model, root, makePart({ Name = "Brow", Size = Vector3.new(eyeSize * 0.8, size * 0.06, size * 0.06), Color = Color3.fromRGB(40, 25, 20) }),
			CFrame.new(eyeX, eyeY + eyeSize * 0.62 + (side == -1 and size * 0.05 or 0), face - eyeSize * 0.2) * CFrame.Angles(0, 0, math.rad(side == -1 and 12 or -22)))
	end

	-- Open mouth with teeth and tongue
	local mouthY = -size * 0.17 * hs
	attach(model, root, makePart({ Name = "Mouth", Size = Vector3.new(size * 0.42, size * 0.17, size * 0.06), Color = Color3.fromRGB(70, 10, 20) }), CFrame.new(0, mouthY, -size * 0.47))
	attach(model, root, makePart({ Name = "Teeth", Size = Vector3.new(size * 0.34, size * 0.05, size * 0.03), Color = Color3.new(1, 1, 1) }), CFrame.new(0, mouthY + size * 0.05, -size * 0.505))
	attach(model, root, makePart({ Name = "Tongue", Shape = "Ball", Size = Vector3.new(size * 0.16, size * 0.16, size * 0.16), Color = Color3.fromRGB(255, 100, 120) }), CFrame.new(size * 0.05, mouthY - size * 0.05, -size * 0.47))
	for side = -1, 1, 2 do
		local blush = makePart({ Name = "Blush", Shape = "Ball", Size = Vector3.new(size * 0.14, size * 0.14, size * 0.14), Color = Color3.fromRGB(255, 130, 150), Transparency = 0.35 })
		attach(model, root, blush, CFrame.new(side * size * 0.33, mouthY + size * 0.06, -size * 0.36))
	end

	-- Arms with white gloves
	for side = -1, 1, 2 do
		attach(model, root, makePart({ Name = "Arm", Size = Vector3.new(size * 0.11, size * 0.42, size * 0.11), Color = SKIN }),
			CFrame.new(side * size * 0.52, -size * 0.05 * hs, -size * 0.05) * CFrame.Angles(math.rad(-15), 0, math.rad(side * 35)))
		attach(model, root, makePart({ Name = "Glove", Shape = "Ball", Size = Vector3.one * size * 0.19, Color = Color3.new(1, 1, 1) }),
			CFrame.new(side * size * 0.66, -size * 0.22 * hs, -size * 0.12))
	end

	-- Human legs + chunky sneakers
	local hip = -size * 0.5 * hs
	for side = -1, 1, 2 do
		local x = side * size * 0.17
		attach(model, root, makePart({ Name = "Leg", Size = Vector3.new(size * 0.13, size * 0.42, size * 0.13), Color = SKIN }), CFrame.new(x, hip - size * 0.12, 0))
		attach(model, root, makePart({ Name = "Sock", Size = Vector3.new(size * 0.15, size * 0.08, size * 0.15), Color = Color3.new(1, 1, 1) }), CFrame.new(x, hip - size * 0.3, 0))
		attach(model, root, makePart({ Name = "Shoe", Size = Vector3.new(size * 0.24, size * 0.13, size * 0.38), Color = Color3.fromRGB(250, 250, 250) }), CFrame.new(x, hip - size * 0.39, -size * 0.06))
		attach(model, root, makePart({ Name = "ShoeStripe", Size = Vector3.new(size * 0.25, size * 0.04, size * 0.2), Color = body.Color2 }), CFrame.new(x, hip - size * 0.37, -size * 0.04))
		attach(model, root, makePart({ Name = "Sole", Size = Vector3.new(size * 0.25, size * 0.04, size * 0.4), Color = Color3.fromRGB(40, 40, 45) }), CFrame.new(x, hip - size * 0.465, -size * 0.06))
	end

	-- Accessories (new list) or legacy single hat
	local accessories = body.Accessories or ((body :: any).Hat and { (body :: any).Hat }) or {}
	for _, name in accessories do
		addAccessory(model, root, name, size, hs, body.Color2)
	end

	-- Rarity flair
	if rarity.Material == Enum.Material.Neon then
		attach(model, root, makePart({ Name = "Glow", Shape = "Ball", Size = Vector3.one * size * 1.08, Color = rarity.Color, Material = Enum.Material.Neon, Transparency = 0.75 }), CFrame.new())
	end
	if rarity.Material == Enum.Material.ForceField or rarity.Order >= 9 then
		attach(model, root, makePart({ Name = "Aura", Shape = "Ball", Size = Vector3.one * size * hs * 1.35, Color = rarity.Color2, Material = Enum.Material.ForceField }), CFrame.new())
	end
	if rarity.Glow then
		local light = Instance.new("PointLight")
		light.Color = rarity.Color
		light.Range = 6 + rarity.Order
		light.Brightness = 1
		light.Parent = root
		addSparkles(root, rarity.Color, rarity.Order >= 8 and 6 or 3, 0.3)
	end

	return model
end

------------------------------------------------------------------------------------------------
-- Egg (used by the hatching reveal and the hatchery decorations)
------------------------------------------------------------------------------------------------
function ModelBuilder.Egg(color: Color3, color2: Color3, material: Enum.Material?, size: number): Model
	local model = Instance.new("Model")
	model.Name = "Egg"
	local shell = makePart({ Name = "Shell", Size = Vector3.one * size, Color = color, Material = material or Enum.Material.SmoothPlastic })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(0.8, 1.05, 0.8)
	mesh.Parent = shell
	shell.CFrame = CFrame.new()
	shell.Parent = model
	model.PrimaryPart = shell
	for i = 0, 4 do
		local angle = math.rad(i * 72)
		attach(model, shell, makePart({ Name = "Spot", Shape = "Ball", Size = Vector3.one * size * 0.18, Color = color2 }),
			CFrame.Angles(0, angle, 0) * CFrame.new(0, size * (i % 2 == 0 and 0.12 or -0.12), -size * 0.37))
	end
	return model
end

------------------------------------------------------------------------------------------------
-- Village buildings (Assets/Buildings/<Id> override, otherwise procedural Japanese architecture)
------------------------------------------------------------------------------------------------
function ModelBuilder.Building(buildingId: string): Model
	local Buildings = require(script.Parent.Parent.Config.Buildings)
	local JapaneseBuilder = require(script.Parent.JapaneseBuilder)
	local def = Buildings.Get(buildingId)
	local width = def and def.Width * 4 or 4
	local depth = def and def.Depth * 4 or 4
	local override = ModelBuilder.GetOverride("Buildings", buildingId)
	local model
	if override then
		model = ModelBuilder.PrepareOverride(override, math.max(width, depth) - 0.4, true, true)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = d ~= model.PrimaryPart
				d.CanQuery = true
			end
		end
	else
		model = JapaneseBuilder.Building(buildingId, width, depth)
	end
	model.Name = buildingId
	return model
end

-- Anchors the root and leaves welded children unanchored so moving PrimaryPart moves everything cheaply.
function ModelBuilder.AnchorRoot(model: Model)
	local root = model.PrimaryPart
	if root then
		root.Anchored = true
	end
end

-- For ViewportFrames (no physics there): anchor every part so PivotTo positions them.
function ModelBuilder.AnchorAll(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
end

return ModelBuilder
