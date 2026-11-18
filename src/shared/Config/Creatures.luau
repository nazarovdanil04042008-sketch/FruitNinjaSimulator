--!strict
-- Original fruit-themed "brainrot" creatures.
-- Bonus values are BASE fractions that get multiplied by the rarity's BonusScale,
-- e.g. Coins = 0.05 on a Common (scale 1) = +5% coins, on a Legendary (scale 15) = +75% coins.
-- Body describes how ModelBuilder draws the creature procedurally (no external assets needed).

local Rarities = require(script.Parent.Rarities)

export type BonusSet = { Coins: number?, Xp: number?, Speed: number?, Training: number? }

export type CreatureDef = {
	Id: string,
	DisplayName: string,
	Rarity: string,
	Emoji: string,
	Quote: string, -- silly catchphrase shown in the reveal / index
	Body: {
		Shape: string, -- "Ball" | "Long" | "Tall" | "Spiky" | "Star"
		Color: Color3,
		Color2: Color3, -- leaves / accessory colour
		Size: number,
		-- Crown | Halo | Horns | Shades | Bow | Cap | Chef | Headphones | Mustache | Bowtie | Headband | Cape
		Accessories: { string }?,
	},
	Bonus: BonusSet,
	Season: string?, -- seasonal creatures only come from that season's egg
}

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local list: { CreatureDef } = {
	-- Common
	{ Id = "AppleCrunchito", DisplayName = "Apple Crunchito", Rarity = "Common", Emoji = "🍎", Quote = "crunch crunch... crunchito!",
		Body = { Shape = "Ball", Color = c(220, 40, 40), Color2 = c(60, 160, 40), Size = 1.6, Accessories = { "Headband" } }, Bonus = { Coins = 0.05 } },
	{ Id = "OranginoRollini", DisplayName = "Orangino Rollini", Rarity = "Common", Emoji = "🍊", Quote = "i only know how to roll.",
		Body = { Shape = "Ball", Color = c(255, 140, 20), Color2 = c(60, 160, 40), Size = 1.6, Accessories = { "Headphones" } }, Bonus = { Xp = 0.05 } },
	-- Uncommon
	{ Id = "BananitoBonkerino", DisplayName = "Bananito Bonkerino", Rarity = "Uncommon", Emoji = "🍌", Quote = "BONK. bonk bonk. BONKERINO.",
		Body = { Shape = "Long", Color = c(255, 225, 70), Color2 = c(110, 80, 40), Size = 1.7, Accessories = { "Mustache", "Cap" } }, Bonus = { Coins = 0.05, Speed = 0.005 } },
	{ Id = "LemonzoSourpuccino", DisplayName = "Lemonzo Sourpuccino", Rarity = "Uncommon", Emoji = "🍋", Quote = "life gave me... me.",
		Body = { Shape = "Ball", Color = c(255, 235, 60), Color2 = c(60, 160, 40), Size = 1.6, Accessories = { "Shades", "Bowtie" } }, Bonus = { Training = 0.05 } },
	-- Rare
	{ Id = "StrawberrinoStompolino", DisplayName = "Strawberrino Stompolino", Rarity = "Rare", Emoji = "🍓", Quote = "stomp stomp, berry berry!",
		Body = { Shape = "Ball", Color = c(235, 30, 70), Color2 = c(60, 170, 50), Size = 1.6, Accessories = { "Bow" } }, Bonus = { Coins = 0.05, Xp = 0.03 } },
	{ Id = "GrapelliWobblini", DisplayName = "Grapelli Wobblini", Rarity = "Rare", Emoji = "🍇", Quote = "wobble wobble... i am 47 grapes.",
		Body = { Shape = "Ball", Color = c(130, 50, 190), Color2 = c(60, 160, 40), Size = 1.6, Accessories = { "Chef", "Mustache" } }, Bonus = { Xp = 0.06 } },
	-- Epic
	{ Id = "WatermelonioChompatelli", DisplayName = "Watermelonio Chompatelli", Rarity = "Epic", Emoji = "🍉", Quote = "CHOMP. the seeds are my friends.",
		Body = { Shape = "Ball", Color = c(40, 150, 50), Color2 = c(255, 60, 80), Size = 2.1, Accessories = { "Headband" } }, Bonus = { Coins = 0.06 } },
	{ Id = "KiwiKaboomba", DisplayName = "Kiwi Kaboomba", Rarity = "Epic", Emoji = "🥝", Quote = "ka-BOOM-ba!!! (kiwi noises)",
		Body = { Shape = "Ball", Color = c(130, 95, 50), Color2 = c(150, 220, 60), Size = 1.6, Accessories = { "Headphones", "Shades" } }, Bonus = { Speed = 0.006, Training = 0.04 } },
	-- Legendary
	{ Id = "PineapploSpinnerino", DisplayName = "Pineapplo Spinnerino", Rarity = "Legendary", Emoji = "🍍", Quote = "spin to win. spin to WIN.",
		Body = { Shape = "Spiky", Color = c(230, 170, 40), Color2 = c(40, 140, 40), Size = 1.9, Accessories = { "Crown" } }, Bonus = { Coins = 0.05, Training = 0.04 } },
	{ Id = "MangolinoMoonwalko", DisplayName = "Mangolino Moonwalko", Rarity = "Legendary", Emoji = "🥭", Quote = "*moonwalks away mysteriously*",
		Body = { Shape = "Tall", Color = c(255, 160, 30), Color2 = c(230, 60, 40), Size = 1.8, Accessories = { "Shades", "Cap" } }, Bonus = { Speed = 0.006, Xp = 0.04 } },
	-- Diamond
	{ Id = "CoconuttoDiamantino", DisplayName = "Coconutto Diamantino", Rarity = "Diamond", Emoji = "🥥", Quote = "shine bright like a coconut.",
		Body = { Shape = "Ball", Color = c(150, 235, 255), Color2 = c(255, 255, 255), Size = 1.8, Accessories = { "Crown", "Bowtie" } }, Bonus = { Coins = 0.06 } },
	{ Id = "BlueberrinaCrystallina", DisplayName = "Blueberrina Crystallina", Rarity = "Diamond", Emoji = "🫐", Quote = "tiny. blue. absolutely iconic.",
		Body = { Shape = "Ball", Color = c(70, 110, 255), Color2 = c(200, 240, 255), Size = 1.4, Accessories = { "Bow", "Halo" } }, Bonus = { Xp = 0.05, Training = 0.04 } },
	-- Gold
	{ Id = "PeachyGoldorado", DisplayName = "Peachy Goldorado", Rarity = "Gold", Emoji = "🍑", Quote = "i am made of 24 karat peach.",
		Body = { Shape = "Ball", Color = c(255, 205, 60), Color2 = c(255, 140, 100), Size = 1.8, Accessories = { "Crown", "Mustache" } }, Bonus = { Coins = 0.07 } },
	{ Id = "CherryTwinsyBling", DisplayName = "Cherry Twinsy Bling", Rarity = "Gold", Emoji = "🍒", Quote = "two cherries. one brain cell.",
		Body = { Shape = "Ball", Color = c(220, 20, 50), Color2 = c(255, 210, 50), Size = 1.5, Accessories = { "Shades", "Bowtie" } }, Bonus = { Coins = 0.04, Speed = 0.005, Xp = 0.03 } },
	-- Mythical
	{ Id = "DragonfruttoFlamerino", DisplayName = "Dragonfrutto Flamerino", Rarity = "Mythical", Emoji = "🐉", Quote = "RAWR (but fruity)",
		Body = { Shape = "Spiky", Color = c(240, 40, 150), Color2 = c(255, 140, 20), Size = 2.0, Accessories = { "Horns", "Cape" } }, Bonus = { Coins = 0.06, Speed = 0.004 } },
	{ Id = "DurianzoStinkolossus", DisplayName = "Durianzo Stinkolossus", Rarity = "Mythical", Emoji = "🌰", Quote = "the smell... is POWER.",
		Body = { Shape = "Spiky", Color = c(170, 160, 60), Color2 = c(110, 200, 40), Size = 2.1, Accessories = { "Horns", "Mustache" } }, Bonus = { Training = 0.06, Xp = 0.03 } },
	-- Cosmic
	{ Id = "CosmicFruitzilla", DisplayName = "Cosmic Fruitzilla", Rarity = "Cosmic", Emoji = "🌌", Quote = "i ate a galaxy. it was a little sour.",
		Body = { Shape = "Tall", Color = c(110, 60, 240), Color2 = c(60, 230, 255), Size = 2.2, Accessories = { "Halo", "Cape" } }, Bonus = { Coins = 0.06, Xp = 0.04 } },
	{ Id = "StarfruttoGalactico", DisplayName = "Starfrutto Galactico", Rarity = "Cosmic", Emoji = "⭐", Quote = "pew pew. pew. (space sounds)",
		Body = { Shape = "Star", Color = c(220, 255, 100), Color2 = c(140, 90, 255), Size = 2.0, Accessories = { "Halo", "Headphones" } }, Bonus = { Speed = 0.005, Training = 0.05 } },
	-- Secret
	{ Id = "Glitchberry404", DisplayName = "Glitchberry 404", Rarity = "Secret", Emoji = "👾", Quote = "ERROR: berry.exe has stopped tasting good",
		Body = { Shape = "Ball", Color = c(40, 255, 120), Color2 = c(255, 0, 200), Size = 1.9, Accessories = { "Halo", "Shades" } }, Bonus = { Coins = 0.06, Xp = 0.05, Training = 0.04 } },
	{ Id = "TheUnsliceable", DisplayName = "The Unsliceable", Rarity = "Secret", Emoji = "🗿", Quote = "you tried. it didn't work. :|",
		Body = { Shape = "Tall", Color = c(120, 120, 130), Color2 = c(255, 215, 50), Size = 2.3, Accessories = { "Crown", "Cape" } }, Bonus = { Coins = 0.08, Speed = 0.005 } },
}

