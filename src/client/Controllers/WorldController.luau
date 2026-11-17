--!nonstrict
-- Connects the 3D world to the UI:
--   * ProximityPrompts (attributes set by WorldBuilder) open windows, start slicing or training
--   * Level gates become passable (locally) once the player's level is high enough
--   * Locked arena pads hide their prompts
--   * First-time player hints

local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Arenas = require(Shared.Config.Arenas)

local UI = script.Parent.Parent.UI
local UIKit = require(UI.UIKit)
local Effects = require(UI.Effects)
local Theme = require(UI.Theme)
local State = require(script.Parent.State)
local SlicingController = require(script.Parent.SlicingController)
local TrainingGames = require(script.Parent.TrainingGames)

local WorldController = {}

local gates: { BasePart } = {}
local gateLabels: { BasePart } = {}
local arenaPrompts: { ProximityPrompt } = {}
local opened: { [string]: boolean } = {}

local function onPrompt(prompt: ProximityPrompt)
	local action = prompt:GetAttribute("Action")
	if action == "Slice" then
		SlicingController.RequestStart(prompt:GetAttribute("Arena") :: string)
	elseif action == "Train" then
		TrainingGames.Start(prompt:GetAttribute("Activity") :: string)
	elseif action == "Open" then
		local window = prompt:GetAttribute("Window") :: string
		if not UIKit.IsWindowOpen(window) then
			UIKit.OpenWindow(window)
		end
	end
end

local function refreshGates(profile: any)
	for _, gate in gates do
		local required = gate:GetAttribute("RequiredLevel") :: number? or 1
		local unlocked = profile.Level >= required
		gate.CanCollide = not unlocked
		gate.Transparency = unlocked and 1 or 0
		local arenaId = gate:GetAttribute("ArenaId") :: string?
		if unlocked and arenaId and not opened[arenaId] then
			opened[arenaId] = true
		end
	end
	for _, label in gateLabels do
		local arena = Arenas.Get(label:GetAttribute("GateFor") :: string)
		if arena then
			local unlocked = profile.Level >= arena.RequiredLevel
			for _, gui in label:GetChildren() do
				local text = gui:FindFirstChildOfClass("TextLabel")
				if text then
					text.Text = unlocked and ("✅ " .. arena.DisplayName:upper()) or ("🔒 LEVEL " .. arena.RequiredLevel .. " REQUIRED")
				end
			end
		end
	end
	for _, prompt in arenaPrompts do
		local arena = Arenas.Get(prompt:GetAttribute("Arena") :: string)
		prompt.Enabled = arena ~= nil and profile.Level >= arena.RequiredLevel
	end
end

-- Works with StreamingEnabled: parts can stream in (and out) at any time, so we register them as they arrive.
local function register(d: Instance): boolean
	if d:IsA("BasePart") and d.Name == "FNS_Gate" then
		table.insert(gates, d)
		return true
	elseif d:IsA("BasePart") and d:GetAttribute("GateFor") then
		table.insert(gateLabels, d)
		return true
	elseif d:IsA("ProximityPrompt") and d:GetAttribute("Action") == "Slice" then
		table.insert(arenaPrompts, d)
		return true
	end
	return false
end

local function prune()
	for _, list: { any } in { gates, gateLabels, arenaPrompts } do
		for i = #list, 1, -1 do
			if not list[i].Parent then
				table.remove(list, i)
			end
		end
	end
end

local function scan(world: Instance)
	for _, d in world:GetDescendants() do
		register(d)
	end
	world.DescendantAdded:Connect(function(d)
		-- attributes / children may arrive a moment after the instance itself
		task.defer(function()
			if register(d) then
				prune()
				if State.Profile then
					refreshGates(State.Profile)
				end
			end
		end)
	end)
end

local function firstTimeHints(profile: any)
	if profile.Totals.FruitsSliced > 0 then
		return
	end
	task.wait(2)
	Effects.Banner("🍉 Welcome, Ninja! 🍉", Theme.Colors.Coins, 2.2, 0.28)
	task.wait(2.5)
	UIKit.Toast("Walk NORTH to the ⚔️ Arenas and step onto a glowing pad!", "info")
	task.wait(3.5)
	UIKit.Toast("Or press 🗺️ Teleport → Sunny Orchard to go there instantly.", "info")
end

function WorldController.Init()
	ProximityPromptService.PromptTriggered:Connect(onPrompt)
	task.spawn(function()
		local world = workspace:WaitForChild("FNS_World", 60)
		if not world then
			warn("[WorldController] FNS_World not found")
			return
		end
		scan(world)
		if State.Profile then
			refreshGates(State.Profile)
		end
	end)
	State.Changed:Connect(function(profile, previous)
		refreshGates(profile)
		if not previous then
			task.spawn(firstTimeHints, profile)
		end
	end)
end

return WorldController
