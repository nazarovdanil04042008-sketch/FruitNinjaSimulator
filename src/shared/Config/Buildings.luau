--!strict
-- Japanese buildings players can buy and place on their own plot in the Ninja Village.
-- Footprint is in grid cells (PlotGrid.Cell studs each). Placed buildings give passive bonuses
-- (fractions, e.g. Coins = 0.02 = +2% coins) that stack up to MaxPlaced copies.

export type BuildingDef = {
	Id: string,
	DisplayName: string,
	Emoji: string,
	Order: number,
	Price: number,
	RequiredLevel: number,
	Width: number, -- cells along X (rotation 0)
	Depth: number, -- cells along Z (rotation 0)
	MaxPlaced: number,
	Bonus: { Coins: number?, Xp: number?, Speed: number?, Training: number? },
	Description: string,
}

local list: { BuildingDef } = {
	{ Id = "StoneLantern", DisplayName = "Stone Lantern", Emoji = "🏮", Order = 1, Price = 250, RequiredLevel = 1, Width = 1, Depth = 1, MaxPlaced = 12,
		Bonus = { Coins = 0.01 }, Description = "A glowing tōrō to light your village paths." },
	{ Id = "PaperLantern", DisplayName = "Paper Lantern", Emoji = "🏮", Order = 2, Price = 400, RequiredLevel = 2, Width = 1, Depth = 1, MaxPlaced = 12,
		Bonus = { Xp = 0.01 }, Description = "A red chōchin lantern on a wooden post." },
	{ Id = "Bonsai", DisplayName = "Bonsai", Emoji = "🪴", Order = 3, Price = 600, RequiredLevel = 3, Width = 1, Depth = 1, MaxPlaced = 8,
		Bonus = { Training = 0.015 }, Description = "Patience makes a true ninja." },
	{ Id = "BambooGrove", DisplayName = "Bamboo Grove", Emoji = "🎋", Order = 4, Price = 900, RequiredLevel = 4, Width = 2, Depth = 2, MaxPlaced = 6,
		Bonus = { Speed = 0.005 }, Description = "Tall bamboo that sways in the wind." },
	{ Id = "SakuraTree", DisplayName = "Sakura Tree", Emoji = "🌸", Order = 5, Price = 1500, RequiredLevel = 5, Width = 2, Depth = 2, MaxPlaced = 8,
		Bonus = { Coins = 0.02 }, Description = "Cherry blossoms with drifting petals." },
	{ Id = "ZenGarden", DisplayName = "Zen Garden", Emoji = "🪨", Order = 6, Price = 4000, RequiredLevel = 7, Width = 3, Depth = 3, MaxPlaced = 2,
		Bonus = { Training = 0.04 }, Description = "Raked sand and calm stones." },
	{ Id = "KoiPond", DisplayName = "Koi Pond", Emoji = "🐟", Order = 7, Price = 6000, RequiredLevel = 9, Width = 3, Depth = 3, MaxPlaced = 2,
		Bonus = { Xp = 0.04 }, Description = "A peaceful pond with colourful koi." },
	{ Id = "ToriiGate", DisplayName = "Torii Gate", Emoji = "⛩️", Order = 8, Price = 9000, RequiredLevel = 11, Width = 3, Depth = 1, MaxPlaced = 3,
		Bonus = { Coins = 0.04 }, Description = "The iconic red gate. Walk through it!" },
	{ Id = "Bridge", DisplayName = "Red Bridge", Emoji = "🌉", Order = 9, Price = 15000, RequiredLevel = 13, Width = 2, Depth = 4, MaxPlaced = 2,
		Bonus = { Speed = 0.01 }, Description = "An arched taikobashi bridge." },
	{ Id = "Shrine", DisplayName = "Shrine", Emoji = "⛩️", Order = 10, Price = 25000, RequiredLevel = 15, Width = 3, Depth = 3, MaxPlaced = 1,
		Bonus = { Coins = 0.06, Xp = 0.03 }, Description = "A small shrine that brings good fortune." },
	{ Id = "TeaHouse", DisplayName = "Tea House", Emoji = "🍵", Order = 11, Price = 50000, RequiredLevel = 18, Width = 4, Depth = 4, MaxPlaced = 1,
		Bonus = { Training = 0.08 }, Description = "Rest and train your mind with matcha." },
	{ Id = "BellTower", DisplayName = "Bell Tower", Emoji = "🔔", Order = 12, Price = 90000, RequiredLevel = 21, Width = 3, Depth = 3, MaxPlaced = 1,
		Bonus = { Xp = 0.08 }, Description = "A bronze temple bell." },
	{ Id = "MinkaHouse", DisplayName = "Ninja House", Emoji = "🏠", Order = 13, Price = 160000, RequiredLevel = 24, Width = 5, Depth = 4, MaxPlaced = 1,
		Bonus = { Coins = 0.1 }, Description = "A traditional house with shoji walls." },
	{ Id = "Pagoda", DisplayName = "Grand Pagoda", Emoji = "🏯", Order = 14, Price = 400000, RequiredLevel = 30, Width = 4, Depth = 4, MaxPlaced = 1,
		Bonus = { Coins = 0.15, Xp = 0.1, Training = 0.1 }, Description = "A five-story pagoda. The pride of any ninja village." },
}

local Buildings = {
	List = list,
	ById = {} :: { [string]: BuildingDef },
	MaxPlacedTotal = 60,

	-- Ninja Village plots (centre of each plot, players face/enter from -Z where the road is)
	PlotSize = 44,
	Plots = {
		Vector3.new(-110, 0, 165), Vector3.new(-166, 0, 165), Vector3.new(-222, 0, 165), Vector3.new(-278, 0, 165),
		Vector3.new(-110, 0, 235), Vector3.new(-166, 0, 235), Vector3.new(-222, 0, 235), Vector3.new(-278, 0, 235),
	},
}

for _, def in list do
	Buildings.ById[def.Id] = def
end

function Buildings.Get(id: string): BuildingDef?
	return Buildings.ById[id]
end

return Buildings
