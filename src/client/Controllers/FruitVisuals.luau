--!nonstrict
-- Client-only visuals for arena objects: building fruit / egg / bomb models, slice halves,
-- juice bursts and katana-specific slice effects. All parts are anchored, non-colliding and
-- moved in bulk by SlicingController, so they cost almost nothing on low-end devices.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fruits = require(ReplicatedStorage.Shared.Config.Fruits)

local FruitVisuals = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

export type Visual = { Parts: { BasePart }, Offsets: { CFrame } }

local folder: Folder
local emitterHolder: Part
local emitters: { [string]: ParticleEmitter } = {}

local function basePart(size: Vector3, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function sphereMesh(part: BasePart)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
end

function FruitVisuals.Build(def: Fruits.FruitDef): Visual
	local r = def.Radius
	local parts: { BasePart } = {}
	local offsets: { CFrame } = {}
	local function add(part: BasePart, offset: CFrame)
		part.Parent = folder
		table.insert(parts, part)
		table.insert(offsets, offset)
	end

	if def.Shape == "Long" then
		local body = basePart(Vector3.new(r * 0.9, r * 2.4, r * 0.9), def.Color, def.Material)
		sphereMesh(body)
		add(body, CFrame.Angles(0, 0, math.rad(25)))
	elseif def.Shape == "Egg" then
		local shell = basePart(Vector3.new(r * 1.6, r * 2.1, r * 1.6), def.Color, def.Material)
		sphereMesh(shell)
		add(shell, CFrame.new())
		local light = Instance.new("PointLight")
		light.Color = def.Color2 or def.Color
		light.Range = 7
		light.Brightness = 1.5
		light.Parent = shell
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Texture = SPARKLE
		sparkles.Rate = 6
		sparkles.Lifetime = NumberRange.new(0.4, 0.7)
		sparkles.Speed = NumberRange.new(1, 2)
		sparkles.Size = NumberSequence.new(0.4, 0)
		sparkles.Color = ColorSequence.new(def.Color2 or Color3.new(1, 1, 1))
		sparkles.LightEmission = 1
		sparkles.Parent = shell
		for i = 0, 2 do
			local a = math.rad(i * 120)
			add(basePart(Vector3.one * r * 0.45, def.Color2 or def.Color, nil, Enum.PartType.Ball), CFrame.new(math.cos(a) * r * 0.62, (i - 1) * r * 0.35, math.sin(a) * r * 0.62))
		end
	elseif def.Shape == "Bomb" then
		add(basePart(Vector3.one * r * 2, def.Color, Enum.Material.Metal, Enum.PartType.Ball), CFrame.new())
		local fuse = basePart(Vector3.new(r * 0.25, r * 0.6, r * 0.25), Color3.fromRGB(90, 70, 50))
		add(fuse, CFrame.new(0, r * 1.1, 0))
		local spark = basePart(Vector3.one * r * 0.4, def.Color2 or Color3.new(1, 0, 0), Enum.Material.Neon, Enum.PartType.Ball)
		add(spark, CFrame.new(0, r * 1.45, 0))
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = SPARKLE
		emitter.Rate = 25
		emitter.Lifetime = NumberRange.new(0.2, 0.4)
		emitter.Speed = NumberRange.new(3, 5)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 40, 0))
		emitter.Size = NumberSequence.new(0.5, 0)
		emitter.LightEmission = 1
		emitter.Parent = spark
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 60, 40)
		light.Range = 8
		light.Brightness = 3
		light.Parent = spark
	else
		local body = basePart(Vector3.one * r * 2, def.Color, def.Material, Enum.PartType.Ball)
		add(body, CFrame.new())
		if def.Shape == "Spiky" then
			for i = 0, 2 do
				local leaf = Instance.new("WedgePart")
				leaf.Anchored = true
				leaf.CanCollide = false
				leaf.CanQuery = false
				leaf.CanTouch = false
				leaf.CastShadow = false
				leaf.Size = Vector3.new(r * 0.2, r * 0.9, r * 0.5)
				leaf.Color = def.Color2 or Color3.fromRGB(60, 160, 40)
				add(leaf, CFrame.Angles(0, math.rad(i * 120), 0) * CFrame.new(0, r * 1.25, r * 0.12))
			end
		elseif def.Shape == "Star" then
			for i = 0, 4 do
				add(basePart(Vector3.new(r * 0.5, r * 0.8, r * 0.5), def.Color, def.Material), CFrame.Angles(0, 0, math.rad(i * 72)) * CFrame.new(0, r * 1.05, 0))
			end
			local light = Instance.new("PointLight")
			light.Color = def.Color
			light.Range = 8
			light.Brightness = 2
			light.Parent = body
		elseif def.Color2 then
			-- stem / leaf
			add(basePart(Vector3.new(r * 0.18, r * 0.5, r * 0.18), Color3.fromRGB(100, 70, 40)), CFrame.new(0, r * 1.05, 0))
			add(basePart(Vector3.new(r * 0.1, r * 0.3, r * 0.6), def.Color2), CFrame.new(r * 0.2, r * 1.05, 0) * CFrame.Angles(0, 0, math.rad(-40)))
		end
		if def.Kind == "Golden" then
			local sparkles = Instance.new("Sparkles")
			sparkles.SparkleColor = Color3.fromRGB(255, 230, 120)
			sparkles.Parent = body
		end
	end
	return { Parts = parts, Offsets = offsets }
