--!nonstrict
-- Colours / fonts for the whole interface.

local Theme = {}

Theme.Font = Enum.Font.FredokaOne
Theme.BodyFont = Enum.Font.GothamBold

Theme.Colors = {
	Background = Color3.fromRGB(30, 32, 52),
	Panel = Color3.fromRGB(44, 47, 76),
	PanelLight = Color3.fromRGB(62, 66, 104),
	Card = Color3.fromRGB(56, 60, 96),
	Text = Color3.fromRGB(255, 255, 255),
	SubText = Color3.fromRGB(190, 195, 225),
	Stroke = Color3.fromRGB(18, 18, 32),
	Coins = Color3.fromRGB(255, 205, 50),
	Xp = Color3.fromRGB(90, 220, 255),
	Green = Color3.fromRGB(80, 210, 100),
	Red = Color3.fromRGB(240, 80, 80),
	Blue = Color3.fromRGB(70, 150, 255),
	Purple = Color3.fromRGB(160, 100, 255),
	Orange = Color3.fromRGB(255, 150, 50),
	Pink = Color3.fromRGB(255, 110, 190),
	Gray = Color3.fromRGB(120, 124, 150),
	Locked = Color3.fromRGB(85, 88, 110),
}

-- Reference resolution: everything is designed at 1100x620 and scaled with a UIScale.
Theme.ReferenceSize = Vector2.new(1100, 620)

return Theme
