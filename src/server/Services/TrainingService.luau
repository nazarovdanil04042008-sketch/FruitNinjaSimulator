--!nonstrict
-- Training mini-games. The client plays the game; the server owns everything that matters:
--   * StartTraining: checks requirements + cooldown, issues a one-time token and the difficulty.
--   * FinishTraining: token must match, at least Duration seconds must have really passed,
--     and the score is clamped to the activity's MaxScore. Rewards are computed here.
-- Worst case an exploiter can report a perfect score - which is capped and still limited by cooldowns.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Training = require(Shared.Config.Training)
local Formulas = require(Shared.Util.Formulas)

local DataService = require(script.Parent.DataService)
local ActionService = require(script.Parent.ActionService)
local ProgressionService = require(script.Parent.ProgressionService)
local SlicingService = require(script.Parent.SlicingService)
local QuestBus = require(script.Parent.QuestBus)

local TrainingService = {}

type Active = { ActivityId: string, Token: string, StartedAt: number, Difficulty: number }

local active: { [Player]: Active } = {}
local cooldowns: { [Player]: { [string]: number } } = {}

local function getCooldownRemaining(player: Player, activityId: string): number
	local list = cooldowns[player]
	local readyAt = list and list[activityId] or 0
	return math.max(0, readyAt - os.clock())
end

function TrainingService.Init()
	ActionService.Register("StartTraining", function(player, profile, activityId: any)
		if not ActionService.IsString(activityId) then
			return false, "Invalid activity."
		end
		local def = Training.Get(activityId)
		if not def then
			return false, "Unknown activity."
		end
		if SlicingService.IsSlicing(player) then
			return false, "Finish your slicing round first."
		end
		if profile.TrainingLevel < def.RequiredTrainingLevel then
			return false, def.DisplayName .. " unlocks at Training Level " .. def.RequiredTrainingLevel .. "."
		end
		local remaining = getCooldownRemaining(player, def.Id)
		if remaining > 0 then
			return false, string.format("%s is on cooldown (%ds).", def.DisplayName, math.ceil(remaining))
		end
		local session: Active = {
			ActivityId = def.Id,
			Token = HttpService:GenerateGUID(false),
			StartedAt = os.clock(),
			Difficulty = Training.GetDifficulty(profile.TrainingLevel),
		}
		active[player] = session
		return true, "Go!", { Token = session.Token, Difficulty = session.Difficulty }
	end)

	ActionService.Register("FinishTraining", function(player, profile, token: any, score: any)
		local session = active[player]
		if not session or type(token) ~= "string" or token ~= session.Token then
			return false, "No training in progress."
		end
		active[player] = nil
		local def = Training.Get(session.ActivityId) :: Training.TrainingDef
		local elapsed = os.clock() - session.StartedAt
		if elapsed < def.Duration - 1 then
			return false, "Training ended too early."
		end
		if elapsed > def.Duration + 30 then
			return false, "Training timed out."
		end
		if type(score) ~= "number" or score ~= score then
			return false, "Invalid score."
		end
		score = math.clamp(math.floor(score), 0, def.MaxScore)

		cooldowns[player] = cooldowns[player] or {}
		cooldowns[player][def.Id] = os.clock() + def.Cooldown

		local ratio = math.min(score / def.Goal, 1)
		-- Scores above the goal give a small bonus (up to +50%) so skilled players are rewarded.
		local overGoal = math.clamp((score - def.Goal) / def.Goal, 0, 1) * 0.5
		local quality = ratio + overGoal
		local derived = Formulas.Compute(profile)
		local gains = {}
		if quality > 0 then
			for stat, base in def.StatRewards do
				local amount = math.max(1, math.floor(base * quality * derived.TrainingMultiplier + 0.5))
				ProgressionService.AddStat(player, stat, amount)
				gains[stat] = amount
			end
			ProgressionService.AddTrainingXp(player, math.ceil(def.TrainingXp * quality * (1 + derived.CreatureBonus.Training)))
			ProgressionService.AddXp(player, math.ceil(def.PlayerXp * quality * derived.XpMultiplier))
			ProgressionService.AddCoins(player, math.ceil(def.Coins * quality * (1 + derived.CreatureBonus.Coins)))
			profile.Totals.TrainingsDone += 1
			QuestBus.Fire(player, "Train", 1)
			DataService.Replicate(player)
		end
		local grade = if score >= def.Goal * 1.5 then "PERFECT!" elseif score >= def.Goal then "Great!" elseif score >= def.Goal * 0.5 then "Good" else "Keep practicing!"
		return true, grade, { Score = score, Goal = def.Goal, Gains = gains, Cooldown = def.Cooldown }
	end)

	ActionService.Register("CancelTraining", function(player)
		active[player] = nil
		return true, "Training cancelled."
	end)

	ActionService.Register("GetTrainingCooldowns", function(player)
		local result = {}
		for _, def in Training.List do
			result[def.Id] = getCooldownRemaining(player, def.Id)
		end
		return true, "", result
	end)
end

function TrainingService.Start()
	Players.PlayerRemoving:Connect(function(player)
		active[player] = nil
		cooldowns[player] = nil
	end)
end

return TrainingService
