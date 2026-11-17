--!strict
-- Deterministic fruit flight. The server only sends launch parameters; the client computes positions
-- from the shared server clock, so every object is perfectly smooth and costs zero network traffic in flight.
-- Coordinates are relative to the stage centre: x = sideways, y = up, z = small depth jitter.

local GameConfig = require(script.Parent.Parent.Config.GameConfig)

local Trajectory = {}

export type Launch = {
	X0: number,
	Y0: number,
	Z: number,
	VX: number,
	VY: number,
	Spin: number,
}

function Trajectory.Position(launch: Launch, t: number): Vector3
	local g = GameConfig.Gravity
	return Vector3.new(launch.X0 + launch.VX * t, launch.Y0 + launch.VY * t - 0.5 * g * t * t, launch.Z)
end

-- Time until the object falls back to its launch height (i.e. leaves the screen).
function Trajectory.Lifetime(launch: Launch): number
	local g = GameConfig.Gravity
	return 2 * launch.VY / g + 0.15
end

-- Build launch parameters. `rng` is a Random object. apexHeight is measured from the launch height.
function Trajectory.Create(rng: Random, halfWidth: number, launchY: number, apexMin: number, apexMax: number): Launch
	local g = GameConfig.Gravity
	local apex = rng:NextNumber(apexMin, apexMax)
	local vy = math.sqrt(2 * g * apex)
	local x0 = rng:NextNumber(-halfWidth, halfWidth)
	local flightTime = 2 * vy / g
	-- Aim to land somewhere within the visible width so fruits arc across the screen.
	local targetX = rng:NextNumber(-halfWidth, halfWidth) * 0.8
	local vx = (targetX - x0) / flightTime
	return {
		X0 = x0,
		Y0 = launchY,
		Z = rng:NextNumber(-2, 2),
		VX = vx,
		VY = vy,
		Spin = rng:NextNumber(-4, 4),
	}
end

return Trajectory
