--!nonstrict
-- Loads, validates, replicates and saves player profiles.
--
-- Reliability features:
--   * UpdateAsync everywhere (never SetAsync) so concurrent writes can't clobber each other.
--   * Session locking: a profile is locked to one server (JobId). Another server waits for the lock
--     to be released (or to go stale after GameConfig.SessionLockTimeout) before loading it, which
--     prevents item duplication / rollback when players hop servers quickly.
--   * Retries with exponential back-off for every DataStore request.
--   * If loading fails for real, the player is kicked with a friendly message INSTEAD of being given
--     an empty profile that would overwrite their progress on leave.
--   * Studio without "Enable Studio Access to API Services": the game still runs with a fresh
--     profile and simply never saves (a warning is printed).
--   * Autosave every GameConfig.AutosaveInterval seconds, save on leave, save on shutdown (BindToClose).

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Katanas = require(Shared.Config.Katanas)
local Belts = require(Shared.Config.Belts)
local Trails = require(Shared.Config.Trails)
local Creatures = require(Shared.Config.Creatures)
local Eggs = require(Shared.Config.Eggs)
local Formulas = require(Shared.Util.Formulas)
local Buildings = require(Shared.Config.Buildings)
local PlotGrid = require(Shared.Util.PlotGrid)
local Signal = require(Shared.Util.Signal)
local Net = require(Shared.Util.Net)

local DataService = {}
DataService.ProfileLoaded = Signal.new() -- (player, profile)
DataService.ProfileChanged = Signal.new() -- (player, profile)  fired (throttled) after changes
DataService.Offline = false

local profiles: { [Player]: any } = {}
local dirty: { [Player]: boolean } = {}
local pendingReplicate: { [Player]: boolean } = {}
local saving: { [Player]: boolean } = {}
local store: DataStore? = nil

local MAX_RETRIES = 5

------------------------------------------------------------------------------------------------
-- Template + reconciliation
------------------------------------------------------------------------------------------------
local function newTemplate()
	return {
		Version = GameConfig.DataVersion,
		Coins = GameConfig.StartingCoins,
		Xp = 0,
		Level = 1,
		Stats = { Speed = 0, Strength = 0, Agility = 0 },
		TrainingLevel = 1,
		TrainingXp = 0,
		OwnedKatanas = { [Katanas.Default] = true },
		EquippedKatana = Katanas.Default,
		OwnedBelts = { [Belts.Default] = true },
		EquippedBelt = Belts.Default,
		OwnedTrails = {},
		EquippedTrail = "",
		Creatures = {}, -- uid -> { Id = creatureId, Obtained = unix }
		EquippedCreatures = {}, -- { uid, ... }
		Discovered = {}, -- creatureId -> true
		Eggs = {}, -- { { Uid, EggId, HatchAt }, ... }
		BuildInventory = {}, -- buildingId -> count bought but not placed
		Buildings = {}, -- placed on the plot: { { Uid, Id, X, Z, R }, ... }
		NextUid = 1,
		Totals = { FruitsSliced = 0, EggsHatched = 0, BestCombo = 0, CoinsEarned = 0, BombsHit = 0, TrainingsDone = 0 },
		LastJoin = 0,
	}
end

-- Fill missing keys from the template (deep), without overwriting existing values.
local function reconcile(target: any, template: any)
	for key, value in template do
		if target[key] == nil then
			if type(value) == "table" then
				target[key] = table.clone(value)
				reconcile(target[key], value)
			else
				target[key] = value
			end
		elseif type(value) == "table" and type(target[key]) == "table" and next(value) ~= nil then
			reconcile(target[key], value)
		end
	end
end

local function sanitizeNumber(n: any, fallback: number, min: number?, max: number?): number
	if type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then
		return fallback
	end
	if min then
		n = math.max(n, min)
	end
	if max then
		n = math.min(n, max)
	end
	return n
end