end

function FruitVisuals.Destroy(visual: Visual)
	for _, part in visual.Parts do
		part:Destroy()
	end
	table.clear(visual.Parts)
end

------------------------------------------------------------------------------------------------
-- Particle bursts (one pooled emitter per look, moved to the burst position before Emit)
------------------------------------------------------------------------------------------------
local function getEmitter(key: string, setup: (ParticleEmitter) -> ()): ParticleEmitter
	local emitter = emitters[key]
	if emitter then
		return emitter
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = key
	attachment.Parent = emitterHolder
	emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Enabled = true
	setup(emitter)
	emitter.Parent = attachment
	emitters[key] = emitter
	return emitter
end

local function burst(key: string, position: Vector3, count: number, setup: (ParticleEmitter) -> ())
	local emitter = getEmitter(key, setup)
	local attachment = emitter.Parent :: Attachment
	attachment.WorldPosition = position
	emitter:Emit(count)
end

function FruitVisuals.Juice(position: Vector3, color: Color3, amount: number)
	local key = "Juice_" .. color:ToHex()
	burst(key, position, amount, function(e)
		e.Texture = SMOKE
		e.Color = ColorSequence.new(color)
		e.Lifetime = NumberRange.new(0.35, 0.6)
		e.Speed = NumberRange.new(8, 16)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0, -40, 0)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0.1) })
		e.Transparency = NumberSequence.new(0.1, 1)
		e.Drag = 2
	end)
end

local EFFECTS: { [string]: (ParticleEmitter) -> () } = {
	Wood = function(e)
		e.Texture = SMOKE
		e.Color = ColorSequence.new(Color3.fromRGB(200, 160, 110))
		e.Size = NumberSequence.new(0.5, 0)
		e.Speed = NumberRange.new(4, 8)
		e.Lifetime = NumberRange.new(0.3, 0.5)
		e.SpreadAngle = Vector2.new(180, 180)
	end,
	Sparks = function(e)
		e.Texture = SPARKLE
		e.Color = ColorSequence.new(Color3.fromRGB(255, 240, 180))
		e.LightEmission = 1
		e.Size = NumberSequence.new(0.6, 0)
		e.Speed = NumberRange.new(10, 18)
		e.Lifetime = NumberRange.new(0.2, 0.4)
		e.SpreadAngle = Vector2.new(180, 180)
	end,
	Shine = function(e)
		e.Texture = SPARKLE
		e.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 220, 100))
		e.LightEmission = 1
		e.Size = NumberSequence.new(1.2, 0)
		e.Speed = NumberRange.new(4, 9)
		e.Lifetime = NumberRange.new(0.4, 0.7)
		e.SpreadAngle = Vector2.new(180, 180)
	end,
	Fire = function(e)
		e.Texture = FIRE
		e.Color = ColorSequence.new(Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 40, 0))
		e.LightEmission = 1
		e.Size = NumberSequence.new(2, 0.3)
		e.Speed = NumberRange.new(4, 10)
		e.Lifetime = NumberRange.new(0.3, 0.6)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0, 15, 0)
	end,
	Lightning = function(e)
		e.Texture = SPARKLE
		e.Color = ColorSequence.new(Color3.fromRGB(255, 255, 200), Color3.fromRGB(90, 180, 255))
		e.LightEmission = 1
		e.Size = NumberSequence.new(1.5, 0)
		e.Speed = NumberRange.new(18, 30)
		e.Lifetime = NumberRange.new(0.1, 0.25)
		e.SpreadAngle = Vector2.new(180, 180)
	end,
	Cosmic = function(e)
		e.Texture = SPARKLE
		e.Color = ColorSequence.new(Color3.fromRGB(200, 140, 255), Color3.fromRGB(40, 230, 255))
		e.LightEmission = 1
		e.Size = NumberSequence.new(1.4, 0)
		e.Speed = NumberRange.new(3, 8)
		e.Lifetime = NumberRange.new(0.6, 1)
		e.SpreadAngle = Vector2.new(180, 180)
		e.RotSpeed = NumberRange.new(-180, 180)
	end,
	Mythic = function(e)
		e.Texture = SPARKLE
		e.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 160)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 230, 80)), ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 255, 255)) })
		e.LightEmission = 1
		e.Size = NumberSequence.new(2, 0)
		e.Speed = NumberRange.new(8, 16)
		e.Lifetime = NumberRange.new(0.5, 0.9)
		e.SpreadAngle = Vector2.new(180, 180)
	end,
}

