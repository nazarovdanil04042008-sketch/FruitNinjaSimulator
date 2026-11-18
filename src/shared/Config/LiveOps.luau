--!strict
-- Live features that keep players coming back: world bosses, timed events, daily rewards,
-- playtime rewards and daily quests. All schedules use the shared server clock (UTC), so every
-- server shows the same boss / event times.

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local LiveOps = {}

------------------------------------------------------------------------------------------------
-- Bosses: one spawns every BossInterval seconds (at :00 and :30 UTC), rotating through this list.
------------------------------------------------------------------------------------------------
LiveOps.BossInterval = 30 * 60
LiveOps.BossDuration = 4 * 60 -- seconds to defeat it before it escapes
LiveOps.BossWarning = 60 -- announce this many seconds before it spawns
LiveOps.StudioFirstBossDelay = 45 -- in Studio the first boss comes quickly so you can test it
LiveOps.BossArena = Vector3.new(190, 0, 175)
LiveOps.BossArenaRadius = 40
LiveOps.BossAttackRange = 42 -- studs from the arena centre where your hits count
LiveOps.BossHitsPerSecond = 5

export type BossDef = { Id: string, DisplayName: string, CreatureId: string, Scale: number, Color: Color3, SlamRadius: number }
LiveOps.Bosses = {
	{ Id = "Durian", DisplayName = "Durianzo the Stinkshogun", CreatureId = "DurianzoStinkolossus", Scale = 7, Color = c(170, 160, 60), SlamRadius = 18 },
	{ Id = "Dragon", DisplayName = "Dragonfrutto Daimyo", CreatureId = "DragonfruttoFlamerino", Scale = 7, Color = c(240, 40, 150), SlamRadius = 20 },
	{ Id = "Zilla", DisplayName = "Cosmic Fruitzilla Prime", CreatureId = "CosmicFruitzilla", Scale = 6.5, Color = c(130, 80, 255), SlamRadius = 22 },
} :: { BossDef }

------------------------------------------------------------------------------------------------
-- Events: two 5-minute events per half hour (at minute 10 and 20 of each half hour).
------------------------------------------------------------------------------------------------
LiveOps.EventDuration = 5 * 60
LiveOps.EventOffsets = { 10 * 60, 20 * 60 }

export type EventDef = { Id: string, DisplayName: string, Emoji: string, Description: string, Color: Color3, Multipliers: { [string]: number } }
LiveOps.Events = {
	{ Id = "DoubleCoins", DisplayName = "Double Coins", Emoji = "🪙", Description = "All slicing coins x2!", Color = c(255, 205, 50), Multipliers = { Coins = 2 } },
	{ Id = "GoldenRain", DisplayName = "Golden Rain", Emoji = "🍏", Description = "Golden Apples everywhere!", Color = c(255, 220, 90), Multipliers = { GoldenChance = 5 } },
	{ Id = "EggFrenzy", DisplayName = "Egg Frenzy", Emoji = "🥚", Description = "Eggs fly 3x more often!", Color = c(255, 170, 220), Multipliers = { EggChance = 3 } },
	{ Id = "LuckyHatch", DisplayName = "Lucky Hatch", Emoji = "🍀", Description = "Rare creatures 2x more likely!", Color = c(90, 230, 120), Multipliers = { Luck = 2 } },
	{ Id = "FruitStorm", DisplayName = "Fruit Storm", Emoji = "🌪️", Description = "Fruit launch 60% faster!", Color = c(90, 200, 255), Multipliers = { SpawnRate = 1.6 } },
	{ Id = "DoubleXp", DisplayName = "Double XP", Emoji = "⭐", Description = "All XP x2!", Color = c(120, 220, 255), Multipliers = { Xp = 2 } },
} :: { EventDef }

------------------------------------------------------------------------------------------------
-- Daily login rewards (7-day streak; missing a day resets it). Coins scale with your level.
------------------------------------------------------------------------------------------------
export type Reward = { Coins: number?, Xp: number?, Egg: string?, Boost: string?, BoostMinutes: number?, Text: string }
LiveOps.Daily = {
	{ Coins = 300, Text = "Coins" },
	{ Coins = 500, Xp = 100, Text = "Coins + XP" },
	{ Coins = 600, Egg = "Spotted", Text = "Coins + Spotted Egg" },
	{ Coins = 900, Boost = "Coins", BoostMinutes = 15, Text = "Coins + 2x Coins (15m)" },
	{ Coins = 1200, Egg = "Jungle", Text = "Coins + Jungle Egg" },
	{ Coins = 1600, Boost = "Xp", BoostMinutes = 20, Text = "Coins + 2x XP (20m)" },
	{ Coins = 3000, Egg = "Crystal", Text = "BIG Coins + Crystal Egg" },
} :: { Reward }

------------------------------------------------------------------------------------------------
-- Playtime rewards (per session, minutes played since joining).
------------------------------------------------------------------------------------------------
export type PlaytimeReward = Reward & { Minutes: number }
LiveOps.Playtime = {
	{ Minutes = 5, Coins = 150, Text = "Coins" },
	{ Minutes = 10, Egg = "Basic", Text = "Basic Egg" },
	{ Minutes = 20, Coins = 500, Text = "Coins" },
	{ Minutes = 30, Boost = "Coins", BoostMinutes = 10, Text = "2x Coins (10m)" },
	{ Minutes = 45, Egg = "Jungle", Text = "Jungle Egg" },
	{ Minutes = 60, Egg = "Crystal", Coins = 1500, Text = "Crystal Egg + Coins" },
} :: { PlaytimeReward }

