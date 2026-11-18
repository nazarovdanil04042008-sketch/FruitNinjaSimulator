--!nonstrict
-- Global leaderboards (OrderedDataStore) shown on three big boards at the spawn plaza:
--   🪙 Total coins earned  •  🔁 Rebirths  •  👹 Boss damage
-- Scores of online players are written every 2 minutes (and when they leave); the top 10 is read
-- every 90 seconds. Without DataStore access (Studio without API access) the boards say so.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

type Board = { Id: string, Title: string, Color: Color3, Value: (profile: any) -> number, Store: OrderedDataStore?, Rows: { TextLabel }, Status: TextLabel }

local boards: { Board } = {
	{ Id = "Coins", Title = "🪙 TOP COINS", Color = Color3.fromRGB(255, 205, 50), Value = function(p) return p.Totals.CoinsEarned end, Rows = {} } :: any,
	{ Id = "Rebirths", Title = "🔁 TOP REBIRTHS", Color = Color3.fromRGB(255, 120, 60), Value = function(p) return p.Rebirths * 1000 + p.Level end, Rows = {} } :: any,
	{ Id = "Boss", Title = "👹 TOP BOSS DAMAGE", Color = Color3.fromRGB(255, 80, 90), Value = function(p) return p.Totals.BossDamage or 0 end, Rows = {} } :: any,
}
local names: { [number]: string } = {}
local available = true

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = ok and name or ("Player " .. userId)
	return names[userId]
end

local function buildBoard(board: Board, cf: CFrame)
	local folder = workspace:FindFirstChild("FNS_Leaderboards") or Instance.new("Folder")
	folder.Name = "FNS_Leaderboards"
	folder.Parent = workspace
	local function part(size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = cf * offset
		p.Color = color
		p.Material = material or Enum.Material.Wood
		p.Parent = folder
		return p
	end
	for _, x in { -5.5, 5.5 } do
		part(Vector3.new(0.8, 14, 0.8), CFrame.new(x, 7, 0), Color3.fromRGB(190, 40, 35), Enum.Material.SmoothPlastic)
	end
	part(Vector3.new(13.5, 0.8, 1.4), CFrame.new(0, 14.2, 0), Color3.fromRGB(35, 30, 30))
	local screen = part(Vector3.new(10.6, 11, 0.4), CFrame.new(0, 8, 0), Color3.fromRGB(30, 28, 36), Enum.Material.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = screen
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = gui
	local function label(text: string, height: number, color: Color3, order: number): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, -20, 0, height)
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.TextColor3 = color
		l.Text = text
		l.LayoutOrder = order
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = l
		return l
	end
	local title = label(board.Title, 52, board.Color, 0)
	title.TextXAlignment = Enum.TextXAlignment.Center
	for i = 1, 10 do
		table.insert(board.Rows, label("", 30, i == 1 and Color3.fromRGB(255, 215, 80) or i <= 3 and Color3.fromRGB(220, 220, 235) or Color3.fromRGB(200, 200, 210), i))
	end
	board.Status = label("Loading...", 24, Color3.fromRGB(160, 160, 180), 20)
end

local function writeScores(player: Player)
	local profile = DataService.Get(player)
	if not profile or not available or DataService.Offline then
		return
	end
	for _, board in boards do
		if board.Store then
			local value = math.floor(board.Value(profile))
			pcall(function()
				board.Store:SetAsync(tostring(player.UserId), value)
			end)
		end
	end
end

local function refreshBoards()
	for _, board in boards do
		if not available or not board.Store or DataService.Offline then
			board.Status.Text = "Leaderboards need a published game with API access."
			continue
		end
		local ok, pages = pcall(function()
			return board.Store:GetSortedAsync(false, 10)
		end)
		if ok and pages then
			local entries = pages:GetCurrentPage()
			for i = 1, 10 do
				local entry = entries[i]
				if entry then
					local value = board.Id == "Rebirths" and (math.floor(entry.value / 1000) .. " (Lv " .. entry.value % 1000 .. ")") or Format.Short(entry.value)
					board.Rows[i].Text = string.format("#%d  %s  —  %s", i, nameOf(tonumber(entry.key) or 0), value)
				else
					board.Rows[i].Text = string.format("#%d  —", i)
				end
			end
			board.Status.Text = "Updates every 90 seconds"
		else
			board.Status.Text = "Couldn't load right now..."
		end
	end
end

function LeaderboardService.Init()
	-- three boards around the spawn plaza, facing the centre
	for i, board in boards do
		local angle = math.rad(({ 135, 45, 225 })[i])
		local pos = Vector3.new(math.cos(angle) * 27, 0.6, math.sin(angle) * 27)
		buildBoard(board, CFrame.lookAt(pos, Vector3.new(0, 0.6, 0)))
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore("FNS_LB_" .. board.Id)
		end)
		if ok then
			board.Store = store
		else
			available = false
		end
	end
end

function LeaderboardService.Start()
	Players.PlayerRemoving:Connect(writeScores)
	task.spawn(function()
		task.wait(10)
		while true do
			for _, player in Players:GetPlayers() do
				writeScores(player)
			end
			refreshBoards()
			task.wait(90)
		end
	end)
end

return LeaderboardService
