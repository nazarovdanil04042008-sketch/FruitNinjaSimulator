--!nonstrict
-- 🎁 Rewards: Daily login streak, Playtime rewards (this session) and Daily quests.
-- Also keeps the "!" badge on the HUD button up to date when something can be claimed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local LiveOps = require(Shared.Config.LiveOps)
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent
local UIKit = require(UI.UIKit)
local Theme = require(UI.Theme)
local HUD = require(UI.HUD)
local State = require(UI.Parent.Controllers.State)

local RewardsWindow = {}
local C = Theme.Colors
local new = UIKit.new
local player = Players.LocalPlayer

local window
local tabs: { [string]: Frame } = {}
local currentTab = "Daily"
local dailyCards: { { Frame: Frame, Status: TextLabel } } = {}
local dailyButton: TextButton
local dailyInfo: TextLabel
local playtimeRows: { { Bar: (number, string?) -> (), Button: TextButton, Minutes: number } } = {}
local questFrame: ScrollingFrame
local questInfo: TextLabel

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function today(): number
	return LiveOps.Day(serverNow())
end

------------------------------------------------------------------------------------------------
-- Claimable checks (used for the badge too)
------------------------------------------------------------------------------------------------
local function dailyClaimable(profile: any): boolean
	return profile.LastDailyDay ~= today()
end

local function claimedPlaytime(): { [number]: boolean }
	local result = {}
	for m in string.gmatch(player:GetAttribute("FNS_PlaytimeClaimed") or "", "%d+") do
		result[tonumber(m) :: number] = true
	end
	return result
end

local function minutesPlayed(): number
	local joined = player:GetAttribute("FNS_JoinTime") or serverNow()
	return (serverNow() - joined) / 60
end

local function countClaimable(): number
	local profile = State.Profile
	if not profile then
		return 0
	end
	local n = dailyClaimable(profile) and 1 or 0
	local claimed = claimedPlaytime()
	local played = minutesPlayed()
	for _, entry in LiveOps.Playtime do
		if played >= entry.Minutes and not claimed[entry.Minutes] then
			n += 1
		end
	end
	if profile.Quests and profile.Quests.Day == today() then
		for _, quest in profile.Quests.List do
			if not quest.Claimed and quest.Progress >= quest.Target then
				n += 1
			end
		end
	end
	return n
end

------------------------------------------------------------------------------------------------
-- Refresh
------------------------------------------------------------------------------------------------
local function rewardText(reward: any): string
	return reward.Text
end

