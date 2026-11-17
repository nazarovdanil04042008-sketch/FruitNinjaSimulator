--!nonstrict
-- Pending eggs, hatching, creature rolls, creature inventory (equip / unequip / equip best / release).
-- Hatch times are stored as absolute unix timestamps (os.time), so eggs keep hatching while offline.
-- The creature is rolled on the SERVER at the moment of hatching - the client only plays the reveal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Eggs = require(Shared.Config.Eggs)
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Formulas = require(Shared.Util.Formulas)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Util.Net)

local DataService = require(script.Parent.DataService)
local ActionService = require(script.Parent.ActionService)
local ProgressionService = require(script.Parent.ProgressionService)
local EquipmentService = require(script.Parent.EquipmentService)

local EggService = {}

local rng = Random.new()
local hatchRevealRemote: RemoteEvent

local function rollRarity(egg: Eggs.EggDef): string
	local total = 0
	for rarityName, weight in egg.Weights do
		if Creatures.ByRarity[rarityName] then
			total += weight
		end
	end
	local roll = rng:NextNumber(0, total)
	-- iterate in rarity order so results are deterministic for a given roll
	for _, rarity in Rarities.List do
		local weight = egg.Weights[rarity.Name]
		if weight and Creatures.ByRarity[rarity.Name] then
			roll -= weight
			if roll <= 0 then
				return rarity.Name
			end
		end
	end
	-- floating point fallback: most common rarity in this egg
	for _, rarity in Rarities.List do
		if egg.Weights[rarity.Name] and Creatures.ByRarity[rarity.Name] then
			return rarity.Name
		end
	end
	return "Common"
end

