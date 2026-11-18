--!nonstrict
-- Daily login rewards (7-day streak), playtime rewards (per session) and daily quests.
--
-- Profile fields: DailyStreak, LastDailyDay, Quests = { Day, List = { { Id, Target, Progress, Claimed } } },
-- Boosts = { Coins = unixExpiry, Xp = unixExpiry }  (2x boosts, applied in Formulas.Compute)
-- Player attributes for the UI: FNS_JoinTime (unix), FNS_PlaytimeClaimed ("5,10,...")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local LiveOps = require(Shared.Config.LiveOps)
local Eggs = require(Shared.Config.Eggs)
local Format = require(Shared.Util.Format)

local DataService = require(script.Parent.DataService)
local ActionService = require(script.Parent.ActionService)
local ProgressionService = require(script.Parent.ProgressionService)
local EggService = require(script.Parent.EggService)
local QuestBus = require(script.Parent.QuestBus)

local RewardService = {}

local joinTime: { [Player]: number } = {}
local playtimeClaimed: { [Player]: { [number]: boolean } } = {}

-- Gives a reward table ({Coins, Xp, Egg, Boost, BoostMinutes}); returns a short description.
local function give(player: Player, profile: any, reward: any): string
	local parts = {}
	if reward.Coins then
		local coins = LiveOps.ScaleCoins(reward.Coins, profile.Level)
		ProgressionService.AddCoins(player, coins)
		table.insert(parts, "🪙 " .. Format.Short(coins))
	end
	if reward.Xp then
		ProgressionService.AddXp(player, reward.Xp)
		table.insert(parts, "⭐ " .. reward.Xp .. " XP")
	end
	if reward.Egg then
		if EggService.AddEgg(player, reward.Egg) then
			local egg = Eggs.Get(reward.Egg)
			table.insert(parts, "🥚 " .. (egg and egg.DisplayName or reward.Egg))
		end
	end
	if reward.Boost then
		local now = os.time()
		profile.Boosts[reward.Boost] = math.max(profile.Boosts[reward.Boost] or 0, now) + (reward.BoostMinutes or 10) * 60
		table.insert(parts, "⚡ 2x " .. reward.Boost .. " for " .. (reward.BoostMinutes or 10) .. "m")
		ProgressionService.ApplyCharacterStats(player)
	end
	DataService.Replicate(player)
	return table.concat(parts, ", ")
end

local function niceTarget(value: number): number
	if value >= 1000 then
		return math.floor(value / 500 + 0.5) * 500
	elseif value >= 100 then
		return math.floor(value / 25 + 0.5) * 25
	end
	return value
end

-- Makes sure today's quests exist (new set every UTC day, same set if you rejoin).
local function ensureQuests(player: Player, profile: any)
	local today = LiveOps.Day(os.time())
	if profile.Quests.Day == today and #profile.Quests.List > 0 then
		return
	end
	local rng = Random.new(player.UserId * 31 + today)
	local pool = table.clone(LiveOps.Quests)
	local list = {}
	for _ = 1, math.min(LiveOps.QuestsPerDay, #pool) do
		local def = table.remove(pool, rng:NextInteger(1, #pool))
		table.insert(list, { Id = def.Id, Target = niceTarget(rng:NextInteger(def.Min, def.Max)), Progress = 0, Claimed = false })
	end
	profile.Quests = { Day = today, List = list }
	DataService.Replicate(player)
end

local function onProgress(player: Player, kind: string, amount: number)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	ensureQuests(player, profile)
	for _, quest in profile.Quests.List do
		local def = LiveOps.QuestById[quest.Id]
		if def and def.Kind == kind and not quest.Claimed and quest.Progress < quest.Target then
			quest.Progress = math.min(quest.Target, quest.Progress + amount)
			if quest.Progress >= quest.Target then
				ProgressionService.Notify(player, "✅ Quest complete: " .. string.format(def.Text, quest.Target) .. "! Claim it in 🎁 Rewards.", "success")
			end
			DataService.Replicate(player)
		end
	end
end

function RewardService.Init()
	ActionService.Register("ClaimDaily", function(player, profile)
		local today = LiveOps.Day(os.time())
		if profile.LastDailyDay == today then
			local wait = (today + 1) * 86400 - os.time()
			return false, "Come back in " .. Format.Time(wait) .. " for your next daily reward!"
		end
		local streak = if profile.LastDailyDay == today - 1 then profile.DailyStreak % #LiveOps.Daily + 1 else 1
		profile.DailyStreak = streak
		profile.LastDailyDay = today
		local text = give(player, profile, LiveOps.Daily[streak])
		return true, "Day " .. streak .. " reward: " .. text
	end)

	ActionService.Register("ClaimPlaytime", function(player, profile, minutes: any)
		if type(minutes) ~= "number" then
			return false, "Invalid reward."
		end
		local reward
		for _, entry in LiveOps.Playtime do
			if entry.Minutes == minutes then
				reward = entry
			end
		end
		if not reward then
			return false, "Invalid reward."
		end
		local claimed = playtimeClaimed[player] or {}
		playtimeClaimed[player] = claimed
		if claimed[minutes] then
			return false, "Already claimed."
		end
		local played = (os.time() - (joinTime[player] or os.time())) / 60
		if played < minutes then
			return false, "Play " .. math.ceil(minutes - played) .. " more minute(s)!"
		end
		claimed[minutes] = true
		local list = {}
		for m in claimed do
			table.insert(list, tostring(m))
		end
		player:SetAttribute("FNS_PlaytimeClaimed", table.concat(list, ","))
		return true, "Playtime reward: " .. give(player, profile, reward)
	end)

	ActionService.Register("ClaimQuest", function(player, profile, index: any)
		if not ActionService.IsInteger(index, 1, 10) then
			return false, "Invalid quest."
		end
		ensureQuests(player, profile)
		local quest = profile.Quests.List[index]
		local def = quest and LiveOps.QuestById[quest.Id]
		if not def then
			return false, "Quest not found."
		end
		if quest.Claimed then
			return false, "Already claimed."
		end
		if quest.Progress < quest.Target then
			return false, "Not finished yet (" .. quest.Progress .. "/" .. quest.Target .. ")."
		end
		quest.Claimed = true
		return true, "Quest reward: " .. give(player, profile, { Coins = def.Coins, Xp = def.Xp, Egg = def.Egg })
	end)

	QuestBus.Progress:Connect(onProgress)
end

function RewardService.Start()
	local function onJoin(player: Player)
		joinTime[player] = os.time()
		playtimeClaimed[player] = {}
		player:SetAttribute("FNS_JoinTime", joinTime[player])
		player:SetAttribute("FNS_PlaytimeClaimed", "")
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, player in Players:GetPlayers() do
		onJoin(player)
	end
	DataService.ProfileLoaded:Connect(function(player, profile)
		ensureQuests(player, profile)
	end)
	Players.PlayerRemoving:Connect(function(player)
		joinTime[player] = nil
		playtimeClaimed[player] = nil
	end)
end

return RewardService
