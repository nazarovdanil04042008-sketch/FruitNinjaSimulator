--!nonstrict
-- Stat upgrades (Speed / Strength / Agility) bought with coins + training level overview.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Upgrades = require(Shared.Config.Upgrades)
local Formulas = require(Shared.Util.Formulas)
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent
local UIKit = require(UI.UIKit)
local Theme = require(UI.Theme)
local State = require(UI.Parent.Controllers.State)

local UpgradesWindow = {}
local C = Theme.Colors
local new = UIKit.new

type Row = { Level: TextLabel, Effect: TextLabel, BuyOne: TextButton, BuyTen: TextButton, BuyMax: TextButton }
local rows: { [string]: Row } = {}
local trainingLabel: TextLabel
local setTrainingBar: (number, string?) -> ()

local function effectText(statId: string, profile: any): string
	local derived = Formulas.Compute(profile)
	local nextProfile = table.clone(profile)
	nextProfile.Stats = table.clone(profile.Stats)
	nextProfile.Stats[statId] += 1
	local nextDerived = Formulas.Compute(nextProfile)
	if statId == "Speed" then
		return string.format("Walk speed %.1f → %.1f  •  Fruit every %.2fs → %.2fs", derived.WalkSpeed, nextDerived.WalkSpeed, derived.SpawnInterval, nextDerived.SpawnInterval)
	elseif statId == "Strength" then
		return string.format("Coins %s → %s", Format.Multiplier(derived.CoinMultiplier), Format.Multiplier(nextDerived.CoinMultiplier))
	else
		return string.format("Blade size %d → %d  •  Slices/s %.1f → %.1f", math.floor(derived.HitRadius), math.floor(nextDerived.HitRadius), derived.SliceRate, nextDerived.SliceRate)
	end
end

local function refresh()
	local profile = State.Profile
	if not profile then
		return
	end
	for _, def in Upgrades.List do
		local row = rows[def.Id]
		local level = profile.Stats[def.Id]
		row.Level.Text = def.Emoji .. " " .. def.DisplayName .. "  Lv. " .. level
		local maxed = level >= GameConfig.MaxStatLevel
		if maxed then
			row.Effect.Text = "MAXED OUT!"
			UIKit.SetButton(row.BuyOne, "MAX", C.Gray)
		else
			row.Effect.Text = effectText(def.Id, profile)
			local cost = Formulas.UpgradeCost(def.BaseCost, def.Growth, level)
			UIKit.SetButton(row.BuyOne, "🪙 " .. Format.Short(cost), profile.Coins >= cost and C.Green or C.Gray)
		end
		local cost10 = 0
		for i = 0, 9 do
			cost10 += Formulas.UpgradeCost(def.BaseCost, def.Growth, level + i)
		end
		UIKit.SetButton(row.BuyTen, "x10  🪙 " .. Format.Short(cost10), profile.Coins >= cost10 and C.Blue or C.Gray)
		UIKit.SetButton(row.BuyMax, "MAX", C.Purple)
	end
	local neededT = Formulas.TrainingXpForLevel(profile.TrainingLevel)
	trainingLabel.Text = "🥋 Training Level " .. profile.TrainingLevel .. "  •  Training gives free stats! Visit the Dojo."
	setTrainingBar(profile.TrainingXp / neededT, string.format("%d / %d", profile.TrainingXp, neededT))
end

function UpgradesWindow.Init()
	local window = UIKit.CreateWindow("Upgrades", "⬆️ UPGRADES", C.Green)
	local content = window.Content
	UIKit.List(10).Parent = content

	for i, def in Upgrades.List do
		local card = new("Frame", { BackgroundColor3 = C.Card, Size = UDim2.new(1, 0, 0, 92), LayoutOrder = i, ZIndex = 6, Parent = content })
		UIKit.Corner(14).Parent = card
		UIKit.Stroke(2.5, def.Color).Parent = card
		local level = UIKit.Label({ Text = def.DisplayName, Color = def.Color, Size = UDim2.new(0.5, 0, 0, 32), Position = UDim2.fromOffset(14, 6), AlignX = Enum.TextXAlignment.Left, Parent = card, ZIndex = 7, StrokeThickness = 2 })
		UIKit.Label({ Text = def.Description, Font = Theme.BodyFont, Color = C.SubText, Size = UDim2.new(0.62, 0, 0, 22), Position = UDim2.fromOffset(14, 40), AlignX = Enum.TextXAlignment.Left, Parent = card, ZIndex = 7, MaxTextSize = 16, Stroke = false })
		local effect = UIKit.Label({ Text = "", Font = Theme.BodyFont, Size = UDim2.new(0.62, 0, 0, 22), Position = UDim2.fromOffset(14, 62), AlignX = Enum.TextXAlignment.Left, Parent = card, ZIndex = 7, MaxTextSize = 16 })
		local function buy(mode: string)
			State.Purchase("BuyUpgrade", def.Id, mode)
		end
		local buyOne = UIKit.Button({ Text = "Buy", Color = C.Green, Size = UDim2.fromOffset(150, 40), Position = UDim2.new(1, -164, 0, 8), Parent = card, ZIndex = 7, OnClick = function() buy("One") end })
		local buyTen = UIKit.Button({ Text = "x10", Color = C.Blue, Size = UDim2.fromOffset(150, 36), Position = UDim2.new(1, -164, 0, 50), Parent = card, ZIndex = 7, MaxTextSize = 18, OnClick = function() buy("Ten") end })
		local buyMax = UIKit.Button({ Text = "MAX", Color = C.Purple, Size = UDim2.fromOffset(70, 36), Position = UDim2.new(1, -244, 0, 50), Parent = card, ZIndex = 7, MaxTextSize = 18, OnClick = function() buy("Max") end })
		rows[def.Id] = { Level = level, Effect = effect, BuyOne = buyOne, BuyTen = buyTen, BuyMax = buyMax }
	end

	local trainingCard = new("Frame", { BackgroundColor3 = C.Card, Size = UDim2.new(1, 0, 0, 74), LayoutOrder = 10, ZIndex = 6, Parent = content })
	UIKit.Corner(14).Parent = trainingCard
	trainingLabel = UIKit.Label({ Text = "", Size = UDim2.new(1, -24, 0, 26), Position = UDim2.fromOffset(12, 6), AlignX = Enum.TextXAlignment.Left, Parent = trainingCard, ZIndex = 7, MaxTextSize = 20 })
	local _, setter = UIKit.ProgressBar({ Size = UDim2.new(1, -24, 0, 26), Position = UDim2.fromOffset(12, 38), Color = C.Orange, Parent = trainingCard })
	setTrainingBar = setter

	window.OnOpen = refresh
	State.Changed:Connect(function()
		if window.IsOpen then
			refresh()
		end
	end)
end

return UpgradesWindow
