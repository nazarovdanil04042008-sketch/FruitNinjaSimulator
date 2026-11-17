--!strict
-- Slicing arenas. Each arena unlocks at a player level and has its own fruit pool, egg pool and coin multiplier.
-- Geometry helpers here are used by BOTH the server (spawn validation, teleports) and the client (camera, rendering),
-- so the world and the fruit simulation always agree.

export type ArenaDef = {
	Id: string,
	DisplayName: string,
	Order: number,
	RequiredLevel: number,
	CoinMultiplier: number,
	XpMultiplier: number,
	Origin: Vector3, -- centre of the arena floor
	PadCount: number,
	FloorColor: Color3,
	AccentColor: Color3,
	BackdropColor: Color3,
	FruitWeights: { [string]: number },
	BombChance: number, -- per spawned object
	GoldenChance: number,
	FrenzyChance: number,
	EggChance: number,
	EggWeights: { [string]: number }, -- fruit id of the egg -> weight
	WaveMin: number,
	WaveMax: number,
}

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local list: { ArenaDef } = {
	{
		Id = "Orchard", DisplayName = "Sunny Orchard", Order = 1, RequiredLevel = 1, CoinMultiplier = 1, XpMultiplier = 1,
		Origin = Vector3.new(0, 0, -190), PadCount = 6,
		FloorColor = c(120, 200, 90), AccentColor = c(255, 190, 60), BackdropColor = c(120, 200, 255),
		FruitWeights = { Apple = 30, Orange = 25, Lemon = 18, Banana = 15, Strawberry = 12, Watermelon = 6 },
		BombChance = 0.05, GoldenChance = 0.02, FrenzyChance = 0.012, EggChance = 0.045,
		EggWeights = { BasicEgg = 85, SpottedEgg = 15 },
		WaveMin = 1, WaveMax = 3,
	},
	{
		Id = "Grove", DisplayName = "Tropical Grove", Order = 2, RequiredLevel = 10, CoinMultiplier = 4, XpMultiplier = 2,
		Origin = Vector3.new(-170, 0, -190), PadCount = 6,
		FloorColor = c(230, 210, 140), AccentColor = c(40, 170, 110), BackdropColor = c(60, 200, 190),
		FruitWeights = { Banana = 18, Watermelon = 18, Pineapple = 20, Coconut = 18, Mango = 16, Strawberry = 10 },
		BombChance = 0.07, GoldenChance = 0.025, FrenzyChance = 0.015, EggChance = 0.05,
		EggWeights = { SpottedEgg = 45, JungleEgg = 45, CrystalEgg = 10 },
		WaveMin = 2, WaveMax = 4,
	},
	{
		Id = "Cosmos", DisplayName = "Cosmic Garden", Order = 3, RequiredLevel = 25, CoinMultiplier = 15, XpMultiplier = 4,
		Origin = Vector3.new(170, 0, -190), PadCount = 6,
		FloorColor = c(60, 40, 110), AccentColor = c(140, 90, 255), BackdropColor = c(20, 10, 50),
		FruitWeights = { Mango = 15, DragonFruit = 25, StarFruit = 25, CosmicBerry = 25, Pineapple = 10 },
		BombChance = 0.09, GoldenChance = 0.03, FrenzyChance = 0.018, EggChance = 0.055,
		EggWeights = { JungleEgg = 35, CrystalEgg = 45, CosmicEgg = 20 },
		WaveMin = 2, WaveMax = 5,
	},
}

local Arenas = {
	List = list,
	ById = {} :: { [string]: ArenaDef },

	-- Stage geometry (relative to a pad). Fruits move in a vertical plane in front of the pad.
	PadSpacing = 14,
	PadOffsetZ = 18, -- pads sit towards the entrance (+Z) of the arena
	StageForward = 20, -- distance from pad to the fruit plane (towards -Z)
	StageHeight = 7, -- height of the fruit plane centre above the pad
	CameraBack = 10,
	CameraUp = 8,
	LaunchY = -20, -- fruits start this far below the stage centre (off screen)
	HalfWidth = 13, -- fruits launch within +/- this X range (fits 4:3 tablets)
}

for _, def in list do
	Arenas.ById[def.Id] = def
end

function Arenas.Get(id: string): ArenaDef?
	return Arenas.ById[id]
end

function Arenas.GetPadPosition(arena: ArenaDef, padIndex: number): Vector3
	local offsetX = (padIndex - (arena.PadCount + 1) / 2) * Arenas.PadSpacing
	return arena.Origin + Vector3.new(offsetX, 1, Arenas.PadOffsetZ)
end

-- World position of the centre of the fruit plane for a pad.
function Arenas.GetStageCenter(arena: ArenaDef, padIndex: number): Vector3
	return Arenas.GetPadPosition(arena, padIndex) + Vector3.new(0, Arenas.StageHeight, -Arenas.StageForward)
end

function Arenas.GetCameraCFrame(arena: ArenaDef, padIndex: number): CFrame
	local pad = Arenas.GetPadPosition(arena, padIndex)
	local eye = pad + Vector3.new(0, Arenas.CameraUp, Arenas.CameraBack)
	return CFrame.lookAt(eye, Arenas.GetStageCenter(arena, padIndex))
end

return Arenas
