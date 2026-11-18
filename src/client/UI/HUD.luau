--!nonstrict
-- Always-visible HUD: level + XP bar, coins, quick stats (speed / katana / belt / trail) and the menu buttons.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Katanas = require(Shared.Config.Katanas)
local Belts = require(Shared.Config.Belts)
local Trails = require(Shared.Config.Trails)
local Formulas = require(Shared.Util.Formulas)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Util.Net)

local UIKit = require(script.Parent.UIKit)
local Theme = require(script.Parent.Theme)
local Effects = require(script.Parent.Effects)
local State = require(script.Parent.Parent.Controllers.State)

local HUD = {}

local C = Theme.Colors
local new = UIKit.new

local container: Frame
local menu: Frame
local infoCard: Frame
local levelLabel: TextLabel
local setXp: (number, string?) -> ()
local coinsLabel: TextLabel
local infoLabels: { [string]: TextLabel } = {}
local eggBadge: TextLabel
local badges: { [string]: TextLabel } = {}
local displayedCoins = 0
local coinTarget = 0
local coinValue: NumberValue

local MENU = {
	{ Window = "Upgrades", Emoji = "⬆️", Label = "Upgrade", Color = C.Green },
	{ Window = "Katanas", Emoji = "⚔️", Label = "Katanas", Color = C.Orange },
	{ Window = "Belts", Emoji = "🥋", Label = "Belts", Color = C.Red },
	{ Window = "Trails", Emoji = "✨", Label = "Trails", Color = C.Purple },
	{ Window = "Pets", Emoji = "🐾", Label = "Creatures", Color = C.Pink },
	{ Window = "Eggs", Emoji = "🥚", Label = "Eggs", Color = Color3.fromRGB(255, 190, 90) },
	{ Window = "Index", Emoji = "📖", Label = "Index", Color = C.Blue },
	{ Window = "Training", Emoji = "🏋️", Label = "Training", Color = Color3.fromRGB(255, 110, 90) },
	{ Window = "Teleport", Emoji = "🗺️", Label = "Teleport", Color = Color3.fromRGB(60, 200, 170) },
	{ Window = "Build", Emoji = "🏯", Label = "Village", Color = Color3.fromRGB(220, 70, 60) },
	{ Window = "Trade", Emoji = "🤝", Label = "Trade", Color = Color3.fromRGB(90, 200, 120) },
	{ Window = "Rewards", Emoji = "🎁", Label = "Rewards", Color = Color3.fromRGB(255, 110, 190) },
	{ Window = "Rebirth", Emoji = "🔁", Label = "Rebirth", Color = Color3.fromRGB(255, 150, 50) },
	{ Window = "Store", Emoji = "💎", Label = "Store", Color = Color3.fromRGB(80, 200, 255) },
}

local function buildVersionLabel(root: ScreenGui)
	local GameConfig = require(Shared.Config.GameConfig)
	UIKit.Label({ Name = "Version", Text = "v" .. GameConfig.Version, Font = Theme.BodyFont, Color = C.SubText, AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -4), Size = UDim2.fromOffset(260, 18), AlignX = Enum.TextXAlignment.Left, Parent = root, MaxTextSize = 14 })
end

local function build(root: ScreenGui)
	-- Everything on the left lives in one column that is scaled as a unit (anchored top-left).
	container = new("Frame", { Name = "HUD", BackgroundTransparency = 1, Size = UDim2.fromOffset(320, 540), Parent = root })
	UIKit.AutoScale(container)

	-- Level + XP + coins panel
	local panel = new("Frame", { Name = "LevelPanel", BackgroundColor3 = C.Panel, BackgroundTransparency = 0.15, Size = UDim2.fromOffset(300, 92), Position = UDim2.fromOffset(10, 10), Parent = container })
	UIKit.Corner(16).Parent = panel
	UIKit.Stroke(3).Parent = panel

	local badge = new("Frame", { BackgroundColor3 = C.Xp, Size = UDim2.fromOffset(72, 72), Position = UDim2.fromOffset(10, 10), Parent = panel })
	UIKit.Corner(36).Parent = badge
	UIKit.Stroke(3).Parent = badge
	UIKit.Gradient(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)).Parent = badge
	UIKit.Label({ Text = "LEVEL", Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 10), Parent = badge })
	levelLabel = UIKit.Label({ Text = "1", Size = UDim2.new(1, -8, 0, 36), Position = UDim2.fromOffset(4, 26), Parent = badge, StrokeThickness = 2.5 })

	local _, xpSetter = UIKit.ProgressBar({ Size = UDim2.fromOffset(196, 24), Position = UDim2.fromOffset(94, 14), Color = C.Xp, Parent = panel })
	setXp = xpSetter

	local coinPill = new("Frame", { BackgroundColor3 = C.Background, Size = UDim2.fromOffset(196, 36), Position = UDim2.fromOffset(94, 46), Parent = panel })
	UIKit.Corner(18).Parent = coinPill
	UIKit.Stroke(2, C.Coins).Parent = coinPill
	UIKit.Label({ Text = "🪙", Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(6, 3), Parent = coinPill, Stroke = false })
	coinsLabel = UIKit.Label({ Text = "0", Color = C.Coins, Size = UDim2.new(1, -46, 1, -6), Position = UDim2.fromOffset(40, 3), AlignX = Enum.TextXAlignment.Left, Parent = coinPill, StrokeThickness = 2 })

	-- Quick stats card
	infoCard = new("Frame", { Name = "Info", BackgroundColor3 = C.Panel, BackgroundTransparency = 0.3, Size = UDim2.fromOffset(300, 98), Position = UDim2.fromOffset(10, 108), Parent = container })
	UIKit.Corner(14).Parent = infoCard
	UIKit.Padding(6).Parent = infoCard
	UIKit.List(2, false, Enum.HorizontalAlignment.Left).Parent = infoCard
	for i, key in { "Speed", "Katana", "Belt", "Trail" } do
		infoLabels[key] = UIKit.Label({ Text = "", Size = UDim2.new(1, 0, 0, 20), AlignX = Enum.TextXAlignment.Left, Font = Theme.BodyFont, LayoutOrder = i, Parent = infoCard, MaxTextSize = 18 })
	end

	-- Menu buttons (4 columns x 4 rows)
	menu = new("Frame", { Name = "Menu", BackgroundTransparency = 1, Size = UDim2.fromOffset(304, 304), Position = UDim2.fromOffset(10, 214), Parent = container })
	new("UIGridLayout", { CellSize = UDim2.fromOffset(70, 70), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = menu })
	for i, entry in MENU do
		local button = UIKit.Button({ Name = entry.Window, Text = "", Color = entry.Color, LayoutOrder = i, Radius = 16, Parent = menu,
			OnClick = function()
				UIKit.OpenWindow(entry.Window)
			end })
		UIKit.Label({ Text = entry.Emoji, Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 6), Parent = button, ZIndex = 3, Stroke = false })
		UIKit.Label({ Text = entry.Label, Size = UDim2.new(1, -6, 0, 18), Position = UDim2.new(0, 3, 1, -24), Parent = button, ZIndex = 3, MaxTextSize = 16 })
		local badge = UIKit.Label({ Text = "!", Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -18, 0, -8), Parent = button, ZIndex = 5 })
		badge.BackgroundTransparency = 0
		badge.BackgroundColor3 = C.Red
		UIKit.Corner(13).Parent = badge
		badge.Visible = false
		badges[entry.Window] = badge
		if entry.Window == "Eggs" then
			eggBadge = UIKit.Label({ Text = "!", Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -18, 0, -8), Parent = button, ZIndex = 5 })
			eggBadge.BackgroundTransparency = 0
			eggBadge.BackgroundColor3 = C.Red
			UIKit.Corner(13).Parent = eggBadge
			eggBadge.Visible = false
		end
	end
