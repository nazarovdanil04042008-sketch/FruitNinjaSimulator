--!strict
-- Grid maths for building on plots, shared by the server (validation) and the client (ghost preview),
-- so "can I place here?" always gets the same answer on both sides.

local Buildings = require(script.Parent.Parent.Config.Buildings)

local PlotGrid = {}

PlotGrid.Cell = 4
PlotGrid.Size = Buildings.PlotSize // 4 -- 11 x 11 cells
PlotGrid.FloorY = 1 -- top of the plot base

function PlotGrid.Footprint(def: Buildings.BuildingDef, rotation: number): (number, number)
	if rotation % 2 == 1 then
		return def.Depth, def.Width
	end
	return def.Width, def.Depth
end

function PlotGrid.InBounds(def: Buildings.BuildingDef, gx: number, gz: number, rotation: number): boolean
	local w, d = PlotGrid.Footprint(def, rotation)
	return gx >= 0 and gz >= 0 and gx + w <= PlotGrid.Size and gz + d <= PlotGrid.Size
end

-- Set of occupied cells "x,z" from a list of placed buildings ({Uid, Id, X, Z, R}).
function PlotGrid.Occupied(placed: { any }, ignoreUid: string?): { [string]: boolean }
	local cells = {}
	for _, item in placed do
		local def = Buildings.Get(item.Id)
		if def and item.Uid ~= ignoreUid then
			local w, d = PlotGrid.Footprint(def, item.R)
			for x = item.X, item.X + w - 1 do
				for z = item.Z, item.Z + d - 1 do
					cells[x .. "," .. z] = true
				end
			end
		end
	end
	return cells
end

function PlotGrid.CanPlace(placed: { any }, id: string, gx: number, gz: number, rotation: number, ignoreUid: string?): boolean
	local def = Buildings.Get(id)
	if not def or not PlotGrid.InBounds(def, gx, gz, rotation) then
		return false
	end
	local occupied = PlotGrid.Occupied(placed, ignoreUid)
	local w, d = PlotGrid.Footprint(def, rotation)
	for x = gx, gx + w - 1 do
		for z = gz, gz + d - 1 do
			if occupied[x .. "," .. z] then
				return false
			end
		end
	end
	return true
end

-- World CFrame of a building's centre (on the plot floor).
function PlotGrid.ToWorld(plotCenter: Vector3, def: Buildings.BuildingDef, gx: number, gz: number, rotation: number): CFrame
	local w, d = PlotGrid.Footprint(def, rotation)
	local half = PlotGrid.Size * PlotGrid.Cell / 2
	local x = plotCenter.X - half + (gx + w / 2) * PlotGrid.Cell
	local z = plotCenter.Z - half + (gz + d / 2) * PlotGrid.Cell
	return CFrame.new(x, plotCenter.Y + PlotGrid.FloorY, z) * CFrame.Angles(0, math.rad(rotation * 90), 0)
end

-- Grid cell whose footprint is centred as close as possible to a world point.
function PlotGrid.FromWorld(plotCenter: Vector3, def: Buildings.BuildingDef, position: Vector3, rotation: number): (number, number)
	local w, d = PlotGrid.Footprint(def, rotation)
	local half = PlotGrid.Size * PlotGrid.Cell / 2
	local gx = math.floor((position.X - plotCenter.X + half) / PlotGrid.Cell - w / 2 + 0.5)
	local gz = math.floor((position.Z - plotCenter.Z + half) / PlotGrid.Cell - d / 2 + 0.5)
	return gx, gz
end

function PlotGrid.CountPlaced(placed: { any }, id: string): number
	local n = 0
	for _, item in placed do
		if item.Id == id then
			n += 1
		end
	end
	return n
end

return PlotGrid
