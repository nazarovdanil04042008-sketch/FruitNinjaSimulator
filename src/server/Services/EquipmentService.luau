--!nonstrict
-- Puts the equipped katana (on the back), belt (around the waist) and trail (behind) on the character,
-- and publishes the equipped creature ids as a player attribute so every client can render pets locally.
-- Visuals are rebuilt only when the equipped items actually change.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Belts = require(Shared.Config.Belts)
local Trails = require(Shared.Config.Trails)
local ModelBuilder = require(Shared.Util.ModelBuilder)

local DataService = require(script.Parent.DataService)

local EquipmentService = {}

local applied: { [Player]: string } = {} -- signature of what is currently on the character
local petSignature: { [Player]: string } = {}

local function getTorso(character: Model): BasePart?
	return (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
end

local function getWaist(character: Model): (BasePart?, number)
	local lower = character:FindFirstChild("LowerTorso") :: BasePart?
	if lower then
		return lower, 0.1
	end
	return character:FindFirstChild("Torso") :: BasePart?, -0.8
end

local function weld(part0: BasePart, part1: BasePart, c0: CFrame)
	local w = Instance.new("Weld")
	w.Part0 = part0
	w.Part1 = part1
	w.C0 = c0
	w.Parent = part1
end

local function clear(character: Model)
	for _, name in { "FNS_Katana", "FNS_Belt", "FNS_Trail" } do
		local existing = character:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		for _, name in { "FNS_TrailTop", "FNS_TrailBottom", "FNS_TrailParticles" } do
			local existing = root:FindFirstChild(name)
			if existing then
				existing:Destroy()
			end
		end
	end
end

local function buildKatana(character: Model, katanaId: string)
	local torso = getTorso(character)
	if not torso then
		return
	end
	local model = ModelBuilder.Katana(katanaId)
	model.Name = "FNS_Katana"
	local handle = model.PrimaryPart :: BasePart
	model.Parent = character
	weld(torso, handle, CFrame.new(0.5, -0.6, 0.62) * CFrame.Angles(0, 0, math.rad(38)))
end

local function buildBelt(character: Model, beltId: string)
	local waist, offsetY = getWaist(character)
	if not waist then
		return
	end
	local def = Belts.Get(beltId)
	local model = Instance.new("Model")
	model.Name = "FNS_Belt"
	local function part(name: string, size: Vector3, offset: CFrame)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = def.Color
		p.Material = def.Material
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		p.Parent = model
		weld(waist, p, offset)
		return p
	end
	local band = part("Band", Vector3.new(waist.Size.X + 0.12, 0.32, waist.Size.Z + 0.12), CFrame.new(0, offsetY, 0))
	part("Knot", Vector3.new(0.42, 0.38, 0.16), CFrame.new(0, offsetY, -waist.Size.Z / 2 - 0.1))
	part("TailL", Vector3.new(0.16, 0.7, 0.1), CFrame.new(-0.16, offsetY - 0.45, -waist.Size.Z / 2 - 0.12) * CFrame.Angles(0, 0, math.rad(-12)))
	part("TailR", Vector3.new(0.16, 0.7, 0.1), CFrame.new(0.16, offsetY - 0.45, -waist.Size.Z / 2 - 0.12) * CFrame.Angles(0, 0, math.rad(12)))
	if def.Order >= 9 then
		local light = Instance.new("PointLight")
		light.Color = def.Color
		light.Range = 6
		light.Brightness = 1
		light.Parent = band
	end
	model.Parent = character
end

local function buildTrail(character: Model, trailId: string)
	local def = Trails.Get(trailId)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not def or not root then
		return
	end
	local top = Instance.new("Attachment")
	top.Name = "FNS_TrailTop"
	top.Position = Vector3.new(0, def.Width / 2, 0.6)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "FNS_TrailBottom"
	bottom.Position = Vector3.new(0, -def.Width / 2, 0.6)
	bottom.Parent = root

	local keypoints = {}
	for i, color in def.Colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / math.max(#def.Colors - 1, 1), color))
	end
	local trail = Instance.new("Trail")
	trail.Name = "FNS_Trail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(keypoints)
	trail.Lifetime = def.Lifetime
	trail.LightEmission = def.LightEmission
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	trail.MinLength = 0.2
	trail.FaceCamera = true
	trail.Parent = character

	if def.Particles then
		local attachment = Instance.new("Attachment")
		attachment.Name = "FNS_TrailParticles"
		attachment.Position = Vector3.new(0, -1.5, 0.5)
		attachment.Parent = root
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = def.ParticleTexture or "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(keypoints)
		emitter.Rate = def.ParticleRate or 8
		emitter.Lifetime = NumberRange.new(0.5, 0.9)
		emitter.Speed = NumberRange.new(0.5, 1.5)
		emitter.SpreadAngle = Vector2.new(60, 60)
		emitter.LightEmission = def.LightEmission
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		emitter.Transparency = NumberSequence.new(0.2, 1)
		emitter.Parent = attachment
	end
end

function EquipmentService.Refresh(player: Player, force: boolean?)
	local profile = DataService.Get(player)
	local character = player.Character
	if not profile or not character or not character.Parent then
		return
	end

	-- Pets: "Id:tier:shiny" entries separated by commas, rendered client-side by PetController.
	local ids = {}
	for _, uid in profile.EquippedCreatures do
		local entry = profile.Creatures[uid]
		if entry then
			table.insert(ids, entry.Id .. ":" .. (entry.Tier or 0) .. ":" .. (entry.Shiny and 1 or 0))
		end
	end
	local pets = table.concat(ids, ",")
	if petSignature[player] ~= pets then
		petSignature[player] = pets
		player:SetAttribute("EquippedCreatures", pets)
	end

	local signature = profile.EquippedKatana .. "|" .. profile.EquippedBelt .. "|" .. profile.EquippedTrail
	if not force and applied[player] == signature and character:FindFirstChild("FNS_Katana") then
		return
	end
	applied[player] = signature
	clear(character)
	buildKatana(character, profile.EquippedKatana)
	buildBelt(character, profile.EquippedBelt)
	if profile.EquippedTrail ~= "" then
		buildTrail(character, profile.EquippedTrail)
	end
end

function EquipmentService.Init() end

function EquipmentService.Start()
	local function hookCharacter(player: Player, character: Model)
		-- Wait until the avatar is assembled so the torso parts exist.
		local started = os.clock()
		while not player:HasAppearanceLoaded() and os.clock() - started < 6 do
			task.wait(0.2)
		end
		character:WaitForChild("HumanoidRootPart", 10)
		if player.Character == character then
			EquipmentService.Refresh(player, true)
		end
	end

	DataService.ProfileLoaded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			hookCharacter(player, character)
		end)
		if player.Character then
			task.spawn(hookCharacter, player, player.Character)
		end
	end)
	DataService.ProfileChanged:Connect(function(player)
		EquipmentService.Refresh(player, false)
	end)
	Players.PlayerRemoving:Connect(function(player)
		applied[player] = nil
		petSignature[player] = nil
	end)
end

return EquipmentService
