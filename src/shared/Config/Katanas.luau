--!strict
-- Katanas: bought in the Katana Shop, equipped in the Katana menu.
-- CoinMultiplier - multiplies coins per slice
-- SliceRate      - multiplies how many objects per second the server accepts from your blade
-- HitRadius      - multiplies the size of the on-screen blade hitbox (forgiving swipes)
-- Effect         - which slice burst effect plays ("Sparks" | "Fire" | "Lightning" | "Cosmic" | "Mythic" | "Wood" | "Shine")

export type KatanaDef = {
	Id: string,
	DisplayName: string,
	Order: number,
	Price: number,
	RequiredLevel: number,
	CoinMultiplier: number,
	SliceRate: number,
	HitRadius: number,
	BladeColor: Color3,
	BladeMaterial: Enum.Material,
	SwipeColor: Color3, -- on-screen blade trail colour
	SwipeColor2: Color3,
	Effect: string,
	Description: string,
	RequiredRebirths: number?, -- exclusive: free, unlocked by rebirthing
}

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local list: { KatanaDef } = {
	{ Id = "Wooden", DisplayName = "Wooden Katana", Order = 1, Price = 0, RequiredLevel = 1, CoinMultiplier = 1, SliceRate = 1, HitRadius = 1,
		BladeColor = c(160, 110, 60), BladeMaterial = Enum.Material.Wood, SwipeColor = c(255, 255, 255), SwipeColor2 = c(220, 190, 150), Effect = "Wood",
		Description = "A trusty practice blade. Everyone starts somewhere!" },
	{ Id = "Iron", DisplayName = "Iron Katana", Order = 2, Price = 480, RequiredLevel = 2, CoinMultiplier = 1.3, SliceRate = 1.1, HitRadius = 1.05,
		BladeColor = c(170, 175, 185), BladeMaterial = Enum.Material.Metal, SwipeColor = c(230, 240, 255), SwipeColor2 = c(150, 160, 180), Effect = "Sparks",
		Description = "Solid steel. Sparks fly with every slice." },
	{ Id = "Golden", DisplayName = "Golden Katana", Order = 3, Price = 3200, RequiredLevel = 5, CoinMultiplier = 1.8, SliceRate = 1.2, HitRadius = 1.1,
		BladeColor = c(255, 200, 40), BladeMaterial = Enum.Material.Foil, SwipeColor = c(255, 230, 90), SwipeColor2 = c(255, 170, 20), Effect = "Shine",
		Description = "Shiny and rich. Fruits pay more just to touch it." },
	{ Id = "Diamond", DisplayName = "Diamond Katana", Order = 4, Price = 14000, RequiredLevel = 9, CoinMultiplier = 2.6, SliceRate = 1.3, HitRadius = 1.15,
		BladeColor = c(140, 240, 255), BladeMaterial = Enum.Material.Glass, SwipeColor = c(170, 250, 255), SwipeColor2 = c(60, 170, 255), Effect = "Shine",
		Description = "Crystal clear edge that never dulls." },
	{ Id = "Fire", DisplayName = "Fire Katana", Order = 5, Price = 56000, RequiredLevel = 14, CoinMultiplier = 3.6, SliceRate = 1.45, HitRadius = 1.2,
		BladeColor = c(255, 110, 20), BladeMaterial = Enum.Material.Neon, SwipeColor = c(255, 200, 60), SwipeColor2 = c(255, 60, 0), Effect = "Fire",
		Description = "Leaves a blazing trail. Fruits come out pre-roasted." },
	{ Id = "Lightning", DisplayName = "Lightning Katana", Order = 6, Price = 190000, RequiredLevel = 20, CoinMultiplier = 5, SliceRate = 1.65, HitRadius = 1.25,
		BladeColor = c(255, 245, 90), BladeMaterial = Enum.Material.Neon, SwipeColor = c(255, 255, 180), SwipeColor2 = c(90, 180, 255), Effect = "Lightning",
		Description = "Strikes faster than thunder. Huge slice rate." },
	{ Id = "Cosmic", DisplayName = "Cosmic Katana", Order = 7, Price = 720000, RequiredLevel = 28, CoinMultiplier = 7.5, SliceRate = 1.85, HitRadius = 1.3,
		BladeColor = c(130, 80, 255), BladeMaterial = Enum.Material.Neon, SwipeColor = c(200, 150, 255), SwipeColor2 = c(40, 230, 255), Effect = "Cosmic",
		Description = "Forged from a fallen star. Slices across dimensions." },
	{ Id = "Mythical", DisplayName = "Mythical Katana", Order = 8, Price = 2400000, RequiredLevel = 38, CoinMultiplier = 11, SliceRate = 2.1, HitRadius = 1.4,
		BladeColor = c(255, 60, 120), BladeMaterial = Enum.Material.ForceField, SwipeColor = c(255, 120, 200), SwipeColor2 = c(255, 230, 80), Effect = "Mythic",
		Description = "The legendary blade of the Fruit Master. Pure power." },
}

table.insert(list, { Id = "Phoenix", DisplayName = "Phoenix Katana", Order = 9, Price = 0, RequiredLevel = 1, RequiredRebirths = 3, CoinMultiplier = 13, SliceRate = 2.2, HitRadius = 1.45,
	BladeColor = c(255, 120, 40), BladeMaterial = Enum.Material.Neon, SwipeColor = c(255, 200, 80), SwipeColor2 = c(255, 60, 20), Effect = "Fire",
	Description = "Reborn from the ashes. Rebirth 3 exclusive." })

local Katanas = {
	List = list,
	ById = {} :: { [string]: KatanaDef },
	Default = "Wooden",
}

for _, def in list do
	Katanas.ById[def.Id] = def
end

function Katanas.Get(id: string?): KatanaDef
	return (id and Katanas.ById[id]) or Katanas.ById[Katanas.Default]
end

return Katanas
