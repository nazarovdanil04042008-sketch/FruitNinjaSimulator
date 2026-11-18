--!strict
-- Egg hatch tables. Eggs are obtained by slicing them in an arena.
-- HatchTime is intentionally short: 20 seconds for a Basic Egg up to 10 minutes for a Cosmic Egg.
-- Weights are relative (they do not need to add up to 100). The UI shows them as percentages.

export type EggDef = {
	Id: string,
	DisplayName: string,
	HatchTime: number,
	FruitId: string, -- the arena object that represents this egg
	Weights: { [string]: number }, -- rarity name -> weight
	Pool: { { Id: string, Weight: number } }?, -- seasonal eggs: explicit creature pool instead of rarity weights
	Season: string?,
}

local list: { EggDef } = {
	{
		Id = "Basic", DisplayName = "Basic Egg", HatchTime = 20, FruitId = "BasicEgg",
		Weights = { Common = 62, Uncommon = 27, Rare = 8.5, Epic = 2, Legendary = 0.45, Diamond = 0.04, Gold = 0.008, Mythical = 0.0015, Cosmic = 0.0004, Secret = 0.0001 },
	},
	{
		Id = "Spotted", DisplayName = "Spotted Egg", HatchTime = 60, FruitId = "SpottedEgg",
		Weights = { Common = 35, Uncommon = 35, Rare = 20, Epic = 7.5, Legendary = 2, Diamond = 0.4, Gold = 0.08, Mythical = 0.015, Cosmic = 0.004, Secret = 0.001 },
	},
	{
		Id = "Jungle", DisplayName = "Jungle Egg", HatchTime = 120, FruitId = "JungleEgg",
		Weights = { Uncommon = 30, Rare = 35, Epic = 22, Legendary = 9, Diamond = 3, Gold = 0.8, Mythical = 0.15, Cosmic = 0.04, Secret = 0.01 },
	},
	{
		Id = "Crystal", DisplayName = "Crystal Egg", HatchTime = 300, FruitId = "CrystalEgg",
		Weights = { Rare = 30, Epic = 32, Legendary = 20, Diamond = 11, Gold = 5, Mythical = 1.5, Cosmic = 0.4, Secret = 0.1 },
	},
	{
		Id = "Cosmic", DisplayName = "Cosmic Egg", HatchTime = 600, FruitId = "CosmicEgg",
		Weights = { Epic = 30, Legendary = 30, Diamond = 18, Gold = 12, Mythical = 6.5, Cosmic = 3, Secret = 0.5 },
	},
}

-- Seasonal eggs (only fly through the arenas while their season is running)
for _, data in { { "Spring", "Sakura Egg", "SpringEgg", "SakurinaBlossomelli", "HanamiDragonino" }, { "Halloween", "Spooky Egg", "HalloweenEgg", "PumpkinoSpookini", "GhostberryBooini" },
	{ "Winter", "Frost Egg", "WinterEgg", "SnowmelonFrostini", "CandyCaneKatanino" } } do
	table.insert(list, {
		Id = data[1], DisplayName = data[2], HatchTime = 120, FruitId = data[3], Season = data[1],
		Weights = { Epic = 92, Mythical = 8 },
		Pool = { { Id = data[4], Weight = 92 }, { Id = data[5], Weight = 8 } },
	})
end

local Eggs = {
	List = list,
	ById = {} :: { [string]: EggDef },
}

for _, def in list do
	Eggs.ById[def.Id] = def
end

function Eggs.Get(id: string): EggDef?
	return Eggs.ById[id]
end

-- Returns { {Rarity=name, Chance=percent}, ... } in rarity order (for UI display).
function Eggs.GetOdds(id: string): { { Rarity: string, Chance: number } }
	local def = Eggs.ById[id]
	local result = {}
	if not def then
		return result
	end
	local total = 0
	for _, weight in def.Weights do
		total += weight
	end
	local Rarities = require(script.Parent.Rarities)
	for _, rarity in Rarities.List do
		local weight = def.Weights[rarity.Name]
		if weight and weight > 0 then
			table.insert(result, { Rarity = rarity.Name, Chance = weight / total * 100 })
		end
	end
	return result
end

return Eggs
