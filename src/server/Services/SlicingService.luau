--!nonstrict
-- Core Fruit Ninja loop (server-authoritative).
--
-- Flow:
--   1. Client fires SlicingStart(arenaId). Server validates the level, assigns a pad, freezes the
--      character on it and tells the client which pad/stage to use (SessionStarted).
--   2. A single scheduler loop launches waves of objects for every active session. Only launch
--      parameters are sent (SpawnObjects); the client simulates the deterministic arc itself.
--   3. The client detects swipes and sends the ids it cut (Slice). The server checks that each id was
--      really spawned for this player, is still on screen (with latency grace), was not already cut,
--      and that the blade isn't cutting faster than the player's SliceRate allows. Only then rewards
--      are granted. Exploiters can't invent fruit, re-slice fruit, or exceed their legit slice rate.
--   4. Bombs cost a heart; at 0 hearts (or when the player leaves) the round ends with a summary.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Arenas = require(Shared.Config.Arenas)
local Fruits = require(Shared.Config.Fruits)
local Formulas = require(Shared.Util.Formulas)
local Trajectory = require(Shared.Util.Trajectory)
local Net = require(Shared.Util.Net)

local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)
local EggService = require(script.Parent.EggService)
local EventService = require(script.Parent.EventService)
local QuestBus = require(script.Parent.QuestBus)
local LiveOps = require(Shared.Config.LiveOps)

local SlicingService = {}

type SpawnRecord = { FruitId: string, SpawnTime: number, Expires: number }
type Session = {
	ArenaId: string,
	PadIndex: number,
	Hearts: number,
	StartTime: number,
	StunUntil: number,
	FrenzyUntil: number,
	NextSpawn: number,
	Spawns: { [number]: SpawnRecord },
	ActiveCount: number,
	NextId: number,
	Combo: number,
	LastSliceTime: number,
	Tokens: number,
	TokensLast: number,
	Coins: number,
	Fruits: number,
	BestCombo: number,
	Eggs: number,
	Derived: Formulas.Derived,
	DerivedAt: number,
}

local sessions: { [Player]: Session } = {}
local padOwners: { [string]: { [number]: Player } } = {}
local lastStartRequest: { [Player]: number } = {}
local rng = Random.new()

local remotes: { [string]: RemoteEvent } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function pickWeighted(weights: { [string]: number }): string
	local total = 0
	for _, w in weights do
		total += w
	end
	local roll = rng:NextNumber(0, total)
	local last = ""
	for id, w in weights do
		last = id
		roll -= w
		if roll <= 0 then
			return id
		end
	end
	return last
end

local function claimPad(arena: Arenas.ArenaDef, player: Player): number
	local owners = padOwners[arena.Id]
	if not owners then
		owners = {}
		padOwners[arena.Id] = owners
	end
	-- Prefer the middle pads so the view is centred, fall back to sharing if all are busy.
	local order = {}
	for i = 1, arena.PadCount do
		table.insert(order, i)
	end
	local middle = (arena.PadCount + 1) / 2
	table.sort(order, function(a, b)
		return math.abs(a - middle) < math.abs(b - middle)
	end)
	for _, index in order do
		local owner = owners[index]
		if not owner or not owner.Parent or not sessions[owner] then
			owners[index] = player
			return index
		end
	end
	local index = rng:NextInteger(1, arena.PadCount)
	return index
end

local function releasePad(session: Session, player: Player)
	local owners = padOwners[session.ArenaId]
	if owners and owners[session.PadIndex] == player then
		owners[session.PadIndex] = nil
	end
end

------------------------------------------------------------------------------------------------
-- Session lifecycle
------------------------------------------------------------------------------------------------
function SlicingService.IsSlicing(player: Player): boolean
	return sessions[player] ~= nil
end

function SlicingService.Stop(player: Player, reason: string)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	releasePad(session, player)
	ProgressionService.SetFrozen(player, false)
	local profile = DataService.Get(player)
	if profile and session.BestCombo > profile.Totals.BestCombo then
		profile.Totals.BestCombo = session.BestCombo
		DataService.Replicate(player)
	end
	if player.Parent then
		remotes.SessionEnded:FireClient(player, {
			Reason = reason,
			Coins = session.Coins,
			Fruits = session.Fruits,
			BestCombo = session.BestCombo,
			Eggs = session.Eggs,
			Duration = now() - session.StartTime,
			ArenaId = session.ArenaId,
		})
	end
end

