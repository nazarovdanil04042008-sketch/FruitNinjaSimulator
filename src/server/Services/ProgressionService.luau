--!nonstrict
-- Coins, XP, levels, stats, training level, character stats (walk speed / jump), leaderstats, teleports.
-- Every currency change in the game goes through this module.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Arenas = require(Shared.Config.Arenas)
local Locations = require(Shared.Config.Locations)
local Formulas = require(Shared.Util.Formulas)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Util.Net)

local DataService = require(script.Parent.DataService)
local ActionService = require(script.Parent.ActionService)

local ProgressionService = {}

local frozen: { [Player]: boolean } = {}
local notifyRemote: RemoteEvent
local statPopupRemote: RemoteEvent
local levelUpRemote: RemoteEvent

function ProgressionService.Notify(player: Player, text: string, kind: string?)
	notifyRemote:FireClient(player, text, kind or "info")
end

function ProgressionService.NotifyAll(text: string, kind: string?)
	notifyRemote:FireAllClients(text, kind or "info")
end

function ProgressionService.GetDerived(player: Player): Formulas.Derived?
	local profile = DataService.Get(player)
	return profile and Formulas.Compute(profile) or nil
end

function ProgressionService.AddCoins(player: Player, amount: number)
	local profile = DataService.Get(player)
	if not profile or amount <= 0 then
		return
	end
	amount = math.floor(amount)
	profile.Coins += amount
	profile.Totals.CoinsEarned += amount
	DataService.Replicate(player)
end

-- Returns false (and changes nothing) if the player can't afford it.
function ProgressionService.SpendCoins(player: Player, amount: number): boolean
	local profile = DataService.Get(player)
	if not profile or amount < 0 or profile.Coins < amount then
		return false
	end
	profile.Coins -= math.floor(amount)
	DataService.Replicate(player)
	return true
end

function ProgressionService.AddXp(player: Player, amount: number)
	local profile = DataService.Get(player)
	if not profile or amount <= 0 then
		return
	end
	profile.Xp += math.floor(amount)
	local levelsGained = 0
	local coinReward = 0
	while profile.Xp >= Formulas.XpForLevel(profile.Level) and profile.Level < 1000 do
		profile.Xp -= Formulas.XpForLevel(profile.Level)
		local oldSlots = Formulas.PetSlots(profile.Level)
		profile.Level += 1
		levelsGained += 1
		coinReward += GameConfig.LevelUpCoinReward * profile.Level
		if Formulas.PetSlots(profile.Level) > oldSlots then
			ProgressionService.Notify(player, "🐾 New creature slot unlocked! (" .. Formulas.PetSlots(profile.Level) .. " slots)", "rare")
		end
		for _, arena in Arenas.List do
			if arena.RequiredLevel == profile.Level then
				ProgressionService.Notify(player, "🔓 " .. arena.DisplayName .. " is now unlocked!", "rare")
			end
		end
	end
	if levelsGained > 0 then
		profile.Coins += coinReward
		levelUpRemote:FireClient(player, profile.Level, coinReward)
		ProgressionService.ApplyCharacterStats(player)
	end
	DataService.Replicate(player)
end

function ProgressionService.AddStat(player: Player, stat: string, amount: number)
	local profile = DataService.Get(player)
	if not profile or profile.Stats[stat] == nil or amount <= 0 then
		return
	end
	local before = profile.Stats[stat]
	profile.Stats[stat] = math.min(before + math.floor(amount), GameConfig.MaxStatLevel)
	local gained = profile.Stats[stat] - before
	if gained > 0 then
		statPopupRemote:FireClient(player, stat, gained)
	end
	ProgressionService.ApplyCharacterStats(player)
	DataService.Replicate(player)
end

function ProgressionService.AddTrainingXp(player: Player, amount: number)
	local profile = DataService.Get(player)
	if not profile or amount <= 0 then
		return
	end
	profile.TrainingXp += math.floor(amount)
	local leveled = false
	while profile.TrainingXp >= Formulas.TrainingXpForLevel(profile.TrainingLevel) and profile.TrainingLevel < 1000 do
		profile.TrainingXp -= Formulas.TrainingXpForLevel(profile.TrainingLevel)
		profile.TrainingLevel += 1
		leveled = true
	end
	if leveled then
		statPopupRemote:FireClient(player, "Training Level", profile.TrainingLevel)
		ProgressionService.Notify(player, "🥋 Training Level " .. profile.TrainingLevel .. "! New belts may be available.", "success")
	end
	DataService.Replicate(player)
