--!nonstrict
-- Full-screen hatching animation: the egg shakes (longer for rarer results), cracks with a flash,
-- and reveals the creature with rarity-coloured rays, NEW! badge, quote and bonuses.
-- Multiple hatches (Hatch All) are queued and shown one after another.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Eggs = require(Shared.Config.Eggs)
local Fruits = require(Shared.Config.Fruits)
local ModelBuilder = require(Shared.Util.ModelBuilder)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Util.Net)

local UI = script.Parent.Parent.UI
local UIKit = require(UI.UIKit)
local Theme = require(UI.Theme)
local Effects = require(UI.Effects)
local Viewport = require(UI.Viewport)

local HatchReveal = {}

local C = Theme.Colors
local new = UIKit.new
local player = Players.LocalPlayer

local gui: ScreenGui
local holder: Frame
local holderScale: UIScale
local viewport: ViewportFrame
local rays: { Frame } = {}
local flash: Frame
local rarityLabel: TextLabel
local nameLabel: TextLabel
local newBadge: TextLabel
local infoLabel: TextLabel
local continueButton: TextButton
local queue: { { Creature: string, IsNew: boolean, Egg: string?, Shiny: boolean? } } = {}
local running = false
local continueClicked = false

local function setRays(visible: boolean, color: Color3?)
	for _, ray in rays do
		ray.Visible = visible
		if color then
			ray.BackgroundColor3 = color
		end
	end
end