local function start(player: Player, arenaId: any)
	if type(arenaId) ~= "string" then
		return
	end
	local t = os.clock()
	if lastStartRequest[player] and t - lastStartRequest[player] < 1 then
		return
	end
	lastStartRequest[player] = t

	local profile = DataService.Get(player)
	local arena = Arenas.Get(arenaId)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not profile or not arena or not character or not humanoid or humanoid.Health <= 0 then
		return
	end
	if profile.Level < arena.RequiredLevel then
		ProgressionService.Notify(player, "🔒 " .. arena.DisplayName .. " unlocks at level " .. arena.RequiredLevel .. "!", "error")
		return
	end
	if sessions[player] then
		SlicingService.Stop(player, "Switched")
	end

	local padIndex = claimPad(arena, player)
	local padPosition = Arenas.GetPadPosition(arena, padIndex)
	local stageCenter = Arenas.GetStageCenter(arena, padIndex)
	local standAt = padPosition + Vector3.new(0, 3, 0)
	ProgressionService.StreamAround(player, stageCenter)
	if not player.Parent or player.Character ~= character then
		return
	end
	character:PivotTo(CFrame.lookAt(standAt, Vector3.new(stageCenter.X, standAt.Y, stageCenter.Z)))
	ProgressionService.SetFrozen(player, true)

	local t0 = now()
	sessions[player] = {
		ArenaId = arena.Id,
		PadIndex = padIndex,
		Hearts = GameConfig.SessionHearts,
		StartTime = t0,
		StunUntil = 0,
		FrenzyUntil = 0,
		NextSpawn = t0 + 1.2, -- short "Get ready!" moment
		Spawns = {},
		ActiveCount = 0,
		NextId = 1,
		Combo = 0,
		LastSliceTime = 0,
		Tokens = 4,
		TokensLast = t0,
		Coins = 0,
		Fruits = 0,
		BestCombo = 0,
		Eggs = 0,
		Derived = Formulas.Compute(profile),
		DerivedAt = t0,
	}
	remotes.SessionStarted:FireClient(player, arena.Id, padIndex, GameConfig.SessionHearts)
end

------------------------------------------------------------------------------------------------
-- Spawning
------------------------------------------------------------------------------------------------
local function chooseObject(arena: Arenas.ArenaDef, session: Session, t: number): string
	local elapsed = t - session.StartTime
	local frenzy = t < session.FrenzyUntil
	local roll = rng:NextNumber()
	-- No bombs during the first seconds or during frenzy: beginner friendly and frenzy feels great.
	if not frenzy and elapsed > 6 then
		if roll < arena.BombChance then
			return "Bomb"
		end
		roll -= arena.BombChance
	end
	local season = EventService.Season()
	if season and roll < LiveOps.SeasonEggChance then
		return season.EggFruit
	end
	if season then
		roll -= LiveOps.SeasonEggChance
	end
	local eggChance = arena.EggChance * EventService.Get("EggChance")
	local goldenChance = arena.GoldenChance * EventService.Get("GoldenChance")
	if roll < eggChance then
		return pickWeighted(arena.EggWeights)
	end
	roll -= eggChance
	if roll < goldenChance then
		return "GoldenApple"
	end
	roll -= goldenChance
	if not frenzy and roll < arena.FrenzyChance then
		return "FrenzyStar"
	end
	return pickWeighted(arena.FruitWeights)
end

local function spawnWave(player: Player, session: Session, t: number)
	local arena = Arenas.Get(session.ArenaId) :: Arenas.ArenaDef
	local frenzy = t < session.FrenzyUntil
	if session.ActiveCount >= GameConfig.MaxActiveSpawnsPerPlayer then
		return
	end
	local count = rng:NextInteger(arena.WaveMin, arena.WaveMax) + (frenzy and 2 or 0)
	local batch = {}
	for i = 1, count do
		local fruitId = chooseObject(arena, session, t)
		local launch = Trajectory.Create(rng, Arenas.HalfWidth, Arenas.LaunchY, 22, 32)
		local spawnTime = t + (i - 1) * rng:NextNumber(0.08, 0.25)
		local id = session.NextId
		session.NextId += 1
		session.Spawns[id] = { FruitId = fruitId, SpawnTime = spawnTime, Expires = spawnTime + Trajectory.Lifetime(launch) }
		session.ActiveCount += 1
		table.insert(batch, {
			Id = id,
			F = fruitId,
			T = spawnTime,
			X0 = launch.X0,
			Y0 = launch.Y0,
			Z = launch.Z,
			VX = launch.VX,
			VY = launch.VY,
			S = launch.Spin,
		})
	end
	remotes.SpawnObjects:FireClient(player, session.ArenaId, session.PadIndex, batch)
end

local function tick()
	local t = now()
	for player, session in sessions do
		if not player.Parent then
			sessions[player] = nil
			releasePad(session, player)
			continue
		end
		-- Refresh derived stats a few times per second at most (equips can change mid-round).
		if t - session.DerivedAt > 2 then
			local profile = DataService.Get(player)
			if profile then
				session.Derived = Formulas.Compute(profile)
			end
			session.DerivedAt = t
		end
		-- Drop expired records.
		for id, record in session.Spawns do
			if t > record.Expires + GameConfig.SliceGraceTime then
				session.Spawns[id] = nil
				session.ActiveCount -= 1
			end
		end
		if t >= session.NextSpawn then
			spawnWave(player, session, t)
			local interval = session.Derived.SpawnInterval / EventService.Get("SpawnRate")
			if t < session.FrenzyUntil then
				interval *= 0.45
			end
			session.NextSpawn = t + interval * rng:NextNumber(0.85, 1.15)
		end
	end
