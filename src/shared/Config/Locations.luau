--!strict
-- Named world locations (used by the world builder, the Teleport menu and server teleport validation).

local Arenas = require(script.Parent.Arenas)
local Training = require(script.Parent.Training)

export type Location = {
	Id: string,
	DisplayName: string,
	Emoji: string,
	Position: Vector3, -- where players are teleported (standing height added by the server)
	ArenaId: string?, -- requires the arena's level when set
	Color: Color3,
}

local list: { Location } = {
	{ Id = "Spawn", DisplayName = "Spawn", Emoji = "🏠", Position = Vector3.new(0, 3, 10), Color = Color3.fromRGB(255, 200, 70) },
	{ Id = "Dojo", DisplayName = "Training Dojo", Emoji = "🥋", Position = Training.DojoOrigin + Vector3.new(0, 3, 22), Color = Color3.fromRGB(255, 110, 90) },
	{ Id = "Shops", DisplayName = "Shops", Emoji = "🛒", Position = Vector3.new(-190, 3, 10), Color = Color3.fromRGB(90, 200, 255) },
	{ Id = "Hatchery", DisplayName = "Egg Hatchery", Emoji = "🥚", Position = Vector3.new(0, 3, 160), Color = Color3.fromRGB(255, 160, 220) },
}

for _, arena in Arenas.List do
	table.insert(list, {
		Id = arena.Id,
		DisplayName = arena.DisplayName,
		Emoji = arena.Order == 1 and "🍎" or arena.Order == 2 and "🍍" or "🌌",
		Position = arena.Origin + Vector3.new(0, 3, 34),
		ArenaId = arena.Id,
		Color = arena.AccentColor,
	})
end

local Locations = {
	List = list,
	ById = {} :: { [string]: Location },
}

for _, loc in list do
	Locations.ById[loc.Id] = loc
end

return Locations
