--!nonstrict
-- Creature collection index: every creature, discovered or not ("???"), with details for discovered ones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent
local UIKit = require(UI.UIKit)
local Theme = require(UI.Theme)
local Viewport = require(UI.Viewport)
local State = require(UI.Parent.Controllers.State)

local IndexWindow = {}
local C = Theme.Colors
local new = UIKit.new

local cards: { [string]: { Frame: TextButton, Emoji: TextLabel, Name: TextLabel } } = {}
local progressLabel: TextLabel
local setProgress: (number, string?) -> ()
local detailViewport: ViewportFrame
local detailName: TextLabel
local detailInfo: TextLabel
local selected: string? = nil

local function bonusText(id: string): string
	local b = Creatures.GetBonus(id)
	local parts = {}
	if b.Coins > 0 then table.insert(parts, "🪙 " .. Format.Percent(b.Coins)) end
	if b.Xp > 0 then table.insert(parts, "⭐ " .. Format.Percent(b.Xp)) end
	if b.Speed > 0 then table.insert(parts, "⚡ " .. Format.Percent(b.Speed)) end
	if b.Training > 0 then table.insert(parts, "🥋 " .. Format.Percent(b.Training)) end
	return table.concat(parts, "  ")
end

local function showDetail(id: string?)
	local profile = State.Profile
	selected = id
	if not id or not profile then
		return
	end
	local def = Creatures.Get(id) :: Creatures.CreatureDef
	local rarity = Rarities.Get(def.Rarity)
	if profile.Discovered[id] then
		Viewport.SetModel(detailViewport, Viewport.CreatureModel(id), nil, 1.2)
		detailName.Text = def.Emoji .. " " .. def.DisplayName
		detailInfo.Text = rarity.Name:upper() .. "\n\"" .. def.Quote .. "\"\n" .. bonusText(id)
	else
		Viewport.SetModel(detailViewport, nil)
		detailName.Text = "❓ ???"
		detailInfo.Text = rarity.Name:upper() .. "\nNot discovered yet!\nHatch eggs to find it."
	end
	detailName.TextColor3 = rarity.Order == 10 and C.Text or rarity.Color
end

local function refresh()
	local profile = State.Profile
	if not profile then
		return
	end
	local found = 0
	for _, def in Creatures.List do
		local card = cards[def.Id]
		local discovered = profile.Discovered[def.Id] == true
		if discovered then
			found += 1
		end
		card.Emoji.Text = discovered and def.Emoji or "❓"
		card.Name.Text = discovered and def.DisplayName or "???"
		card.Frame.BackgroundTransparency = discovered and 0 or 0.55
	end
	setProgress(found / #Creatures.List, string.format("%d / %d discovered", found, #Creatures.List))
	progressLabel.Text = found == #Creatures.List and "🏆 COLLECTION COMPLETE! 🏆" or "📖 Discover every creature!"
	showDetail(selected or Creatures.List[1].Id)
end

function IndexWindow.Init()
	local window = UIKit.CreateWindow("Index", "📖 CREATURE INDEX", C.Blue)
	local content = window.Content

	progressLabel = UIKit.Label({ Text = "", Size = UDim2.new(1, -280, 0, 22), AlignX = Enum.TextXAlignment.Left, Parent = content, ZIndex = 7, MaxTextSize = 20 })
	local _, setter = UIKit.ProgressBar({ Size = UDim2.new(1, -280, 0, 22), Position = UDim2.fromOffset(0, 26), Color = C.Blue, Parent = content })
	setProgress = setter

	local holder = new("Frame", { BackgroundColor3 = C.Background, BackgroundTransparency = 0.3, Size = UDim2.new(1, -280, 1, -56), Position = UDim2.fromOffset(0, 56), ZIndex = 6, Parent = content })
	UIKit.Corner(12).Parent = holder
	local grid = UIKit.Grid(holder, Vector2.new(92, 96), 8)
	for i, def in Creatures.List do
		local rarity = Rarities.Get(def.Rarity)
		local card = new("TextButton", { Name = def.Id, Text = "", AutoButtonColor = true, BackgroundColor3 = rarity.Color, LayoutOrder = i, ZIndex = 7, Parent = grid })
		UIKit.Corner(12).Parent = card
		UIKit.Stroke(2).Parent = card
		UIKit.Gradient(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)).Parent = card
		local emoji = UIKit.Label({ Text = "❓", Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 6), Parent = card, ZIndex = 8, Stroke = false })
		local name = UIKit.Label({ Text = "???", Size = UDim2.new(1, -6, 0, 26), Position = UDim2.fromOffset(3, 48), Parent = card, ZIndex = 8, MaxTextSize = 13 })
		UIKit.Label({ Text = rarity.Name, Font = Theme.BodyFont, Size = UDim2.new(1, -6, 0, 14), Position = UDim2.fromOffset(3, 76), Parent = card, ZIndex = 8, MaxTextSize = 12 })
		cards[def.Id] = { Frame = card, Emoji = emoji, Name = name }
		card.Activated:Connect(function()
			showDetail(def.Id)
		end)
	end

	local detail = new("Frame", { BackgroundColor3 = C.Card, Size = UDim2.new(0, 268, 1, 0), Position = UDim2.new(1, -268, 0, 0), ZIndex = 6, Parent = content })
	UIKit.Corner(14).Parent = detail
	local vpHolder = new("Frame", { BackgroundColor3 = C.Background, Size = UDim2.new(1, -16, 0, 150), Position = UDim2.fromOffset(8, 8), ZIndex = 7, Parent = detail })
	UIKit.Corner(10).Parent = vpHolder
	detailViewport = Viewport.Create({ Parent = vpHolder, ZIndex = 8 })
	detailName = UIKit.Label({ Text = "", Size = UDim2.new(1, -12, 0, 30), Position = UDim2.fromOffset(6, 164), Parent = detail, ZIndex = 7, MaxTextSize = 22 })
	detailInfo = UIKit.Label({ Text = "", Font = Theme.BodyFont, Size = UDim2.new(1, -16, 1, -204), Position = UDim2.fromOffset(8, 198), AlignY = Enum.TextYAlignment.Top, Parent = detail, ZIndex = 7, MaxTextSize = 17 })

	window.OnOpen = refresh
	State.Changed:Connect(function()
		if window.IsOpen then
			refresh()
		end
	end)
end

return IndexWindow
