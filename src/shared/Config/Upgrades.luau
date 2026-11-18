--!strict
-- Coin-purchasable stat upgrades. Training also raises these stats for free (with cooldowns).
-- Price for the next level = floor(BaseCost * Growth ^ currentLevel)

export type UpgradeDef = {
	Id: string, -- matches the key in profile.Stats
	DisplayName: string,
	Emoji: string,
	Color: Color3,
	BaseCost: number,
	Growth: number,
	Description: string,
}

local list: { UpgradeDef } = {
	{ Id = "Speed", DisplayName = "Speed", Emoji = "⚡", Color = Color3.fromRGB(60, 200, 255), BaseCost = 30, Growth = 1.135,
		Description = "Run faster and fruits are launched more often." },
	{ Id = "Strength", DisplayName = "Strength", Emoji = "💪", Color = Color3.fromRGB(255, 90, 80), BaseCost = 38, Growth = 1.145,
		Description = "+4% coins from every slice per level." },
	{ Id = "Agility", DisplayName = "Agility", Emoji = "🌀", Color = Color3.fromRGB(120, 230, 90), BaseCost = 45, Growth = 1.145,
		Description = "Bigger blade hitbox, faster slicing, longer combos, higher jumps." },
}

local Upgrades = {
	List = list,
	ById = {} :: { [string]: UpgradeDef },
}

for _, def in list do
	Upgrades.ById[def.Id] = def
end

function Upgrades.Get(id: string): UpgradeDef?
	return Upgrades.ById[id]
end

return Upgrades
