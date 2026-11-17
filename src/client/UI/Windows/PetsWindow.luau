--!nonstrict
-- Creature inventory: view, equip / unequip, equip best, compare bonuses, release.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Formulas = require(Shared.Util.Formulas)
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent
local UIKit = require(UI.UIKit)
local Theme = require(UI.Theme)
local Viewport = require(UI.Viewport)
local State = require(UI.Parent.Controllers.State)

local PetsWindow = {}
local C = Theme.Colors
local new = UIKit.new

local grid: ScrollingFrame
local headerLabel: TextLabel
local totalsLabel: TextLabel
local detail: Frame
local detailViewport: ViewportFrame
local detailName: TextLabel
local detailRarity: TextLabel
local detailBonus: TextLabel
local detailCompare: TextLabel
local equipButton: TextButton
local releaseButton: TextButton
local emptyLabel: TextLabel
local selectedUid: string? = nil
local shownModelFor: string? = nil

local function bonusLines(bonus: { Coins: number, Xp: number, Speed: number, Training: number }): string
	local parts = {}
	if bonus.Coins > 0 then
		table.insert(parts, "🪙 " .. Format.Percent(bonus.Coins) .. " coins")
	end
	if bonus.Xp > 0 then
		table.insert(parts, "⭐ " .. Format.Percent(bonus.Xp) .. " XP")
	end
	if bonus.Speed > 0 then
		table.insert(parts, "⚡ " .. Format.Percent(bonus.Speed) .. " speed")
	end
	if bonus.Training > 0 then
		table.insert(parts, "🥋 " .. Format.Percent(bonus.Training) .. " training")
	end
	return #parts > 0 and table.concat(parts, "\n") or "No bonus"
end

local function sortedCreatures(profile: any): { { uid: string, id: string, power: number, equipped: boolean } }
	local list = {}
	for uid, entry in profile.Creatures do
		table.insert(list, { uid = uid, id = entry.Id, power = Creatures.GetPower(entry.Id), equipped = table.find(profile.EquippedCreatures, uid) ~= nil })
	end
	table.sort(list, function(a, b)
		if a.equipped ~= b.equipped then
			return a.equipped
		end
		if a.power ~= b.power then
			return a.power > b.power
		end
		return a.uid < b.uid
	end)
	return list
end

local function refreshDetail()
	local profile = State.Profile
	local entry = profile and selectedUid and profile.Creatures[selectedUid]
	if not entry then
		detail.Visible = false
		shownModelFor = nil
		return
	end
	detail.Visible = true
	local def = Creatures.Get(entry.Id) :: Creatures.CreatureDef
	local rarity = Rarities.Get(def.Rarity)
	if shownModelFor ~= selectedUid then
		shownModelFor = selectedUid
		Viewport.SetModel(detailViewport, Viewport.CreatureModel(def.Id), nil, 1.2)
	end
	detailName.Text = def.Emoji .. " " .. def.DisplayName
	detailRarity.Text = rarity.Name:upper()
	detailRarity.TextColor3 = rarity.Order == 10 and C.Text or rarity.Color
	detailBonus.Text = bonusLines(Creatures.GetBonus(def.Id))

	local equipped = table.find(profile.EquippedCreatures, selectedUid) ~= nil
	local slots = Formulas.PetSlots(profile.Level)
	if equipped then
		UIKit.SetButton(equipButton, "UNEQUIP", C.Orange)
		detailCompare.Text = "Equipped ✅"
	else
		UIKit.SetButton(equipButton, "EQUIP", C.Green)
		if #profile.EquippedCreatures >= slots then
			local weakest, weakestPower = nil, math.huge
			for _, uid in profile.EquippedCreatures do
				local e = profile.Creatures[uid]
				if e then
					local p = Creatures.GetPower(e.Id)
					if p < weakestPower then
						weakest, weakestPower = e, p
					end
				end
			end
			local diff = Creatures.GetPower(def.Id) - weakestPower
			if weakest then
				local weakDef = Creatures.Get(weakest.Id)
				detailCompare.Text = (diff > 0 and "▲ Stronger" or diff < 0 and "▼ Weaker" or "= Same") .. " than your weakest (" .. (weakDef and weakDef.DisplayName or "?") .. ")"
				detailCompare.TextColor3 = diff > 0 and C.Green or diff < 0 and C.Red or C.SubText
			end
		else
			detailCompare.Text = "Free slot available!"
			detailCompare.TextColor3 = C.Green
		end
	end
	UIKit.SetButton(releaseButton, "Release (🪙 " .. Format.Short(GameConfig.ReleaseCreatureRefund[rarity.Order] or 5) .. ")", C.Red)
