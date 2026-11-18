--!nonstrict
-- World boss every 30 minutes (at :00 and :30 UTC; in Studio the first one comes after ~45 s).
--
-- The boss is a giant brainrot in the Boss Arena. The server owns its HP and all rewards; every client
-- renders and animates the boss model locally (smooth, zero physics). State is published as Workspace
-- attributes: FNS_BossActive, FNS_BossId, FNS_BossHP, FNS_BossMaxHP, FNS_BossEnds, FNS_BossNextAt,
-- FNS_BossSlamAt, FNS_BossSlamRadius.
--
-- Players hit it with BossAttack (rate-limited, range-checked, stun-checked). HP scales with the
-- power of everyone online so a fight takes roughly a minute or two. Every few seconds the boss
-- telegraphs a ground slam (red circle); players inside get knocked back and stunned.
-- Rewards depend on your share of the damage: coins, XP and an egg (top damage = Cosmic Egg).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local LiveOps = require(Shared.Config.LiveOps)
local Formulas = require(Shared.Util.Formulas)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Util.Net)

local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)
local EggService = require(script.Parent.EggService)
local QuestBus = require(script.Parent.QuestBus)

local BossService = {}

local remotes: { [string]: RemoteEvent } = {}
local rng = Random.new()

local active = false
local def: LiveOps.BossDef? = nil
local hp, maxHp = 0, 0
local endsAt = 0
local nextBossAt = 0
local nextSlamAt = 0
local hpDirty = false
local damage: { [Player]: number } = {}
local buckets: { [Player]: { Tokens: number, Last: number } } = {}
local stunnedUntil: { [Player]: number } = {}

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

function BossService.DamagePerHit(profile: any): number
	local derived = Formulas.Compute(profile)
	return math.max(1, math.floor(10 * derived.CoinMultiplier ^ 0.7 * (1 + profile.Level * 0.05)))
end

local function publish()
	workspace:SetAttribute("FNS_BossActive", active)
	workspace:SetAttribute("FNS_BossId", def and def.Id or "")
	workspace:SetAttribute("FNS_BossHP", math.max(0, math.floor(hp)))
	workspace:SetAttribute("FNS_BossMaxHP", maxHp)
	workspace:SetAttribute("FNS_BossEnds", endsAt)
	workspace:SetAttribute("FNS_BossNextAt", nextBossAt)
end

local function scheduleNext()
	local now = os.time()
	nextBossAt = if RunService:IsStudio() then now + 300 else LiveOps.NextBossAt(now)
	publish()
end