------------------------------------------------------------------------------------------------
-- Daily quests: 3 random quests per UTC day.
------------------------------------------------------------------------------------------------
export type QuestDef = { Id: string, Kind: string, Text: string, Min: number, Max: number, Coins: number, Xp: number, Egg: string? }
LiveOps.QuestsPerDay = 3
LiveOps.Quests = {
	{ Id = "SliceFruit", Kind = "Slice", Text = "Slice %d fruit", Min = 150, Max = 400, Coins = 600, Xp = 150 },
	{ Id = "EarnCoins", Kind = "EarnCoins", Text = "Earn %d coins from slicing", Min = 2000, Max = 8000, Coins = 800, Xp = 150 },
	{ Id = "Combo", Kind = "Combo5", Text = "Get a x5 combo %d times", Min = 5, Max = 15, Coins = 700, Xp = 200 },
	{ Id = "Hatch", Kind = "Hatch", Text = "Hatch %d eggs", Min = 3, Max = 8, Coins = 600, Xp = 150, Egg = "Spotted" },
	{ Id = "Train", Kind = "Train", Text = "Finish %d training sessions", Min = 4, Max = 10, Coins = 600, Xp = 200 },
	{ Id = "Boss", Kind = "Boss", Text = "Hit a world boss %d times", Min = 30, Max = 80, Coins = 1000, Xp = 300, Egg = "Jungle" },
	{ Id = "Build", Kind = "Build", Text = "Place %d buildings in your village", Min = 1, Max = 3, Coins = 700, Xp = 150 },
	{ Id = "Golden", Kind = "Golden", Text = "Slice %d Golden Apples", Min = 3, Max = 8, Coins = 900, Xp = 200 },
} :: { QuestDef }

LiveOps.QuestById = {} :: { [string]: QuestDef }
for _, q in LiveOps.Quests do
	LiveOps.QuestById[q.Id] = q
end

------------------------------------------------------------------------------------------------
-- Seasons (UTC dates). During a season: its egg flies through every arena, the world gets
-- seasonal visuals (snow / spooky night / extra petals) and a banner shows on screen.
-- GameConfig.ForceSeason can force one for testing in Studio.
------------------------------------------------------------------------------------------------
export type SeasonDef = { Id: string, DisplayName: string, Emoji: string, Color: Color3, StartMonth: number, StartDay: number, EndMonth: number, EndDay: number, EggFruit: string }
LiveOps.Seasons = {
	{ Id = "Spring", DisplayName = "Sakura Festival", Emoji = "🌸", Color = c(255, 170, 210), StartMonth = 3, StartDay = 20, EndMonth = 4, EndDay = 30, EggFruit = "SpringEgg" },
	{ Id = "Halloween", DisplayName = "Spooky Season", Emoji = "🎃", Color = c(255, 140, 30), StartMonth = 10, StartDay = 15, EndMonth = 11, EndDay = 5, EggFruit = "HalloweenEgg" },
	{ Id = "Winter", DisplayName = "Winter Festival", Emoji = "❄️", Color = c(170, 220, 255), StartMonth = 12, StartDay = 10, EndMonth = 1, EndDay = 10, EggFruit = "WinterEgg" },
} :: { SeasonDef }
LiveOps.SeasonEggChance = 0.02 -- extra chance per launched object during a season

function LiveOps.CurrentSeason(unix: number, forced: string?): SeasonDef?
	if forced and forced ~= "" then
		for _, s in LiveOps.Seasons do
			if s.Id == forced then
				return s
			end
		end
	end
	local date = os.date("!*t", unix)
	local key = date.month * 100 + date.day
	for _, s in LiveOps.Seasons do
		local startKey = s.StartMonth * 100 + s.StartDay
		local endKey = s.EndMonth * 100 + s.EndDay
		if startKey <= endKey then
			if key >= startKey and key <= endKey then
				return s
			end
		elseif key >= startKey or key <= endKey then -- wraps over new year
			return s
		end
	end
	return nil
end

-- Coins in rewards scale gently with level so they stay meaningful.
function LiveOps.ScaleCoins(base: number, level: number): number
	return math.floor(base * (1 + (level - 1) * 0.25))
end

function LiveOps.Day(unix: number): number
	return math.floor(unix / 86400)
end

-- Next boss spawn time (unix) after `now`.
function LiveOps.NextBossAt(now: number): number
	return (math.floor(now / LiveOps.BossInterval) + 1) * LiveOps.BossInterval
end

-- Current event (or nil) and when it ends, for unix time `now`.
function LiveOps.CurrentEvent(now: number): (EventDef?, number)
	local slot = math.floor(now / LiveOps.BossInterval)
	local into = now - slot * LiveOps.BossInterval
	for k, offset in LiveOps.EventOffsets do
		if into >= offset and into < offset + LiveOps.EventDuration then
			local index = (slot * #LiveOps.EventOffsets + k) % #LiveOps.Events + 1
			return LiveOps.Events[index], slot * LiveOps.BossInterval + offset + LiveOps.EventDuration
		end
	end
	return nil, 0
end

return LiveOps
