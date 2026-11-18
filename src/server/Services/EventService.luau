--!nonstrict
-- Timed server events (Double Coins, Golden Rain, Egg Frenzy, Lucky Hatch, Fruit Storm, Double XP).
-- The schedule comes from LiveOps.CurrentEvent(os.time()), identical on every server.
-- Current state is published as Workspace attributes for the client UI:
--   FNS_EventId (string, "" = none), FNS_EventEnds (unix time)
-- Other services read multipliers with EventService.Get("Coins" | "Xp" | "EggChance" | "GoldenChance" | "Luck" | "SpawnRate").

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiveOps = require(ReplicatedStorage.Shared.Config.LiveOps)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ProgressionService = require(script.Parent.ProgressionService)

local EventService = {}

local current: LiveOps.EventDef? = nil
local endsAt = 0
local studioOverride: { Def: LiveOps.EventDef, Ends: number }? = nil

function EventService.Get(kind: string): number
	if current and os.time() < endsAt then
		return current.Multipliers[kind] or 1
	end
	return 1
end

function EventService.Current(): LiveOps.EventDef?
	return current
end

-- Current season (Spring / Halloween / Winter) or nil. GameConfig.ForceSeason works in Studio only.
function EventService.Season(): LiveOps.SeasonDef?
	return LiveOps.CurrentSeason(os.time(), RunService:IsStudio() and GameConfig.ForceSeason or nil)
end

local lastSeason = nil
local function update()
	local now = os.time()
	local season = EventService.Season()
	local seasonId = season and season.Id or ""
	if seasonId ~= lastSeason then
		lastSeason = seasonId
		workspace:SetAttribute("FNS_Season", seasonId)
	end
	local def, ends = LiveOps.CurrentEvent(now)
	if studioOverride and now < studioOverride.Ends then
		def, ends = studioOverride.Def, studioOverride.Ends
	end
	if def ~= current then
		current = def
		endsAt = ends
		workspace:SetAttribute("FNS_EventId", def and def.Id or "")
		workspace:SetAttribute("FNS_EventEnds", ends)
		if def then
			ProgressionService.NotifyAll(def.Emoji .. " EVENT: " .. def.DisplayName .. "! " .. def.Description, "rare")
		end
	end
end

function EventService.Init()
	workspace:SetAttribute("FNS_EventId", "")
	workspace:SetAttribute("FNS_EventEnds", 0)
end

function EventService.Start()
	if RunService:IsStudio() then
		-- In Studio, show an event 20 s after starting so you can test it without waiting.
		task.delay(20, function()
			local def = LiveOps.Events[math.random(1, #LiveOps.Events)]
			studioOverride = { Def = def, Ends = os.time() + 180 }
		end)
	end
	task.spawn(function()
		while true do
			update()
			task.wait(1)
		end
	end)
end

return EventService
