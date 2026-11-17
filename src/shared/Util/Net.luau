--!strict
-- Remote definitions. The server creates every remote at startup (Net.Setup) inside
-- ReplicatedStorage.Remotes, the client waits for them. No remote has to be created by hand in Studio.
--
-- Client -> Server (always validated on the server):
--   SlicingStart(arenaId)          ask to start a slicing round in an arena
--   SlicingStop()                  leave the current round
--   Slice({spawnId, ...})          objects the blade passed through this frame
--   Action (RemoteFunction)        (actionName, ...) -> (ok, message, extra)   all shop / equip / egg / training actions
--   GetData (RemoteFunction)       () -> profile snapshot
-- Server -> Client:
--   DataChanged(profile)           full profile snapshot after any change
--   SpawnObjects(arenaId, padIndex, {spawn...})
--   SliceResult({results})         per-object rewards for visual feedback
--   SessionStarted(arenaId, padIndex, hearts)
--   SessionEnded(summary)
--   Notify(text, kind)             toast message ("info" | "success" | "error" | "rare")
--   StatPopup(statName, amount)    "+3 Speed!" feedback
--   HatchReveal(creatureId, isNew, uid)
--   LevelUp(newLevel, coinReward)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

Net.Events = {
	"SlicingStart",
	"SlicingStop",
	"Slice",
	"DataChanged",
	"SpawnObjects",
	"SliceResult",
	"SessionStarted",
	"SessionEnded",
	"Notify",
	"StatPopup",
	"HatchReveal",
	"LevelUp",
}

Net.Functions = {
	"Action",
	"GetData",
}

local FOLDER_NAME = "Remotes"

function Net.Setup()
	assert(RunService:IsServer(), "Net.Setup must run on the server")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for _, name in Net.Events do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for _, name in Net.Functions do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

local function getFolder(): Instance
	if RunService:IsServer() then
		return ReplicatedStorage:FindFirstChild(FOLDER_NAME) :: Instance
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

function Net.Event(name: string): RemoteEvent
	local remote = getFolder():WaitForChild(name, 30)
	assert(remote and remote:IsA("RemoteEvent"), "Missing RemoteEvent " .. name)
	return remote :: RemoteEvent
end

function Net.Function(name: string): RemoteFunction
	local remote = getFolder():WaitForChild(name, 30)
	assert(remote and remote:IsA("RemoteFunction"), "Missing RemoteFunction " .. name)
	return remote :: RemoteFunction
end

return Net
