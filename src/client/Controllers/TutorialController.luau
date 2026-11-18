--!nonstrict
-- First-time tutorial: a card at the bottom of the screen with the current step, and a glowing guide
-- line + bouncing arrow pointing to where you need to go. Steps complete automatically from your
-- profile; the server checks everything again before paying the reward (CompleteTutorial).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Arenas = require(Shared.Config.Arenas)
local Buildings = require(Shared.Config.Buildings)
local Training = require(Shared.Config.Training)

local UI = script.Parent.Parent.UI
local UIKit = require(UI.UIKit)
local Theme = require(UI.Theme)
local Effects = require(UI.Effects)
local State = require(script.Parent.State)

local TutorialController = {}
TutorialController.Hidden = false -- set while slicing / training

local C = Theme.Colors
local new = UIKit.new
local player = Players.LocalPlayer

type Step = { Text: string, Done: (profile: any) -> boolean, Progress: ((profile: any) -> string)?, Target: () -> Vector3? }

local orchard = Arenas.Get("Orchard")
local STEPS: { Step } = {
	{ Text = "⚔️ Slice 10 fruit in Sunny Orchard (step on a glowing pad)", Done = function(p) return p.Totals.FruitsSliced >= 10 end,
		Progress = function(p) return math.min(p.Totals.FruitsSliced, 10) .. "/10" end,
		Target = function() return orchard and Arenas.GetPadPosition(orchard, 3) end },
	{ Text = "🗡️ Buy the Iron Katana at the Katana Shop (or ⚔️ Katanas menu)", Done = function(p) return p.OwnedKatanas.Iron == true end,
		Target = function() return Vector3.new(-210, 0, -25) end },
	{ Text = "🏋️ Finish one training at the Dojo", Done = function(p) return p.Totals.TrainingsDone >= 1 end,
		Target = function() return Training.Get("Speed").Station end },
	{ Text = "🥚 Hatch an egg (slice eggs, then open 🥚 Eggs)", Done = function(p) return p.Totals.EggsHatched >= 1 end,
		Target = function() return Vector3.new(-16, 0, 180) end },
	{ Text = "🏯 Place a building in your village (🏯 Village menu)", Done = function(p) return #p.Buildings >= 1 end,
		Target = function()
			local index = player:GetAttribute("PlotIndex")
			return type(index) == "number" and Buildings.Plots[index] or Vector3.new(-194, 0, 122)
		end },
}

local gui: ScreenGui
local cardFrame: Frame
local stepLabel: TextLabel
local claimButton: TextButton
local beam: Beam
local targetPart: Part
local arrow: Part
local startAttachment: Attachment
local currentStep = 0

local function currentIndex(profile: any): number
	for i, step in STEPS do
		if not step.Done(profile) then
			return i
		end
	end
	return #STEPS + 1
end

local function attachToCharacter()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		startAttachment.Parent = root
	end
end

local function update()
	local profile = State.Profile
	if not profile or profile.TutorialDone then
		gui.Enabled = false
		beam.Enabled = false
		arrow.Transparency = 1
		return
	end
	gui.Enabled = not TutorialController.Hidden
	local index = currentIndex(profile)
	if index ~= currentStep then
		if currentStep > 0 and index > currentStep then
			Effects.Play("LevelUp", 1.3)
			Effects.Banner("✅ Step complete!", C.Green, 1.2, 0.35)
		end
		currentStep = index
	end
	if index > #STEPS then
		stepLabel.Text = "🎓 Tutorial complete! Claim 🪙 800 coins + a Spotted Egg"
		claimButton.Visible = true
		beam.Enabled = false
		arrow.Transparency = 1
		return
	end
	claimButton.Visible = false
	local step = STEPS[index]
	stepLabel.Text = string.format("Step %d/%d: %s%s", index, #STEPS, step.Text, step.Progress and ("  (" .. step.Progress(profile) .. ")") or "")
	local target = step.Target()
	if target and not TutorialController.Hidden then
		targetPart.Position = target + Vector3.new(0, 3, 0)
		beam.Enabled = true
		arrow.Transparency = 0
	else
		beam.Enabled = false
		arrow.Transparency = 1
	end
end

function TutorialController.Init()
	gui = new("ScreenGui", { Name = "FNS_Tutorial", ResetOnSpawn = false, DisplayOrder = 13, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
	cardFrame = new("Frame", { BackgroundColor3 = C.Panel, BackgroundTransparency = 0.1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(620, 78), Parent = gui })
	UIKit.AutoScale(cardFrame)
	UIKit.Corner(16).Parent = cardFrame
	UIKit.Stroke(3, C.Coins).Parent = cardFrame
	stepLabel = UIKit.Label({ Text = "", Size = UDim2.new(1, -150, 1, -14), Position = UDim2.fromOffset(12, 7), AlignX = Enum.TextXAlignment.Left, Parent = cardFrame, MaxTextSize = 22 })
	claimButton = UIKit.Button({ Text = "🎁 Claim", Color = C.Green, Size = UDim2.fromOffset(120, 54), Position = UDim2.new(1, -130, 0, 12), Parent = cardFrame,
		OnClick = function()
			State.Action("CompleteTutorial", false)
		end })
	claimButton.Visible = false
	UIKit.Button({ Text = "Skip", Color = C.Gray, Size = UDim2.fromOffset(70, 30), Position = UDim2.new(1, -78, 0, -36), Parent = cardFrame, MaxTextSize = 16,
		OnClick = function()
			UIKit.Confirm("Skip the tutorial?", "You won't get the tutorial reward.", "Skip", function()
				State.Action("CompleteTutorial", true, true)
			end)
		end })

	-- guide line from you to the target + bouncing arrow over the target
	local folder = Instance.new("Folder")
	folder.Name = "FNS_TutorialGuide"
	folder.Parent = workspace
	targetPart = Instance.new("Part")
	targetPart.Anchored = true
	targetPart.CanCollide = false
	targetPart.CanQuery = false
	targetPart.Transparency = 1
	targetPart.Size = Vector3.one
	targetPart.Parent = folder
	local endAttachment = Instance.new("Attachment")
	endAttachment.Parent = targetPart
	startAttachment = Instance.new("Attachment")
	startAttachment.Name = "FNS_TutorialStart"
	beam = Instance.new("Beam")
	beam.Attachment0 = startAttachment
	beam.Attachment1 = endAttachment
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 230, 90), Color3.fromRGB(255, 150, 40))
	beam.LightEmission = 1
	beam.Width0 = 0.8
	beam.Width1 = 0.8
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 0.1) })
	beam.Enabled = false
	beam.Parent = folder
	arrow = Instance.new("Part")
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.CanQuery = false
	arrow.Material = Enum.Material.Neon
	arrow.Color = Color3.fromRGB(255, 220, 60)
	arrow.Size = Vector3.new(2.4, 3, 2.4)
	arrow.Transparency = 1
	arrow.Parent = folder

	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		attachToCharacter()
	end)
	attachToCharacter()
	State.Changed:Connect(update)
	RunService.RenderStepped:Connect(function()
		if arrow.Transparency < 1 then
			local t = os.clock()
			arrow.CFrame = CFrame.new(targetPart.Position + Vector3.new(0, 6 + math.sin(t * 3) * 1, 0)) * CFrame.Angles(0, t * 2, math.rad(45))
		end
	end)
	task.spawn(function()
		while true do
			update()
			task.wait(1)
		end
	end)
end

function TutorialController.SetHidden(hidden: boolean)
	TutorialController.Hidden = hidden
end

return TutorialController
