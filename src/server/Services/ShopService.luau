--!nonstrict
-- Stat upgrades + Katana / Belt / Trail shops. All prices and requirements are checked here on the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Upgrades = require(Shared.Config.Upgrades)
local Katanas = require(Shared.Config.Katanas)
local Belts = require(Shared.Config.Belts)
local Trails = require(Shared.Config.Trails)
local Formulas = require(Shared.Util.Formulas)
local Format = require(Shared.Util.Format)

local DataService = require(script.Parent.DataService)
local ActionService = require(script.Parent.ActionService)
local ProgressionService = require(script.Parent.ProgressionService)
local EquipmentService = require(script.Parent.EquipmentService)

local ShopService = {}

local function afterEquip(player: Player)
	DataService.Replicate(player)
	ProgressionService.ApplyCharacterStats(player)
	EquipmentService.Refresh(player, false)
end

function ShopService.Init()
	------------------------------------------------------------------ Stat upgrades
	ActionService.Register("BuyUpgrade", function(player, profile, statId: any, mode: any)
		if not ActionService.IsString(statId) then
			return false, "Invalid upgrade."
		end
		local def = Upgrades.Get(statId)
		if not def then
			return false, "Unknown upgrade."
		end
		local maxLevels = if mode == "Max" then GameConfig.MaxStatLevel elseif mode == "Ten" then 10 else 1
		local level = profile.Stats[def.Id]
		local bought = 0
		local spent = 0
		while bought < maxLevels and level < GameConfig.MaxStatLevel do
			local cost = Formulas.UpgradeCost(def.BaseCost, def.Growth, level)
			if profile.Coins - spent < cost then
				break
			end
			spent += cost
			level += 1
			bought += 1
		end
		if bought == 0 then
			if level >= GameConfig.MaxStatLevel then
				return false, def.DisplayName .. " is maxed out!"
			end
			return false, "Not enough coins! You need " .. Format.Short(Formulas.UpgradeCost(def.BaseCost, def.Growth, level)) .. "."
		end
		if not ProgressionService.SpendCoins(player, spent) then
			return false, "Not enough coins!"
		end
		ProgressionService.AddStat(player, def.Id, bought)
		return true, string.format("%s +%d (Level %d)", def.DisplayName, bought, profile.Stats[def.Id])
	end)

	------------------------------------------------------------------ Katanas
	ActionService.Register("BuyKatana", function(player, profile, id: any)
		local def = ActionService.IsString(id) and Katanas.ById[id]
		if not def then
			return false, "Unknown katana."
		end
		if profile.OwnedKatanas[def.Id] then
			return false, "You already own this katana."
		end
		if profile.Level < def.RequiredLevel then
			return false, "Reach level " .. def.RequiredLevel .. " first!"
		end
		if not ProgressionService.SpendCoins(player, def.Price) then
			return false, "Not enough coins! You need " .. Format.Short(def.Price) .. "."
		end
		profile.OwnedKatanas[def.Id] = true
		profile.EquippedKatana = def.Id
		afterEquip(player)
		return true, "Purchased and equipped the " .. def.DisplayName .. "!"
	end)

	ActionService.Register("EquipKatana", function(player, profile, id: any)
		if not ActionService.IsString(id) or not profile.OwnedKatanas[id] then
			return false, "You don't own that katana."
		end
		profile.EquippedKatana = id
		afterEquip(player)
		return true, "Equipped the " .. Katanas.Get(id).DisplayName
	end)

	------------------------------------------------------------------ Belts
	ActionService.Register("BuyBelt", function(player, profile, id: any)
		local def = ActionService.IsString(id) and Belts.ById[id]
		if not def then
			return false, "Unknown belt."
		end
		if profile.OwnedBelts[def.Id] then
			return false, "You already own this belt."
		end
		if profile.TrainingLevel < def.RequiredTrainingLevel then
			return false, "Reach Training Level " .. def.RequiredTrainingLevel .. " first! Train at the Dojo."
		end
		if not ProgressionService.SpendCoins(player, def.Price) then
			return false, "Not enough coins! You need " .. Format.Short(def.Price) .. "."
		end
		profile.OwnedBelts[def.Id] = true
		profile.EquippedBelt = def.Id
		afterEquip(player)
		return true, "You earned the " .. def.DisplayName .. "!"
	end)

	ActionService.Register("EquipBelt", function(player, profile, id: any)
		if not ActionService.IsString(id) or not profile.OwnedBelts[id] then
			return false, "You don't own that belt."
		end
		profile.EquippedBelt = id
		afterEquip(player)
		return true, "Equipped the " .. Belts.Get(id).DisplayName
	end)

	------------------------------------------------------------------ Trails
	ActionService.Register("BuyTrail", function(player, profile, id: any)
		local def = ActionService.IsString(id) and Trails.ById[id]
		if not def then
			return false, "Unknown trail."
		end
		if profile.OwnedTrails[def.Id] then
			return false, "You already own this trail."
		end
		if profile.Level < def.RequiredLevel then
			return false, "Reach level " .. def.RequiredLevel .. " first!"
		end
		if not ProgressionService.SpendCoins(player, def.Price) then
			return false, "Not enough coins! You need " .. Format.Short(def.Price) .. "."
		end
		profile.OwnedTrails[def.Id] = true
		profile.EquippedTrail = def.Id
		afterEquip(player)
		return true, "Purchased and equipped the " .. def.DisplayName .. "!"
	end)

	ActionService.Register("EquipTrail", function(player, profile, id: any)
		if id == "" then
			profile.EquippedTrail = ""
			afterEquip(player)
			return true, "Trail removed."
		end
		if not ActionService.IsString(id) or not profile.OwnedTrails[id] then
			return false, "You don't own that trail."
		end
		profile.EquippedTrail = id
		afterEquip(player)
		local def = Trails.Get(id)
		return true, "Equipped the " .. (def and def.DisplayName or id)
	end)
end

function ShopService.Start() end

return ShopService