local function refreshDaily()
	local profile = State.Profile
	if not profile then
		return
	end
	local canClaim = dailyClaimable(profile)
	local streakAlive = profile.LastDailyDay == today() - 1 or profile.LastDailyDay == today()
	local nextDay = canClaim and ((profile.LastDailyDay == today() - 1) and (profile.DailyStreak % #LiveOps.Daily + 1) or 1) or profile.DailyStreak
	for i, card in dailyCards do
		local claimedAlready = streakAlive and i <= profile.DailyStreak and not (canClaim and nextDay == 1)
		if canClaim and i == nextDay then
			card.Status.Text = "⭐ TODAY"
			card.Frame.BackgroundColor3 = C.Green
		elseif claimedAlready then
			card.Status.Text = "✅"
			card.Frame.BackgroundColor3 = C.Gray
		else
			card.Status.Text = "🔒"
			card.Frame.BackgroundColor3 = C.Card
		end
	end
	if canClaim then
		UIKit.SetButton(dailyButton, "🎁 Claim Day " .. nextDay, C.Green)
		dailyInfo.Text = "Log in every day to keep your streak! Missing a day restarts at Day 1."
	else
		UIKit.SetButton(dailyButton, "✅ Claimed", C.Gray)
		dailyInfo.Text = "Next reward in " .. Format.Time((today() + 1) * 86400 - serverNow())
	end
end

local function refreshPlaytime()
	local claimed = claimedPlaytime()
	local played = minutesPlayed()
	for _, row in playtimeRows do
		local ready = played >= row.Minutes
		row.Bar(played / row.Minutes, ready and "Ready!" or Format.Time((row.Minutes - played) * 60))
		if claimed[row.Minutes] then
			UIKit.SetButton(row.Button, "✅", C.Gray)
		else
			UIKit.SetButton(row.Button, ready and "Claim" or "⏳", ready and C.Green or C.Locked)
		end
	end
end

local function refreshQuests()
	local profile = State.Profile
	if not profile then
		return
	end
	UIKit.ClearChildren(questFrame, { "UIListLayout" })
	questInfo.Text = "New quests in " .. Format.Time((today() + 1) * 86400 - serverNow())
	if not profile.Quests or profile.Quests.Day ~= today() then
		UIKit.Label({ Text = "Loading today's quests...", Font = Theme.BodyFont, Size = UDim2.new(1, 0, 0, 40), Parent = questFrame, ZIndex = 8, MaxTextSize = 20 })
		return
	end
	for index, quest in profile.Quests.List do
		local def = LiveOps.QuestById[quest.Id]
		if def then
			local row = new("Frame", { BackgroundColor3 = C.Card, Size = UDim2.new(1, -12, 0, 92), LayoutOrder = index, ZIndex = 7, Parent = questFrame })
			UIKit.Corner(12).Parent = row
			UIKit.Label({ Text = "📜 " .. string.format(def.Text, quest.Target), Size = UDim2.new(1, -200, 0, 28), Position = UDim2.fromOffset(12, 6), AlignX = Enum.TextXAlignment.Left, Parent = row, ZIndex = 8, MaxTextSize = 21 })
			local reward = "Reward: 🪙 " .. Format.Short(LiveOps.ScaleCoins(def.Coins, profile.Level)) .. "  ⭐ " .. def.Xp .. " XP" .. (def.Egg and ("  🥚 " .. def.Egg .. " Egg") or "")
			UIKit.Label({ Text = reward, Font = Theme.BodyFont, Color = C.Coins, Size = UDim2.new(1, -200, 0, 18), Position = UDim2.fromOffset(12, 34), AlignX = Enum.TextXAlignment.Left, Parent = row, ZIndex = 8, MaxTextSize = 15, Stroke = false })
			local _, setBar = UIKit.ProgressBar({ Size = UDim2.new(1, -200, 0, 22), Position = UDim2.fromOffset(12, 60), Color = C.Purple, Parent = row })
			setBar(quest.Progress / quest.Target, Format.Short(quest.Progress) .. " / " .. Format.Short(quest.Target))
			local done = quest.Progress >= quest.Target
			UIKit.Button({ Text = quest.Claimed and "✅ Done" or (done and "🎁 Claim" or "In progress"), Color = quest.Claimed and C.Gray or (done and C.Green or C.Locked),
				Size = UDim2.fromOffset(170, 56), Position = UDim2.new(1, -182, 0, 18), Parent = row, ZIndex = 8, MaxTextSize = 20,
				OnClick = function()
					if done and not quest.Claimed then
						State.Action("ClaimQuest", false, index)
					end
				end })
		end
	end
end

local function refresh()
	if currentTab == "Daily" then
		refreshDaily()
	elseif currentTab == "Playtime" then
		refreshPlaytime()
	else
		refreshQuests()
	end
end

local function setTab(name: string)
	currentTab = name
	for tabName, frame in tabs do
		frame.Visible = tabName == name
	end
	refresh()
end

------------------------------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------------------------------
function RewardsWindow.Init()
	window = UIKit.CreateWindow("Rewards", "🎁 REWARDS", C.Pink)
	local content = window.Content
	for i, tab in { { "Daily", "📅 Daily" }, { "Playtime", "⏱️ Playtime" }, { "Quests", "📜 Quests" } } do
		UIKit.Button({ Text = tab[2], Color = C.Purple, Size = UDim2.fromOffset(200, 42), Position = UDim2.fromOffset((i - 1) * 212, 0), Parent = content, ZIndex = 7, MaxTextSize = 20,
			OnClick = function()
				setTab(tab[1])
			end })
		tabs[tab[1]] = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -52), Position = UDim2.fromOffset(0, 52), Visible = false, ZIndex = 6, Parent = content })
	end

	-- Daily
	local daily = tabs.Daily
	local grid = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 170), ZIndex = 6, Parent = daily })
	new("UIGridLayout", { CellSize = UDim2.fromOffset(92, 160), CellPadding = UDim2.fromOffset(6, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = grid })
	for i, reward in LiveOps.Daily do
		local card = new("Frame", { BackgroundColor3 = C.Card, LayoutOrder = i, ZIndex = 7, Parent = grid })
		UIKit.Corner(12).Parent = card
		UIKit.Stroke(2).Parent = card
		UIKit.Label({ Text = "Day " .. i, Size = UDim2.new(1, -6, 0, 26), Position = UDim2.fromOffset(3, 6), Parent = card, ZIndex = 8, MaxTextSize = 20 })
		UIKit.Label({ Text = i == 7 and "🎁" or (reward.Egg and "🥚" or (reward.Boost and "⚡" or "🪙")), Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 32), Parent = card, ZIndex = 8, Stroke = false })
		UIKit.Label({ Text = rewardText(reward), Font = Theme.BodyFont, Size = UDim2.new(1, -8, 0, 44), Position = UDim2.fromOffset(4, 76), Parent = card, ZIndex = 8, MaxTextSize = 13 })
		local status = UIKit.Label({ Text = "", Size = UDim2.new(1, -6, 0, 26), Position = UDim2.new(0, 3, 1, -32), Parent = card, ZIndex = 8, MaxTextSize = 18 })
		table.insert(dailyCards, { Frame = card, Status = status })
	end
	dailyButton = UIKit.Button({ Text = "Claim", Color = C.Green, Size = UDim2.fromOffset(280, 60), Position = UDim2.new(0.5, -140, 0, 186), Parent = daily, ZIndex = 7,
		OnClick = function()
			State.Action("ClaimDaily", false)
		end })
	dailyInfo = UIKit.Label({ Text = "", Font = Theme.BodyFont, Color = C.SubText, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 256), Parent = daily, ZIndex = 7, MaxTextSize = 18 })

	-- Playtime
	local playtime = new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8, ZIndex = 6, Parent = tabs.Playtime })
	UIKit.List(8).Parent = playtime
	for i, entry in LiveOps.Playtime do
		local row = new("Frame", { BackgroundColor3 = C.Card, Size = UDim2.new(1, -12, 0, 46), LayoutOrder = i, ZIndex = 7, Parent = playtime })
		UIKit.Corner(10).Parent = row
		UIKit.Label({ Text = "⏱️ " .. entry.Minutes .. " min — " .. entry.Text, Size = UDim2.new(0.42, 0, 1, -10), Position = UDim2.fromOffset(10, 5), AlignX = Enum.TextXAlignment.Left, Parent = row, ZIndex = 8, MaxTextSize = 18 })
		local _, setBar = UIKit.ProgressBar({ Size = UDim2.new(0.33, 0, 0, 22), Position = UDim2.new(0.44, 0, 0, 12), Color = C.Blue, Parent = row })
		local minutes = entry.Minutes
		local button = UIKit.Button({ Text = "", Size = UDim2.new(0.2, -10, 0, 38), Position = UDim2.new(0.8, 0, 0, 4), Parent = row, ZIndex = 8, MaxTextSize = 18,
			OnClick = function()
				State.Action("ClaimPlaytime", false, minutes)
			end })
		table.insert(playtimeRows, { Bar = setBar, Button = button, Minutes = minutes })
	end

	-- Quests
	questInfo = UIKit.Label({ Text = "", Font = Theme.BodyFont, Color = C.SubText, Size = UDim2.new(1, 0, 0, 22), Parent = tabs.Quests, ZIndex = 7, MaxTextSize = 17 })
	questFrame = new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, -28), Position = UDim2.fromOffset(0, 28), CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 8, ZIndex = 6, Parent = tabs.Quests })
	UIKit.List(8).Parent = questFrame

	window.OnOpen = function()
		setTab(currentTab)
		while window.IsOpen do
			task.wait(1)
			if currentTab ~= "Quests" then
				refresh()
			end
		end
	end
	State.Changed:Connect(function()
		if window.IsOpen then
			refresh()
		end
	end)
	-- HUD badge
	task.spawn(function()
		while true do
			HUD.SetBadge("Rewards", countClaimable())
			task.wait(2)
		end
	end)
end

return RewardsWindow
