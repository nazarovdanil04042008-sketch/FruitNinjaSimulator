--!strict
-- Trails follow the player's character. Every trail gives a small speed multiplier.
-- Keep multipliers modest: the final walk speed is capped in GameConfig.MaxWalkSpeed.

export type TrailDef = {
	Id: string,
	DisplayName: string,
	Order: number,
	Price: number,
	RequiredLevel: number,
	SpeedMultiplier: number,
	Colors: { Color3 }, -- 2-4 colours spread along the trail
	Lifetime: number,
	Width: number,
	LightEmission: number,
	Particles: boolean, -- adds a light-weight ParticleEmitter (rate kept low)
	ParticleTexture: string?,
	ParticleRate: number?,
}

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local list: { TrailDef } = {
	{ Id = "Neon", DisplayName = "Neon Trail", Order = 1, Price = 800, RequiredLevel = 3, SpeedMultiplier = 1.04, Colors = { c(0, 255, 140), c(0, 200, 255) }, Lifetime = 0.45, Width = 1.6, LightEmission = 1, Particles = false },
	{ Id = "Shadow", DisplayName = "Shadow Trail", Order = 2, Price = 2400, RequiredLevel = 5, SpeedMultiplier = 1.06, Colors = { c(40, 0, 60), c(0, 0, 0) }, Lifetime = 0.6, Width = 2, LightEmission = 0, Particles = false },
	{ Id = "Fire", DisplayName = "Fire Trail", Order = 3, Price = 8000, RequiredLevel = 8, SpeedMultiplier = 1.08, Colors = { c(255, 230, 80), c(255, 90, 0), c(150, 0, 0) }, Lifetime = 0.5, Width = 1.8, LightEmission = 1, Particles = true, ParticleTexture = FIRE, ParticleRate = 12 },
	{ Id = "Lightning", DisplayName = "Lightning Trail", Order = 4, Price = 24000, RequiredLevel = 12, SpeedMultiplier = 1.1, Colors = { c(255, 255, 255), c(120, 200, 255), c(255, 255, 120) }, Lifetime = 0.35, Width = 1.4, LightEmission = 1, Particles = true, ParticleTexture = SPARKLE, ParticleRate = 10 },
	{ Id = "Golden", DisplayName = "Golden Trail", Order = 5, Price = 64000, RequiredLevel = 16, SpeedMultiplier = 1.12, Colors = { c(255, 240, 150), c(255, 190, 20) }, Lifetime = 0.55, Width = 1.8, LightEmission = 0.7, Particles = true, ParticleTexture = SPARKLE, ParticleRate = 8 },
	{ Id = "Diamond", DisplayName = "Diamond Trail", Order = 6, Price = 160000, RequiredLevel = 20, SpeedMultiplier = 1.15, Colors = { c(255, 255, 255), c(130, 240, 255), c(60, 160, 255) }, Lifetime = 0.6, Width = 1.8, LightEmission = 0.8, Particles = true, ParticleTexture = SPARKLE, ParticleRate = 10 },
	{ Id = "Rainbow", DisplayName = "Rainbow Trail", Order = 7, Price = 400000, RequiredLevel = 24, SpeedMultiplier = 1.18, Colors = { c(255, 60, 60), c(255, 220, 40), c(60, 220, 90), c(60, 140, 255) }, Lifetime = 0.7, Width = 2, LightEmission = 0.8, Particles = false },
	{ Id = "Energy", DisplayName = "Energy Trail", Order = 8, Price = 960000, RequiredLevel = 30, SpeedMultiplier = 1.22, Colors = { c(120, 255, 80), c(0, 255, 200), c(255, 255, 255) }, Lifetime = 0.5, Width = 2.2, LightEmission = 1, Particles = true, ParticleTexture = SPARKLE, ParticleRate = 14 },
	{ Id = "Cosmic", DisplayName = "Cosmic Trail", Order = 9, Price = 2400000, RequiredLevel = 36, SpeedMultiplier = 1.26, Colors = { c(255, 120, 255), c(120, 80, 255), c(40, 230, 255) }, Lifetime = 0.8, Width = 2.2, LightEmission = 1, Particles = true, ParticleTexture = SPARKLE, ParticleRate = 16 },
	{ Id = "Galaxy", DisplayName = "Galaxy Trail", Order = 10, Price = 6400000, RequiredLevel = 44, SpeedMultiplier = 1.32, Colors = { c(20, 0, 60), c(120, 40, 255), c(255, 100, 220), c(255, 255, 255) }, Lifetime = 0.9, Width = 2.6, LightEmission = 1, Particles = true, ParticleTexture = SPARKLE, ParticleRate = 18 },
}

local Trails = {
	List = list,
	ById = {} :: { [string]: TrailDef },
}

for _, def in list do
	Trails.ById[def.Id] = def
end

function Trails.Get(id: string?): TrailDef?
	return id and Trails.ById[id] or nil
end

return Trails
