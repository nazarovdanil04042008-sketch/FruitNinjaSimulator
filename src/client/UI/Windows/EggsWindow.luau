--!nonstrict
-- Pending eggs with live countdowns, hatch / skip buttons, and an odds tab for every egg type.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Eggs = require(Shared.Config.Eggs)
local Fruits = require(Shared.Config.Fruits)
local Arenas = require(Shared.Config.Arenas)
local Rarities = require(Shared.Config.Rarities)
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent
local UIKit = require(UI.UIKit)
local Theme = require(UI.Theme)
local State = require(UI.Parent.Controllers.State)

local EggsWindow = {}
local C = Theme.Colors
local new = UIKit.new

local window: UIKit.Window
local listFrame: ScrollingFrame
local oddsFrame: ScrollingFrame
local countLabel: TextLabel
local emptyLabel: TextLabel
local rows: { [string]: { Bar: (number, string?) -> (), Button: TextButton, HatchAt: number, Total: number } } = {}
local currentTab = "Eggs"

local function eggColors(eggId: string): (Color3, Color3)
	local def = Eggs.Get(eggId)
	local fruit = def and Fruits.Get(def.FruitId)
	return fruit and fruit.Color or Color3.new(1, 1, 1), fruit and fruit.Color2 or Color3.new(1, 1, 1)
end

local function updateTimers()
	local now = workspace:GetServerTimeNow()
	for _, row in rows do
		local remaining = row.HatchAt - now
		if remaining <= 0 then
			row.Bar(1, "READY!")
			UIKit.SetButton(row.Button, "🐣 HATCH!", C.Green)
		else
			row.Bar(1 - remaining / row.Total, "⏳ " .. Format.Time(remaining))
			UIKit.SetButton(row.Button, "⏩ 🪙 " .. Format.Short(math.ceil(remaining * GameConfig.SkipHatchCostPerSecond)), C.Orange)
		end
	end
end