end

------------------------------------------------------------------------------------------------
-- Slicing
------------------------------------------------------------------------------------------------
local function onSlice(player: Player, ids: any)
	local session = sessions[player]
	if not session or type(ids) ~= "table" or #ids == 0 or #ids > 12 then
		return
	end
	local arena = Arenas.Get(session.ArenaId) :: Arenas.ArenaDef
	local derived = session.Derived
	local t = now()

	-- Token bucket: refills at SliceRate per second, small burst allowed for multi-fruit swipes.
	local burst = math.max(5, derived.SliceRate * 0.75)
	session.Tokens = math.min(burst, session.Tokens + (t - session.TokensLast) * derived.SliceRate)
	session.TokensLast = t

	local results = {}
	local coinsTotal, xpTotal = 0, 0
	local profile = DataService.Get(player)
	if not profile then
		return
	end

	for _, id in ids do
		if type(id) ~= "number" then
			continue
		end
		local record = session.Spawns[id]
		if not record then
			continue
		end
		if t < record.SpawnTime - 0.15 or t > record.Expires + GameConfig.SliceGraceTime then
			continue
		end
		if t < session.StunUntil then
			break
		end
		if session.Tokens < 1 then
			break
		end
		session.Tokens -= 1
		session.Spawns[id] = nil
		session.ActiveCount -= 1

		local def = Fruits.Get(record.FruitId) :: Fruits.FruitDef
		if def.Kind == "Bomb" then
			session.Hearts -= 1
			session.StunUntil = t + GameConfig.BombStunTime
			session.Combo = 0
			profile.Totals.BombsHit += 1
			table.insert(results, { Id = id, Kind = "Bomb", Hearts = session.Hearts })
			break -- a bomb ends the swipe
		end

		if t - session.LastSliceTime <= derived.ComboWindow then
			session.Combo += 1
		else
			session.Combo = 1
		end
		session.LastSliceTime = t
		session.BestCombo = math.max(session.BestCombo, session.Combo)

		local coins = math.floor(Formulas.SliceCoins(def.Coins, derived, arena.CoinMultiplier, session.Combo) * EventService.Get("Coins"))
		local xp = math.floor(Formulas.SliceXp(def.Xp, derived, arena.XpMultiplier) * EventService.Get("Xp"))
		if session.Combo == 5 then
			QuestBus.Fire(player, "Combo5", 1)
		end
		if def.Kind == "Golden" then
			QuestBus.Fire(player, "Golden", 1)
		end
		local result = { Id = id, Kind = def.Kind, Coins = coins, Xp = xp, Combo = session.Combo }

		if def.Kind == "Frenzy" then
			session.FrenzyUntil = t + GameConfig.FrenzyDuration
			session.NextSpawn = math.min(session.NextSpawn, t + 0.3)
		elseif def.Kind == "Egg" and def.EggId then
			result.EggAdded = EggService.AddEgg(player, def.EggId)
			result.EggId = def.EggId
			if result.EggAdded then
				session.Eggs += 1
			end
		end

		coinsTotal += coins
		xpTotal += xp
		session.Coins += coins
		session.Fruits += 1
		profile.Totals.FruitsSliced += 1
		table.insert(results, result)
	end

	if #results == 0 then
		return
	end
	if coinsTotal > 0 then
		ProgressionService.AddCoins(player, coinsTotal)
		QuestBus.Fire(player, "EarnCoins", coinsTotal)
	end
	local slicedCount = 0
	for _, r in results do
		if r.Kind ~= "Bomb" then
			slicedCount += 1
		end
	end
	if slicedCount > 0 then
		QuestBus.Fire(player, "Slice", slicedCount)
	end
	if xpTotal > 0 then
		ProgressionService.AddXp(player, xpTotal)
	end
	DataService.Replicate(player)
	remotes.SliceResult:FireClient(player, results, session.FrenzyUntil > t and session.FrenzyUntil - t or 0)

	if session.Hearts <= 0 then
		SlicingService.Stop(player, "OutOfHearts")
	end
end

function SlicingService.Init()
	for _, name in { "SlicingStart", "SlicingStop", "Slice", "SpawnObjects", "SliceResult", "SessionStarted", "SessionEnded" } do
		remotes[name] = Net.Event(name)
	end
	remotes.SlicingStart.OnServerEvent:Connect(start)
	remotes.SlicingStop.OnServerEvent:Connect(function(player)
		SlicingService.Stop(player, "Left")
	end)
	remotes.Slice.OnServerEvent:Connect(onSlice)
end

function SlicingService.Start()
	task.spawn(function()
		while true do
			task.wait(0.05)
			local ok, err = pcall(tick)
			if not ok then
				warn("[SlicingService] tick error: " .. tostring(err))
			end
		end
	end)

	local function hook(player: Player)
		player.CharacterRemoving:Connect(function()
			SlicingService.Stop(player, "Respawned")
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]
		if session then
			releasePad(session, player)
		end
		sessions[player] = nil
		lastStartRequest[player] = nil
	end)
end

return SlicingService