-- Seasonal exclusives (only from Spring / Halloween / Winter eggs during the season)
table.insert(list, { Id = "SakurinaBlossomelli", DisplayName = "Sakurina Blossomelli", Rarity = "Epic", Emoji = "🌸", Quote = "petals everywhere. EVERYWHERE.", Season = "Spring",
	Body = { Shape = "Ball", Color = c(255, 180, 210), Color2 = c(255, 120, 170), Size = 1.7, Accessories = { "Bow", "Headband" } }, Bonus = { Coins = 0.06, Training = 0.03 } })
table.insert(list, { Id = "HanamiDragonino", DisplayName = "Hanami Dragonino", Rarity = "Mythical", Emoji = "🐲", Quote = "i only come out when the trees are pink.", Season = "Spring",
	Body = { Shape = "Spiky", Color = c(255, 150, 200), Color2 = c(120, 220, 140), Size = 2, Accessories = { "Horns", "Cape" } }, Bonus = { Coins = 0.07, Speed = 0.004 } })
table.insert(list, { Id = "PumpkinoSpookini", DisplayName = "Pumpkino Spookini", Rarity = "Epic", Emoji = "🎃", Quote = "boo. (but make it fruity)", Season = "Halloween",
	Body = { Shape = "Ball", Color = c(255, 130, 20), Color2 = c(60, 130, 40), Size = 1.9, Accessories = { "Horns" } }, Bonus = { Coins = 0.05, Xp = 0.04 } })
