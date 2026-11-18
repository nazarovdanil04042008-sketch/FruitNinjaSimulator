--!nonstrict
-- Rebirth (prestige): pay coins and reach a level to reset Coins / Level / XP / Stats in exchange for a
-- permanent multiplier (+50% coins, +25% XP per rebirth) and exclusive rewards (Phoenix Trail at
-- Rebirth 1, Phoenix Katana at Rebirth 3). Katanas, belts, trails, creatures, eggs and buildings are kept.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Formulas = require(Shared.Util.Formulas)
local Format = require(Shared.Util.Format)

local DataService = require(script.Parent.DataService)
local ActionService = require(script.Parent.ActionService)
local ProgressionService = require(script.Parent.ProgressionService)
local EquipmentService = require(script.Parent.EquipmentService)
local QuestBus = require(script.Parent.QuestBus)

local RebirthService = {}

function RebirthService.Init()
	ActionService.Register("Rebirth", function(player, profile)
		if ProgressionService.IsFrozen(player) then
			return false, "Leave the slicing round first."
		end
		local cost = Formulas.RebirthCost(profile.Rebirths)
		local needLevel = Formulas.RebirthLevel(profile.Rebirths)
		if profile.Level < needLevel then
			return false, "Reach level " .. needLevel .. " to rebirth!"
		end
		if profile.Coins < cost then
			return false, "You need " .. Format.Short(cost) .. " coins to rebirth."
		end
		profile.Rebirths += 1
		profile.Coins = GameConfig.StartingCoins
		profile.Level = 1
		profile.Xp = 0
		profile.Stats = { Speed = 0, Strength = 0, Agility = 0 }
		local slots = Formulas.PetSlots(1, profile)
		while #profile.EquippedCreatures > slots do
			table.remove(profile.EquippedCreatures)
		end
		DataService.Replicate(player)
		ProgressionService.ApplyCharacterStats(player)
		EquipmentService.Refresh(player, false)
		QuestBus.Fire(player, "Rebirth", 1)
		ProgressionService.NotifyAll("🔁 " .. player.DisplayName .. " reached Rebirth " .. profile.Rebirths .. "!", "rare")
		local extra = profile.Rebirths == 1 and " Phoenix Trail unlocked in the Trail Shop!" or profile.Rebirths == 3 and " Phoenix Katana unlocked in the Katana Shop!" or ""
		return true, "Rebirth " .. profile.Rebirths .. "! Coins x" .. string.format("%.1f", 1 + profile.Rebirths * GameConfig.RebirthCoinBonus) .. " forever." .. extra
	end)
end

function RebirthService.Start() end

return RebirthService
