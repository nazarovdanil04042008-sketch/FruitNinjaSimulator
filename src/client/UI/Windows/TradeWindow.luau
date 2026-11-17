--!nonstrict
-- 🤝 Trading UI:
--   * no trade: list of players in the server with a "Trade" button each
--   * incoming request: a popup with Accept / Decline (30 s)
--   * active trade: your offer, their offer, your creature inventory (tap to add / remove),
--     coins box, Ready -> Confirm (both players, short safety countdown), Cancel
-- The server owns the trade state; this window only shows it and sends requests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Util.Net)

local UI = script.Parent.Parent
local UIKit = require(UI.UIKit)
local Theme = require(UI.Theme)
local Effects = require(UI.Effects)
local State = require(UI.Parent.Controllers.State)

local TradeWindow = {}
local C = Theme.Colors
local new = UIKit.new
local player = Players.LocalPlayer

local window
local lobby: Frame
local lobbyList: ScrollingFrame
local tradeFrame: Frame
local statusLabel: TextLabel
local myGrid: ScrollingFrame
local theirGrid: ScrollingFrame
local myCoinsLabel: TextLabel
local theirCoinsLabel: TextLabel
local theirTitle: TextLabel
local inventoryGrid: ScrollingFrame
local coinsBox: TextBox
local readyButton: TextButton
local confirmButton: TextButton
local invitePopup: Frame
local inviteLabel: TextLabel
local inviteFrom: number? = nil

local tradeState: any = nil
local sending = false

local function creatureCard(parent: Instance, creatureId: string, order: number, onClick: (() -> ())?, selected: boolean?): TextButton
	local def = Creatures.Get(creatureId)
	local rarity = Rarities.Get(def and def.Rarity or "Common")
	local card = new("TextButton", { Text = "", AutoButtonColor = onClick ~= nil, BackgroundColor3 = rarity.Color, LayoutOrder = order, ZIndex = 8, Parent = parent })
	UIKit.Corner(10).Parent = card
	UIKit.Stroke(selected and 4 or 2, selected and Color3.new(1, 1, 1) or C.Stroke).Parent = card
	UIKit.Gradient(rarity.Color, rarity.Color2, 90).Parent = card
	UIKit.Label({ Text = def and def.Emoji or "?", Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 4), Parent = card, ZIndex = 9, Stroke = false })
	UIKit.Label({ Text = def and def.DisplayName or creatureId, Size = UDim2.new(1, -6, 0, 26), Position = UDim2.fromOffset(3, 40), Parent = card, ZIndex = 9, MaxTextSize = 11 })
	if selected then
		UIKit.Label({ Text = "✅", Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, -22, 0, 2), Parent = card, ZIndex = 10, Stroke = false })
	end
	if onClick then
		card.Activated:Connect(onClick)
	end
	return card
end

local function grid(parent: Instance, size: UDim2, position: UDim2): ScrollingFrame
	local holder = new("Frame", { BackgroundColor3 = C.Background, BackgroundTransparency = 0.3, Size = size, Position = position, ZIndex = 6, Parent = parent })
	UIKit.Corner(10).Parent = holder
	return UIKit.Grid(holder, Vector2.new(70, 70), 6)
end

------------------------------------------------------------------------------------------------
-- Lobby (choose a player)
------------------------------------------------------------------------------------------------
local function refreshLobby()
	UIKit.ClearChildren(lobbyList, { "UIListLayout" })
	local count = 0
	for _, other in Players:GetPlayers() do
		if other ~= player then
			count += 1
			local row = new("Frame", { BackgroundColor3 = C.Card, Size = UDim2.new(1, -12, 0, 56), LayoutOrder = count, ZIndex = 7, Parent = lobbyList })
			UIKit.Corner(12).Parent = row
			UIKit.Label({ Text = "👤 " .. other.DisplayName .. "  (@" .. other.Name .. ")", Size = UDim2.new(1, -200, 1, -12), Position = UDim2.fromOffset(14, 6), AlignX = Enum.TextXAlignment.Left, Parent = row, ZIndex = 8, MaxTextSize = 22 })
			UIKit.Button({ Text = "🤝 Trade", Color = C.Green, Size = UDim2.fromOffset(170, 44), Position = UDim2.new(1, -180, 0, 6), Parent = row, ZIndex = 8,
				OnClick = function()
					State.Action("TradeRequest", false, other.UserId)
				end })
		end
	end
	if count == 0 then
		UIKit.Label({ Text = "Nobody else is in this server yet.\nInvite a friend to trade creatures and coins!", Font = Theme.BodyFont, Color = C.SubText, Size = UDim2.new(1, -20, 0, 80), Parent = lobbyList, ZIndex = 8, MaxTextSize = 20 })
	end