table.insert(list, { Id = "GhostberryBooini", DisplayName = "Ghostberry Booini", Rarity = "Mythical", Emoji = "👻", Quote = "you can't slice what you can't see~", Season = "Halloween",
	Body = { Shape = "Tall", Color = c(235, 235, 255), Color2 = c(150, 90, 255), Size = 1.9, Accessories = { "Halo", "Cape" } }, Bonus = { Xp = 0.06, Training = 0.04 } })
table.insert(list, { Id = "SnowmelonFrostini", DisplayName = "Snowmelon Frostini", Rarity = "Epic", Emoji = "⛄", Quote = "brrr... a melon in winter?!", Season = "Winter",
	Body = { Shape = "Ball", Color = c(220, 245, 255), Color2 = c(60, 160, 220), Size = 1.9, Accessories = { "Cap", "Bowtie" } }, Bonus = { Coins = 0.05, Speed = 0.004 } })
table.insert(list, { Id = "CandyCaneKatanino", DisplayName = "Candy Cane Katanino", Rarity = "Mythical", Emoji = "🍬", Quote = "sweet. sharp. festive.", Season = "Winter",
	Body = { Shape = "Long", Color = c(250, 250, 250), Color2 = c(230, 30, 50), Size = 1.9, Accessories = { "Headband", "Shades" } }, Bonus = { Coins = 0.08 } })

local Creatures = {
	List = list,
	ById = {} :: { [string]: CreatureDef },
	ByRarity = {} :: { [string]: { CreatureDef } },
}

for _, def in list do
	Creatures.ById[def.Id] = def
	if not def.Season then -- seasonal creatures never appear in the normal egg pools
		Creatures.ByRarity[def.Rarity] = Creatures.ByRarity[def.Rarity] or {}
		table.insert(Creatures.ByRarity[def.Rarity], def)
	end
end

function Creatures.Get(id: string): CreatureDef?
	-- Variants -------------------------------------------------------------------------------------
