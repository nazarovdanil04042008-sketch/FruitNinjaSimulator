--!strict
-- Global tuning values shared by server and client.
-- Every gameplay number that is not item-specific lives here so balancing is done in one place.

local GameConfig = {}

-- Shown on screen (bottom-left) and in the Output window, so you can always see which build you're running.
GameConfig.Version = "2.1 - Beautiful World"

GameConfig.DataStoreName = "FruitNinjaSimulator_PlayerData_v1"
GameConfig.DataVersion = 1
GameConfig.AutosaveInterval = 90 -- seconds
GameConfig.SessionLockTimeout = 60 * 10 -- a lock older than this is considered stale (crashed server)

-- World / ambience
GameConfig.Lake = { Center = Vector3.new(84, 0, 84), Radius = 26 }
GameConfig.DayNightCycle = 12 * 60 -- seconds for a full day + night (synced for everyone via server time)
GameConfig.DayFraction = 0.7 -- share of the cycle that is daytime

-- Progression
GameConfig.StartingCoins = 50
GameConfig.MaxStatLevel = 250
GameConfig.MaxCreatureInventory = 80
GameConfig.MaxPendingEggs = 8
GameConfig.LevelUpCoinReward = 30 -- multiplied by the new level

-- Creature slots unlock by player level: { level, slots }
GameConfig.PetSlotsByLevel = {
	{ level = 1, slots = 2 },
	{ level = 8, slots = 3 },
	{ level = 20, slots = 4 },
	{ level = 35, slots = 5 },
}

-- Movement
GameConfig.BaseWalkSpeed = 16
GameConfig.MaxBaseWalkSpeed = 40 -- before multipliers
GameConfig.MaxWalkSpeed = 80 -- absolute cap after every multiplier
GameConfig.BaseJumpPower = 50
GameConfig.MaxJumpPower = 75

-- Slicing
GameConfig.Gravity = 32 -- studs/s^2 used by fruit trajectories (deterministic, not physics)
GameConfig.SessionHearts = 3
GameConfig.BombStunTime = 1.25
GameConfig.FrenzyDuration = 6
GameConfig.BaseSpawnInterval = 1.45
GameConfig.MinSpawnInterval = 0.45
GameConfig.MaxActiveSpawnsPerPlayer = 40
GameConfig.SliceGraceTime = 0.6 -- seconds of latency tolerance after an object leaves the screen
GameConfig.MaxComboMultiplier = 2.5

-- Training
GameConfig.TrainingXpBase = 25
GameConfig.TrainingXpExponent = 1.35

-- Egg hatching
GameConfig.SkipHatchCostPerSecond = 2 -- coins per remaining second to hatch instantly
GameConfig.ReleaseCreatureRefund = { -- coins refunded when releasing a creature, by rarity index
	5, 10, 25, 60, 150, 400, 900, 2000, 5000, 12000,
}

return GameConfig
