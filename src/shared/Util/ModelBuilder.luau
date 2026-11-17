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
-- Creature
------------------------------------------------------------------------------------------------
local function addHat(model: Model, root: BasePart, hat: string, size: number, color2: Color3)
	local top = size * 0.5
	if hat == "Crown" then
		local gold = Color3.fromRGB(255, 205, 40)
		attach(model, root, makePart({ Name = "Crown", Shape = "Cylinder", Size = Vector3.new(size * 0.22, size * 0.55, size * 0.55), Color = gold, Material = Enum.Material.Foil }),
			CFrame.new(0, top + size * 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)))
		for i = 0, 2 do
			local angle = math.rad(i * 120)
			attach(model, root, makePart({ Name = "CrownSpike", Size = Vector3.new(size * 0.09, size * 0.22, size * 0.09), Color = gold, Material = Enum.Material.Foil }),
				CFrame.new(math.cos(angle) * size * 0.2, top + size * 0.25, math.sin(angle) * size * 0.2))
		end
	elseif hat == "Halo" then
		attach(model, root, makePart({ Name = "Halo", Shape = "Cylinder", Size = Vector3.new(size * 0.06, size * 0.8, size * 0.8), Color = color2, Material = Enum.Material.Neon, Transparency = 0.15 }),
			CFrame.new(0, top + size * 0.35, 0) * CFrame.Angles(0, 0, math.rad(90)))
	elseif hat == "Horns" then
		for side = -1, 1, 2 do
			attach(model, root, makePart({ Name = "Horn", Shape = "Wedge", Size = Vector3.new(size * 0.12, size * 0.4, size * 0.2), Color = color2, Material = Enum.Material.SmoothPlastic }),
				CFrame.new(side * size * 0.25, top + size * 0.1, 0) * CFrame.Angles(0, 0, math.rad(-side * 20)))
		end
	elseif hat == "Shades" then
		attach(model, root, makePart({ Name = "Shades", Size = Vector3.new(size * 0.75, size * 0.18, size * 0.08), Color = Color3.new(0.05, 0.05, 0.05), Material = Enum.Material.Glass }),
			CFrame.new(0, size * 0.12, -size * 0.5))
	elseif hat == "Bow" then
		for side = -1, 1, 2 do
			attach(model, root, makePart({ Name = "Bow", Shape = "Ball", Size = Vector3.one * size * 0.24, Color = color2 }),
				CFrame.new(side * size * 0.14, top + size * 0.02, -size * 0.1))
		end
	end
end

function ModelBuilder.Creature(creatureId: string): Model
	local def = Creatures.Get(creatureId)
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
	local size = body.Size

	local bodyMaterial = Enum.Material.SmoothPlastic
	if rarity.Material and rarity.Material ~= Enum.Material.ForceField then
		bodyMaterial = rarity.Material
	end

	-- Root body (anchored by the caller if needed)
	local root = makePart({ Name = "Body", Shape = "Ball", Size = Vector3.one * size, Color = body.Color, Material = bodyMaterial })
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root

	if body.Shape == "Long" or body.Shape == "Tall" then
		root.Shape = Enum.PartType.Block
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = body.Shape == "Long" and Vector3.new(0.65, 1.5, 0.65) or Vector3.new(0.95, 1.35, 0.95)
		mesh.Parent = root
	elseif body.Shape == "Spiky" then
		for i = 0, 7 do
			local angle = math.rad(i * 45)
			attach(model, root, makePart({ Name = "Spike", Shape = "Wedge", Size = Vector3.new(size * 0.12, size * 0.28, size * 0.2), Color = body.Color2 }),
				CFrame.Angles(0, angle, 0) * CFrame.new(0, size * 0.1, size * 0.47) * CFrame.Angles(math.rad(70), 0, 0))
		end
	elseif body.Shape == "Star" then
		for i = 0, 4 do
			local angle = math.rad(i * 72)
			attach(model, root, makePart({ Name = "StarPoint", Size = Vector3.new(size * 0.28, size * 0.5, size * 0.28), Color = body.Color, Material = Enum.Material.Neon }),
				CFrame.Angles(0, 0, angle) * CFrame.new(0, size * 0.5, 0))
		end
	end

	local heightScale = (body.Shape == "Long" and 1.5) or (body.Shape == "Tall" and 1.35) or 1
	local top = size * 0.5 * heightScale

	-- Leaf / stem
	if body.Shape ~= "Star" then
		attach(model, root, makePart({ Name = "Leaf", Shape = "Wedge", Size = Vector3.new(size * 0.08, size * 0.3, size * 0.35), Color = body.Color2 }),
			CFrame.new(size * 0.08, top + size * 0.08, 0) * CFrame.Angles(0, math.rad(90), math.rad(-25)))
	end

	-- Googly eyes (slightly mismatched for the brainrot look)
	local eyeY = size * 0.12 * heightScale
	for side = -1, 1, 2 do
		local eyeSize = size * (side == -1 and 0.34 or 0.28)
		attach(model, root, makePart({ Name = "Eye", Shape = "Ball", Size = Vector3.one * eyeSize, Color = Color3.new(1, 1, 1) }),
			CFrame.new(side * size * 0.2, eyeY, -size * 0.4))
		attach(model, root, makePart({ Name = "Pupil", Shape = "Ball", Size = Vector3.one * eyeSize * 0.45, Color = Color3.new(0, 0, 0) }),
			CFrame.new(side * size * 0.2 + side * eyeSize * 0.12, eyeY - eyeSize * 0.1, -size * 0.4 - eyeSize * 0.4))
	end

	-- Big goofy smile
	attach(model, root, makePart({ Name = "Mouth", Size = Vector3.new(size * 0.36, size * 0.07, size * 0.05), Color = Color3.fromRGB(60, 10, 20) }),
		CFrame.new(0, -size * 0.14 * heightScale, -size * 0.46))

	-- Tiny legs
	for side = -1, 1, 2 do
		attach(model, root, makePart({ Name = "Leg", Size = Vector3.new(size * 0.12, size * 0.3, size * 0.12), Color = body.Color:Lerp(Color3.new(0, 0, 0), 0.35) }),
			CFrame.new(side * size * 0.18, -size * 0.5 * heightScale - size * 0.08, 0))
		attach(model, root, makePart({ Name = "Shoe", Size = Vector3.new(size * 0.2, size * 0.1, size * 0.28), Color = Color3.fromRGB(250, 250, 250) }),
			CFrame.new(side * size * 0.18, -size * 0.5 * heightScale - size * 0.24, -size * 0.04))
	end

	if body.Hat then
		addHat(model, root, body.Hat, size * heightScale, body.Color2)
	end

	-- Rarity flair
	if rarity.Material == Enum.Material.ForceField or rarity.Order >= 9 then
		local shell = makePart({ Name = "Aura", Shape = "Ball", Size = Vector3.one * size * heightScale * 1.25, Color = rarity.Color2, Material = Enum.Material.ForceField })
		attach(model, root, shell, CFrame.new())
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