local function spawnBoss()
	-- pick by time slot so all servers fight the same boss
	local slot = math.floor(os.time() / LiveOps.BossInterval)
	def = LiveOps.Bosses[slot % #LiveOps.Bosses + 1]
	local total = 0
	for _, player in Players:GetPlayers() do
		local profile = DataService.Get(player)
		if profile then
			total += BossService.DamagePerHit(profile) * LiveOps.BossHitsPerSecond * 0.6 * 75
		end
	end
	maxHp = math.max(3000, math.floor(total))
	hp = maxHp
	active = true
	endsAt = os.time() + LiveOps.BossDuration
	nextSlamAt = serverNow() + 8
	table.clear(damage)
	publish()
	ProgressionService.NotifyAll("👹 " .. (def :: LiveOps.BossDef).DisplayName .. " has appeared in the Boss Arena! Teleport and fight!", "rare")
	remotes.BossEvent:FireAllClients("Spawned", { Id = (def :: LiveOps.BossDef).Id })
end

local function finish(defeated: boolean)
	if not active then
		return
	end
	active = false
	local bossDef = def :: LiveOps.BossDef
	workspace:SetAttribute("FNS_BossSlamAt", 0)
	-- rank participants by damage
	local ranking = {}
	local totalDamage = 0
	for player, amount in damage do
		if player.Parent and amount > 0 then
			table.insert(ranking, { Player = player, Damage = amount })
			totalDamage += amount
		end
	end
	table.sort(ranking, function(a, b)
		return a.Damage > b.Damage
	end)
	for rank, entry in ranking do
		local player = entry.Player
		local profile = DataService.Get(player)
		if profile then
			local share = entry.Damage / math.max(totalDamage, 1)
			local baseCoins = LiveOps.ScaleCoins(1500, profile.Level)
			local coins, xp, egg
			if defeated then
				coins = math.floor(baseCoins * (0.5 + share * 1.5))
				xp = math.floor(300 * (1 + profile.Level * 0.1) * (0.5 + share))
				egg = rank == 1 and "Cosmic" or rank <= 3 and "Crystal" or "Jungle"
			else
				coins = math.floor(baseCoins * 0.2)
				xp = 50
			end
			ProgressionService.AddCoins(player, coins)
			ProgressionService.AddXp(player, xp)
			local eggAdded = egg and EggService.AddEgg(player, egg) or false
			if defeated then
				profile.Totals.BossesDefeated = (profile.Totals.BossesDefeated or 0) + 1
				QuestBus.Fire(player, "BossDefeated", 1)
			end
			remotes.BossEvent:FireClient(player, "Result", {
				Defeated = defeated, Rank = rank, Players = #ranking, Damage = entry.Damage,
				Coins = coins, Xp = xp, Egg = eggAdded and egg or nil, BossName = bossDef.DisplayName,
			})
		end
	end
	if defeated then
		local top = ranking[1]
		ProgressionService.NotifyAll("🏆 " .. bossDef.DisplayName .. " was defeated!" .. (top and (" MVP: " .. top.Player.DisplayName) or ""), "rare")
	else
		ProgressionService.NotifyAll("💨 " .. bossDef.DisplayName .. " escaped! Next boss in 30 minutes.", "info")
	end
	remotes.BossEvent:FireAllClients(defeated and "Defeated" or "Escaped", { Id = bossDef.Id })
	hp = 0
	table.clear(damage)
	table.clear(stunnedUntil)
	scheduleNext()
end

local function slam()
	local bossDef = def :: LiveOps.BossDef
	local hitAt = serverNow() + 1.6
	workspace:SetAttribute("FNS_BossSlamRadius", bossDef.SlamRadius)
	workspace:SetAttribute("FNS_BossSlamAt", hitAt)
	task.delay(1.6, function()
		if not active then
			return
		end
		local center = LiveOps.BossArena
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				local offset = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
				if offset.Magnitude <= bossDef.SlamRadius and root.Position.Y < center.Y + 9 then
					stunnedUntil[player] = os.clock() + 1.5
					local away = offset.Magnitude > 0.1 and offset.Unit or Vector3.new(1, 0, 0)
					remotes.BossEvent:FireClient(player, "Knockback", { Direction = away })
				end
			end
		end
	end)
end

local function onAttack(player: Player)
	if not active then
		return
	end
	local profile = DataService.Get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not profile or not root then
		return
	end
	local center = LiveOps.BossArena
	if Vector2.new(root.Position.X - center.X, root.Position.Z - center.Z).Magnitude > LiveOps.BossAttackRange then
		return
	end
	if (stunnedUntil[player] or 0) > os.clock() then
		return
	end
	local now = os.clock()
	local bucket = buckets[player]
	if not bucket then
		bucket = { Tokens = LiveOps.BossHitsPerSecond, Last = now }
		buckets[player] = bucket
	end
	bucket.Tokens = math.min(LiveOps.BossHitsPerSecond, bucket.Tokens + (now - bucket.Last) * LiveOps.BossHitsPerSecond)
	bucket.Last = now
	if bucket.Tokens < 1 then
		return
	end
	bucket.Tokens -= 1
	local amount = BossService.DamagePerHit(profile)
	local crit = rng:NextNumber() < 0.1
	if crit then
		amount *= 2
	end
	damage[player] = (damage[player] or 0) + amount
	profile.Totals.BossDamage = (profile.Totals.BossDamage or 0) + amount
	hp -= amount
	hpDirty = true
	QuestBus.Fire(player, "Boss", 1)
	remotes.BossEvent:FireClient(player, "Hit", { Damage = amount, Crit = crit })
	if hp <= 0 then
		finish(true)
	end
end

function BossService.Init()
	remotes.BossEvent = Net.Event("BossEvent")
	remotes.BossAttack = Net.Event("BossAttack")
	remotes.BossAttack.OnServerEvent:Connect(onAttack)
	publish()
end

function BossService.Start()
	if RunService:IsStudio() then
		nextBossAt = os.time() + LiveOps.StudioFirstBossDelay
	else
		nextBossAt = LiveOps.NextBossAt(os.time())
	end
	publish()
	local warned = false
	task.spawn(function()
		while true do
			task.wait(0.2)
			local now = os.time()
			if active then
				if hpDirty then
					hpDirty = false
					workspace:SetAttribute("FNS_BossHP", math.max(0, math.floor(hp)))
				end
				if now >= endsAt then
					finish(false)
				elseif serverNow() >= nextSlamAt then
					nextSlamAt = serverNow() + rng:NextNumber(6, 9)
					slam()
				end
			else
				if not warned and nextBossAt - now <= LiveOps.BossWarning and nextBossAt - now > 0 then
					warned = true
					ProgressionService.NotifyAll("👹 A world boss appears in " .. Format.Time(nextBossAt - now) .. "! Get ready in the Boss Arena.", "rare")
				end
				if now >= nextBossAt then
					warned = false
					spawnBoss()
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		damage[player] = nil
		buckets[player] = nil
		stunnedUntil[player] = nil
	end)
end

return BossService
