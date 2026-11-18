--!nonstrict
-- 🔁 Rebirth: requirements, what you keep / lose, the permanent bonus and exclusive rewards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Formulas = require(Shared.Util.Formulas)
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent
local UIKit = require(UI.UIKit)
local Theme = require(UI.Theme)
local Effects = require(UI.Effects)
local State = require(UI.Parent.Controllers.State)

local RebirthWindow = {}
local C = Theme.Colors

local titleLabel: TextLabel
local bonusLabel: TextLabel
local setLevel: (number, string?) -> ()
local setCoins: (number, string?) -> ()
local rebirthButton: TextButton

local function refresh()
	local profile = State.Profile
	if not profile then
		return
	end
	local r = profile.Rebirths or 0
	local cost = Formulas.RebirthCost(r)
	local needLevel = Formulas.RebirthLevel(r)
	titleLabel.Text = "🔁 Rebirths: " .. r
	bonusLabel.Text = string.format("Coins x%.1f → x%.1f   •   XP x%.2f → x%.2f", 1 + r * GameConfig.RebirthCoinBonus, 1 + (r + 1) * GameConfig.RebirthCoinBonus,
		1 + r * GameConfig.RebirthXpBonus, 1 + (r + 1) * GameConfig.RebirthXpBonus)
	setLevel(profile.Level / needLevel, "Level " .. profile.Level .. " / " .. needLevel)
	setCoins(profile.Coins / cost, Format.Short(profile.Coins) .. " / " .. Format.Short(cost) .. " coins")
	local ready = profile.Level >= needLevel and profile.Coins >= cost
	UIKit.SetButton(rebirthButton, ready and "🔁 REBIRTH!" or "🔒 Not ready", ready and C.Orange or C.Locked)
end

function RebirthWindow.Init()
	local window = UIKit.CreateWindow("Rebirth", "🔁 REBIRTH", C.Orange)
	local content = window.Content
	titleLabel = UIKit.Label({ Text = "", Size = UDim2.new(1, 0, 0, 34), Parent = content, ZIndex = 7, MaxTextSize = 30 })
	bonusLabel = UIKit.Label({ Text = "", Color = C.Coins, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 38), Parent = content, ZIndex = 7, MaxTextSize = 22 })
	local _, lv = UIKit.ProgressBar({ Size = UDim2.new(1, -40, 0, 28), Position = UDim2.fromOffset(20, 76), Color = C.Xp, Parent = content })
	local _, co = UIKit.ProgressBar({ Size = UDim2.new(1, -40, 0, 28), Position = UDim2.fromOffset(20, 112), Color = C.Coins, Parent = content })
	setLevel, setCoins = lv, co
	UIKit.Label({ Text = "❌ Resets: coins, level, XP, Speed / Strength / Agility\n✅ Keeps: katanas, belts, trails, creatures, eggs, village, trainings\n🎁 Rebirth 1: Phoenix Trail   •   Rebirth 3: Phoenix Katana",
		Font = Theme.BodyFont, Size = UDim2.new(1, -40, 0, 96), Position = UDim2.fromOffset(20, 150), Parent = content, ZIndex = 7, MaxTextSize = 18 })
	rebirthButton = UIKit.Button({ Text = "Rebirth", Color = C.Orange, Size = UDim2.fromOffset(300, 70), Position = UDim2.new(0.5, -150, 0, 270), Parent = content, ZIndex = 7, MaxTextSize = 30,
		OnClick = function()
			UIKit.Confirm("Rebirth now?", "Your coins, level and stats reset, but you keep your items and get a permanent bonus!", "Rebirth!", function()
				if State.Action("Rebirth", false) then
					Effects.Banner("🔁 REBORN! 🔁", C.Orange, 2.2, 0.3)
					Effects.Play("LevelUp", 0.8)
					UIKit.CloseWindow()
				end
			end)
		end })
	window.OnOpen = refresh
	State.Changed:Connect(function()
		if window.IsOpen then
			refresh()
		end
	end)
end

return RebirthWindow