-- Removes anything invalid (items deleted from config, corrupted values) so the rest of the code can trust the profile.
local function sanitize(profile: any)
	profile.Coins = math.floor(sanitizeNumber(profile.Coins, 0, 0))
	profile.Xp = math.floor(sanitizeNumber(profile.Xp, 0, 0))
	profile.Level = math.floor(sanitizeNumber(profile.Level, 1, 1, 1000))
	profile.TrainingLevel = math.floor(sanitizeNumber(profile.TrainingLevel, 1, 1, 1000))
	profile.TrainingXp = math.floor(sanitizeNumber(profile.TrainingXp, 0, 0))
	for _, stat in { "Speed", "Strength", "Agility" } do
		profile.Stats[stat] = math.floor(sanitizeNumber(profile.Stats[stat], 0, 0, GameConfig.MaxStatLevel))
	end

	for id in profile.OwnedKatanas do
		if not Katanas.ById[id] then
			profile.OwnedKatanas[id] = nil
		end
	end
	profile.OwnedKatanas[Katanas.Default] = true
	if not profile.OwnedKatanas[profile.EquippedKatana] then
		profile.EquippedKatana = Katanas.Default
	end

	for id in profile.OwnedBelts do
		if not Belts.ById[id] then
			profile.OwnedBelts[id] = nil
		end
	end
	profile.OwnedBelts[Belts.Default] = true
	if not profile.OwnedBelts[profile.EquippedBelt] then
		profile.EquippedBelt = Belts.Default
	end

	for id in profile.OwnedTrails do
		if not Trails.ById[id] then
			profile.OwnedTrails[id] = nil
		end
	end
	if type(profile.EquippedTrail) ~= "string" or (profile.EquippedTrail ~= "" and not profile.OwnedTrails[profile.EquippedTrail]) then
		profile.EquippedTrail = ""
	end

	for uid, entry in profile.Creatures do
		if type(entry) ~= "table" or not Creatures.ById[entry.Id] then
			profile.Creatures[uid] = nil
		end
	end
	local seen = {}
	local equipped = {}
	local slots = Formulas.PetSlots(profile.Level)
	for _, uid in profile.EquippedCreatures do
		if profile.Creatures[uid] and not seen[uid] and #equipped < slots then
			seen[uid] = true
			table.insert(equipped, uid)
		end
	end
	profile.EquippedCreatures = equipped

	local eggs = {}
	for _, egg in profile.Eggs do
		if type(egg) == "table" and Eggs.ById[egg.EggId] and type(egg.HatchAt) == "number" and type(egg.Uid) == "string" then
			table.insert(eggs, egg)
		end
	end
	profile.Eggs = eggs

	for id, count in profile.BuildInventory do
		if not Buildings.Get(id) or type(count) ~= "number" or count < 1 then
			profile.BuildInventory[id] = nil
		else
			profile.BuildInventory[id] = math.floor(math.min(count, 999))
		end
	end
	local placed = {}
	for _, item in profile.Buildings do
		local def = type(item) == "table" and Buildings.Get(item.Id)
		local valid = def
			and type(item.Uid) == "string"
			and type(item.X) == "number" and type(item.Z) == "number" and type(item.R) == "number"
			and item.X % 1 == 0 and item.Z % 1 == 0 and item.R % 1 == 0
			and #placed < Buildings.MaxPlacedTotal
			and PlotGrid.CountPlaced(placed, item.Id) < def.MaxPlaced
			and PlotGrid.CanPlace(placed, item.Id, item.X, item.Z, item.R % 4)
		if valid then
			item.R = item.R % 4
			table.insert(placed, item)
		elseif def then
			-- invalid spot (e.g. grid size changed): give the building back instead of deleting it
			profile.BuildInventory[item.Id] = (profile.BuildInventory[item.Id] or 0) + 1
		end
	end
	profile.Buildings = placed
	profile.NextUid = math.floor(sanitizeNumber(profile.NextUid, 1, 1))
end

------------------------------------------------------------------------------------------------
-- DataStore helpers
------------------------------------------------------------------------------------------------
local function keyFor(userId: number): string
	return "Player_" .. userId
end

-- Errors that will never succeed on retry (Studio API access disabled, unpublished place).
local function isApiAccessError(message: string): boolean
	message = message:lower()
	if message:find("studio") and (message:find("api") or message:find("access") or message:find("not allowed")) then
		return true
	end
	return message:find("publish") ~= nil
end

local function retry<T>(fn: () -> T): (boolean, T | string)
	local lastError: string = "unknown"
	for attempt = 1, MAX_RETRIES do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = tostring(result)
		if isApiAccessError(lastError) then
			return false, lastError
		end
		warn(string.format("[DataService] DataStore request failed (attempt %d/%d): %s", attempt, MAX_RETRIES, lastError))
		task.wait(math.min(2 ^ attempt, 16))
	end
	return false, lastError
end

------------------------------------------------------------------------------------------------
-- Loading
------------------------------------------------------------------------------------------------
local function loadFromStore(player: Player): (boolean, any)
	local activeStore = store
	if not activeStore then
		return true, nil
	end
	local key = keyFor(player.UserId)
	local attempts = 0
	while true do
		attempts += 1
		local lockedElsewhere = false
		local forceLock = attempts >= 6 -- after ~30s of waiting, assume the other server died
		local ok, result = retry(function()
			return activeStore:UpdateAsync(key, function(record: any)
				record = record or {}
				local lock = record.Lock
				if not forceLock and lock and lock.JobId ~= game.JobId and os.time() - (lock.Time or 0) < GameConfig.SessionLockTimeout then
					lockedElsewhere = true
					return nil -- cancel: another server still owns this profile
				end
				record.Lock = { JobId = game.JobId, Time = os.time() }
				return record
			end)
		end)
		if not ok then
			return false, result
		end
		if not lockedElsewhere then
			local record = result :: any
			return true, record and record.Data or nil
		end
		if not player.Parent then
			return false, "player left"
		end
		task.wait(5)
	end
end

