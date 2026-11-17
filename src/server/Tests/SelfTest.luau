--!nonstrict
-- Automatic sanity checks that run when you press Play in Studio (never in live servers).
-- They catch broken config edits: missing ids, impossible requirements, non-monotonic prices, etc.
-- Results print to the Output window as "[SelfTest] PASS ..." / "[SelfTest] FAIL ...".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local Fruits = require(Config.Fruits)
local Eggs = require(Config.Eggs)
local Creatures = require(Config.Creatures)
local Rarities = require(Config.Rarities)
local Arenas = require(Config.Arenas)
local Katanas = require(Config.Katanas)
local Belts = require(Config.Belts)
local Trails = require(Config.Trails)
local Training = require(Config.Training)
local Locations = require(Config.Locations)
local GameConfig = require(Config.GameConfig)
local Formulas = require(Shared.Util.Formulas)
local Format = require(Shared.Util.Format)
local Trajectory = require(Shared.Util.Trajectory)

local SelfTest = {}

local passed, failed = 0, 0

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
	else
		failed += 1
		warn("[SelfTest] FAIL " .. name .. (detail and (" - " .. detail) or ""))
	end
end

local function baseProfile(): any
	return {
		Level = 1, Coins = 0, Xp = 0, TrainingLevel = 1,
		Stats = { Speed = 0, Strength = 0, Agility = 0 },
		EquippedKatana = "Wooden", EquippedBelt = "White", EquippedTrail = "",
		Creatures = {}, EquippedCreatures = {},
	}
end