local function rebuildList()
	local profile = State.Profile
	if not profile then
		return
	end
	UIKit.ClearChildren(listFrame, { "UIListLayout" })
	table.clear(rows)
	countLabel.Text = string.format("🥚 Eggs %d/%d", #profile.Eggs, GameConfig.MaxPendingEggs)
	emptyLabel.Visible = #profile.Eggs == 0
	for i, egg in profile.Eggs do
		local def = Eggs.Get(egg.EggId)
		if not def then
			continue
		end
		local color, color2 = eggColors(egg.EggId)
		local row = new("Frame", { BackgroundColor3 = C.Card, Size = UDim2.new(1, -12, 0, 62), LayoutOrder = i, ZIndex = 7, Parent = listFrame })
		UIKit.Corner(12).Parent = row
		local icon = new("Frame", { BackgroundColor3 = color, Size = UDim2.fromOffset(44, 52), Position = UDim2.fromOffset(8, 5), ZIndex = 8, Parent = row })
		UIKit.Corner(22).Parent = icon
		UIKit.Stroke(2).Parent = icon
		UIKit.Gradient(color, color2, 45).Parent = icon
		UIKit.Label({ Text = def.DisplayName, Size = UDim2.new(0, 200, 0, 26), Position = UDim2.fromOffset(62, 4), AlignX = Enum.TextXAlignment.Left, Parent = row, ZIndex = 8, MaxTextSize = 22 })
		local _, setBar = UIKit.ProgressBar({ Size = UDim2.new(1, -280, 0, 22), Position = UDim2.fromOffset(62, 34), Color = C.Coins, Parent = row })
		local uid = egg.Uid
		local button = UIKit.Button({ Text = "", Size = UDim2.fromOffset(190, 48), Position = UDim2.new(1, -200, 0, 7), Parent = row, ZIndex = 8, MaxTextSize = 20,
			OnClick = function()
				local now = workspace:GetServerTimeNow()
				if now >= egg.HatchAt then
					State.Action("HatchEgg", true, uid)
				else
					local cost = math.ceil((egg.HatchAt - now) * GameConfig.SkipHatchCostPerSecond)
					UIKit.Confirm("Hatch instantly?", "Skip the wait for 🪙 " .. Format.Commas(cost) .. " coins.", "Skip!", function()
						State.Action("SkipEgg", true, uid)
					end)
				end
			end })
		rows[uid] = { Bar = setBar, Button = button, HatchAt = egg.HatchAt, Total = def.HatchTime }
	end
	updateTimers()
end

local function buildOdds()
	for i, def in Eggs.List do
		local color = eggColors(def.Id)
		local foundIn = {}
		for _, arena in Arenas.List do
			if arena.EggWeights[def.FruitId] then
				table.insert(foundIn, arena.DisplayName)
			end
		end
		local row = new("Frame", { BackgroundColor3 = C.Card, Size = UDim2.new(1, -12, 0, 104), LayoutOrder = i, ZIndex = 7, Parent = oddsFrame })
		UIKit.Corner(12).Parent = row
		UIKit.Stroke(2, color).Parent = row
		UIKit.Label({ Text = "🥚 " .. def.DisplayName .. "  •  hatches in " .. Format.Time(def.HatchTime), Color = color, Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 4), AlignX = Enum.TextXAlignment.Left, Parent = row, ZIndex = 8, MaxTextSize = 20 })
		UIKit.Label({ Text = "Found in: " .. table.concat(foundIn, ", "), Font = Theme.BodyFont, Color = C.SubText, Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 30), AlignX = Enum.TextXAlignment.Left, Parent = row, ZIndex = 8, MaxTextSize = 14, Stroke = false })
		local chips = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 50), Position = UDim2.fromOffset(10, 50), ZIndex = 8, Parent = row })
		new("UIGridLayout", { CellSize = UDim2.fromOffset(104, 22), CellPadding = UDim2.fromOffset(4, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = chips })
		for j, odds in Eggs.GetOdds(def.Id) do
			local rarity = Rarities.Get(odds.Rarity)
			local chip = new("Frame", { BackgroundColor3 = rarity.Color, LayoutOrder = j, ZIndex = 8, Parent = chips })
			UIKit.Corner(8).Parent = chip
			local pct = odds.Chance >= 1 and string.format("%.1f%%", odds.Chance) or odds.Chance >= 0.01 and string.format("%.2f%%", odds.Chance) or string.format("%.4f%%", odds.Chance)
			UIKit.Label({ Text = rarity.Name .. " " .. pct, Size = UDim2.new(1, -6, 1, -4), Position = UDim2.fromOffset(3, 2), Parent = chip, ZIndex = 9, MaxTextSize = 13, Font = Theme.BodyFont })
		end
	end
end

local function setTab(tab: string)
	currentTab = tab
	listFrame.Visible = tab == "Eggs"
	oddsFrame.Visible = tab == "Odds"
	emptyLabel.Visible = tab == "Eggs" and State.Profile ~= nil and #State.Profile.Eggs == 0
end

function EggsWindow.Init()
	window = UIKit.CreateWindow("Eggs", "🥚 MY EGGS", Color3.fromRGB(255, 170, 70))
	local content = window.Content

	countLabel = UIKit.Label({ Text = "", Size = UDim2.fromOffset(180, 40), Position = UDim2.fromOffset(0, 0), AlignX = Enum.TextXAlignment.Left, Parent = content, ZIndex = 7, MaxTextSize = 24 })
	UIKit.Button({ Text = "My Eggs", Color = C.Blue, Size = UDim2.fromOffset(130, 40), Position = UDim2.fromOffset(190, 0), Parent = content, ZIndex = 7, MaxTextSize = 20, OnClick = function() setTab("Eggs") end })
	UIKit.Button({ Text = "📊 Odds", Color = C.Purple, Size = UDim2.fromOffset(130, 40), Position = UDim2.fromOffset(330, 0), Parent = content, ZIndex = 7, MaxTextSize = 20, OnClick = function() setTab("Odds") end })
	UIKit.Button({ Text = "🐣 Hatch All Ready", Color = C.Green, Size = UDim2.fromOffset(220, 40), Position = UDim2.new(1, -220, 0, 0), Parent = content, ZIndex = 7, MaxTextSize = 20,
		OnClick = function()
			State.Action("HatchAllReady", true)
		end })

	local function scroller(): ScrollingFrame
		local s = new("ScrollingFrame", {
			BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, -50), Position = UDim2.fromOffset(0, 50),
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 8, ZIndex = 6, Parent = content,
		})
		UIKit.List(8).Parent = s
		return s
	end
	listFrame = scroller()
	oddsFrame = scroller()
	emptyLabel = UIKit.Label({ Text = "No eggs yet!\nEggs fly through the slicing arenas — slice them to collect them.\nCommon eggs hatch in seconds!", Font = Theme.BodyFont, Color = C.SubText,
		Size = UDim2.new(1, -60, 0, 100), Position = UDim2.fromOffset(30, 120), Parent = content, ZIndex = 8, MaxTextSize = 20 })
	buildOdds()
	setTab("Eggs")

	window.OnOpen = function()
		rebuildList()
		setTab(currentTab)
		while window.IsOpen do
			task.wait(0.5)
			updateTimers()
		end
	end
	State.Changed:Connect(function()
		if window.IsOpen then
			rebuildList()
			setTab(currentTab)
		end
	end)
end

return EggsWindow
