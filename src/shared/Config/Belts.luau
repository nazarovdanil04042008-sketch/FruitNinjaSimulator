--!strict
-- Belts represent training rank. They need a Training Level AND coins.
-- SpeedMultiplier multiplies walk speed + spawn rate, TrainingMultiplier multiplies stat gains from training.

export type BeltDef = {
	Id: string,
	DisplayName: string,
	Order: number,
	Price: number,
	RequiredTrainingLevel: number,
	SpeedMultiplier: number,
	TrainingMultiplier: number,
	Color: Color3,
	Material: Enum.Material,
}

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local list: { BeltDef } = {
	{ Id = "White", DisplayName = "White Belt", Order = 1, Price = 0, RequiredTrainingLevel = 1, SpeedMultiplier = 1, TrainingMultiplier = 1, Color = c(245, 245, 245), Material = Enum.Material.Fabric },
	{ Id = "Yellow", DisplayName = "Yellow Belt", Order = 2, Price = 200, RequiredTrainingLevel = 2, SpeedMultiplier = 1.04, TrainingMultiplier = 1.25, Color = c(255, 225, 40), Material = Enum.Material.Fabric },
	{ Id = "Orange", DisplayName = "Orange Belt", Order = 3, Price = 900, RequiredTrainingLevel = 4, SpeedMultiplier = 1.08, TrainingMultiplier = 1.5, Color = c(255, 140, 20), Material = Enum.Material.Fabric },
	{ Id = "Green", DisplayName = "Green Belt", Order = 4, Price = 3500, RequiredTrainingLevel = 6, SpeedMultiplier = 1.12, TrainingMultiplier = 1.8, Color = c(60, 190, 60), Material = Enum.Material.Fabric },
	{ Id = "Blue", DisplayName = "Blue Belt", Order = 5, Price = 12000, RequiredTrainingLevel = 9, SpeedMultiplier = 1.17, TrainingMultiplier = 2.2, Color = c(40, 120, 255), Material = Enum.Material.Fabric },
	{ Id = "Purple", DisplayName = "Purple Belt", Order = 6, Price = 40000, RequiredTrainingLevel = 12, SpeedMultiplier = 1.22, TrainingMultiplier = 2.7, Color = c(150, 60, 220), Material = Enum.Material.Fabric },
	{ Id = "Brown", DisplayName = "Brown Belt", Order = 7, Price = 120000, RequiredTrainingLevel = 16, SpeedMultiplier = 1.28, TrainingMultiplier = 3.3, Color = c(120, 70, 35), Material = Enum.Material.Fabric },
	{ Id = "Black", DisplayName = "Black Belt", Order = 8, Price = 350000, RequiredTrainingLevel = 20, SpeedMultiplier = 1.35, TrainingMultiplier = 4, Color = c(25, 25, 25), Material = Enum.Material.Fabric },
	{ Id = "Master", DisplayName = "Master Belt", Order = 9, Price = 1000000, RequiredTrainingLevel = 26, SpeedMultiplier = 1.45, TrainingMultiplier = 5, Color = c(220, 30, 40), Material = Enum.Material.SmoothPlastic },
	{ Id = "Cosmic", DisplayName = "Cosmic Belt", Order = 10, Price = 3000000, RequiredTrainingLevel = 34, SpeedMultiplier = 1.6, TrainingMultiplier = 6.5, Color = c(140, 80, 255), Material = Enum.Material.Neon },
}

local Belts = {
	List = list,
	ById = {} :: { [string]: BeltDef },
	Default = "White",
}

for _, def in list do
	Belts.ById[def.Id] = def
end

function Belts.Get(id: string?): BeltDef
	return (id and Belts.ById[id]) or Belts.ById[Belts.Default]
end

return Belts
