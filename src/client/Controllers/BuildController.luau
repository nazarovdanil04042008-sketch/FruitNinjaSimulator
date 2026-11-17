--!nonstrict
-- Placement on your village plot:
--   * a see-through "ghost" of the building follows the mouse / your finger, snapped to the grid
--   * green = can build here, red = blocked (same PlotGrid rules the server checks)
--   * PC: click to place, R to rotate, Q to cancel.  Mobile/tablet: tap to move, then the big buttons.
--   * Remove mode: click / tap one of your buildings to put it back into your inventory.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Buildings = require(Shared.Config.Buildings)
local PlotGrid = require(Shared.Util.PlotGrid)
local ModelBuilder = require(Shared.Util.ModelBuilder)
local Signal = require(Shared.Util.Signal)

local UI = script.Parent.Parent.UI
local UIKit = require(UI.UIKit)
local Theme = require(UI.Theme)
local Effects = require(UI.Effects)
local State = require(script.Parent.State)

local BuildController = {}
BuildController.ModeChanged = Signal.new() -- (mode: "Place" | "Remove" | nil)
BuildController.Mode = nil :: string?

local C = Theme.Colors
local new = UIKit.new
local player = Players.LocalPlayer

local gui: ScreenGui
local bar: Frame
local hint: TextLabel
local rotateButton: TextButton
local placeButton: TextButton
local cancelButton: TextButton

local currentId: string? = nil
local rotation = 0
local ghost: Model? = nil
local highlight: Highlight? = nil
local pointer: Vector2? = nil
local gx, gz = 0, 0
local valid = false
local hovered: Model? = nil
local busy = false

local function plotCenter(): Vector3?
	local index = player:GetAttribute("PlotIndex")
	return type(index) == "number" and Buildings.Plots[index] or nil
end

local function screenPointer(): Vector2
	if pointer then
		return pointer
	end
	local camera = workspace.CurrentCamera
	return camera.ViewportSize / 2
end

local function clearGhost()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	if highlight then
		highlight:Destroy()
		highlight = nil
	end
end

local function setHovered(model: Model?)
	if hovered == model then
		return
	end
	hovered = model
	if highlight and BuildController.Mode == "Remove" then
		highlight.Adornee = model
		highlight.Enabled = model ~= nil
	end
end

function BuildController.Stop()
	clearGhost()
	setHovered(nil)
	currentId = nil
	BuildController.Mode = nil
	if gui then
		gui.Enabled = false
	end
	BuildController.ModeChanged:Fire(nil)
end

local function ensureNearPlot(): boolean
	local center = plotCenter()
	if not center then
		UIKit.Toast("You don't have a village plot on this server.", "error")
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - center).Magnitude > 90 then
		local ok = State.Action("TeleportToPlot", true)
		if not ok then
			return false
		end
	end
	return true
end

local function showBar(mode: string)
	gui.Enabled = true
	rotateButton.Visible = mode == "Place"
	placeButton.Visible = mode == "Place"
	if mode == "Place" then
		local touch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
		hint.Text = touch and "Tap where to build, then press ✅ Place" or "Click to build • R = rotate • Q = cancel"
	else
		hint.Text = "Click / tap one of your buildings to put it back in your inventory"
	end
end

function BuildController.StartPlacing(buildingId: string)
	local def = Buildings.Get(buildingId)
	local profile = State.Profile
	if not def or not profile then
		return
	end
	if (profile.BuildInventory[buildingId] or 0) < 1 then
		UIKit.Toast("Buy this building first!", "error")
		return
	end
	if not ensureNearPlot() then
		return
	end
	BuildController.Stop()
	UIKit.CloseWindow(true)
	currentId = buildingId
	rotation = 0
	BuildController.Mode = "Place"
	ghost = ModelBuilder.Building(buildingId)
	for _, d in ghost:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		elseif d:IsA("ParticleEmitter") or d:IsA("Light") then
			d.Enabled = false
		end
	end
	ghost.Parent = workspace
	highlight = new("Highlight", { FillTransparency = 0.55, OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Adornee = ghost, Parent = ghost })
	showBar("Place")
	BuildController.ModeChanged:Fire("Place")
end

function BuildController.StartRemoving()
	if not ensureNearPlot() then
		return
	end
	BuildController.Stop()
	UIKit.CloseWindow(true)
	BuildController.Mode = "Remove"
	highlight = new("Highlight", { FillColor = C.Red, OutlineColor = Color3.new(1, 1, 1), FillTransparency = 0.5, Enabled = false, Parent = workspace })
	showBar("Remove")
	BuildController.ModeChanged:Fire("Remove")
end

local function rotate()
	rotation = (rotation + 1) % 4
	Effects.Play("Click", 1.2)
end

local function tryPlace()
	local id = currentId
	if busy or not id then
		return
	end
	if not valid then
		UIKit.Toast("Can't build there! Pick a green spot inside your plot.", "error")
		return
	end
	busy = true
	local ok = State.Action("PlaceBuilding", true, id, gx, gz, rotation)
	busy = false
	if ok then
		Effects.Play("Purchase", 1.1)
		task.wait(0.25) -- let the new profile arrive
		local profile = State.Profile
		if not profile or (profile.BuildInventory[id] or 0) < 1 then
			BuildController.Stop()
			UIKit.Toast("Built! Open 🏯 Build to place more.", "success")
		end
	end