function FruitVisuals.KatanaEffect(effect: string, position: Vector3)
	local setup = EFFECTS[effect] or EFFECTS.Sparks
	burst("Katana_" .. effect, position, effect == "Mythic" and 18 or 10, setup)
end

function FruitVisuals.Explosion(position: Vector3)
	burst("Explosion", position, 30, function(e)
		e.Texture = FIRE
		e.Color = ColorSequence.new(Color3.fromRGB(255, 220, 80), Color3.fromRGB(80, 20, 0))
		e.LightEmission = 0.8
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) })
		e.Speed = NumberRange.new(10, 25)
		e.Lifetime = NumberRange.new(0.3, 0.7)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Transparency = NumberSequence.new(0, 1)
	end)
end

-- Two halves that fly apart. Returned as debris entries for SlicingController to animate.
export type Debris = { Part: BasePart, Velocity: Vector3, Spin: Vector3, Life: number, Age: number, CFrame: CFrame }

function FruitVisuals.Halves(def: Fruits.FruitDef, cframe: CFrame, cutDirection: Vector3): { Debris }
	local r = def.Radius
	local result = {}
	local perpendicular = cutDirection:Cross(Vector3.new(0, 0, 1))
	if perpendicular.Magnitude < 0.01 then
		perpendicular = Vector3.new(1, 0, 0)
	end
	perpendicular = perpendicular.Unit
	for side = -1, 1, 2 do
		local half = basePart(Vector3.new(r * 2, r * 1.05, r * 2), def.Color:Lerp(def.Juice, 0.25), def.Material)
		sphereMesh(half)
		half.Parent = folder
		local orient = CFrame.lookAt(Vector3.zero, perpendicular * side) * CFrame.Angles(math.rad(90), 0, 0)
		local cf = CFrame.new(cframe.Position + perpendicular * side * r * 0.5) * orient.Rotation
		half.CFrame = cf
		table.insert(result, {
			Part = half,
			Velocity = perpendicular * side * math.random(8, 13) + Vector3.new(0, math.random(4, 9), 0),
			Spin = Vector3.new(math.random(-6, 6), math.random(-6, 6), side * math.random(3, 8)),
			Life = 0.9,
			Age = 0,
			CFrame = cf,
		})
	end
	return result
end

function FruitVisuals.GetFolder(): Folder
	return folder
end

function FruitVisuals.Init()
	folder = Instance.new("Folder")
	folder.Name = "FNS_LocalFruits"
	folder.Parent = workspace
	emitterHolder = basePart(Vector3.one, Color3.new(), nil)
	emitterHolder.Transparency = 1
	emitterHolder.Name = "FNS_Emitters"
	emitterHolder.CFrame = CFrame.new(0, -100, 0)
	emitterHolder.Parent = workspace
end

return FruitVisuals
