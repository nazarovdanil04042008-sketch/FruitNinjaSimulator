--!nonstrict
-- Client bootstrap. Location in Studio: StarterPlayer/StarterPlayerScripts/Client/Main (LocalScript)
-- Builds the UI, connects controllers and wires them together.

local UI = script.Parent:WaitForChild("UI")
local Controllers = script.Parent:WaitForChild("Controllers")

local Effects = require(UI.Effects)
local UIKit = require(UI.UIKit)
local State = require(Controllers.State)

Effects.Init()
UIKit.Init()
State.Init()

local FruitVisuals = require(Controllers.FruitVisuals)
local HUD = require(UI.HUD)
local TrainingGames = require(Controllers.TrainingGames)
local SlicingController = require(Controllers.SlicingController)
local HatchReveal = require(Controllers.HatchReveal)
local PetController = require(Controllers.PetController)
local WorldController = require(Controllers.WorldController)
local BuildController = require(Controllers.BuildController)

FruitVisuals.Init()
HUD.Init()

-- Windows
for _, name in { "UpgradesWindow", "ShopWindows", "PetsWindow", "EggsWindow", "IndexWindow", "TrainingWindow", "TeleportWindow", "BuildWindow", "TradeWindow" } do
	local ok, err = pcall(function()
		require(UI.Windows:WaitForChild(name)).Init()
	end)
	if not ok then
		warn("[Client] Failed to build " .. name .. ": " .. tostring(err))
	end
end

TrainingGames.Init()
SlicingController.Init()
HatchReveal.Init()
PetController.Init()
WorldController.Init()
BuildController.Init()

-- Cross-controller rules
SlicingController.IsBlocked = function()
	return TrainingGames.Active
end
TrainingGames.IsBlocked = function()
	return SlicingController.Active
end
SlicingController.ActiveChanged:Connect(function(active: boolean)
	HUD.SetSlicingMode(active)
	PetController.SetLocalHidden(active)
	if active then
		BuildController.Stop()
	end
end)
BuildController.ModeChanged:Connect(function(mode: string?)
	HUD.SetMenuVisible(mode == nil)
end)
TrainingGames.ActiveChanged:Connect(function(active: boolean)
	HUD.SetMenuVisible(not active)
	if active then
		BuildController.Stop()
	end
end)

State.WaitForProfile()
print("[Fruit Ninja Simulator] Client ready.")
