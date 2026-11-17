--!strict
-- The ten creature rarity tiers, ordered from most common to most exclusive.

export type Rarity = {
	Name: string,
	Order: number,
	Color: Color3,
	Color2: Color3, -- secondary gradient colour for UI
	BonusScale: number, -- multiplies a creature's base bonus
	Glow: boolean, -- adds PointLight + sparkles to the creature model
	Material: Enum.Material?,
	RevealTime: number, -- seconds the reveal animation builds suspense
}

local list: { Rarity } = {
	{ Name = "Common", Order = 1, Color = Color3.fromRGB(190, 190, 190), Color2 = Color3.fromRGB(140, 140, 140), BonusScale = 1, Glow = false, RevealTime = 1.2 },
	{ Name = "Uncommon", Order = 2, Color = Color3.fromRGB(95, 215, 95), Color2 = Color3.fromRGB(40, 160, 60), BonusScale = 2, Glow = false, RevealTime = 1.3 },
	{ Name = "Rare", Order = 3, Color = Color3.fromRGB(70, 150, 255), Color2 = Color3.fromRGB(30, 90, 220), BonusScale = 4, Glow = false, RevealTime = 1.5 },
	{ Name = "Epic", Order = 4, Color = Color3.fromRGB(180, 90, 255), Color2 = Color3.fromRGB(120, 40, 210), BonusScale = 8, Glow = true, RevealTime = 1.8 },
	{ Name = "Legendary", Order = 5, Color = Color3.fromRGB(255, 170, 40), Color2 = Color3.fromRGB(255, 110, 20), BonusScale = 15, Glow = true, RevealTime = 2.2 },
	{ Name = "Diamond", Order = 6, Color = Color3.fromRGB(120, 240, 255), Color2 = Color3.fromRGB(60, 170, 255), BonusScale = 25, Glow = true, Material = Enum.Material.Glass, RevealTime = 2.4 },
	{ Name = "Gold", Order = 7, Color = Color3.fromRGB(255, 215, 50), Color2 = Color3.fromRGB(220, 160, 0), BonusScale = 40, Glow = true, Material = Enum.Material.Foil, RevealTime = 2.6 },
	{ Name = "Mythical", Order = 8, Color = Color3.fromRGB(255, 60, 110), Color2 = Color3.fromRGB(200, 0, 60), BonusScale = 70, Glow = true, Material = Enum.Material.Neon, RevealTime = 2.8 },
	{ Name = "Cosmic", Order = 9, Color = Color3.fromRGB(140, 90, 255), Color2 = Color3.fromRGB(30, 230, 255), BonusScale = 120, Glow = true, Material = Enum.Material.Neon, RevealTime = 3.0 },
	{ Name = "Secret", Order = 10, Color = Color3.fromRGB(20, 20, 20), Color2 = Color3.fromRGB(255, 255, 255), BonusScale = 220, Glow = true, Material = Enum.Material.ForceField, RevealTime = 3.4 },
}

local Rarities = {
	List = list,
	ByName = {} :: { [string]: Rarity },
}

for _, rarity in list do
	Rarities.ByName[rarity.Name] = rarity
end

function Rarities.Get(name: string): Rarity
	return Rarities.ByName[name] or list[1]
end

return Rarities
