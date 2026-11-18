--!strict
-- Central sound list. These use sounds that ship with the Roblox client (rbxasset://),
-- so they work in every place without uploading anything.
-- To customise, replace any value with "rbxassetid://<your id>".

return {
	Slice = { Id = "rbxasset://sounds/swordslash.wav", Volume = 0.45 },
	SliceHeavy = { Id = "rbxasset://sounds/swordlunge.wav", Volume = 0.5 },
	Bomb = { Id = "rbxasset://sounds/Rocket shot.wav", Volume = 0.6 },
	Equip = { Id = "rbxasset://sounds/unsheath.wav", Volume = 0.5 },
	Click = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.25 },
	Coin = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.35 },
	Purchase = { Id = "rbxasset://sounds/unsheath.wav", Volume = 0.5 },
	Error = { Id = "rbxasset://sounds/uuhhh.mp3", Volume = 0.25 },
	LevelUp = { Id = "rbxasset://sounds/victory.wav", Volume = 0.5 },
	Hatch = { Id = "rbxasset://sounds/glassbreak.wav", Volume = 0.5 },
	Reveal = { Id = "rbxasset://sounds/victory.wav", Volume = 0.6 },
	Whoosh = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.3 },

	-- Background music (looped, cross-faded by MusicController). Roblox doesn't ship music with the
	-- client, so paste "rbxassetid://<id>" of tracks you pick in Creator Store → Audio (filter "Music",
	-- search "japanese", "koto", "shamisen", "epic boss"). Leave "" to keep silent.
	MusicDay = { Id = "", Volume = 0.25 },
	MusicNight = { Id = "", Volume = 0.22 },
	MusicBoss = { Id = "", Volume = 0.35 },
}