end

local function findBuilding(screen: Vector2): Model?
	local camera = workspace.CurrentCamera
	local ray = camera:ScreenPointToRay(screen.X, screen.Y)
	local params = RaycastParams.new()
	local plots = workspace:FindFirstChild("FNS_Plots")
	if not plots then
		return nil
	end
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { plots }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	local instance = result and result.Instance
	while instance and instance ~= plots do
		if instance:IsA("Model") and instance:GetAttribute("BuildingUid") then
			return instance:GetAttribute("OwnerUserId") == player.UserId and instance or nil
		end
		instance = instance.Parent
	end
	return nil
end

local function tryRemove()
	local model = hovered or findBuilding(screenPointer())
	if not model then
		return
	end
	local uid = model:GetAttribute("BuildingUid")
	local def = Buildings.Get(model.Name)
	UIKit.Confirm("Pick up " .. (def and def.DisplayName or "building") .. "?", "It goes back to your inventory. You can place it again anytime.", "Pick up", function()
		State.Action("RemoveBuilding", false, uid)
		setHovered(nil)
	end)
end

local function step()
	if BuildController.Mode == "Place" and ghost and currentId then
		local center = plotCenter()
		local def = Buildings.Get(currentId)
		if not center or not def then
			return
		end
		local camera = workspace.CurrentCamera
		local screen = screenPointer()
		local ray = camera:ScreenPointToRay(screen.X, screen.Y)
		local floorY = center.Y + PlotGrid.FloorY
		if ray.Direction.Y < -0.01 then
			local t = (floorY - ray.Origin.Y) / ray.Direction.Y
			local hit = ray.Origin + ray.Direction * t
			local w, d = PlotGrid.Footprint(def, rotation)
			gx, gz = PlotGrid.FromWorld(center, def, hit, rotation)
			gx = math.clamp(gx, -w, PlotGrid.Size)
			gz = math.clamp(gz, -d, PlotGrid.Size)
		end
		local profile = State.Profile
		valid = profile ~= nil and PlotGrid.CanPlace(profile.Buildings, currentId, gx, gz, rotation)
		ghost:PivotTo(PlotGrid.ToWorld(center, def, gx, gz, rotation))
		if highlight then
			highlight.FillColor = valid and C.Green or C.Red
			highlight.OutlineColor = valid and Color3.fromRGB(200, 255, 200) or Color3.fromRGB(255, 200, 200)
		end
	elseif BuildController.Mode == "Remove" and UserInputService.MouseEnabled then
		setHovered(findBuilding(screenPointer()))
	end
end

function BuildController.Init()
	gui = new("ScreenGui", { Name = "FNS_Build", ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 14, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
	bar = new("Frame", { BackgroundColor3 = C.Panel, BackgroundTransparency = 0.15, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(560, 128), Parent = gui })
	UIKit.AutoScale(bar)
	UIKit.Corner(18).Parent = bar
	UIKit.Stroke(3).Parent = bar
	hint = UIKit.Label({ Text = "", Font = Theme.BodyFont, Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 8), Parent = bar, MaxTextSize = 20 })
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 70), Position = UDim2.fromOffset(10, 46), Parent = bar })
	UIKit.List(12, true).Parent = row
	rotateButton = UIKit.Button({ Text = "🔄 Rotate", Color = C.Blue, Size = UDim2.fromOffset(160, 64), LayoutOrder = 1, Parent = row, OnClick = rotate })
	placeButton = UIKit.Button({ Text = "✅ Place", Color = C.Green, Size = UDim2.fromOffset(170, 64), LayoutOrder = 2, Parent = row, OnClick = tryPlace })
	cancelButton = UIKit.Button({ Text = "✖ Done", Color = C.Red, Size = UDim2.fromOffset(160, 64), LayoutOrder = 3, Parent = row, OnClick = BuildController.Stop })

	UserInputService.InputBegan:Connect(function(input, processed)
		if not BuildController.Mode then
			return
		end
		if input.KeyCode == Enum.KeyCode.R and BuildController.Mode == "Place" and not processed then
			rotate()
		elseif input.KeyCode == Enum.KeyCode.Q and not processed then
			BuildController.Stop()
		elseif processed then
			return
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			pointer = Vector2.new(input.Position.X, input.Position.Y)
			if BuildController.Mode == "Place" then
				task.spawn(tryPlace)
			else
				task.spawn(tryRemove)
			end
		elseif input.UserInputType == Enum.UserInputType.Touch then
			pointer = Vector2.new(input.Position.X, input.Position.Y)
			if BuildController.Mode == "Remove" then
				task.spawn(tryRemove)
			end
		end
	end)
	UserInputService.InputChanged:Connect(function(input, processed)
		if BuildController.Mode and not processed and input.UserInputType == Enum.UserInputType.MouseMovement then
			pointer = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	RunService.RenderStepped:Connect(step)
	player.CharacterRemoving:Connect(BuildController.Stop)
end

return BuildController
