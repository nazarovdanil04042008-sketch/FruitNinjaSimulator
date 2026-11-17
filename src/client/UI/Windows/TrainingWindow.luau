--!nonstrict
-- Lists every training activity with rewards, requirements and live cooldowns. Starts mini-games.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Training = require(Shared.Config.Training)

local UI = script.Parent.Parent
local UIKit = require(UI.UIKit)
local Theme = require(UI.Theme)
local State = require(UI.Parent.Controllers.State)
local TrainingGames = require(UI.Parent.Controllers.TrainingGames)

local TrainingWindow = {}
local C = Theme.Colors
local new = UIKit.new

local buttons: { [string]: TextButton } = {}
local readyAt: { [string]: number } = {}
local window: UIKit.Window

local function rewardText(def: Training.TrainingDef, multiplier: number): string
	local parts = {}
	for stat, amount in def.StatRewards do
		table.insert(parts, string.format("+%d %s", math.max(1, math.floor(amount * multiplier + 0.5)), stat))
	end
	table.sort(parts)
	return "Perfect run: " .. table.concat(parts, ", ") .. "  •  🪙 " .. def.Coins
end

local function refreshButtons()
	local profile = State.Profile
	if not profile then
		return
	end
	local now = os.clock()
	for _, def in Training.List do
		local button = buttons[def.Id]
		if profile.TrainingLevel < def.RequiredTrainingLevel then
			UIKit.SetButton(button, "🔒 Training Lv " .. def.RequiredTrainingLevel, C.Locked)
		elseif (readyAt[def.Id] or 0) > now then
			UIKit.SetButton(button, string.format("⏳ %ds", math.ceil(readyAt[def.Id] - now)), C.Gray)
		else
			UIKit.SetButton(button, "▶ START", C.Green)
		end
	end
end

local function fetchCooldowns()
	local ok, _, cooldowns = State.Action("GetTrainingCooldowns", true)
	if ok and type(cooldowns) == "table" then
		local now = os.clock()
		for id, remaining in cooldowns do
			readyAt[id] = now + remaining
		end
	end
	refreshButtons()
end

function TrainingWindow.Init()
	window = UIKit.CreateWindow("Training", "🏋️ TRAINING", Color3.fromRGB(255, 110, 90))
	local content = window.Content
	local scroll = new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 8, ZIndex = 6, Parent = content })
	UIKit.List(8).Parent = scroll

	local rewardLabels: { [string]: TextLabel } = {}
	for i, def in Training.List do
		local card = new("Frame", { BackgroundColor3 = C.Card, Size = UDim2.new(1, -12, 0, 68), LayoutOrder = i, ZIndex = 7, Parent = scroll })
		UIKit.Corner(12).Parent = card
		UIKit.Stroke(2.5, def.Color).Parent = card
		UIKit.Label({ Text = def.Emoji, Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(8, 8), Parent = card, ZIndex = 8, Stroke = false })
		UIKit.Label({ Text = def.DisplayName, Color = def.Color, Size = UDim2.new(1, -270, 0, 24), Position = UDim2.fromOffset(66, 4), AlignX = Enum.TextXAlignment.Left, Parent = card, ZIndex = 8, MaxTextSize = 21 })
		UIKit.Label({ Text = def.Description, Font = Theme.BodyFont, Size = UDim2.new(1, -270, 0, 18), Position = UDim2.fromOffset(66, 28), AlignX = Enum.TextXAlignment.Left, Parent = card, ZIndex = 8, MaxTextSize = 14, Stroke = false })
		rewardLabels[def.Id] = UIKit.Label({ Text = "", Font = Theme.BodyFont, Color = C.Coins, Size = UDim2.new(1, -270, 0, 16), Position = UDim2.fromOffset(66, 47), AlignX = Enum.TextXAlignment.Left, Parent = card, ZIndex = 8, MaxTextSize = 13, Stroke = false })
		buttons[def.Id] = UIKit.Button({ Text = "▶ START", Color = C.Green, Size = UDim2.fromOffset(190, 50), Position = UDim2.new(1, -200, 0, 9), Parent = card, ZIndex = 8, MaxTextSize = 20,
			OnClick = function()
				local profile = State.Profile
				if not profile then
					return
				end
				if profile.TrainingLevel < def.RequiredTrainingLevel then
					UIKit.Toast("Reach Training Level " .. def.RequiredTrainingLevel .. " to unlock this!", "error")
					return
				end
				UIKit.CloseWindow()
				TrainingGames.Start(def.Id)
			end })
	end

	local function refreshRewards()
		local derived = State.Derived
		local multiplier = derived and derived.TrainingMultiplier or 1
		for _, def in Training.List do
			rewardLabels[def.Id].Text = rewardText(def, multiplier)
		end
	end

	window.OnOpen = function()
		refreshRewards()
		fetchCooldowns()
		while window.IsOpen do
			task.wait(1)
			refreshButtons()
		end
	end
	State.Changed:Connect(function()
		if window.IsOpen then
			refreshRewards()
			refreshButtons()
		end
	end)
	TrainingGames.Finished:Connect(function(activityId: string, cooldown: number)
		readyAt[activityId] = os.clock() + cooldown
	end)
end

return TrainingWindow
