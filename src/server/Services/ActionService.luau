--!nonstrict
-- Single, safe entry point for every client request that changes data (shops, equips, eggs, training...).
--
-- Client: Remotes.Action:InvokeServer("BuyKatana", "Iron")  ->  ok: boolean, message: string, extra: any
--
-- Safety:
--   * Only whitelisted action names registered by services can run.
--   * Per-player rate limit (token bucket) blocks spam / exploit loops.
--   * Handlers run inside pcall, so a bad argument can never break the remote for everyone.
--   * Profiles must be loaded before any action runs.
--   * Handlers receive raw arguments and MUST type-check them (helpers below).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Util.Net)
local DataService = require(script.Parent.DataService)

local ActionService = {}

type Handler = (player: Player, profile: any, ...any) -> (boolean, string?, any?)

local handlers: { [string]: Handler } = {}
local buckets: { [Player]: { tokens: number, last: number } } = {}

local BUCKET_SIZE = 12
local REFILL_PER_SECOND = 6

local function allow(player: Player): boolean
	local now = os.clock()
	local bucket = buckets[player]
	if not bucket then
		bucket = { tokens = BUCKET_SIZE, last = now }
		buckets[player] = bucket
	end
	bucket.tokens = math.min(BUCKET_SIZE, bucket.tokens + (now - bucket.last) * REFILL_PER_SECOND)
	bucket.last = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

function ActionService.Register(name: string, handler: Handler)
	assert(handlers[name] == nil, "Action already registered: " .. name)
	handlers[name] = handler
end

-- Validation helpers ---------------------------------------------------------------------------
function ActionService.IsString(value: any, maxLength: number?): boolean
	return type(value) == "string" and #value > 0 and #value <= (maxLength or 64)
end

function ActionService.IsInteger(value: any, min: number, max: number): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and value >= min and value <= max
end

function ActionService.Init()
	Net.Function("Action").OnServerInvoke = function(player: Player, actionName: any, ...: any)
		if type(actionName) ~= "string" then
			return false, "Invalid request."
		end
		local handler = handlers[actionName]
		if not handler then
			return false, "Unknown action."
		end
		if not allow(player) then
			return false, "Slow down a little!"
		end
		local profile = DataService.Get(player)
		if not profile then
			return false, "Your data is still loading..."
		end
		local results = table.pack(pcall(handler, player, profile, ...))
		if not results[1] then
			warn(string.format("[ActionService] %s failed for %s: %s", actionName, player.Name, tostring(results[2])))
			return false, "Something went wrong. Please try again."
		end
		return results[2], results[3], results[4]
	end
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

function ActionService.Start() end

return ActionService
