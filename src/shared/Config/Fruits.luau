--!strict
-- Every object that can be launched into a slicing arena.
-- Kind:
--   "Fruit"  - normal reward
--   "Golden" - big coin bonus
--   "Frenzy" - starts Fruit Frenzy (faster spawns) for a few seconds
--   "Bomb"   - dangerous: costs a heart, stuns the blade, resets combo
--   "Egg"    - hatches into a creature (EggId says which egg)

export type FruitDef = {
	Id: string,
	DisplayName: string,
	Kind: string,
	Coins: number,
	Xp: number,
	Radius: number, -- studs (also drives the on-screen hitbox)
	Color: Color3,
	Color2: Color3?, -- stripes / leaves
	Juice: Color3,
	Shape: string, -- "Ball" | "Long" | "Spiky" | "Egg" | "Bomb" | "Star"
	Material: Enum.Material?,
	EggId: string?,
}

local list: { FruitDef } = {
	{ Id = "Apple", DisplayName = "Apple", Kind = "Fruit", Coins = 1, Xp = 1, Radius = 1.2, Color = Color3.fromRGB(220, 40, 40), Color2 = Color3.fromRGB(60, 150, 40), Juice = Color3.fromRGB(255, 240, 200), Shape = "Ball" },
	{ Id = "Orange", DisplayName = "Orange", Kind = "Fruit", Coins = 2, Xp = 1, Radius = 1.25, Color = Color3.fromRGB(255, 140, 20), Juice = Color3.fromRGB(255, 180, 60), Shape = "Ball" },
	{ Id = "Lemon", DisplayName = "Lemon", Kind = "Fruit", Coins = 2, Xp = 2, Radius = 1.1, Color = Color3.fromRGB(255, 235, 60), Juice = Color3.fromRGB(255, 250, 150), Shape = "Ball" },
	{ Id = "Banana", DisplayName = "Banana", Kind = "Fruit", Coins = 3, Xp = 2, Radius = 1.3, Color = Color3.fromRGB(255, 225, 70), Juice = Color3.fromRGB(255, 250, 210), Shape = "Long" },
	{ Id = "Strawberry", DisplayName = "Strawberry", Kind = "Fruit", Coins = 3, Xp = 2, Radius = 1.0, Color = Color3.fromRGB(235, 30, 70), Color2 = Color3.fromRGB(60, 170, 50), Juice = Color3.fromRGB(255, 70, 100), Shape = "Ball" },
	{ Id = "Watermelon", DisplayName = "Watermelon", Kind = "Fruit", Coins = 5, Xp = 3, Radius = 1.9, Color = Color3.fromRGB(40, 150, 50), Color2 = Color3.fromRGB(20, 90, 30), Juice = Color3.fromRGB(255, 60, 80), Shape = "Ball" },
	{ Id = "Pineapple", DisplayName = "Pineapple", Kind = "Fruit", Coins = 6, Xp = 4, Radius = 1.5, Color = Color3.fromRGB(230, 170, 40), Color2 = Color3.fromRGB(40, 140, 40), Juice = Color3.fromRGB(255, 230, 90), Shape = "Spiky" },
	{ Id = "Coconut", DisplayName = "Coconut", Kind = "Fruit", Coins = 7, Xp = 4, Radius = 1.4, Color = Color3.fromRGB(110, 70, 40), Juice = Color3.fromRGB(250, 250, 250), Shape = "Ball" },
	{ Id = "Mango", DisplayName = "Mango", Kind = "Fruit", Coins = 8, Xp = 5, Radius = 1.3, Color = Color3.fromRGB(255, 160, 30), Color2 = Color3.fromRGB(230, 60, 40), Juice = Color3.fromRGB(255, 190, 40), Shape = "Ball" },
	{ Id = "DragonFruit", DisplayName = "Dragon Fruit", Kind = "Fruit", Coins = 12, Xp = 7, Radius = 1.4, Color = Color3.fromRGB(240, 40, 150), Color2 = Color3.fromRGB(120, 220, 60), Juice = Color3.fromRGB(250, 250, 250), Shape = "Spiky" },
	{ Id = "StarFruit", DisplayName = "Star Fruit", Kind = "Fruit", Coins = 16, Xp = 9, Radius = 1.3, Color = Color3.fromRGB(200, 255, 90), Juice = Color3.fromRGB(240, 255, 170), Shape = "Star", Material = Enum.Material.Neon },
	{ Id = "CosmicBerry", DisplayName = "Cosmic Berry", Kind = "Fruit", Coins = 24, Xp = 12, Radius = 1.2, Color = Color3.fromRGB(130, 70, 255), Juice = Color3.fromRGB(120, 230, 255), Shape = "Ball", Material = Enum.Material.Neon },

	-- Specials
	{ Id = "GoldenApple", DisplayName = "Golden Apple", Kind = "Golden", Coins = 40, Xp = 10, Radius = 1.3, Color = Color3.fromRGB(255, 205, 40), Juice = Color3.fromRGB(255, 240, 120), Shape = "Ball", Material = Enum.Material.Foil },
	{ Id = "FrenzyStar", DisplayName = "Frenzy Star", Kind = "Frenzy", Coins = 10, Xp = 5, Radius = 1.4, Color = Color3.fromRGB(80, 255, 230), Juice = Color3.fromRGB(180, 255, 250), Shape = "Star", Material = Enum.Material.Neon },
	{ Id = "Bomb", DisplayName = "Bomb", Kind = "Bomb", Coins = 0, Xp = 0, Radius = 1.3, Color = Color3.fromRGB(30, 30, 35), Color2 = Color3.fromRGB(255, 60, 40), Juice = Color3.fromRGB(255, 120, 30), Shape = "Bomb" },

	-- Eggs (see Eggs.luau for hatch tables)
	{ Id = "BasicEgg", DisplayName = "Basic Egg", Kind = "Egg", EggId = "Basic", Coins = 0, Xp = 3, Radius = 1.3, Color = Color3.fromRGB(250, 245, 230), Color2 = Color3.fromRGB(255, 200, 120), Juice = Color3.fromRGB(255, 255, 230), Shape = "Egg" },
	{ Id = "SpottedEgg", DisplayName = "Spotted Egg", Kind = "Egg", EggId = "Spotted", Coins = 0, Xp = 5, Radius = 1.35, Color = Color3.fromRGB(140, 220, 255), Color2 = Color3.fromRGB(40, 120, 230), Juice = Color3.fromRGB(200, 240, 255), Shape = "Egg" },
	{ Id = "JungleEgg", DisplayName = "Jungle Egg", Kind = "Egg", EggId = "Jungle", Coins = 0, Xp = 8, Radius = 1.4, Color = Color3.fromRGB(90, 200, 80), Color2 = Color3.fromRGB(255, 220, 60), Juice = Color3.fromRGB(200, 255, 180), Shape = "Egg" },
	{ Id = "CrystalEgg", DisplayName = "Crystal Egg", Kind = "Egg", EggId = "Crystal", Coins = 0, Xp = 12, Radius = 1.4, Color = Color3.fromRGB(150, 245, 255), Color2 = Color3.fromRGB(255, 255, 255), Juice = Color3.fromRGB(220, 255, 255), Shape = "Egg", Material = Enum.Material.Glass },
	{ Id = "CosmicEgg", DisplayName = "Cosmic Egg", Kind = "Egg", EggId = "Cosmic", Coins = 0, Xp = 20, Radius = 1.5, Color = Color3.fromRGB(110, 50, 230), Color2 = Color3.fromRGB(60, 230, 255), Juice = Color3.fromRGB(200, 170, 255), Shape = "Egg", Material = Enum.Material.Neon },
}

local Fruits = {
	List = list,
	ById = {} :: { [string]: FruitDef },
}

for _, def in list do
	Fruits.ById[def.Id] = def
end

function Fruits.Get(id: string): FruitDef?
	return Fruits.ById[id]
end

return Fruits