local function play(entry: { Creature: string, IsNew: boolean, Egg: string?, Shiny: boolean? })
	local def = Creatures.Get(entry.Creature)
	if not def then
		return
	end
	local rarity = Rarities.Get(def.Rarity)
	local eggDef = entry.Egg and Eggs.Get(entry.Egg)
	local eggFruit = eggDef and Fruits.Get(eggDef.FruitId)

	gui.Enabled = true
	rarityLabel.Visible = false
	nameLabel.Visible = false
	newBadge.Visible = false
	infoLabel.Visible = false
	continueButton.Visible = false
	setRays(false)
	holderScale.Scale = UIKit.Scale

	-- 1) Egg shake
	local egg = ModelBuilder.Egg(eggFruit and eggFruit.Color or Color3.new(1, 1, 1), eggFruit and eggFruit.Color2 or Color3.fromRGB(255, 200, 120), eggFruit and eggFruit.Material, 4)
	Viewport.SetModel(viewport, egg, nil, nil, 0.9)
	local duration = rarity.RevealTime
	local start = os.clock()
	local nextTick = 0
	while os.clock() - start < duration do
		local t = os.clock() - start
		local intensity = (t / duration) ^ 1.5
		egg:PivotTo(CFrame.Angles(0, 0, math.sin(t * (14 + intensity * 30)) * (0.08 + intensity * 0.45)))
		if t >= nextTick then
			nextTick = t + math.max(0.12, 0.45 - intensity * 0.35)
			Effects.Play("Click", 0.8 + intensity)
		end
		RunService.RenderStepped:Wait()
	end

	-- 2) Crack + flash
	Effects.Play("Hatch")
	flash.BackgroundTransparency = 0
	flash.BackgroundColor3 = rarity.Order >= 5 and rarity.Color or Color3.new(1, 1, 1)
	UIKit.Tween(flash, 0.6, { BackgroundTransparency = 1 })

	-- 3) Reveal
	Viewport.SetModel(viewport, ModelBuilder.Creature(def.Id, 0, entry.Shiny), nil, 1.4, 0.85)
	setRays(rarity.Order >= 3, rarity.Color)
	rarityLabel.Text = (entry.Shiny and "✨ SHINY " or "") .. rarity.Name:upper()
	rarityLabel.TextColor3 = rarity.Order == 10 and Color3.new(1, 1, 1) or rarity.Color
	nameLabel.Text = def.Emoji .. " " .. def.DisplayName .. " " .. def.Emoji
	newBadge.Visible = entry.IsNew
	local bonus = Creatures.GetBonus(def.Id)
	local parts = {}
	if bonus.Coins > 0 then table.insert(parts, "🪙 " .. Format.Percent(bonus.Coins) .. " coins") end
	if bonus.Xp > 0 then table.insert(parts, "⭐ " .. Format.Percent(bonus.Xp) .. " XP") end
	if bonus.Speed > 0 then table.insert(parts, "⚡ " .. Format.Percent(bonus.Speed) .. " speed") end
	if bonus.Training > 0 then table.insert(parts, "🥋 " .. Format.Percent(bonus.Training) .. " training") end
	infoLabel.Text = "\"" .. def.Quote .. "\"\n" .. table.concat(parts, "   ")
	for _, label in { rarityLabel, nameLabel, infoLabel } do
		label.Visible = true
		local s = label:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = label })
		s.Scale = 0.3
		UIKit.Tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	Effects.Play("Reveal", rarity.Order >= 6 and 0.8 or 1.1)
	if entry.Shiny then
		Effects.Banner("✨ SHINY! ✨ (1% chance)", Color3.fromRGB(200, 245, 255), 2, 0.12)
	elseif rarity.Order >= 5 then
		Effects.Banner("✨ " .. rarity.Name:upper() .. "! ✨", rarity.Order == 10 and Color3.new(1, 1, 1) or rarity.Color, 1.6, 0.12)
	end

	-- spin the rays while waiting for the player
	continueClicked = false
	task.delay(0.6, function()
		continueButton.Visible = true
	end)
	local spinStart = os.clock()
	while not continueClicked and os.clock() - spinStart < 12 do
		local angle = (os.clock() - spinStart) * 25
		for i, ray in rays do
			ray.Rotation = angle + i * (180 / #rays)
		end
		RunService.RenderStepped:Wait()
	end
	Viewport.SetModel(viewport, nil)
end

local function processQueue()
	if running then
		return
	end
	running = true
	while #queue > 0 do
		local entry = table.remove(queue, 1) :: any
		play(entry)
	end
	gui.Enabled = false
	running = false
end

function HatchReveal.Show(creatureId: string, isNew: boolean, eggId: string?, shiny: boolean?)
	table.insert(queue, { Creature = creatureId, IsNew = isNew, Egg = eggId, Shiny = shiny })
	task.spawn(processQueue)
end

function HatchReveal.Init()
	gui = new("ScreenGui", { Name = "FNS_Hatch", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 40, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
	new("Frame", { BackgroundColor3 = Color3.fromRGB(10, 10, 25), BackgroundTransparency = 0.25, Size = UDim2.fromScale(1, 1), Active = true, Parent = gui })
	for i = 1, 6 do
		local ray = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.75, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.new(0, 46, 2, 0), Rotation = i * 30, Visible = false, Parent = gui })
		new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }), Rotation = 90, Parent = ray })
		table.insert(rays, ray)
	end
	holder = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(620, 560), Parent = gui })
	holderScale = new("UIScale", { Parent = holder })
	viewport = Viewport.Create({ Parent = holder, Size = UDim2.fromOffset(360, 300), Position = UDim2.new(0.5, 0, 0, 0), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 3 })
	rarityLabel = UIKit.Label({ Text = "", Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 300), Parent = holder, ZIndex = 4, StrokeThickness = 3.5 })
	nameLabel = UIKit.Label({ Text = "", Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 356), Parent = holder, ZIndex = 4, StrokeThickness = 2.5 })
	infoLabel = UIKit.Label({ Text = "", Font = Theme.BodyFont, Size = UDim2.new(1, -40, 0, 60), Position = UDim2.fromOffset(20, 398), Parent = holder, ZIndex = 4, MaxTextSize = 20 })
	newBadge = UIKit.Label({ Text = "NEW!", Color = C.Text, Size = UDim2.fromOffset(110, 40), Position = UDim2.new(0.5, 120, 0, 20), Parent = holder, ZIndex = 5, StrokeThickness = 2 })
	newBadge.BackgroundTransparency = 0
	newBadge.BackgroundColor3 = C.Red
	newBadge.Rotation = 12
	UIKit.Corner(12).Parent = newBadge
	continueButton = UIKit.Button({ Text = "Awesome! 🎉", Color = C.Green, Size = UDim2.fromOffset(240, 60), Position = UDim2.new(0.5, 0, 1, -70), AnchorPoint = Vector2.new(0.5, 0), Parent = holder, ZIndex = 6,
		OnClick = function()
			continueClicked = true
		end })
	flash = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 10, Parent = gui })

	Net.Event("HatchReveal").OnClientEvent:Connect(function(creatureId: string, isNew: boolean, _uid: string, eggId: string?, shiny: boolean?)
		HatchReveal.Show(creatureId, isNew, eggId, shiny)
	end)
end

return HatchReveal
