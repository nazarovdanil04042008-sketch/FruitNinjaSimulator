--!nonstrict
-- ViewportFrame helpers for 3D previews (katanas, creatures, eggs) inside the UI.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelBuilder = require(ReplicatedStorage.Shared.Util.ModelBuilder)

local Viewport = {}

type SpinEntry = { Model: Model, Base: CFrame, Speed: number, Frame: ViewportFrame }
local spinning: { [ViewportFrame]: SpinEntry } = {}

function Viewport.Create(props: { [string]: any }): ViewportFrame
	local vpf = Instance.new("ViewportFrame")
	vpf.Name = props.Name or "Viewport"
	vpf.BackgroundTransparency = 1
	vpf.Size = props.Size or UDim2.fromScale(1, 1)
	vpf.Position = props.Position or UDim2.new()
	vpf.AnchorPoint = props.AnchorPoint or Vector2.zero
	vpf.ZIndex = props.ZIndex or 1
	vpf.LightColor = Color3.fromRGB(255, 250, 240)
	vpf.LightDirection = Vector3.new(-0.5, -1, 0.8)
	vpf.Ambient = Color3.fromRGB(170, 170, 180)
	vpf.LayoutOrder = props.LayoutOrder or 0
	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	camera.Parent = vpf
	vpf.CurrentCamera = camera
	vpf.Parent = props.Parent
	return vpf
end

-- Replaces whatever model is in the viewport. `rotation` tilts the model (e.g. katanas diagonally).
function Viewport.SetModel(vpf: ViewportFrame, model: Model?, rotation: CFrame?, spinSpeed: number?, zoom: number?)
	for _, child in vpf:GetChildren() do
		if child:IsA("Model") or child:IsA("WorldModel") then
			child:Destroy()
		end
	end
	spinning[vpf] = nil
	if not model then
		return
	end
	ModelBuilder.AnchorAll(model)
	local base = rotation or CFrame.new()
	model:PivotTo(base)
	model.Parent = vpf
	local cf, size = model:GetBoundingBox()
	local camera = vpf.CurrentCamera :: Camera
	local distance = size.Magnitude * 1.35 * (zoom or 1) + 0.5
	camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, size.Y * 0.08, -distance), cf.Position)
	if spinSpeed and spinSpeed ~= 0 then
		spinning[vpf] = { Model = model, Base = base, Speed = spinSpeed, Frame = vpf }
	end
end

function Viewport.CreatureModel(creatureId: string): Model
	return ModelBuilder.Creature(creatureId)
end

function Viewport.KatanaModel(katanaId: string): Model
	return ModelBuilder.Katana(katanaId)
end

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for vpf, entry in spinning do
		if not vpf.Parent then
			spinning[vpf] = nil
		elseif vpf.Visible then
			entry.Model:PivotTo(CFrame.Angles(0, math.sin(t * entry.Speed) * 0.9, 0) * entry.Base)
		end
	end
end)

return Viewport
