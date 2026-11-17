--!nonstrict
-- Ninja Village: every player gets a plot, buys Japanese buildings and places them on a grid.
-- Placed buildings are real server-side models (everyone sees them) and give passive bonuses
-- (see Formulas.BuildingBonus). All placement rules are validated here with the shared PlotGrid.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Buildings = require(Shared.Config.Buildings)
local PlotGrid = require(Shared.Util.PlotGrid)
local ModelBuilder = require(Shared.Util.ModelBuilder)
local Format = require(Shared.Util.Format)

local DataService = require(script.Parent.DataService)
local ActionService = require(script.Parent.ActionService)
local ProgressionService = require(script.Parent.ProgressionService)

local BuildingService = {}

type Plot = { Index: number, Center: Vector3, Owner: Player?, Folder: Folder, SignLabel: TextLabel }

local plots: { Plot } = {}
local playerPlot: { [Player]: Plot } = {}
local models: { [Player]: { [string]: Model } } = {}
local rootFolder: Folder

------------------------------------------------------------------------------------------------
-- Plot bases
------------------------------------------------------------------------------------------------
local function newPart(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function buildPlot(index: number, center: Vector3): Plot
	local folder = Instance.new("Folder")
	folder.Name = "Plot_" .. index
	folder.Parent = rootFolder
	local size = Buildings.PlotSize
	local base = newPart(folder, Vector3.new(size, 1, size), CFrame.new(center + Vector3.new(0, 0.5, 0)), Color3.fromRGB(125, 190, 95), Enum.Material.Grass)
	base.Name = "PlotBase"
	-- subtle grid lines so players can see the cells
	for i = 1, PlotGrid.Size - 1 do
		local offset = -size / 2 + i * PlotGrid.Cell
		for _, horizontal in { true, false } do
			local line = newPart(folder, horizontal and Vector3.new(size, 0.05, 0.12) or Vector3.new(0.12, 0.05, size),
				CFrame.new(center + (horizontal and Vector3.new(0, 1.02, offset) or Vector3.new(offset, 1.02, 0))), Color3.fromRGB(110, 170, 85))
			line.CanCollide = false
			line.CanQuery = false
		end
	end
	-- low wooden fence with an opening towards the road (-Z)
	local fenceColor = Color3.fromRGB(120, 80, 50)
	local half = size / 2
	newPart(folder, Vector3.new(size, 1.4, 0.5), CFrame.new(center + Vector3.new(0, 1.7, half)), fenceColor, Enum.Material.Wood)
	newPart(folder, Vector3.new(0.5, 1.4, size), CFrame.new(center + Vector3.new(-half, 1.7, 0)), fenceColor, Enum.Material.Wood)
	newPart(folder, Vector3.new(0.5, 1.4, size), CFrame.new(center + Vector3.new(half, 1.7, 0)), fenceColor, Enum.Material.Wood)
	for _, sx in { -1, 1 } do
		newPart(folder, Vector3.new(size / 2 - 4, 1.4, 0.5), CFrame.new(center + Vector3.new(sx * (size / 4 + 2), 1.7, -half)), fenceColor, Enum.Material.Wood)
	end
	-- owner sign at the entrance
	local signPost = newPart(folder, Vector3.new(0.6, 7, 0.6), CFrame.new(center + Vector3.new(-6, 3.5, -half - 1.5)), Color3.fromRGB(90, 60, 40), Enum.Material.Wood)
	signPost.Name = "SignPost"
	local board = newPart(folder, Vector3.new(9, 2.6, 0.4), CFrame.new(center + Vector3.new(-6, 6.5, -half - 1.5)), Color3.fromRGB(40, 30, 30), Enum.Material.Wood)
	board.Name = "Sign"
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 220, 140)
	label.Text = "🏯 Free plot"
	label.Parent = gui
	return { Index = index, Center = center, Owner = nil, Folder = folder, SignLabel = label }
end

------------------------------------------------------------------------------------------------
-- Models
------------------------------------------------------------------------------------------------
local function spawnModel(player: Player, plot: Plot, item: any)
	local def = Buildings.Get(item.Id)
	if not def then
		return
	end
	local model = ModelBuilder.Building(item.Id)
	model:PivotTo(PlotGrid.ToWorld(plot.Center, def, item.X, item.Z, item.R))
	model:SetAttribute("BuildingUid", item.Uid)
	model:SetAttribute("OwnerUserId", player.UserId)
	model.Parent = plot.Folder
	models[player] = models[player] or {}
	models[player][item.Uid] = model
end

local function clearModels(player: Player)
	for _, model in models[player] or {} do
		model:Destroy()
	end
	models[player] = nil
end

local function afterChange(player: Player)
	DataService.Replicate(player)
	ProgressionService.ApplyCharacterStats(player)
end

function BuildingService.GetPlot(player: Player): Plot?
	return playerPlot[player]
end

local function assignPlot(player: Player, profile: any)
	for _, plot in plots do
		if not plot.Owner or not plot.Owner.Parent then
			plot.Owner = player
			playerPlot[player] = plot
			plot.SignLabel.Text = "🏯 " .. player.DisplayName .. "'s Village"
			player:SetAttribute("PlotIndex", plot.Index)
			for _, item in profile.Buildings do
				spawnModel(player, plot, item)
			end
			return
		end
	end
	player:SetAttribute("PlotIndex", 0)
	ProgressionService.Notify(player, "🏯 All village plots are taken on this server. Your buildings are safe and will appear on a server with a free plot.", "info")
