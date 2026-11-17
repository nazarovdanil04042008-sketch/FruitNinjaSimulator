--!nonstrict
-- Renders every player's equipped creatures locally (from the "EquippedCreatures" player attribute)
-- and makes them float behind their owner. Client-side rendering = zero server physics and
-- perfectly smooth movement. Far-away players' pets are not updated (cheap on mobile).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ModelBuilder = require(game:GetService("ReplicatedStorage").Shared.Util.ModelBuilder)

local PetController = {}

type Entry = { Models: { Model }, Signature: string, Connection: RBXScriptConnection? }

local entries: { [Player]: Entry } = {}
local folder: Folder
local localHidden = false
local MAX_DISTANCE = 220

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
	for id in string.gmatch(signature, "[^,]+") do
		local model = ModelBuilder.Creature(id)
		ModelBuilder.AnchorRoot(model)
		model:ScaleTo(0.8)
		model.Parent = folder
		table.insert(entry.Models, model)
	end
end

local function track(player: Player)
	local entry: Entry = { Models = {}, Signature = "" }
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
		local count = #entry.Models
		for i, model in entry.Models do
			local root = model.PrimaryPart
			if root then
				local spread = (i - (count + 1) / 2) * 3.4
				local row = 5 + math.abs(spread) * 0.25
				local bob = math.sin(t * 3 + i * 1.7) * 0.35
				local target = hrp.CFrame * CFrame.new(spread, -0.6 + bob, row)
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
