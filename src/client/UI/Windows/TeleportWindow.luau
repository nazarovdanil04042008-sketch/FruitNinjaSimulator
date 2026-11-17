--!nonstrict
-- Quick travel to every area. Locked arenas show the level they need (the server validates too).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Locations = require(Shared.Config.Locations)
local Arenas = require(Shared.Config.Arenas)

local UI = script.Parent.Parent
local UIKit = require(UI.UIKit)
local Theme = require(UI.Theme)
local State = require(UI.Parent.Controllers.State)

local TeleportWindow = {}
local C = Theme.Colors

local buttons: { [string]: TextButton } = {}

local function refresh()
	local profile = State.Profile
	if not profile then
		return
	end
	for _, loc in Locations.List do
		local arena = loc.ArenaId and Arenas.Get(loc.ArenaId)
		local button = buttons[loc.Id]
		if arena and profile.Level < arena.RequiredLevel then
			UIKit.SetButton(button, "🔒 " .. loc.DisplayName .. "\nLevel " .. arena.RequiredLevel, C.Locked)
		else
			UIKit.SetButton(button, loc.Emoji .. " " .. loc.DisplayName, loc.Color)
		end
	end
end

function TeleportWindow.Init()
	local window = UIKit.CreateWindow("Teleport", "🗺️ TELEPORT", Color3.fromRGB(60, 200, 170))
	local grid = UIKit.Grid(window.Content, Vector2.new(214, 100), 12)
	for i, loc in Locations.List do
		buttons[loc.Id] = UIKit.Button({ Text = loc.DisplayName, Color = loc.Color, LayoutOrder = i, Parent = grid, ZIndex = 7, MaxTextSize = 24,
			OnClick = function()
				local ok = State.Action("Teleport", true, loc.Id)
				if ok then
					UIKit.CloseWindow()
				end
			end })
	end
	window.OnOpen = refresh
	State.Changed:Connect(function()
		if window.IsOpen then
			refresh()
		end
	end)
end

return TeleportWindow
