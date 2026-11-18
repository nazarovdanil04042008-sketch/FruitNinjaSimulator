--!nonstrict
-- Server bootstrap. Creates remotes, builds the world and starts every service in dependency order.
-- Location in Studio: ServerScriptService/Server/Main (Script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared").Util.Net)
Net.Setup() -- must happen before services look up remotes

local Services = script.Parent:WaitForChild("Services")

local order = {
	"WorldBuilder",
	"DataService",
	"ActionService",
	"ProgressionService",
	"EquipmentService",
	"ShopService",
	"EggService",
	"SlicingService",
	"TrainingService",
	"BuildingService",
	"TradeService",
}

local loaded = {}
for _, name in order do
	local module = require(Services:WaitForChild(name)) :: any
	loaded[name] = module
end

for _, name in order do
	local ok, err = pcall(loaded[name].Init)
	if not ok then
		warn("[Main] " .. name .. ".Init failed: " .. tostring(err))
	end
end

for _, name in order do
	local ok, err = pcall(loaded[name].Start)
	if not ok then
		warn("[Main] " .. name .. ".Start failed: " .. tostring(err))
	end
end

print("[Fruit Ninja Simulator] Server ready. Version " .. require(ReplicatedStorage.Shared.Config.GameConfig).Version)

-- Config / formula sanity checks (Studio only)
if game:GetService("RunService"):IsStudio() then
	local tests = script.Parent:FindFirstChild("Tests")
	local selfTest = tests and tests:FindFirstChild("SelfTest")
	if selfTest then
		task.spawn(function()
			local ok, err = pcall(function()
				(require(selfTest) :: any).Run()
			end)
			if not ok then
				warn("[SelfTest] crashed: " .. tostring(err))
			end
		end)
	end
end