-- Tier 0 = normal, 1 = Golden (merge 5 normal), 2 = Rainbow (merge 5 Golden). Shiny = 1% hatch chance.
Creatures.TierNames = { [0] = "", [1] = "Golden", [2] = "Rainbow" }
Creatures.TierMultiplier = { [0] = 1, [1] = 3, [2] = 10 }
Creatures.ShinyMultiplier = 1.5
Creatures.MergeCount = 5
Creatures.MaxTier = 2
Creatures.ShinyChance = 0.01

function Creatures.EntryMultiplier(entry: any): number
	local tier = math.clamp(entry and entry.Tier or 0, 0, Creatures.MaxTier)
	return (Creatures.TierMultiplier[tier] or 1) * ((entry and entry.Shiny) and Creatures.ShinyMultiplier or 1)
end

-- Bonus of an owned creature (inventory entry {Id, Tier, Shiny}).
function Creatures.GetEntryBonus(entry: any): { Coins: number, Xp: number, Speed: number, Training: number }
	local bonus = Creatures.GetBonus(entry.Id)
	local m = Creatures.EntryMultiplier(entry)
	return { Coins = bonus.Coins * m, Xp = bonus.Xp * m, Speed = bonus.Speed * m, Training = bonus.Training * m }
end

function Creatures.GetEntryPower(entry: any): number
	return Creatures.GetPower(entry.Id) * Creatures.EntryMultiplier(entry)
end

-- "Golden Shiny Bananito Bonkerino"
function Creatures.EntryName(entry: any): string
	local def = Creatures.Get(entry.Id)
	local prefix = ""
	if entry.Shiny then
		prefix ..= "✨Shiny "
	end
	local tier = Creatures.TierNames[entry.Tier or 0] or ""
	if tier ~= "" then
		prefix ..= tier .. " "
	end
	return prefix .. (def and def.DisplayName or entry.Id)
end

return Creatures.ById[id]
end

-- Final bonus values for a creature after rarity scaling.
function Creatures.GetBonus(id: string): { Coins: number, Xp: number, Speed: number, Training: number }
	local def = Creatures.ById[id]
	local result = { Coins = 0, Xp = 0, Speed = 0, Training = 0 }
	if not def then
		return result
	end
	local scale = Rarities.Get(def.Rarity).BonusScale
	result.Coins = (def.Bonus.Coins or 0) * scale
	result.Xp = (def.Bonus.Xp or 0) * scale
	result.Speed = (def.Bonus.Speed or 0) * scale
	result.Training = (def.Bonus.Training or 0) * scale
	return result
end

-- A single comparable "power" number used for sorting and "Equip Best".
function Creatures.GetPower(id: string): number
	local b = Creatures.GetBonus(id)
	return b.Coins + b.Xp * 0.8 + b.Speed * 6 + b.Training * 0.8
end

-- Variants -------------------------------------------------------------------------------------
-- Tier 0 = normal, 1 = Golden (merge 5 normal), 2 = Rainbow (merge 5 Golden). Shiny = 1% hatch chance.
Creatures.TierNames = { [0] = "", [1] = "Golden", [2] = "Rainbow" }
Creatures.TierMultiplier = { [0] = 1, [1] = 3, [2] = 10 }
Creatures.ShinyMultiplier = 1.5
Creatures.MergeCount = 5
Creatures.MaxTier = 2
Creatures.ShinyChance = 0.01

function Creatures.EntryMultiplier(entry: any): number
	local tier = math.clamp(entry and entry.Tier or 0, 0, Creatures.MaxTier)
	return (Creatures.TierMultiplier[tier] or 1) * ((entry and entry.Shiny) and Creatures.ShinyMultiplier or 1)
end

-- Bonus of an owned creature (inventory entry {Id, Tier, Shiny}).
function Creatures.GetEntryBonus(entry: any): { Coins: number, Xp: number, Speed: number, Training: number }
	local bonus = Creatures.GetBonus(entry.Id)
	local m = Creatures.EntryMultiplier(entry)
	return { Coins = bonus.Coins * m, Xp = bonus.Xp * m, Speed = bonus.Speed * m, Training = bonus.Training * m }
end

function Creatures.GetEntryPower(entry: any): number
	return Creatures.GetPower(entry.Id) * Creatures.EntryMultiplier(entry)
end

-- "Golden Shiny Bananito Bonkerino"
function Creatures.EntryName(entry: any): string
	local def = Creatures.Get(entry.Id)
	local prefix = ""
	if entry.Shiny then
		prefix ..= "✨Shiny "
	end
	local tier = Creatures.TierNames[entry.Tier or 0] or ""
	if tier ~= "" then
		prefix ..= tier .. " "
	end
	return prefix .. (def and def.DisplayName or entry.Id)
end

return Creatures
