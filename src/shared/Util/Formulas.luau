--!strict
-- Every derived number in the game is computed here, from the player's profile.
-- The server uses these values authoritatively; the client uses the same code purely for display.

local Config = script.Parent.Parent.Config
local GameConfig = require(Config.GameConfig)
local Katanas = require(Config.Katanas)
local Belts = require(Config.Belts)
local Trails = require(Config.Trails)
local Creatures = require(Config.Creatures)
local Buildings = require(Config.Buildings)

local Formulas = {}

export type Derived = {
	CoinMultiplier: number,
	XpMultiplier: number,
	TrainingMultiplier: number,
	SpeedMultiplier: number,
	WalkSpeed: number,
	JumpPower: number,
	SpawnInterval: number,
	SliceRate: number, -- objects per second the server will accept
	HitRadius: number, -- extra on-screen hitbox in pixels (at 1080p-equivalent)
	ComboWindow: number,
	PetSlots: number,
	CreatureBonus: { Coins: number, Xp: number, Speed: number, Training: number },
	BuildingBonus: { Coins: number, Xp: number, Speed: number, Training: number },
}

-- XP needed to go from `level` to `level + 1`.
function Formulas.XpForLevel(level: number): number
	return math.floor(40 * level ^ 1.45 + 20)
end

function Formulas.TrainingXpForLevel(level: number): number
	return math.floor(GameConfig.TrainingXpBase * level ^ GameConfig.TrainingXpExponent)
end

function Formulas.UpgradeCost(baseCost: number, growth: number, currentLevel: number): number
	return math.floor(baseCost * growth ^ currentLevel)
end

function Formulas.PetSlots(level: number): number
	local slots = 1
	for _, entry in GameConfig.PetSlotsByLevel do
		if level >= entry.level then
			slots = entry.slots
		end
	end
	return slots
end

-- Sum of bonuses from equipped creatures (missing / invalid uids are ignored).
function Formulas.CreatureBonus(profile: any): { Coins: number, Xp: number, Speed: number, Training: number }
	local total = { Coins = 0, Xp = 0, Speed = 0, Training = 0 }
	local creatures = profile.Creatures or {}
	for _, uid in profile.EquippedCreatures or {} do
		local entry = creatures[uid]
		if entry then
			local bonus = Creatures.GetBonus(entry.Id)
			total.Coins += bonus.Coins
			total.Xp += bonus.Xp
			total.Speed += bonus.Speed
			total.Training += bonus.Training
		end
	end
	total.Speed = math.min(total.Speed, 1) -- creature speed bonus capped at +100%
	return total
end

-- Sum of bonuses from buildings placed on the player's plot (each type counts up to its MaxPlaced).
function Formulas.BuildingBonus(profile: any): { Coins: number, Xp: number, Speed: number, Training: number }
	local total = { Coins = 0, Xp = 0, Speed = 0, Training = 0 }
	local counts: { [string]: number } = {}
	for _, item in profile.Buildings or {} do
		local def = Buildings.Get(item.Id)
		if def then
			counts[def.Id] = (counts[def.Id] or 0) + 1
			if counts[def.Id] <= def.MaxPlaced then
				total.Coins += def.Bonus.Coins or 0
				total.Xp += def.Bonus.Xp or 0
				total.Speed += def.Bonus.Speed or 0
				total.Training += def.Bonus.Training or 0
			end
		end
	end
	return total
end

function Formulas.Compute(profile: any): Derived
	local stats = profile.Stats or {}
	local speed = stats.Speed or 0
	local strength = stats.Strength or 0
	local agility = stats.Agility or 0
	local trainingLevel = profile.TrainingLevel or 1

	local katana = Katanas.Get(profile.EquippedKatana)
	local belt = Belts.Get(profile.EquippedBelt)
	local trail = Trails.Get(profile.EquippedTrail)
	local creature = Formulas.CreatureBonus(profile)
	local building = Formulas.BuildingBonus(profile)

	local speedMultiplier = belt.SpeedMultiplier * (trail and trail.SpeedMultiplier or 1) * (1 + creature.Speed + building.Speed)

	local baseWalk = math.min(GameConfig.BaseWalkSpeed + speed * 0.3, GameConfig.MaxBaseWalkSpeed)
	local walkSpeed = math.min(baseWalk * speedMultiplier, GameConfig.MaxWalkSpeed)

	local spawnInterval = GameConfig.BaseSpawnInterval / (1 + speed * 0.012) / math.sqrt(speedMultiplier)
	spawnInterval = math.max(spawnInterval, GameConfig.MinSpawnInterval)

	return {
		CoinMultiplier = (1 + strength * 0.04) * katana.CoinMultiplier * (1 + creature.Coins + building.Coins),
		XpMultiplier = (1 + (trainingLevel - 1) * 0.05) * (1 + creature.Xp + building.Xp),
		TrainingMultiplier = belt.TrainingMultiplier * (1 + creature.Training + building.Training) * (1 + (trainingLevel - 1) * 0.02),
		SpeedMultiplier = speedMultiplier,
		WalkSpeed = walkSpeed,
		JumpPower = math.min(GameConfig.BaseJumpPower + agility * 0.2, GameConfig.MaxJumpPower),
		SpawnInterval = spawnInterval,
		SliceRate = math.min(8 + agility * 0.2, 30) * katana.SliceRate,
		HitRadius = math.min(16 + agility * 0.25, 45) * katana.HitRadius,
		ComboWindow = math.min(0.45 + agility * 0.003, 0.8),
		PetSlots = Formulas.PetSlots(profile.Level or 1),
		CreatureBonus = creature,
		BuildingBonus = building,
	}
end

-- Coins awarded for one sliced object.
function Formulas.SliceCoins(baseCoins: number, derived: Derived, arenaMultiplier: number, combo: number): number
	local comboMultiplier = math.min(1 + math.max(combo - 1, 0) * 0.1, GameConfig.MaxComboMultiplier)
	return math.max(math.floor(baseCoins * derived.CoinMultiplier * arenaMultiplier * comboMultiplier + 0.5), baseCoins > 0 and 1 or 0)
end

function Formulas.SliceXp(baseXp: number, derived: Derived, arenaXpMultiplier: number): number
	return math.max(math.floor(baseXp * derived.XpMultiplier * arenaXpMultiplier + 0.5), baseXp > 0 and 1 or 0)
end

return Formulas
