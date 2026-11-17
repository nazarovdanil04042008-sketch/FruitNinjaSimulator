--!nonstrict
-- Katana shop, Belt shop and Trail shop (one generic card-grid implementation, three windows).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Katanas = require(Shared.Config.Katanas)
local Belts = require(Shared.Config.Belts)
local Trails = require(Shared.Config.Trails)
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent
local UIKit = require(UI.UIKit)
local Theme = require(UI.Theme)
local Viewport = require(UI.Viewport)
local State = require(UI.Parent.Controllers.State)

local ShopWindows = {}
local C = Theme.Colors
local new = UIKit.new

type ShopItem = {
	Id: string,
	Name: string,
	Price: number,
	Order: number,
	Stats: string,
	Color: Color3,
	Description: string?,
	RequirementMet: (profile: any) -> boolean,
	RequirementText: string,
	Owned: (profile: any) -> boolean,
	Equipped: (profile: any) -> boolean,
	BuildPreview: (parent: Frame) -> (),
	BuyAction: string,
	EquipAction: string,
}

local function trailGradient(colors: { Color3 }): UIGradient
	local keypoints = {}
	for i, color in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / math.max(#colors - 1, 1), color))
	end
	return new("UIGradient", { Color = ColorSequence.new(keypoints) })
end

local function buildShop(windowName: string, title: string, color: Color3, items: { ShopItem })
	local window = UIKit.CreateWindow(windowName, title, color)
	local grid = UIKit.Grid(window.Content, Vector2.new(214, 214), 10)
	local refreshers: { () -> () } = {}

	for _, item in items do
		local card = new("Frame", { Name = item.Id, BackgroundColor3 = C.Card, LayoutOrder = item.Order, ZIndex = 6, Parent = grid })
		UIKit.Corner(14).Parent = card
		local stroke = UIKit.Stroke(3, item.Color)
		stroke.Parent = card

		local preview = new("Frame", { Name = "Preview", BackgroundColor3 = C.Background, Size = UDim2.new(1, -16, 0, 84), Position = UDim2.fromOffset(8, 8), ZIndex = 6, Parent = card })
		UIKit.Corner(10).Parent = preview
		item.BuildPreview(preview)

		UIKit.Label({ Text = item.Name, Color = item.Color, Size = UDim2.new(1, -12, 0, 26), Position = UDim2.fromOffset(6, 96), Parent = card, ZIndex = 7, StrokeThickness = 2, MaxTextSize = 22 })
		UIKit.Label({ Text = item.Stats, Font = Theme.BodyFont, Size = UDim2.new(1, -12, 0, 34), Position = UDim2.fromOffset(6, 122), Parent = card, ZIndex = 7, MaxTextSize = 15 })

		local button: TextButton
		button = UIKit.Button({ Text = "", Size = UDim2.new(1, -20, 0, 44), Position = UDim2.new(0, 10, 1, -52), Parent = card, ZIndex = 7,
			OnClick = function()
				local profile = State.Profile
				if not profile then
					return
				end
				if item.Equipped(profile) then
					return
				elseif item.Owned(profile) then
					State.Action(item.EquipAction, false, item.Id)
				elseif not item.RequirementMet(profile) then
					UIKit.Toast("🔒 Requires " .. item.RequirementText .. "!", "error")
				elseif profile.Coins < item.Price then
					UIKit.Toast("You need " .. Format.Short(item.Price - profile.Coins) .. " more coins!", "error")
				else
					UIKit.Confirm("Buy " .. item.Name .. "?", "Price: 🪙 " .. Format.Commas(item.Price) .. "\n" .. item.Stats, "Buy!", function()
						State.Purchase(item.BuyAction, item.Id)
					end)
				end
			end })

		table.insert(refreshers, function()
			local profile = State.Profile
			if not profile then
				return
			end
			if item.Equipped(profile) then
				UIKit.SetButton(button, "✅ EQUIPPED", C.Gray)
				stroke.Thickness = 5
			elseif item.Owned(profile) then
				UIKit.SetButton(button, "EQUIP", C.Blue)
				stroke.Thickness = 3
			elseif not item.RequirementMet(profile) then
				UIKit.SetButton(button, "🔒 " .. item.RequirementText, C.Locked)
				stroke.Thickness = 3
			else
				UIKit.SetButton(button, item.Price == 0 and "FREE" or ("🪙 " .. Format.Short(item.Price)), profile.Coins >= item.Price and C.Green or C.Orange)
				stroke.Thickness = 3
			end
		end)
	end

	local function refresh()
		for _, fn in refreshers do
			fn()
		end
	end
	window.OnOpen = refresh
	State.Changed:Connect(function()
		if window.IsOpen then
			refresh()
		end
	end)
end

function ShopWindows.Init()
	------------------------------------------------------------------ Katanas
	local katanaItems: { ShopItem } = {}
	for _, def in Katanas.List do
		table.insert(katanaItems, {
			Id = def.Id,
			Name = def.DisplayName,
			Price = def.Price,
			Order = def.Order,
			Color = def.SwipeColor,
			Stats = string.format("🪙 %s coins  •  ⚔️ %s slice speed", Format.Multiplier(def.CoinMultiplier), Format.Multiplier(def.SliceRate)),
			RequirementMet = function(profile)
				return profile.Level >= def.RequiredLevel
			end,
			RequirementText = "Level " .. def.RequiredLevel,
			Owned = function(profile)
				return profile.OwnedKatanas[def.Id] == true
			end,
			Equipped = function(profile)
				return profile.EquippedKatana == def.Id
			end,
			BuildPreview = function(parent)
				local vpf = Viewport.Create({ Parent = parent, ZIndex = 7 })
				Viewport.SetModel(vpf, Viewport.KatanaModel(def.Id), CFrame.Angles(0, math.rad(90), math.rad(-60)), nil, 0.6)
			end,
			BuyAction = "BuyKatana",
			EquipAction = "EquipKatana",
		})
	end
	buildShop("Katanas", "⚔️ KATANA SHOP", C.Orange, katanaItems)

	------------------------------------------------------------------ Belts
	local beltItems: { ShopItem } = {}
	for _, def in Belts.List do
		table.insert(beltItems, {
			Id = def.Id,
			Name = def.DisplayName,
			Price = def.Price,
			Order = def.Order,
			Color = def.Color == Color3.fromRGB(25, 25, 25) and C.SubText or def.Color,
			Stats = string.format("⚡ %s speed  •  🥋 %s training", Format.Multiplier(def.SpeedMultiplier), Format.Multiplier(def.TrainingMultiplier)),
			RequirementMet = function(profile)
				return profile.TrainingLevel >= def.RequiredTrainingLevel
			end,
			RequirementText = "Training Lv " .. def.RequiredTrainingLevel,
			Owned = function(profile)
				return profile.OwnedBelts[def.Id] == true
			end,
			Equipped = function(profile)
				return profile.EquippedBelt == def.Id
			end,
			BuildPreview = function(parent)
				local band = new("Frame", { BackgroundColor3 = def.Color, Size = UDim2.new(0.86, 0, 0, 22), Position = UDim2.fromScale(0.07, 0.36), ZIndex = 7, Parent = parent })
				UIKit.Corner(6).Parent = band
				UIKit.Stroke(2).Parent = band
				local knot = new("Frame", { BackgroundColor3 = def.Color, Size = UDim2.fromOffset(26, 30), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.49), ZIndex = 8, Parent = parent })
				UIKit.Corner(6).Parent = knot
				UIKit.Stroke(2).Parent = knot
				for side = -1, 1, 2 do
					local tail = new("Frame", { BackgroundColor3 = def.Color, Size = UDim2.fromOffset(10, 30), Position = UDim2.new(0.5, side * 9 - 5, 0.55, 0), Rotation = side * 15, ZIndex = 7, Parent = parent })
					UIKit.Stroke(2).Parent = tail
				end
			end,
			BuyAction = "BuyBelt",
			EquipAction = "EquipBelt",
		})
	end
	buildShop("Belts", "🥋 BELT SHOP", C.Red, beltItems)

	------------------------------------------------------------------ Trails
	local trailItems: { ShopItem } = {
		{
			Id = "",
			Name = "No Trail",
			Price = 0,
			Order = 0,
			Color = C.SubText,
			Stats = "Remove your trail",
			RequirementMet = function()
				return true
			end,
			RequirementText = "",
			Owned = function()
				return true
			end,
			Equipped = function(profile)
				return profile.EquippedTrail == ""
			end,
			BuildPreview = function(parent)
				UIKit.Label({ Text = "🚫", Size = UDim2.fromScale(1, 1), Parent = parent, ZIndex = 7, Stroke = false })
			end,
			BuyAction = "EquipTrail",
			EquipAction = "EquipTrail",
		},
	}
	for _, def in Trails.List do
		table.insert(trailItems, {
			Id = def.Id,
			Name = def.DisplayName,
			Price = def.Price,
			Order = def.Order,
			Color = def.Colors[#def.Colors == 1 and 1 or 2],
			Stats = string.format("⚡ %s speed%s", Format.Multiplier(def.SpeedMultiplier), def.Particles and "  •  ✨ particles" or ""),
			RequirementMet = function(profile)
				return profile.Level >= def.RequiredLevel
			end,
			RequirementText = "Level " .. def.RequiredLevel,
			Owned = function(profile)
				return profile.OwnedTrails[def.Id] == true
			end,
			Equipped = function(profile)
				return profile.EquippedTrail == def.Id
			end,
			BuildPreview = function(parent)
				local bar = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(0.9, 0, 0, 30), Position = UDim2.fromScale(0.05, 0.32), ZIndex = 7, Parent = parent })
				UIKit.Corner(15).Parent = bar
				trailGradient(def.Colors).Parent = bar
				if def.Particles then
					UIKit.Label({ Text = "✨", Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -34, 0, 4), Parent = parent, ZIndex = 8, Stroke = false })
				end
			end,
			BuyAction = "BuyTrail",
			EquipAction = "EquipTrail",
		})
	end
	buildShop("Trails", "✨ TRAIL SHOP", C.Purple, trailItems)
end

return ShopWindows
