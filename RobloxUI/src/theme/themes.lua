local function hex(value)
	return Color3.fromHex(value)
end

return {
	Dark = {
		Colors = {
			Window = hex("0E0E10"),
			Sidebar = hex("131316"),
			Card = hex("18181B"),
			Control = hex("232328"),
			ControlHover = hex("2C2C32"),
			ControlPressed = hex("36363D"),
			Stroke = hex("2A2A30"),
			Divider = hex("26262B"),
			Text = hex("F2F2F4"),
			TextDim = hex("A1A1AA"),
			TextMuted = hex("6B6B74"),
			Accent = hex("FF7A2F"),
			AccentText = hex("FFFFFF"),
			AccentAlt = hex("FF4F8B"),
			Danger = hex("FF5A5A"),
			Success = hex("4CD08B"),
			Warning = hex("FFC24B"),
		},
		Radius = { Window = 12, Card = 10, Control = 8 },
		Spacing = {
			Padding = 12,
			Gap = 8,
			Row = 34,
			RowTouch = 44,
			Header = 40,
			TopBar = 52,
			Sidebar = 196,
			SidebarRail = 60,
		},
		Font = {
			Regular = Enum.Font.Gotham,
			Medium = Enum.Font.GothamMedium,
			Bold = Enum.Font.GothamBold,
		},
		TextSize = { Title = 17, Header = 15, Body = 14, Small = 12 },
		Animation = { Fast = 0.12, Normal = 0.2, Slow = 0.35 },

		Transparency = { Toast = 0.2, Pill = 0.12, Card = 0.04, Glow = 0.9, BrandGlow = 0.82 },
	},

	Mono = {
		Colors = {
			Window = hex("0A0A0A"),
			Sidebar = hex("0F0F0F"),
			Card = hex("141414"),
			Control = hex("1F1F1F"),
			ControlHover = hex("2A2A2A"),
			ControlPressed = hex("353535"),
			Stroke = hex("2A2A2A"),
			Divider = hex("232323"),
			Text = hex("F5F5F5"),
			TextDim = hex("A3A3A3"),
			TextMuted = hex("666666"),
			Accent = hex("F5F5F5"),
			AccentAlt = hex("8C8C8C"),
			AccentText = hex("0A0A0A"),
			Danger = hex("E5E5E5"),
			Success = hex("D4D4D4"),
			Warning = hex("BDBDBD"),
		},
		Transparency = { Glow = 0.95, BrandGlow = 0.93 },
	},

	Ocean = {
		Colors = { Accent = hex("3B9BFF"), AccentAlt = hex("A855F7") },
	},
}