local function onPlayerAdded(player: Player)
	local ok, data = loadFromStore(player)
	if not player.Parent then
		return
	end
	if not ok then
		if isApiAccessError(tostring(data)) then
			warn("[DataService] Studio API access is disabled - running WITHOUT saving. Enable it in Game Settings > Security to test saving.")
			DataService.Offline = true
			store = nil
			data = nil
		else
			warn("[DataService] Could not load data for " .. player.Name .. ": " .. tostring(data))
			player:Kick("We couldn't load your save data right now (Roblox servers are having trouble). Your progress is safe - please rejoin in a minute!")
			return
		end
	end

	local profile = type(data) == "table" and data or newTemplate()
	reconcile(profile, newTemplate())
	sanitize(profile)
	profile.LastJoin = os.time()

	profiles[player] = profile
	DataService.ProfileLoaded:Fire(player, profile)
	DataService.Replicate(player)
end

------------------------------------------------------------------------------------------------
-- Saving
------------------------------------------------------------------------------------------------
local function save(player: Player, releaseLock: boolean): boolean
	local profile = profiles[player]
	local activeStore = store
	if not profile or not activeStore or DataService.Offline then
		return true
	end
	if saving[player] then
		-- Wait for an in-flight save (e.g. autosave) to finish so the final save always wins.
		local started = os.clock()
		while saving[player] and os.clock() - started < 20 do
			task.wait(0.2)
		end
	end
	saving[player] = true
	local snapshot = HttpService:JSONDecode(HttpService:JSONEncode(profile)) -- deep copy
	local ok, err = retry(function()
		return activeStore:UpdateAsync(keyFor(player.UserId), function(record: any)
			record = record or {}
			local lock = record.Lock
			if lock and lock.JobId ~= game.JobId and os.time() - (lock.Time or 0) < GameConfig.SessionLockTimeout then
				-- Another server force-took this profile; never overwrite its newer data.
				return nil
			end
			record.Data = snapshot
			record.Lock = if releaseLock then nil else { JobId = game.JobId, Time = os.time() }
			record.SavedAt = os.time()
			return record
		end)
	end)
	saving[player] = nil
	if not ok then
		warn("[DataService] Save failed for " .. player.Name .. ": " .. tostring(err))
		return false
	end
	dirty[player] = nil
	return true
end

local function onPlayerRemoving(player: Player)
	if profiles[player] then
		save(player, true)
	end
	profiles[player] = nil
	dirty[player] = nil
	pendingReplicate[player] = nil
end

------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------
function DataService.Get(player: Player): any
	return profiles[player]
end

function DataService.WaitFor(player: Player, timeout: number?): any
	local started = os.clock()
	while not profiles[player] and player.Parent and os.clock() - started < (timeout or 30) do
		task.wait(0.1)
	end
	return profiles[player]
end

-- Mark the profile as changed: it will be replicated to the client (throttled) and saved on the next autosave.
function DataService.Replicate(player: Player)
	if profiles[player] then
		dirty[player] = true
		pendingReplicate[player] = true
	end
end

-- Immediate save (used after trades so both sides are persisted right away). Returns success.
function DataService.SaveNow(player: Player): boolean
	return save(player, false)
end

function DataService.NewUid(player: Player, prefix: string): string
	local profile = profiles[player]
	local uid = prefix .. tostring(profile.NextUid)
	profile.NextUid += 1
	return uid
end

function DataService.Init()
	Net.Function("GetData").OnServerInvoke = function(player: Player)
		return DataService.WaitFor(player, 15)
	end

	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStoreService unavailable (" .. tostring(result) .. ") - running without saving.")
		DataService.Offline = true
	end
end

function DataService.Start()
	Players.PlayerAdded:Connect(function(player)
		task.defer(onPlayerAdded, player)
	end)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	-- Deferred so every service has connected to ProfileLoaded before the first profile can load.
	for _, player in Players:GetPlayers() do
		task.defer(onPlayerAdded, player)
	end

	-- Throttled replication: at most ~6 snapshots per second per player, no matter how often data changes.
	local dataChanged = Net.Event("DataChanged")
	task.spawn(function()
		while true do
			task.wait(0.15)
			for player in pendingReplicate do
				pendingReplicate[player] = nil
				local profile = profiles[player]
				if profile and player.Parent then
					dataChanged:FireClient(player, profile)
					DataService.ProfileChanged:Fire(player, profile)
				end
			end
		end
	end)

	-- Autosave
	task.spawn(function()
		while true do
			task.wait(GameConfig.AutosaveInterval)
			for player in profiles do
				if dirty[player] and player.Parent then
					task.spawn(save, player, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		if DataService.Offline or not store then
			return
		end
		local remaining = 0
		for player in profiles do
			remaining += 1
			task.spawn(function()
				save(player, true)
				remaining -= 1
			end)
		end
		local started = os.clock()
		while remaining > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)

	if RunService:IsStudio() then
		print("[DataService] Running in Studio. Saving is " .. (DataService.Offline and "OFF" or "ON (if API access is enabled)") .. ".")
	end
end

return DataService
