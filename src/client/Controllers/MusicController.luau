--!nonstrict
-- Background music with smooth cross-fades: day theme, night theme, and a boss theme near an active
-- boss. Track ids are set in Config/Sounds (MusicDay / MusicNight / MusicBoss); empty = silent.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Sounds = require(Shared.Config.Sounds)
local LiveOps = require(Shared.Config.LiveOps)

local MusicController = {}

local player = Players.LocalPlayer
local tracks: { [string]: Sound } = {}
local current: string? = nil

local function pick(): string
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if workspace:GetAttribute("FNS_BossActive") and root then
		local c = LiveOps.BossArena
		if Vector2.new(root.Position.X - c.X, root.Position.Z - c.Z).Magnitude < 120 then
			return "MusicBoss"
		end
	end
	local clock = Lighting.ClockTime
	return (clock >= 19 or clock < 5.5) and "MusicNight" or "MusicDay"
end

local function switch(name: string)
	if current == name then
		return
	end
	for key, sound in tracks do
		local info = (Sounds :: any)[key]
		local target = key == name and info.Volume or 0
		TweenService:Create(sound, TweenInfo.new(2.5), { Volume = target }):Play()
		if key == name and not sound.IsPlaying then
			sound:Play()
		end
	end
	current = name
end

function MusicController.Init()
	for _, key in { "MusicDay", "MusicNight", "MusicBoss" } do
		local info = (Sounds :: any)[key]
		if info and info.Id ~= "" then
			local sound = Instance.new("Sound")
			sound.Name = key
			sound.SoundId = info.Id
			sound.Looped = true
			sound.Volume = 0
			sound.Parent = SoundService
			tracks[key] = sound
		end
	end
	if next(tracks) == nil then
		return -- no music configured
	end
	task.spawn(function()
		while true do
			local wanted = pick()
			if tracks[wanted] then
				switch(wanted)
			end
			task.wait(2)
		end
	end)
end

return MusicController