end

local function refresh()
	local profile = State.Profile
	if not profile then
		return
	end
	local list = sortedCreatures(profile)
	local slots = Formulas.PetSlots(profile.Level)
	headerLabel.Text = string.format("🐾 Equipped %d/%d   •   Inventory %d/%d", #profile.EquippedCreatures, slots, #list, GameConfig.MaxCreatureInventory)
	local totals = Formulas.CreatureBonus(profile)
	totalsLabel.Text = string.format("Total: 🪙 %s  ⭐ %s  ⚡ %s  🥋 %s", Format.Percent(totals.Coins), Format.Percent(totals.Xp), Format.Percent(totals.Speed), Format.Percent(totals.Training))

	UIKit.ClearChildren(grid)
	emptyLabel.Visible = #list == 0
	if selectedUid and not profile.Creatures[selectedUid] then
		selectedUid = nil
	end
	if not selectedUid and #list > 0 then
		selectedUid = list[1].uid
	end
	for i, item in list do
		local def = Creatures.Get(item.id) :: Creatures.CreatureDef
		local rarity = Rarities.Get(def.Rarity)
		local card = new("TextButton", { Name = item.uid, Text = "", AutoButtonColor = true, BackgroundColor3 = rarity.Color, LayoutOrder = i, ZIndex = 7, Parent = grid })
		UIKit.Corner(12).Parent = card
		UIKit.Stroke(item.uid == selectedUid and 4 or 2, item.uid == selectedUid and Color3.new(1, 1, 1) or C.Stroke).Parent = card
		UIKit.Gradient(rarity.Color, rarity.Color2, 90).Parent = card
		UIKit.Label({ Text = def.Emoji, Size = UDim2.new(1, 0, 0, 46), Position = UDim2.fromOffset(0, 6), Parent = card, ZIndex = 8, Stroke = false })
		UIKit.Label({ Text = def.DisplayName, Size = UDim2.new(1, -8, 0, 30), Position = UDim2.fromOffset(4, 54), Parent = card, ZIndex = 8, MaxTextSize = 14 })
		UIKit.Label({ Text = rarity.Name, Size = UDim2.new(1, -8, 0, 16), Position = UDim2.fromOffset(4, 86), Parent = card, ZIndex = 8, MaxTextSize = 13, Font = Theme.BodyFont })
		if item.equipped then
			UIKit.Label({ Text = "✅", Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -26, 0, 2), Parent = card, ZIndex = 9, Stroke = false })
		end
		card.Activated:Connect(function()
			selectedUid = item.uid
			refresh()
		end)
	end
	refreshDetail()
end

