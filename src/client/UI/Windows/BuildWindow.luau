--!nonstrict
-- 🏯 Build menu: buy Japanese buildings, see what you own, start placing / removing, go to your village.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Buildings = require(Shared.Config.Buildings)
local PlotGrid = require(Shared.Util.PlotGrid)
local Formulas = require(Shared.Util.Formulas)
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent
local UIKit = require(UI.UIKit)
local Theme = require(UI.Theme)
local State = require(UI.Parent.Controllers.State)
local BuildController = require(UI.Parent.Controllers.BuildController)

local BuildWindow = {}
local C = Theme.Colors
local new = UIKit.new

local refreshers: { () -> () } = {}
local totalsLabel: TextLabel

local function bonusText(bonus: any): string
	local parts = {}
	if bonus.Coins and bonus.Coins > 0 then table.insert(parts, "🪙 " .. Format.Percent(bonus.Coins)) end
	if bonus.Xp and bonus.Xp > 0 then table.insert(parts, "⭐ " .. Format.Percent(bonus.Xp)) end
	if bonus.Speed and bonus.Speed > 0 then table.insert(parts, "⚡ " .. Format.Percent(bonus.Speed)) end
	if bonus.Training and bonus.Training > 0 then table.insert(parts, "🥋 " .. Format.Percent(bonus.Training)) end
	return table.concat(parts, "  ")
end

local function refresh()
	local profile = State.Profile
	if not profile then
		return
	end
	local total = Formulas.BuildingBonus(profile)
	totalsLabel.Text = string.format("Village bonus: 🪙 %s  ⭐ %s  ⚡ %s  🥋 %s   •   Built %d/%d",
		Format.Percent(total.Coins), Format.Percent(total.Xp), Format.Percent(total.Speed), Format.Percent(total.Training), #profile.Buildings, Buildings.MaxPlacedTotal)
	for _, fn in refreshers do
		fn()
	end
end

function BuildWindow.Init()
	local window = UIKit.CreateWindow("Build", "🏯 NINJA VILLAGE", Color3.fromRGB(220, 70, 60))
	local content = window.Content

	UIKit.Button({ Text = "🏯 Go to my village", Color = Color3.fromRGB(220, 70, 60), Size = UDim2.fromOffset(220, 42), Parent = content, ZIndex = 7, MaxTextSize = 20,
		OnClick = function()
			if State.Action("TeleportToPlot", true) then
				UIKit.CloseWindow()
			end
		end })
	UIKit.Button({ Text = "🧹 Pick up buildings", Color = C.Orange, Size = UDim2.fromOffset(220, 42), Position = UDim2.fromOffset(230, 0), Parent = content, ZIndex = 7, MaxTextSize = 20,
		OnClick = function()
			BuildController.StartRemoving()
		end })
	totalsLabel = UIKit.Label({ Text = "", Font = Theme.BodyFont, Color = C.SubText, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 48), AlignX = Enum.TextXAlignment.Left, Parent = content, ZIndex = 7, MaxTextSize = 15 })

	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -74), Position = UDim2.fromOffset(0, 74), ZIndex = 6, Parent = content })
	local grid = UIKit.Grid(holder, Vector2.new(214, 196), 10)

	for _, def in Buildings.List do
		local card = new("Frame", { Name = def.Id, BackgroundColor3 = C.Card, LayoutOrder = def.Order, ZIndex = 7, Parent = grid })
		UIKit.Corner(14).Parent = card
		UIKit.Stroke(2.5, Color3.fromRGB(220, 70, 60)).Parent = card
		UIKit.Label({ Text = def.Emoji, Size = UDim2.fromOffset(50, 50), Position = UDim2.fromOffset(8, 6), Parent = card, ZIndex = 8, Stroke = false })
		UIKit.Label({ Text = def.DisplayName, Size = UDim2.new(1, -66, 0, 26), Position = UDim2.fromOffset(60, 8), AlignX = Enum.TextXAlignment.Left, Parent = card, ZIndex = 8, MaxTextSize = 20 })
		UIKit.Label({ Text = def.Width .. "x" .. def.Depth .. " tiles", Font = Theme.BodyFont, Color = C.SubText, Size = UDim2.new(1, -66, 0, 16), Position = UDim2.fromOffset(60, 34), AlignX = Enum.TextXAlignment.Left, Parent = card, ZIndex = 8, MaxTextSize = 13, Stroke = false })
		UIKit.Label({ Text = bonusText(def.Bonus), Color = C.Coins, Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 60), Parent = card, ZIndex = 8, MaxTextSize = 17 })
		UIKit.Label({ Text = def.Description, Font = Theme.BodyFont, Color = C.SubText, Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 84), Parent = card, ZIndex = 8, MaxTextSize = 13, Stroke = false })
		local status = UIKit.Label({ Text = "", Font = Theme.BodyFont, Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 118), Parent = card, ZIndex = 8, MaxTextSize = 14 })
		local buy = UIKit.Button({ Text = "", Size = UDim2.new(0.5, -12, 0, 44), Position = UDim2.new(0, 8, 1, -52), Parent = card, ZIndex = 8, MaxTextSize = 18,
			OnClick = function()
				local profile = State.Profile
				if not profile then
					return
				end
				if profile.Level < def.RequiredLevel then
					UIKit.Toast("🔒 Reach level " .. def.RequiredLevel .. " to unlock " .. def.DisplayName .. "!", "error")
				elseif profile.Coins < def.Price then
					UIKit.Toast("You need " .. Format.Short(def.Price - profile.Coins) .. " more coins!", "error")
				else
					UIKit.Confirm("Buy " .. def.DisplayName .. "?", "Price: 🪙 " .. Format.Commas(def.Price) .. "\n" .. bonusText(def.Bonus), "Buy!", function()
						State.Purchase("BuyBuilding", def.Id)
					end)
				end
			end })
		local placeButton = UIKit.Button({ Text = "", Size = UDim2.new(0.5, -12, 0, 44), Position = UDim2.new(0.5, 4, 1, -52), Parent = card, ZIndex = 8, MaxTextSize = 18,
			OnClick = function()
				BuildController.StartPlacing(def.Id)
			end })
		table.insert(refreshers, function()
			local profile = State.Profile
			local inBag = profile.BuildInventory[def.Id] or 0
			local placed = PlotGrid.CountPlaced(profile.Buildings, def.Id)
			status.Text = string.format("Placed %d/%d  •  In bag: %d", placed, def.MaxPlaced, inBag)
			if profile.Level < def.RequiredLevel then
				UIKit.SetButton(buy, "🔒 Lv " .. def.RequiredLevel, C.Locked)
			elseif inBag + placed >= def.MaxPlaced then
				UIKit.SetButton(buy, "MAX", C.Gray)
			else
				UIKit.SetButton(buy, "🪙 " .. Format.Short(def.Price), profile.Coins >= def.Price and C.Green or C.Orange)
			end
			placeButton.Visible = inBag > 0
			UIKit.SetButton(placeButton, "🔨 Place", C.Blue)
		end)
	end

	window.OnOpen = refresh
	State.Changed:Connect(function()
		if window.IsOpen then
			refresh()
		end
	end)
end

return BuildWindow
