--!nonstrict
-- 💎 Store: Robux game passes, developer products and the code box.
-- Purchases are prompted with MarketplaceService; the server (MonetizationService) grants them.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)

local UI = script.Parent.Parent
local UIKit = require(UI.UIKit)
local Theme = require(UI.Theme)
local State = require(UI.Parent.Controllers.State)

local StoreWindow = {}
local C = Theme.Colors
local new = UIKit.new
local player = Players.LocalPlayer

local passButtons: { [string]: TextButton } = {}

local function card(parent: Instance, order: number, def: any, buttonText: string, onClick: () -> ()): TextButton
	local frame = new("Frame", { BackgroundColor3 = C.Card, LayoutOrder = order, ZIndex = 7, Parent = parent })
	UIKit.Corner(14).Parent = frame
	UIKit.Stroke(3, def.Color).Parent = frame
	UIKit.Gradient(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 215)).Parent = frame
	UIKit.Label({ Text = def.Emoji, Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 6), Parent = frame, ZIndex = 8, Stroke = false })
	UIKit.Label({ Text = def.DisplayName, Color = def.Color, Size = UDim2.new(1, -12, 0, 26), Position = UDim2.fromOffset(6, 58), Parent = frame, ZIndex = 8, MaxTextSize = 21, StrokeThickness = 2 })
	UIKit.Label({ Text = def.Description, Font = Theme.BodyFont, Size = UDim2.new(1, -14, 0, 44), Position = UDim2.fromOffset(7, 86), Parent = frame, ZIndex = 8, MaxTextSize = 14 })
	return UIKit.Button({ Text = buttonText, Color = C.Green, Size = UDim2.new(1, -20, 0, 44), Position = UDim2.new(0, 10, 1, -52), Parent = frame, ZIndex = 8, MaxTextSize = 20, OnClick = onClick })
end

local function refresh()
	local profile = State.Profile
	for id, button in passButtons do
		local def = Monetization.GetPass(id)
		if profile and profile.Passes and profile.Passes[id] then
			UIKit.SetButton(button, "✅ Owned", C.Gray)
		elseif def and def.PassId == 0 then
			UIKit.SetButton(button, "Coming soon", C.Locked)
		else
			UIKit.SetButton(button, "💎 R$" .. (def and def.RobuxHint or "?"), C.Green)
		end
	end
end

function StoreWindow.Init()
	local window = UIKit.CreateWindow("Store", "💎 STORE", Color3.fromRGB(80, 200, 255))
	local content = window.Content
	local scroll = new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 8, ZIndex = 6, Parent = content })
	UIKit.List(10).Parent = scroll

	-- Codes
	local codeRow = new("Frame", { BackgroundColor3 = C.Card, Size = UDim2.new(1, -12, 0, 64), LayoutOrder = 1, ZIndex = 7, Parent = scroll })
	UIKit.Corner(12).Parent = codeRow
	UIKit.Label({ Text = "🎟️ Codes", Size = UDim2.fromOffset(130, 40), Position = UDim2.fromOffset(12, 12), Parent = codeRow, ZIndex = 8, MaxTextSize = 24 })
	local box = new("TextBox", { PlaceholderText = "Enter a code...", Text = "", ClearTextOnFocus = false, Font = Theme.Font, TextScaled = true, TextColor3 = C.Text, PlaceholderColor3 = C.SubText,
		BackgroundColor3 = C.Background, Size = UDim2.new(1, -330, 0, 44), Position = UDim2.fromOffset(150, 10), ZIndex = 8, Parent = codeRow })
	UIKit.Corner(10).Parent = box
	UIKit.Padding(6).Parent = box
	UIKit.Button({ Text = "Redeem", Color = C.Purple, Size = UDim2.fromOffset(160, 44), Position = UDim2.new(1, -172, 0, 10), Parent = codeRow, ZIndex = 8,
		OnClick = function()
			if box.Text ~= "" then
				local ok = State.Action("RedeemCode", false, box.Text)
				if ok then
					box.Text = ""
				end
			end
		end })

	-- Game passes
	UIKit.Label({ Text = "👑 Game Passes (forever)", Size = UDim2.new(1, -12, 0, 28), LayoutOrder = 2, AlignX = Enum.TextXAlignment.Left, Parent = scroll, ZIndex = 7, MaxTextSize = 22 })
	local passGrid = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, ZIndex = 6, Parent = scroll })
	new("UIGridLayout", { CellSize = UDim2.fromOffset(214, 190), CellPadding = UDim2.fromOffset(10, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = passGrid })
	for i, def in Monetization.Passes do
		passButtons[def.Id] = card(passGrid, i, def, "", function()
			local profile = State.Profile
			if profile and profile.Passes and profile.Passes[def.Id] then
				return
			end
			if def.PassId == 0 then
				UIKit.Toast("This pass isn't set up yet (Config/Monetization).", "info")
				return
			end
			MarketplaceService:PromptGamePassPurchase(player, def.PassId)
		end)
	end

	-- Developer products
	UIKit.Label({ Text = "🛍️ Items", Size = UDim2.new(1, -12, 0, 28), LayoutOrder = 4, AlignX = Enum.TextXAlignment.Left, Parent = scroll, ZIndex = 7, MaxTextSize = 22 })
	local productGrid = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 5, ZIndex = 6, Parent = scroll })
	new("UIGridLayout", { CellSize = UDim2.fromOffset(214, 190), CellPadding = UDim2.fromOffset(10, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = productGrid })
	for i, def in Monetization.Products do
		card(productGrid, i, def, def.ProductId == 0 and "Coming soon" or ("💎 R$" .. def.RobuxHint), function()
			if def.ProductId == 0 then
				UIKit.Toast("This item isn't set up yet (Config/Monetization).", "info")
				return
			end
			MarketplaceService:PromptProductPurchase(player, def.ProductId)
		end)
	end

	window.OnOpen = refresh
	State.Changed:Connect(function()
		if window.IsOpen then
			refresh()
		end
	end)
end

return StoreWindow