end

------------------------------------------------------------------------------------------------
-- Active trade
------------------------------------------------------------------------------------------------
local function myOfferUids(): { string }
	local list = {}
	if tradeState then
		for _, item in tradeState.Mine.Creatures do
			table.insert(list, item.Uid)
		end
	end
	return list
end

local function sendOffer(uids: { string }, coins: number)
	if sending then
		return
	end
	sending = true
	State.Action("TradeSetOffer", true, uids, coins)
	sending = false
end

local function refreshTrade()
	local s = tradeState
	local profile = State.Profile
	if not s or not profile then
		return
	end
	theirTitle.Text = "📦 " .. s.PartnerName .. "'s offer"
	UIKit.ClearChildren(myGrid)
	UIKit.ClearChildren(theirGrid)
	for i, item in s.Mine.Creatures do
		creatureCard(myGrid, item.Id, i)
	end
	for i, item in s.Theirs.Creatures do
		creatureCard(theirGrid, item.Id, i)
	end
	myCoinsLabel.Text = "🪙 " .. Format.Commas(s.Mine.Coins)
	theirCoinsLabel.Text = "🪙 " .. Format.Commas(s.Theirs.Coins)

	-- inventory: tap to add / remove from your offer
	UIKit.ClearChildren(inventoryGrid)
	local offered = {}
	for _, uid in myOfferUids() do
		offered[uid] = true
	end
	local list = {}
	for uid, entry in profile.Creatures do
		table.insert(list, { uid = uid, id = entry.Id, power = Creatures.GetPower(entry.Id) })
	end
	table.sort(list, function(a, b)
		return a.power > b.power
	end)
	for i, item in list do
		creatureCard(inventoryGrid, item.id, i, function()
			local uids = myOfferUids()
			local index = table.find(uids, item.uid)
			if index then
				table.remove(uids, index)
			else
				table.insert(uids, item.uid)
			end
			task.spawn(sendOffer, uids, tradeState and tradeState.Mine.Coins or 0)
		end, offered[item.uid])
	end

	UIKit.SetButton(readyButton, s.MyReady and "✅ Ready!" or "Ready", s.MyReady and C.Green or C.Blue)
	local bothReady = s.MyReady and s.TheirReady
	UIKit.SetButton(confirmButton, s.MyConfirmed and "⏳ Waiting..." or "🤝 Confirm", bothReady and not s.MyConfirmed and C.Purple or C.Gray)
	if s.MyConfirmed and not s.TheirConfirmed then
		statusLabel.Text = "You confirmed. Waiting for " .. s.PartnerName .. "..."
	elseif s.TheirConfirmed then
		statusLabel.Text = s.PartnerName .. " confirmed! Press Confirm to finish."
	elseif bothReady then
		statusLabel.Text = "Both ready. Check the offers, then press Confirm."
	elseif s.TheirReady then
		statusLabel.Text = s.PartnerName .. " is ready."
	else
		statusLabel.Text = "Add creatures / coins, then press Ready. Any change resets Ready."
	end
end

local function showMode()
	local inTrade = tradeState ~= nil
	lobby.Visible = not inTrade
	tradeFrame.Visible = inTrade
	if inTrade then
		refreshTrade()
	else
		refreshLobby()
	end
end