end

local function refresh(profile: any)
	local derived = State.Derived
	if not derived then
		return
	end
	levelLabel.Text = tostring(profile.Level)
	local needed = Formulas.XpForLevel(profile.Level)
	setXp(profile.Xp / needed, string.format("XP %s / %s", Format.Short(profile.Xp), Format.Short(needed)))

	coinTarget = profile.Coins
	UIKit.Tween(coinValue, 0.4, { Value = coinTarget })

	local trail = Trails.Get(profile.EquippedTrail)
	infoLabels.Speed.Text = string.format("⚡ Speed: %.1f  (%s)", derived.WalkSpeed, Format.Multiplier(derived.SpeedMultiplier))
	infoLabels.Katana.Text = "⚔️ " .. Katanas.Get(profile.EquippedKatana).DisplayName .. "  " .. Format.Multiplier(derived.CoinMultiplier) .. " coins"
	infoLabels.Belt.Text = "🥋 " .. Belts.Get(profile.EquippedBelt).DisplayName .. "  •  Training Lv " .. profile.TrainingLevel .. ((profile.Rebirths or 0) > 0 and ("  •  🔁 " .. profile.Rebirths) or "")
	infoLabels.Trail.Text = "✨ " .. (trail and trail.DisplayName or "No trail") .. "  •  🐾 " .. #profile.EquippedCreatures .. "/" .. derived.PetSlots
end

local function updateEggBadge()
	local profile = State.Profile
	if not profile or not eggBadge then
		return
	end
	local now = workspace:GetServerTimeNow()
	local ready = 0
	for _, egg in profile.Eggs do
		if now >= egg.HatchAt then
			ready += 1
		end
	end
	eggBadge.Visible = ready > 0
	eggBadge.Text = tostring(ready)
end

-- Shows a red counter on a menu button (0 hides it).
function HUD.SetBadge(windowName: string, count: number)
	local badge = badges[windowName]
	if badge then
		badge.Visible = count > 0
		badge.Text = tostring(count)
	end
end

function HUD.SetSlicingMode(active: boolean)
	menu.Visible = not active
	infoCard.Visible = not active
end

function HUD.SetMenuVisible(visible: boolean)
	menu.Visible = visible
end

function HUD.Init()
	build(UIKit.Root :: ScreenGui)
	buildVersionLabel(UIKit.Root :: ScreenGui)
	coinValue = Instance.new("NumberValue")
	coinValue.Changed:Connect(function(value)
		local rounded = math.floor(value + 0.5)
		if rounded ~= displayedCoins then
			displayedCoins = rounded
			coinsLabel.Text = Format.Commas(rounded)
		end
	end)
	State.Changed:Connect(function(profile)
		refresh(profile)
		updateEggBadge()
	end)
	if State.Profile then
		refresh(State.Profile)
	end
	Net.Event("LevelUp").OnClientEvent:Connect(function(level: number, coins: number)
		Effects.Banner("⭐ LEVEL " .. level .. "! ⭐", C.Coins, 1.8, 0.25)
		Effects.Play("LevelUp")
		UIKit.Toast("Level up bonus: +" .. Format.Short(coins) .. " coins!", "success")
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			updateEggBadge()
		end
	end)
end

return HUD