end

local function releasePlot(player: Player)
	clearModels(player)
	local plot = playerPlot[player]
	if plot then
		plot.Owner = nil
		plot.SignLabel.Text = "🏯 Free plot"
	end
	playerPlot[player] = nil
end

local function integer(value: any, min: number, max: number): boolean
	return ActionService.IsInteger(value, min, max)
end

function BuildingService.Init()
	rootFolder = Instance.new("Folder")
	rootFolder.Name = "FNS_Plots"
	rootFolder.Parent = workspace
	for index, center in Buildings.Plots do
		table.insert(plots, buildPlot(index, center))
	end

	ActionService.Register("BuyBuilding", function(player, profile, id: any)
		local def = ActionService.IsString(id) and Buildings.Get(id)
		if not def then
			return false, "Unknown building."
		end
		if profile.Level < def.RequiredLevel then
			return false, "Reach level " .. def.RequiredLevel .. " first!"
		end
		local owned = (profile.BuildInventory[def.Id] or 0) + PlotGrid.CountPlaced(profile.Buildings, def.Id)
		if owned >= def.MaxPlaced then
			return false, "You already have the maximum (" .. def.MaxPlaced .. ") of this building."
		end
		if not ProgressionService.SpendCoins(player, def.Price) then
			return false, "Not enough coins! You need " .. Format.Short(def.Price) .. "."
		end
		profile.BuildInventory[def.Id] = (profile.BuildInventory[def.Id] or 0) + 1
		afterChange(player)
		return true, "Bought " .. def.DisplayName .. "! Place it in your village."
	end)

	ActionService.Register("PlaceBuilding", function(player, profile, id: any, gx: any, gz: any, rotation: any)
		local def = ActionService.IsString(id) and Buildings.Get(id)
		if not def or not integer(gx, 0, PlotGrid.Size) or not integer(gz, 0, PlotGrid.Size) or not integer(rotation, 0, 3) then
			return false, "Invalid placement."
		end
		local plot = playerPlot[player]
		if not plot then
			return false, "You don't have a village plot on this server."
		end
		if (profile.BuildInventory[def.Id] or 0) < 1 then
			return false, "Buy this building first."
		end
		if PlotGrid.CountPlaced(profile.Buildings, def.Id) >= def.MaxPlaced or #profile.Buildings >= Buildings.MaxPlacedTotal then
			return false, "You can't place more of these."
		end
		if not PlotGrid.CanPlace(profile.Buildings, def.Id, gx, gz, rotation) then
			return false, "Can't build there - the spot is blocked or outside your plot."
		end
		profile.BuildInventory[def.Id] -= 1
		if profile.BuildInventory[def.Id] <= 0 then
			profile.BuildInventory[def.Id] = nil
		end
		local item = { Uid = DataService.NewUid(player, "b"), Id = def.Id, X = gx, Z = gz, R = rotation }
		table.insert(profile.Buildings, item)
		spawnModel(player, plot, item)
		afterChange(player)
		return true, def.DisplayName .. " built!", item.Uid
	end)

	ActionService.Register("MoveBuilding", function(player, profile, uid: any, gx: any, gz: any, rotation: any)
		if type(uid) ~= "string" or not integer(gx, 0, PlotGrid.Size) or not integer(gz, 0, PlotGrid.Size) or not integer(rotation, 0, 3) then
			return false, "Invalid move."
		end
		local plot = playerPlot[player]
		for _, item in profile.Buildings do
			if item.Uid == uid then
				if not plot then
					return false, "You don't have a village plot on this server."
				end
				if not PlotGrid.CanPlace(profile.Buildings, item.Id, gx, gz, rotation, uid) then
					return false, "Can't move it there."
				end
				item.X, item.Z, item.R = gx, gz, rotation
				local model = models[player] and models[player][uid]
				if model then
					model:PivotTo(PlotGrid.ToWorld(plot.Center, Buildings.Get(item.Id), gx, gz, rotation))
				end
				afterChange(player)
				return true, "Moved!"
			end
		end
		return false, "Building not found."
	end)

	ActionService.Register("RemoveBuilding", function(player, profile, uid: any)
		if type(uid) ~= "string" then
			return false, "Invalid building."
		end
		for index, item in profile.Buildings do
			if item.Uid == uid then
				table.remove(profile.Buildings, index)
				profile.BuildInventory[item.Id] = (profile.BuildInventory[item.Id] or 0) + 1
				local model = models[player] and models[player][uid]
				if model then
					model:Destroy()
					models[player][uid] = nil
				end
				afterChange(player)
				local def = Buildings.Get(item.Id)
				return true, (def and def.DisplayName or "Building") .. " moved back to your inventory."
			end
		end
		return false, "Building not found."
	end)

	ActionService.Register("TeleportToPlot", function(player)
		local plot = playerPlot[player]
		if not plot then
			return false, "You don't have a village plot on this server."
		end
		if ProgressionService.IsFrozen(player) then
			return false, "Leave the slicing round first."
		end
		ProgressionService.TeleportTo(player, plot.Center + Vector3.new(0, 4, -Buildings.PlotSize / 2 - 4), plot.Center)
		return true, "Welcome home!"
	end)
end

function BuildingService.Start()
	DataService.ProfileLoaded:Connect(assignPlot)
	Players.PlayerRemoving:Connect(releasePlot)
end

return BuildingService