------------------------------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------------------------------
local function buildTrade(content: Frame)
	tradeFrame = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 6, Parent = content })
	statusLabel = UIKit.Label({ Text = "", Font = Theme.BodyFont, Size = UDim2.new(1, 0, 0, 22), Parent = tradeFrame, ZIndex = 7, MaxTextSize = 17 })

	UIKit.Label({ Text = "🎁 Your offer", Color = C.Green, Size = UDim2.new(0.5, -6, 0, 22), Position = UDim2.fromOffset(0, 26), AlignX = Enum.TextXAlignment.Left, Parent = tradeFrame, ZIndex = 7, MaxTextSize = 19 })
	myCoinsLabel = UIKit.Label({ Text = "", Color = C.Coins, Size = UDim2.new(0.25, 0, 0, 22), Position = UDim2.new(0.25, 0, 0, 26), AlignX = Enum.TextXAlignment.Right, Parent = tradeFrame, ZIndex = 7, MaxTextSize = 19 })
	theirTitle = UIKit.Label({ Text = "", Color = C.Orange, Size = UDim2.new(0.5, -6, 0, 22), Position = UDim2.new(0.5, 6, 0, 26), AlignX = Enum.TextXAlignment.Left, Parent = tradeFrame, ZIndex = 7, MaxTextSize = 19 })
	theirCoinsLabel = UIKit.Label({ Text = "", Color = C.Coins, Size = UDim2.new(0.25, -6, 0, 22), Position = UDim2.new(0.75, 0, 0, 26), AlignX = Enum.TextXAlignment.Right, Parent = tradeFrame, ZIndex = 7, MaxTextSize = 19 })
	myGrid = grid(tradeFrame, UDim2.new(0.5, -6, 0, 120), UDim2.fromOffset(0, 50))
	theirGrid = grid(tradeFrame, UDim2.new(0.5, -6, 0, 120), UDim2.new(0.5, 6, 0, 50))

	UIKit.Label({ Text = "Your creatures — tap to add / remove (max 9)", Font = Theme.BodyFont, Color = C.SubText, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 174), AlignX = Enum.TextXAlignment.Left, Parent = tradeFrame, ZIndex = 7, MaxTextSize = 15, Stroke = false })
	inventoryGrid = grid(tradeFrame, UDim2.new(1, 0, 0, 120), UDim2.fromOffset(0, 194))

	local bottom = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 56), Position = UDim2.new(0, 0, 1, -56), ZIndex = 6, Parent = tradeFrame })
	UIKit.List(10, true).Parent = bottom
	coinsBox = new("TextBox", { PlaceholderText = "🪙 coins", Text = "", ClearTextOnFocus = false, Font = Theme.Font, TextScaled = true, TextColor3 = C.Coins, PlaceholderColor3 = C.SubText,
		BackgroundColor3 = C.Background, Size = UDim2.fromOffset(150, 50), LayoutOrder = 1, ZIndex = 7, Parent = bottom })
	UIKit.Corner(10).Parent = coinsBox
	UIKit.Stroke(2, C.Coins).Parent = coinsBox
	UIKit.Padding(6).Parent = coinsBox
	coinsBox.FocusLost:Connect(function()
		local amount = math.floor(tonumber((coinsBox.Text:gsub("[^%d]", ""))) or 0)
		local profile = State.Profile
		if profile then
			amount = math.clamp(amount, 0, profile.Coins)
		end
		coinsBox.Text = amount > 0 and tostring(amount) or ""
		task.spawn(sendOffer, myOfferUids(), amount)
	end)
	readyButton = UIKit.Button({ Text = "Ready", Color = C.Blue, Size = UDim2.fromOffset(150, 50), LayoutOrder = 2, Parent = bottom, ZIndex = 7,
		OnClick = function()
			State.Action("TradeReady", true, not (tradeState and tradeState.MyReady))
		end })
	confirmButton = UIKit.Button({ Text = "🤝 Confirm", Color = C.Gray, Size = UDim2.fromOffset(190, 50), LayoutOrder = 3, Parent = bottom, ZIndex = 7,
		OnClick = function()
			State.Action("TradeConfirm", true)
		end })
	UIKit.Button({ Text = "✖ Cancel", Color = C.Red, Size = UDim2.fromOffset(150, 50), LayoutOrder = 4, Parent = bottom, ZIndex = 7,
		OnClick = function()
			State.Action("TradeCancel", true)
		end })
