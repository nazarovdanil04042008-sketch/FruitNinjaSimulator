--!nonstrict
-- Renders every player's equipped creatures locally (from the "EquippedCreatures" player attribute)
-- and makes them float behind their owner. Client-side rendering = zero server physics and
-- perfectly smooth movement. Far-away players' pets are not updated (cheap on mobile).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ModelBuilder = require(game:GetService("ReplicatedStorage").Shared.Util.ModelBuilder)

local PetController = {}

type Entry = { Models: { Model }, Feet: { number }, Signature: string, Connection: RBXScriptConnection? }

local entries: { [Player]: Entry } = {}
local folder: Folder
local localHidden = false
local MAX_DISTANCE = 220
local rainbowParts: { BasePart } = {}
local rainbowDirty = true

local function collectRainbow()
	table.clear(rainbowParts)
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Rainbow") then
			table.insert(rainbowParts, d)
		end
	end
	rainbowDirty = false
end

local function clearModels(entry: Entry)
	for _, model in entry.Models do
		model:Destroy()
	end
	table.clear(entry.Models)
end

local function rebuild(player: Player)
	local entry = entries[player]
	if not entry then
		return
	end
	local signature = (player:GetAttribute("EquippedCreatures") :: string?) or ""
	if signature == entry.Signature then
		return
	end
	entry.Signature = signature
	clearModels(entry)
	table.clear(entry.Feet)
	for item in string.gmatch(signature, "[^,]+") do
		-- "Id:tier:shiny" (older servers sent just "Id")
		local id, tier, shiny = string.match(item, "^([^:]+):?(%d*):?(%d*)$")
		local model = ModelBuilder.Creature(id or item, tonumber(tier) or 0, shiny == "1")
		ModelBuilder.AnchorRoot(model)
		model:ScaleTo(0.8)
		-- distance from the root down to the soles, so pets walk on the ground
		local box, size = model:GetBoundingBox()
		local root = model.PrimaryPart :: BasePart
		table.insert(entry.Feet, root.Position.Y - (box.Position.Y - size.Y / 2))
		model.Parent = folder
		table.insert(entry.Models, model)
	end
	rainbowDirty = true
end

local function track(player: Player)
	local entry: Entry = { Models = {}, Feet = {}, Signature = "" }
	entries[player] = entry
	entry.Connection = player:GetAttributeChangedSignal("EquippedCreatures"):Connect(function()
		rebuild(player)
	end)
	rebuild(player)
end

local function untrack(player: Player)
	local entry = entries[player]
	if entry then
		clearModels(entry)
		if entry.Connection then
			entry.Connection:Disconnect()
		end
		entries[player] = nil
	end
end

function PetController.SetLocalHidden(hidden: boolean)
	localHidden = hidden
	local entry = entries[Players.LocalPlayer]
	if entry then
		for _, model in entry.Models do
			model.Parent = hidden and nil or folder
		end
	end
end

local roots: { BasePart } = {}
local cframes: { CFrame } = {}

local function update(dt: number)
	local camera = workspace.CurrentCamera
	local t = os.clock()
	local alpha = 1 - math.exp(-dt * 7)
	table.clear(roots)
	table.clear(cframes)
	for player, entry in entries do
		if player == Players.LocalPlayer and localHidden then
			continue
		end
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp or #entry.Models == 0 then
			continue
		end
		if (hrp.Position - camera.CFrame.Position).Magnitude > MAX_DISTANCE then
			continue
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local groundY = hrp.Position.Y - 3
		if humanoid and humanoid.RigType == Enum.HumanoidRigType.R15 then
			groundY = hrp.Position.Y - humanoid.HipHeight - hrp.Size.Y / 2
		end
		local velocity = hrp.AssemblyLinearVelocity
		local moving = Vector2.new(velocity.X, velocity.Z).Magnitude > 2
		local count = #entry.Models
		for i, model in entry.Models do
			local root = model.PrimaryPart
			if root then
				local spread = (i - (count + 1) / 2) * 3.6
				local row = 5 + math.abs(spread) * 0.25
				-- walking: little hops + side-to-side waddle; idle: gentle breathing bob
				local phase = t * 11 + i * 1.9
				local hop = moving and math.abs(math.sin(phase)) * 0.9 or (math.sin(t * 2.5 + i) + 1) * 0.08
				local waddle = moving and math.sin(phase) * 0.18 or math.sin(t * 1.5 + i) * 0.04
				local flat = hrp.CFrame * CFrame.new(spread, 0, row)
				local target = CFrame.new(flat.Position.X, groundY + (entry.Feet[i] or 1) + hop, flat.Position.Z)
					* hrp.CFrame.Rotation * CFrame.Angles(0, 0, waddle)
				local current = root.CFrame
				if (current.Position - target.Position).Magnitude > 40 then
					current = target -- teleported: snap
				end
				table.insert(roots, root)
				table.insert(cframes, current:Lerp(target, alpha))
			end
		end
	end
	if #roots > 0 then
		workspace:BulkMoveTo(roots, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
	-- Rainbow-tier pets slowly cycle through the colours
	if rainbowDirty then
		collectRainbow()
	end
	for i, part in rainbowParts do
		if part.Parent then
			part.Color = Color3.fromHSV((t * 0.2 + i * 0.03) % 1, 0.65, 1)
		end
	end
end

function PetController.Init()
	folder = Instance.new("Folder")
	folder.Name = "FNS_Pets"
	folder.Parent = workspace
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(untrack)
	for _, player in Players:GetPlayers() do
		track(player)
	end
	RunService.RenderStepped:Connect(update)
end

return PetController