end

------------------------------------------------------------------------------------------------
-- Character stats
------------------------------------------------------------------------------------------------
function ProgressionService.SetFrozen(player: Player, isFrozen: boolean)
	frozen[player] = isFrozen or nil
	ProgressionService.ApplyCharacterStats(player)
end

function ProgressionService.ApplyCharacterStats(player: Player)
	local profile = DataService.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not profile or not humanoid then
		return
	end
	local derived = Formulas.Compute(profile)
	humanoid.UseJumpPower = true
	if frozen[player] then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	else
		humanoid.WalkSpeed = derived.WalkSpeed
		humanoid.JumpPower = derived.JumpPower
	end
end

------------------------------------------------------------------------------------------------
-- Leaderstats
------------------------------------------------------------------------------------------------
local function setupLeaderstats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = 1
	level.Parent = folder
	local coins = Instance.new("StringValue")
	coins.Name = "Coins"
	coins.Value = "0"
	coins.Parent = folder
	folder.Parent = player
end

local function updateLeaderstats(player: Player, profile: any)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		return
	end
	local level = folder:FindFirstChild("Level") :: IntValue?
	local coins = folder:FindFirstChild("Coins") :: StringValue?
	if level then
		level.Value = profile.Level
	end
	if coins then
		coins.Value = Format.Short(profile.Coins)
	end
end

------------------------------------------------------------------------------------------------
-- Teleport
------------------------------------------------------------------------------------------------
function ProgressionService.CanEnterArena(profile: any, arenaId: string): boolean
	local arena = Arenas.Get(arenaId)
	return arena ~= nil and profile.Level >= arena.RequiredLevel
end

-- With StreamingEnabled the destination floor must be loaded on the client before we move them there.
function ProgressionService.StreamAround(player: Player, position: Vector3)
	if workspace.StreamingEnabled then
		pcall(function()
			player:RequestStreamAroundAsync(position, 4)
		end)
	end
end

function ProgressionService.TeleportTo(player: Player, position: Vector3, lookAt: Vector3?)
	local character = player.Character
	if not character or not character.PrimaryPart then
		return
	end
	local target = if lookAt then CFrame.lookAt(position, Vector3.new(lookAt.X, position.Y, lookAt.Z)) else CFrame.new(position)
	ProgressionService.StreamAround(player, position)
	character:PivotTo(target)
end

function ProgressionService.Init()
	notifyRemote = Net.Event("Notify")
	statPopupRemote = Net.Event("StatPopup")
	levelUpRemote = Net.Event("LevelUp")

	ActionService.Register("Teleport", function(player, profile, locationId: any)
		if not ActionService.IsString(locationId) then
			return false, "Invalid location."
		end
		local location = Locations.ById[locationId]
		if not location then
			return false, "Unknown location."
		end
		if location.ArenaId and not ProgressionService.CanEnterArena(profile, location.ArenaId) then
			local arena = Arenas.Get(location.ArenaId)
			return false, "Reach level " .. (arena and arena.RequiredLevel or 0) .. " to unlock " .. location.DisplayName .. "!"
		end
		if frozen[player] then
			return false, "Leave the slicing round first."
		end
		ProgressionService.TeleportTo(player, location.Position)
		return true, "Teleported to " .. location.DisplayName
	end)
end

function ProgressionService.Start()
	Players.PlayerAdded:Connect(setupLeaderstats)
	for _, player in Players:GetPlayers() do
		if not player:FindFirstChild("leaderstats") then
			setupLeaderstats(player)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		frozen[player] = nil
	end)

	DataService.ProfileLoaded:Connect(function(player, profile)
		updateLeaderstats(player, profile)
		ProgressionService.ApplyCharacterStats(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			ProgressionService.ApplyCharacterStats(player)
		end)
	end)
	DataService.ProfileChanged:Connect(function(player, profile)
		updateLeaderstats(player, profile)
	end)
end

return ProgressionService
