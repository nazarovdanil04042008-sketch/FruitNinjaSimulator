--!nonstrict
-- Sounds + lightweight 2D feedback (floating text, stat popups, level up banner, screen shake hooks).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Theme = require(script.Parent.Theme)

local Effects = {}

local player = Players.LocalPlayer
local pools: { [string]: { sounds: { Sound }, index: number } } = {}
local fxGui: ScreenGui

local function getPool(name: string)
	local pool = pools[name]
	if pool then
		return pool
	end
	local info = (Sounds :: any)[name]
	pool = { sounds = {}, index = 1 }
	if info then
		for _ = 1, 4 do
			local sound = Instance.new("Sound")
			sound.SoundId = info.Id
			sound.Volume = info.Volume
			sound.Parent = SoundService
			table.insert(pool.sounds, sound)
		end
	end
	pools[name] = pool
	return pool
end

function Effects.Play(name: string, pitch: number?)
	local pool = getPool(name)
	if #pool.sounds == 0 then
		return
	end
	local sound = pool.sounds[pool.index]
	pool.index = pool.index % #pool.sounds + 1
	sound.PlaybackSpeed = pitch or 1
	sound.TimePosition = 0
	sound:Play()
end

function Effects.GetGui(): ScreenGui
	return fxGui
end

-- Text that rises and fades at a screen position (pixels, GUI-inset space).
function Effects.FloatText(position: Vector2, text: string, color: Color3, size: number?)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromOffset(position.X, position.Y)
	label.Size = UDim2.fromOffset(220, size or 34)
	label.BackgroundTransparency = 1
	label.Font = Theme.Font
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.ZIndex = 20
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Theme.Colors.Stroke
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = label
	label.Parent = fxGui
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(position.X, position.Y - 70),
		TextTransparency = 1,
	}):Play()
	TweenService:Create(stroke, TweenInfo.new(0.9), { Transparency = 1 }):Play()
	task.delay(0.95, function()
		label:Destroy()
	end)
end

-- Big centred banner (level up, combo, frenzy...)
function Effects.Banner(text: string, color: Color3, duration: number?, yScale: number?)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, yScale or 0.3)
	label.Size = UDim2.fromScale(0.6, 0.11)
	label.BackgroundTransparency = 1
	label.Font = Theme.Font
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.ZIndex = 30
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Theme.Colors.Stroke
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = label
	label.Parent = fxGui
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(duration or 1.4, function()
		TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		TweenService:Create(scale, TweenInfo.new(0.3), { Scale = 1.3 }):Play()
		task.wait(0.32)
		label:Destroy()
	end)
end

local STAT_COLORS = {
	Speed = Color3.fromRGB(60, 200, 255),
	Strength = Color3.fromRGB(255, 90, 80),
	Agility = Color3.fromRGB(120, 230, 90),
	["Training Level"] = Color3.fromRGB(255, 200, 60),
}
local STAT_EMOJI = { Speed = "⚡", Strength = "💪", Agility = "🌀", ["Training Level"] = "🥋" }

function Effects.StatPopup(stat: string, amount: number)
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1100, 620)
	local text
	if stat == "Training Level" then
		text = "🥋 Training Level " .. amount .. "!"
	else
		text = string.format("+%d %s %s!", amount, STAT_EMOJI[stat] or "", stat)
	end
	local jitter = (math.random() - 0.5) * 120
	Effects.FloatText(Vector2.new(viewport.X / 2 + jitter, viewport.Y * 0.55), text, STAT_COLORS[stat] or Theme.Colors.Text, 44)
	Effects.Play("Coin", 1.3)
end

function Effects.Init()
	fxGui = Instance.new("ScreenGui")
	fxGui.Name = "FNS_FX"
	fxGui.ResetOnSpawn = false
	fxGui.DisplayOrder = 50
	fxGui.IgnoreGuiInset = false
	fxGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	fxGui.Parent = player:WaitForChild("PlayerGui")
end

return Effects
