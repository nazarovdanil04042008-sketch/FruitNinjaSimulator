--!strict
-- Interactive training mini-games. Each one is a short, fixed-length challenge.
-- Server validation uses Duration (minimum real time that must pass) and MaxScore (upper bound on a legit score).
-- Rewards scale with min(score, Goal) / Goal, then by the player's training multiplier.

export type TrainingDef = {
	Id: string,
	DisplayName: string,
	Emoji: string,
	Color: Color3,
	Description: string,
	HowTo: string,
	Duration: number,
	Goal: number,
	MaxScore: number,
	Cooldown: number,
	RequiredTrainingLevel: number,
	StatRewards: { [string]: number }, -- stat id -> points at a perfect run (before multipliers)
	TrainingXp: number,
	PlayerXp: number,
	Coins: number,
	Station: Vector3, -- world position of the training station (relative to the Dojo origin)
}

local DOJO = Vector3.new(190, 0, 0)

local list: { TrainingDef } = {
	{
		Id = "Speed", DisplayName = "Speed Training", Emoji = "⚡", Color = Color3.fromRGB(60, 200, 255),
		Description = "Arrow Rush: hit the arrows as fast as you can!",
		HowTo = "Press the matching arrow (Arrow keys / WASD or tap the buttons). Wrong presses cost time!",
		Duration = 10, Goal = 18, MaxScore = 45, Cooldown = 12, RequiredTrainingLevel = 1,
		StatRewards = { Speed = 3 }, TrainingXp = 10, PlayerXp = 8, Coins = 10,
		Station = DOJO + Vector3.new(-30, 0, -24),
	},
	{
		Id = "Strength", DisplayName = "Strength Training", Emoji = "💪", Color = Color3.fromRGB(255, 90, 80),
		Description = "Power Lift: stop the needle in the green zone for a perfect rep!",
		HowTo = "Click / tap / press Space when the needle is inside the green zone. Each rep gets harder.",
		Duration = 12, Goal = 10, MaxScore = 30, Cooldown = 12, RequiredTrainingLevel = 1,
		StatRewards = { Strength = 3 }, TrainingXp = 10, PlayerXp = 8, Coins = 10,
		Station = DOJO + Vector3.new(-15, 0, -34),
	},
	{
		Id = "Agility", DisplayName = "Agility Training", Emoji = "🌀", Color = Color3.fromRGB(120, 230, 90),
		Description = "Reflex Targets: tap targets before they vanish!",
		HowTo = "Click or tap each target before it disappears. Don't touch the red ones!",
		Duration = 10, Goal = 14, MaxScore = 30, Cooldown = 12, RequiredTrainingLevel = 1,
		StatRewards = { Agility = 3 }, TrainingXp = 10, PlayerXp = 8, Coins = 10,
		Station = DOJO + Vector3.new(0, 0, -38),
	},
	{
		Id = "Katana", DisplayName = "Katana Training", Emoji = "⚔️", Color = Color3.fromRGB(255, 200, 60),
		Description = "Dummy Slice: swipe through flying training dummies!",
		HowTo = "Hold and drag across the dummies to slice them. Avoid the bombs!",
		Duration = 12, Goal = 16, MaxScore = 40, Cooldown = 18, RequiredTrainingLevel = 2,
		StatRewards = { Strength = 2, Agility = 2 }, TrainingXp = 16, PlayerXp = 14, Coins = 40,
		Station = DOJO + Vector3.new(15, 0, -34),
	},
	{
		Id = "Special", DisplayName = "Master Gauntlet", Emoji = "🔥", Color = Color3.fromRGB(200, 90, 255),
		Description = "Every skill at once. Fast targets, bombs and arrows!",
		HowTo = "Tap targets, avoid bombs, and hit the arrow shown at the top for double points.",
		Duration = 15, Goal = 22, MaxScore = 60, Cooldown = 45, RequiredTrainingLevel = 5,
		StatRewards = { Speed = 3, Strength = 3, Agility = 3 }, TrainingXp = 35, PlayerXp = 30, Coins = 150,
		Station = DOJO + Vector3.new(30, 0, -24),
	},
}

local Training = {
	List = list,
	ById = {} :: { [string]: TrainingDef },
	DojoOrigin = DOJO,
}

for _, def in list do
	Training.ById[def.Id] = def
end

function Training.Get(id: string): TrainingDef?
	return Training.ById[id]
end

-- Difficulty grows with training level: 0 at level 1, approaches 1 around level 40.
function Training.GetDifficulty(trainingLevel: number): number
	return math.clamp((trainingLevel - 1) / 40, 0, 1)
end

return Training