end

local function buildInvitePopup()
	local gui = new("ScreenGui", { Name = "FNS_TradeInvite", ResetOnSpawn = false, DisplayOrder = 45, Parent = player:WaitForChild("PlayerGui") })
	invitePopup = new("Frame", { BackgroundColor3 = C.Panel, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.fromOffset(440, 130), Visible = false, Parent = gui })
	UIKit.AutoScale(invitePopup)
	UIKit.Corner(16).Parent = invitePopup
	UIKit.Stroke(3, C.Green).Parent = invitePopup
	inviteLabel = UIKit.Label({ Text = "", Size = UDim2.new(1, -20, 0, 44), Position = UDim2.fromOffset(10, 8), Parent = invitePopup, MaxTextSize = 24 })
	local function respond(accept: boolean)
		local from = inviteFrom
		invitePopup.Visible = false
		inviteFrom = nil
		if from then
			State.Action("TradeRespond", not accept, from, accept)
		end
	end
	UIKit.Button({ Text = "✅ Accept", Color = C.Green, Size = UDim2.fromOffset(190, 56), Position = UDim2.new(0.5, -200, 1, -66), Parent = invitePopup, OnClick = function() respond(true) end })
	UIKit.Button({ Text = "✖ Decline", Color = C.Red, Size = UDim2.fromOffset(190, 56), Position = UDim2.new(0.5, 10, 1, -66), Parent = invitePopup, OnClick = function() respond(false) end })
end

function TradeWindow.Init()
	window = UIKit.CreateWindow("Trade", "🤝 TRADE", C.Green)
	local content = window.Content

	lobby = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = content })
	UIKit.Label({ Text = "Choose a player to trade creatures and coins with:", Font = Theme.BodyFont, Size = UDim2.new(1, 0, 0, 24), Parent = lobby, ZIndex = 7, MaxTextSize = 18 })
	lobbyList = new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, -32), Position = UDim2.fromOffset(0, 32), CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 8, ZIndex = 6, Parent = lobby })
	UIKit.List(8).Parent = lobbyList
	buildTrade(content)
	buildInvitePopup()

	window.OnOpen = showMode
	Players.PlayerAdded:Connect(function()
		if window.IsOpen and not tradeState then
			refreshLobby()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		if window.IsOpen and not tradeState then
			task.defer(refreshLobby)
		end
	end)
	State.Changed:Connect(function()
		if window.IsOpen and tradeState then
			refreshTrade()
		end
	end)

	Net.Event("TradeInvite").OnClientEvent:Connect(function(fromUserId: number, fromName: string)
		inviteFrom = fromUserId
		inviteLabel.Text = "🤝 " .. fromName .. " wants to trade!"
		invitePopup.Visible = true
		Effects.Play("Coin", 1.4)
		task.delay(30, function()
			if inviteFrom == fromUserId then
				invitePopup.Visible = false
				inviteFrom = nil
			end
		end)
	end)
	Net.Event("TradeUpdate").OnClientEvent:Connect(function(newState: any)
		local first = tradeState == nil
		tradeState = newState
		if first then
			coinsBox.Text = ""
			if not window.IsOpen then
				UIKit.OpenWindow("Trade")
			end
		end
		showMode()
	end)
	Net.Event("TradeClosed").OnClientEvent:Connect(function(reason: string, completed: boolean)
		tradeState = nil
		UIKit.Toast(reason, completed and "success" or "info")
		if completed then
			Effects.Play("LevelUp")
		end
		if window.IsOpen then
			showMode()
		end
	end)
end

-- Closing the window keeps the trade open; reopen 🤝 Trade to continue (or press Cancel).
function TradeWindow.IsTrading(): boolean
	return tradeState ~= nil
end

return TradeWindow