local function rollCreature(egg: Eggs.EggDef): string
	local pool = Creatures.ByRarity[rollRarity(egg)]
	return pool[rng:NextInteger(1, #pool)].Id
end

local function countCreatures(profile: any): number
	local n = 0
	for _ in profile.Creatures do
		n += 1
	end
	return n
end

-- Called by SlicingService when an egg is sliced. Returns true if the egg was stored.
function EggService.AddEgg(player: Player, eggId: string): boolean
	local profile = DataService.Get(player)
	local def = Eggs.Get(eggId)
	if not profile or not def then
		return false
	end
	if #profile.Eggs >= GameConfig.MaxPendingEggs then
		-- Inventory full: convert to coins so slicing an egg never feels wasted.
		local refund = math.floor(def.HatchTime * 2)
		ProgressionService.AddCoins(player, refund)
		ProgressionService.Notify(player, "🥚 Egg slots full! Converted to " .. Format.Short(refund) .. " coins. Hatch your eggs!", "error")
		return false
	end
	table.insert(profile.Eggs, {
		Uid = DataService.NewUid(player, "e"),
		EggId = def.Id,
		HatchAt = os.time() + def.HatchTime,
	})
	DataService.Replicate(player)
	return true
end

local function findEgg(profile: any, uid: any): (number?, any)
	if type(uid) ~= "string" then
		return nil, nil
	end
	for index, egg in profile.Eggs do
		if egg.Uid == uid then
			return index, egg
		end
	end
	return nil, nil
end

local function hatch(player: Player, profile: any, index: number, egg: any): (boolean, string)
	if countCreatures(profile) >= GameConfig.MaxCreatureInventory then
		return false, "Creature inventory full (" .. GameConfig.MaxCreatureInventory .. ")! Release some creatures first."
	end
	local def = Eggs.Get(egg.EggId)
	if not def then
		table.remove(profile.Eggs, index)
		return false, "That egg no longer exists."
	end
	table.remove(profile.Eggs, index)
	local creatureId = rollCreature(def)
	local creature = Creatures.Get(creatureId) :: Creatures.CreatureDef
	local isNew = not profile.Discovered[creatureId]
	local uid = DataService.NewUid(player, "c")
	profile.Creatures[uid] = { Id = creatureId, Obtained = os.time() }
	profile.Discovered[creatureId] = true
	profile.Totals.EggsHatched += 1

	-- Auto-equip into a free slot so new players immediately feel the bonus.
	if #profile.EquippedCreatures < Formulas.PetSlots(profile.Level) then
		table.insert(profile.EquippedCreatures, uid)
	end

	DataService.Replicate(player)
	ProgressionService.ApplyCharacterStats(player)
	EquipmentService.Refresh(player, false)
	hatchRevealRemote:FireClient(player, creatureId, isNew, uid, egg.EggId)

	local rarity = Rarities.Get(creature.Rarity)
	if rarity.Order >= 6 then
		ProgressionService.NotifyAll("🌟 " .. player.DisplayName .. " hatched a " .. rarity.Name:upper() .. " " .. creature.DisplayName .. "!", "rare")
	end
	return true, "Hatched " .. creature.DisplayName .. "!"
end

local function equipBest(profile: any)
	local list = {}
	for uid, entry in profile.Creatures do
		table.insert(list, { uid = uid, power = Creatures.GetPower(entry.Id) })
	end
	table.sort(list, function(a, b)
		return a.power > b.power
	end)
	local equipped = {}
	for i = 1, math.min(Formulas.PetSlots(profile.Level), #list) do
		table.insert(equipped, list[i].uid)
	end
	profile.EquippedCreatures = equipped
end

local function afterCreatureChange(player: Player)
	DataService.Replicate(player)
	ProgressionService.ApplyCharacterStats(player)
	EquipmentService.Refresh(player, false)
end

function EggService.Init()
	hatchRevealRemote = Net.Event("HatchReveal")

	ActionService.Register("HatchEgg", function(player, profile, uid: any)
		local index, egg = findEgg(profile, uid)
		if not index then
			return false, "Egg not found."
		end
		if os.time() < egg.HatchAt then
			return false, "This egg needs " .. Format.Time(egg.HatchAt - os.time()) .. " more."
		end
		return hatch(player, profile, index, egg)
	end)

	ActionService.Register("SkipEgg", function(player, profile, uid: any)
		local index, egg = findEgg(profile, uid)
		if not index then
			return false, "Egg not found."
		end
		local remaining = math.max(0, egg.HatchAt - os.time())
		local cost = math.ceil(remaining * GameConfig.SkipHatchCostPerSecond)
		if countCreatures(profile) >= GameConfig.MaxCreatureInventory then
			return false, "Creature inventory full! Release some creatures first."
		end
		if cost > 0 and not ProgressionService.SpendCoins(player, cost) then
			return false, "Not enough coins! Skipping costs " .. Format.Short(cost) .. "."
		end
		return hatch(player, profile, index, egg)
	end)

	ActionService.Register("HatchAllReady", function(player, profile)
		local hatched = 0
		local now = os.time()
		local i = 1
		while i <= #profile.Eggs do
			local egg = profile.Eggs[i]
			if now >= egg.HatchAt then
				local ok = hatch(player, profile, i, egg)
				if not ok then
					break
				end
				hatched += 1
			else
				i += 1
			end
		end
		if hatched == 0 then
			return false, "No eggs are ready yet."
		end
		return true, "Hatched " .. hatched .. " egg" .. (hatched == 1 and "" or "s") .. "!"
	end)

	ActionService.Register("EquipCreature", function(player, profile, uid: any)
		if type(uid) ~= "string" or not profile.Creatures[uid] then
			return false, "Creature not found."
		end
		if table.find(profile.EquippedCreatures, uid) then
			return false, "Already equipped."
		end
		local slots = Formulas.PetSlots(profile.Level)
		if #profile.EquippedCreatures >= slots then
			return false, "All " .. slots .. " slots are full. Unequip one first (or level up for more slots)."
		end
		table.insert(profile.EquippedCreatures, uid)
		afterCreatureChange(player)
		return true, "Equipped!"
	end)

	ActionService.Register("UnequipCreature", function(player, profile, uid: any)
		local index = type(uid) == "string" and table.find(profile.EquippedCreatures, uid)
		if not index then
			return false, "Not equipped."
		end
		table.remove(profile.EquippedCreatures, index)
		afterCreatureChange(player)
		return true, "Unequipped."
	end)

	ActionService.Register("EquipBest", function(player, profile)
		equipBest(profile)
		afterCreatureChange(player)
		return true, "Equipped your best creatures!"
	end)

	ActionService.Register("ReleaseCreature", function(player, profile, uid: any)
		local entry = type(uid) == "string" and profile.Creatures[uid]
		if not entry then
			return false, "Creature not found."
		end
		local def = Creatures.Get(entry.Id)
		local rarity = Rarities.Get(def and def.Rarity or "Common")
		local refund = GameConfig.ReleaseCreatureRefund[rarity.Order] or 5
		profile.Creatures[uid] = nil
		local index = table.find(profile.EquippedCreatures, uid)
		if index then
			table.remove(profile.EquippedCreatures, index)
		end
		ProgressionService.AddCoins(player, refund)
		afterCreatureChange(player)
		return true, "Released for " .. Format.Short(refund) .. " coins."
	end)
end

function EggService.Start()
	-- Light-weight "your egg is ready" reminders (one check every 2s for all players).
	local notified: { [string]: boolean } = {}
	task.spawn(function()
		while true do
			task.wait(2)
			local now = os.time()
			for _, player in Players:GetPlayers() do
				local profile = DataService.Get(player)
				if profile then
					for _, egg in profile.Eggs do
						local key = player.UserId .. egg.Uid
						if now >= egg.HatchAt and not notified[key] then
							notified[key] = true
							local def = Eggs.Get(egg.EggId)
							ProgressionService.Notify(player, "🥚 Your " .. (def and def.DisplayName or "egg") .. " is ready to hatch!", "success")
						end
					end
				end
			end
		end
	end)
end

return EggService