function PetsWindow.Init()
	local window = UIKit.CreateWindow("Pets", "🐾 MY CREATURES", C.Pink)
	local content = window.Content

	headerLabel = UIKit.Label({ Text = "", Size = UDim2.new(0, 420, 0, 24), Position = UDim2.fromOffset(0, 0), AlignX = Enum.TextXAlignment.Left, Parent = content, ZIndex = 7, MaxTextSize = 20 })
	totalsLabel = UIKit.Label({ Text = "", Font = Theme.BodyFont, Color = C.SubText, Size = UDim2.new(0, 420, 0, 18), Position = UDim2.fromOffset(0, 26), AlignX = Enum.TextXAlignment.Left, Parent = content, ZIndex = 7, MaxTextSize = 15 })
	UIKit.Button({ Text = "⭐ Equip Best", Color = C.Purple, Size = UDim2.fromOffset(268, 42), Position = UDim2.new(1, -268, 0, 0), Parent = content, ZIndex = 7, MaxTextSize = 20,
		OnClick = function()
			State.Action("EquipBest")
		end })

	local gridHolder = new("Frame", { BackgroundColor3 = C.Background, BackgroundTransparency = 0.3, Size = UDim2.new(1, -280, 1, -52), Position = UDim2.fromOffset(0, 50), ZIndex = 6, Parent = content })
	UIKit.Corner(12).Parent = gridHolder
	grid = UIKit.Grid(gridHolder, Vector2.new(96, 106), 8)
	emptyLabel = UIKit.Label({ Text = "No creatures yet!\nSlice 🥚 eggs in the arenas, then hatch them.", Font = Theme.BodyFont, Color = C.SubText, Size = UDim2.new(1, -40, 0, 80), Position = UDim2.fromOffset(20, 110), Parent = gridHolder, ZIndex = 8, MaxTextSize = 20 })

	detail = new("Frame", { Name = "Detail", BackgroundColor3 = C.Card, Size = UDim2.new(0, 268, 1, -52), Position = UDim2.new(1, -268, 0, 50), ZIndex = 6, Parent = content })
	UIKit.Corner(14).Parent = detail
	UIKit.Stroke(2).Parent = detail
	local vpHolder = new("Frame", { BackgroundColor3 = C.Background, Size = UDim2.new(1, -16, 0, 110), Position = UDim2.fromOffset(8, 8), ZIndex = 7, Parent = detail })
	UIKit.Corner(10).Parent = vpHolder
	detailViewport = Viewport.Create({ Parent = vpHolder, ZIndex = 8 })
	detailName = UIKit.Label({ Text = "", Size = UDim2.new(1, -12, 0, 26), Position = UDim2.fromOffset(6, 120), Parent = detail, ZIndex = 7, MaxTextSize = 20 })
	detailRarity = UIKit.Label({ Text = "", Size = UDim2.new(1, -12, 0, 20), Position = UDim2.fromOffset(6, 146), Parent = detail, ZIndex = 7, MaxTextSize = 18 })
	detailBonus = UIKit.Label({ Text = "", Font = Theme.BodyFont, Size = UDim2.new(1, -16, 0, 60), Position = UDim2.fromOffset(8, 168), Parent = detail, ZIndex = 7, MaxTextSize = 15 })
	detailCompare = UIKit.Label({ Text = "", Font = Theme.BodyFont, Color = C.SubText, Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 228), Parent = detail, ZIndex = 7, MaxTextSize = 13 })
	equipButton = UIKit.Button({ Text = "EQUIP", Color = C.Green, Size = UDim2.new(1, -16, 0, 40), Position = UDim2.new(0, 8, 1, -86), Parent = detail, ZIndex = 7,
		OnClick = function()
			local profile = State.Profile
			local uid = selectedUid
			if not profile or not uid then
				return
			end
			if table.find(profile.EquippedCreatures, uid) then
				State.Action("UnequipCreature", true, uid)
			else
				State.Action("EquipCreature", true, uid)
			end
		end })
	releaseButton = UIKit.Button({ Text = "Release", Color = C.Red, Size = UDim2.new(1, -16, 0, 34), Position = UDim2.new(0, 8, 1, -42), Parent = detail, ZIndex = 7, MaxTextSize = 16,
		OnClick = function()
			local profile = State.Profile
			local uid = selectedUid
			local entry = profile and uid and profile.Creatures[uid]
			if not entry then
				return
			end
			local def = Creatures.Get(entry.Id)
			UIKit.Confirm("Release " .. (def and def.DisplayName or "creature") .. "?", "It will be gone forever (you keep it in the Index).", "Release", function()
				State.Action("ReleaseCreature", false, uid)
			end)
		end })

	window.OnOpen = refresh
	State.Changed:Connect(function()
		if window.IsOpen then
			refresh()
		end
	end)
end

return PetsWindow
