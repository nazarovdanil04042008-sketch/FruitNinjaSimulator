--!nonstrict
-- Interactive grass around the local player (client only, zero network):
--   * a pool of grass blades is scattered on Terrain grass around you (never on roads, floors or water)
--   * blades sway in the wind and bend away from your legs as you walk through them
--   * blades that end up far behind you are recycled ahead of you, so the patch follows you everywhere
-- Works together with Roblox's own terrain grass (Terrain.Decoration) but doesn't need it.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GrassController = {}

local player = Players.LocalPlayer
local folder: Folder
local rng = Random.new()

local RADIUS = 32
local MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local BLADE_COUNT = MOBILE and 150 or 260
local RECYCLE_PER_FRAME = 14
local PUSH_RADIUS = 3
local HIDDEN = CFrame.new(0, -400, 0)

type Blade = { Part: BasePart, Base: Vector3?, Yaw: number, Height: number, Phase: number }
local blades: { Blade } = {}
local parts: { BasePart } = {}
local cframes: { CFrame } = {}
local params = RaycastParams.new()
local recycleIndex = 1

local COLORS = {
	Color3.fromRGB(88, 160, 66), Color3.fromRGB(104, 176, 74), Color3.fromRGB(76, 145, 58), Color3.fromRGB(120, 185, 80), Color3.fromRGB(95, 168, 60),
}

local function focus(): (Vector3?, Vector3)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		return root.Position, root.AssemblyLinearVelocity
	end
	return nil, Vector3.zero
end

local function refreshFilter()
	local ignore = { folder }
	for _, name in { "FNS_Ambience", "FNS_LocalFruits", "FNS_Pets" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(ignore, f)
		end
	end
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
end

-- Find a spot on terrain grass near `center`. Returns nil if the random spot isn't grass.
local function findSpot(center: Vector3, minRadius: number, velocity: Vector3): Vector3?
	local a = rng:NextNumber(0, math.pi * 2)
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	if flat.Magnitude > 4 and rng:NextNumber() < 0.7 then
		-- moving: place new blades mostly ahead of the player
		a = math.atan2(flat.Z, flat.X) + rng:NextNumber(-1.1, 1.1)
	end
	local r = minRadius + math.sqrt(rng:NextNumber()) * (RADIUS - minRadius)
	local origin = Vector3.new(center.X + math.cos(a) * r, center.Y + 8, center.Z + math.sin(a) * r)
	local result = workspace:Raycast(origin, Vector3.new(0, -20, 0), params)
	if result and result.Instance == workspace.Terrain and result.Material == Enum.Material.Grass then
		return result.Position
	end
	return nil
end

local function step()
	local position, velocity = focus()
	table.clear(parts)
	table.clear(cframes)
	if not position then
		return
	end
	local t = os.clock()

	-- recycle a few blades per frame: unplaced ones and ones that fell too far behind
	for _ = 1, RECYCLE_PER_FRAME do
		local blade = blades[recycleIndex]
		recycleIndex = recycleIndex % #blades + 1
		local base = blade.Base
		if not base or Vector2.new(base.X - position.X, base.Z - position.Z).Magnitude > RADIUS + 3 then
			blade.Base = findSpot(position, base and RADIUS * 0.55 or 0, velocity)
			if not blade.Base then
				table.insert(parts, blade.Part)
				table.insert(cframes, HIDDEN)
			end
		end
	end

	for _, blade in blades do
		local base = blade.Base
		if base then
			-- wind: a slow wave travelling across the field
			local wind = math.sin(t * 1.8 + base.X * 0.22 + base.Z * 0.17 + blade.Phase) * 0.16 + 0.08
			local bendAxis = Vector3.new(0, 0, 1)
			local bend = wind
			local offset = Vector3.new(base.X - position.X, 0, base.Z - position.Z)
			local distance = offset.Magnitude
			if distance < PUSH_RADIUS and math.abs(base.Y - (position.Y - 3)) < 4 then
				-- trampled: bend away from the player
				local away = distance > 0.01 and offset.Unit or Vector3.new(1, 0, 0)
				bendAxis = Vector3.new(0, 1, 0):Cross(away)
				bend = (1 - distance / PUSH_RADIUS) * 1.15 + 0.1
			end
			local cf = CFrame.new(base) * CFrame.fromAxisAngle(bendAxis.Magnitude > 0 and bendAxis.Unit or Vector3.new(0, 0, 1), bend)
				* CFrame.Angles(0, blade.Yaw, 0) * CFrame.new(0, blade.Height / 2, 0)
			table.insert(parts, blade.Part)
			table.insert(cframes, cf)
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function GrassController.Init()
	folder = Instance.new("Folder")
	folder.Name = "FNS_Grass"
	folder.Parent = workspace
	for _ = 1, BLADE_COUNT do
		local height = rng:NextNumber(0.9, 1.8)
		local blade = Instance.new("WedgePart")
		blade.Anchored = true
		blade.CanCollide = false
		blade.CanQuery = false
		blade.CanTouch = false
		blade.CastShadow = false
		blade.Size = Vector3.new(0.07, height, 0.32)
		blade.Color = COLORS[rng:NextInteger(1, #COLORS)]
		blade.Material = Enum.Material.SmoothPlastic
		blade.CFrame = HIDDEN
		blade.Parent = folder
		table.insert(blades, { Part = blade, Base = nil, Yaw = rng:NextNumber(0, math.pi * 2), Height = height, Phase = rng:NextNumber(0, 6) })
	end
	refreshFilter()
	Players.PlayerAdded:Connect(function(other)
		other.CharacterAdded:Connect(refreshFilter)
	end)
	for _, other in Players:GetPlayers() do
		other.CharacterAdded:Connect(function()
			task.wait(0.5)
			refreshFilter()
		end)
	end
	task.spawn(function()
		while true do
			task.wait(5)
			refreshFilter() -- pick up folders created later (pets, fruit)
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return GrassController
