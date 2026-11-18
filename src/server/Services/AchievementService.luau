--!nonstrict
-- Roblox badges for milestones (IDs in Config/Monetization.Badges; 0 = skipped).
-- Listens to QuestBus so gameplay code doesn't need to know about badges.

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)
local DataService = require(script.Parent.DataService)
local QuestBus = require(script.Parent.QuestBus)

local AchievementService = {}

local awarded: { [Player]: { [string]: boolean } } = {}

local function award(player: Player, key: string)
	local badgeId = Monetization.Badges[key]
	if not badgeId or badgeId == 0 then
		return
	end
	awarded[player] = awarded[player] or {}
	if awarded[player][key] then
		return
	end
	awarded[player][key] = true
	task.spawn(function()
		pcall(function()
			if not BadgeService:UserHasBadgeAsync(player.UserId, badgeId) then
				BadgeService:AwardBadge(player.UserId, badgeId)
			end
		end)
	end)
end

function AchievementService.Init()
	QuestBus.Progress:Connect(function(player: Player, kind: string)
		local profile = DataService.Get(player)
		if not profile then
			return
		end
		if kind == "Slice" and profile.Totals.FruitsSliced >= 100 then
			award(player, "FirstSlice")
		elseif kind == "Hatch" then
			award(player, "FirstHatch")
		elseif kind == "ShinyHatch" then
			award(player, "Shiny")
		elseif kind == "SecretHatch" then
			award(player, "Secret")
		elseif kind == "BossDefeated" then
			award(player, "BossSlayer")
		elseif kind == "Rebirth" then
			award(player, "Rebirth")
		elseif kind == "Build" and #profile.Buildings >= 10 then
			award(player, "Village")
		end
	end)
end

function AchievementService.Start()
	DataService.ProfileLoaded:Connect(function(player)
		award(player, "Welcome")
	end)
	Players.PlayerRemoving:Connect(function(player)
		awarded[player] = nil
	end)
end

return AchievementService