function SelfTest.Run()
	-- Arenas reference real fruits / eggs
	for _, arena in Arenas.List do
		for id in arena.FruitWeights do
			check("arena fruit " .. arena.Id .. "/" .. id, Fruits.Get(id) ~= nil and Fruits.Get(id).Kind == "Fruit")
		end
		for id in arena.EggWeights do
			local def = Fruits.Get(id)
			check("arena egg " .. arena.Id .. "/" .. id, def ~= nil and def.Kind == "Egg" and def.EggId ~= nil and Eggs.Get(def.EggId :: string) ~= nil)
		end
		check("arena chances < 1 " .. arena.Id, arena.BombChance + arena.EggChance + arena.GoldenChance + arena.FrenzyChance < 0.5)
	end

	-- Eggs: every weighted rarity has at least one creature, hatch times reasonable
	for _, egg in Eggs.List do
		local total = 0
		for rarity, weight in egg.Weights do
			check("egg rarity exists " .. egg.Id .. "/" .. rarity, Rarities.ByName[rarity] ~= nil)
			check("egg rarity has creatures " .. egg.Id .. "/" .. rarity, Creatures.ByRarity[rarity] ~= nil and #Creatures.ByRarity[rarity] > 0)
			total += weight
		end
		check("egg weights positive " .. egg.Id, total > 0)
		check("egg hatch time <= 15 min " .. egg.Id, egg.HatchTime > 0 and egg.HatchTime <= 900)
		local fruit = Fruits.Get(egg.FruitId)
		check("egg fruit link " .. egg.Id, fruit ~= nil and fruit.EggId == egg.Id)
		local sum = 0
		for _, odds in Eggs.GetOdds(egg.Id) do
			sum += odds.Chance
		end
		check("egg odds sum to 100 " .. egg.Id, math.abs(sum - 100) < 0.01, tostring(sum))
	end

	-- Every rarity is obtainable from some egg, and has creatures
	for _, rarity in Rarities.List do
		local obtainable = false
		for _, egg in Eggs.List do
			if (egg.Weights[rarity.Name] or 0) > 0 then
				obtainable = true
			end
		end
		check("rarity obtainable " .. rarity.Name, obtainable)
		check("rarity has creatures " .. rarity.Name, Creatures.ByRarity[rarity.Name] ~= nil)
	end

	-- Creatures: bonuses grow with rarity
	local lastPower = 0
	for _, rarity in Rarities.List do
		local best = 0
		for _, def in Creatures.ByRarity[rarity.Name] or {} do
			best = math.max(best, Creatures.GetPower(def.Id))
		end
		check("creature power grows " .. rarity.Name, best > lastPower)
		lastPower = best
	end

	-- Shops: prices / bonuses increase with order
	local function ascending(name: string, list: { any }, priceKey: string, bonusKey: string)
		for i = 2, #list do
			check(name .. " price ascending " .. list[i].Id, list[i][priceKey] > list[i - 1][priceKey])
			check(name .. " bonus ascending " .. list[i].Id, list[i][bonusKey] >= list[i - 1][bonusKey])
		end
	end
	ascending("katana", Katanas.List, "Price", "CoinMultiplier")
	ascending("belt", Belts.List, "Price", "TrainingMultiplier")
	ascending("trail", Trails.List, "Price", "SpeedMultiplier")

	-- Formulas
	local p = baseProfile()
	local d0 = Formulas.Compute(p)
	check("base walk speed", math.abs(d0.WalkSpeed - GameConfig.BaseWalkSpeed) < 0.01, tostring(d0.WalkSpeed))
	p.Stats.Speed = 50
	p.Stats.Strength = 50
	p.Stats.Agility = 50
	local d1 = Formulas.Compute(p)
	check("speed upgrades help", d1.WalkSpeed > d0.WalkSpeed and d1.SpawnInterval < d0.SpawnInterval)
	check("strength upgrades help", d1.CoinMultiplier > d0.CoinMultiplier)
	check("agility upgrades help", d1.HitRadius > d0.HitRadius and d1.SliceRate > d0.SliceRate)
	p.Stats.Speed = GameConfig.MaxStatLevel
	p.EquippedBelt = "Cosmic"
	p.EquippedTrail = "Galaxy"
	local d2 = Formulas.Compute(p)
	check("walk speed capped", d2.WalkSpeed <= GameConfig.MaxWalkSpeed + 1e-6)
	check("spawn interval floor", d2.SpawnInterval >= GameConfig.MinSpawnInterval - 1e-6)
	check("xp curve increasing", Formulas.XpForLevel(10) > Formulas.XpForLevel(9))
	check("pet slots", Formulas.PetSlots(1) >= 1 and Formulas.PetSlots(100) >= Formulas.PetSlots(1))
	check("slice coins >= 1", Formulas.SliceCoins(1, d0, 1, 1) >= 1)
	check("combo multiplier capped", Formulas.SliceCoins(10, d0, 1, 1000) <= math.ceil(10 * GameConfig.MaxComboMultiplier))

	-- Trajectory: objects rise above the stage centre and come back down
	local rng = Random.new(1)
	for _ = 1, 50 do
		local launch = Trajectory.Create(rng, Arenas.HalfWidth, Arenas.LaunchY, 22, 32)
		local lifetime = Trajectory.Lifetime(launch)
		local apex = Trajectory.Position(launch, launch.VY / GameConfig.Gravity)
		check("trajectory apex visible", apex.Y > 0 and apex.Y < 16, tostring(apex.Y))
		check("trajectory ends below", Trajectory.Position(launch, lifetime).Y < launch.Y0 + 0.1)
	end

	-- Training / locations
	for _, def in Training.List do
		check("training goal <= max " .. def.Id, def.Goal <= def.MaxScore)
		check("training cooldown " .. def.Id, def.Cooldown > 0)
	end
	for _, loc in Locations.List do
		check("location arena " .. loc.Id, loc.ArenaId == nil or Arenas.Get(loc.ArenaId) ~= nil)
	end

	-- Formatting
	check("format short 999", Format.Short(999) == "999", Format.Short(999))
	check("format short 1500", Format.Short(1500) == "1.5K", Format.Short(1500))
	check("format short 100000", Format.Short(100000) == "100K", Format.Short(100000))
	check("format short 2000000", Format.Short(2000000) == "2M", Format.Short(2000000))
	check("format commas", Format.Commas(1234567) == "1,234,567", Format.Commas(1234567))
	check("format time", Format.Time(75) == "1m 15s", Format.Time(75))

	local summary = string.format("[SelfTest] %d passed, %d failed", passed, failed)
	if failed > 0 then
		warn(summary)
	else
		print(summary)
	end
	return failed == 0
end

return SelfTest
