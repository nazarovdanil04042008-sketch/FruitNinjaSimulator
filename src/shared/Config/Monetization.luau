--!strict
-- Robux store, codes and badges.
--
-- ⚠️ HOW TO SET UP (once):
--   1. Publish the game. Go to create.roblox.com → your experience → Monetization → Passes / Developer Products.
--   2. Create each pass / product below (name + price you like), copy its ID number.
--   3. Paste the ID into PassId / ProductId here (0 = not set up yet; the store shows "Coming soon").
--   4. Badges: create.roblox.com → your experience → Badges → create, paste the BadgeId below.

export type PassDef = { Id: string, PassId: number, DisplayName: string, Emoji: string, Description: string, Color: Color3, RobuxHint: number }
export type ProductDef = { Id: string, ProductId: number, DisplayName: string, Emoji: string, Description: string, Color: Color3, RobuxHint: number }

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local Monetization = {}

Monetization.Passes = {
	{ Id = "DoubleCoins", PassId = 0, DisplayName = "2x Coins", Emoji = "🪙", Description = "Double coins from slicing forever!", Color = c(255, 200, 50), RobuxHint = 199 },
	{ Id = "ExtraSlots", PassId = 0, DisplayName = "+2 Creature Slots", Emoji = "🐾", Description = "Equip 2 more brainrots at once.", Color = c(255, 120, 190), RobuxHint = 149 },
	{ Id = "FastHatch", PassId = 0, DisplayName = "Fast Hatch", Emoji = "🥚", Description = "Eggs hatch 2x faster and +4 egg slots.", Color = c(255, 180, 90), RobuxHint = 129 },
	{ Id = "Lucky", PassId = 0, DisplayName = "Lucky Ninja", Emoji = "🍀", Description = "Rare creatures 1.5x more likely, double Shiny chance.", Color = c(90, 220, 120), RobuxHint = 249 },
	{ Id = "VIP", PassId = 0, DisplayName = "VIP", Emoji = "👑", Description = "+25% coins & XP, VIP Gold Trail, VIP tag.", Color = c(255, 215, 80), RobuxHint = 299 },
} :: { PassDef }

Monetization.Products = {
	{ Id = "CoinsSmall", ProductId = 0, DisplayName = "Coin Pouch", Emoji = "💰", Description = "A pouch of coins (scales with level).", Color = c(255, 200, 50), RobuxHint = 25 },
	{ Id = "CoinsMedium", ProductId = 0, DisplayName = "Coin Chest", Emoji = "🧰", Description = "A chest full of coins (scales with level).", Color = c(255, 170, 40), RobuxHint = 99 },
	{ Id = "CoinsLarge", ProductId = 0, DisplayName = "Coin Vault", Emoji = "🏦", Description = "A huge vault of coins (scales with level).", Color = c(255, 140, 30), RobuxHint = 299 },
	{ Id = "HatchAll", ProductId = 0, DisplayName = "Hatch All Now", Emoji = "🐣", Description = "Instantly finish every egg you're incubating.", Color = c(255, 160, 220), RobuxHint = 49 },
	{ Id = "LuckBoost", ProductId = 0, DisplayName = "Luck Potion (30m)", Emoji = "🧪", Description = "3x rare-creature luck for 30 minutes.", Color = c(140, 255, 160), RobuxHint = 79 },
} :: { ProductDef }

-- Coins given by coin products: base * (1 + level * 0.35) * (1 + rebirths)
Monetization.CoinPackBase = { CoinsSmall = 2500, CoinsMedium = 12000, CoinsLarge = 45000 }

-- Codes: case-insensitive. Each player can redeem each code once. Expires = unix time (0 = never).
Monetization.Codes = {
	RELEASE = { Coins = 1000, Expires = 0 },
	NINJA = { Coins = 500, Egg = "Spotted", Expires = 0 },
	SAKURA = { Boost = "Coins", BoostMinutes = 15, Expires = 0 },
	BRAINROT = { Egg = "Jungle", Expires = 0 },
} :: { [string]: { Coins: number?, Egg: string?, Boost: string?, BoostMinutes: number?, Expires: number } }

-- Roblox badges (0 = not set up yet, simply skipped).
Monetization.Badges = {
	Welcome = 0, -- joined the game
	FirstSlice = 0, -- sliced 100 fruit
	FirstHatch = 0, -- hatched an egg
	BossSlayer = 0, -- helped defeat a world boss
	Shiny = 0, -- hatched a shiny creature
	Secret = 0, -- hatched a Secret creature
	Rebirth = 0, -- first rebirth
	Village = 0, -- placed 10 buildings
}

function Monetization.GetPass(id: string): PassDef?
	for _, p in Monetization.Passes do
		if p.Id == id then
			return p
		end
	end
	return nil
end

function Monetization.GetProduct(id: string): ProductDef?
	for _, p in Monetization.Products do
		if p.Id == id then
			return p
		end
	end
	return nil
end

return Monetization
