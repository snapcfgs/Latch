--!strict
--[[
	Maps — registry of original Latch arenas (Phase 1).
	Balance / presentation only; geometry lives in ServerScriptService/Services/Maps/.
]]

export type SizeClass = "Small" | "Medium" | "Large"

export type LightingHints = {
	ClockTime: number,
	FogEnd: number,
	FogStart: number,
	FogColor: Color3,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	Brightness: number?,
}

export type MapDef = {
	Id: string,
	DisplayName: string,
	SizeClass: SizeClass,
	ThumbnailColor: Color3,
	Description: string,
	Lighting: LightingHints,
}

local Maps = {
	Order = { "Splityard", "Voltage", "Hollow", "Dredge", "Glassline", "Ridge" } :: { string },

	Maps = {
		Splityard = {
			Id = "Splityard",
			DisplayName = "Splityard",
			SizeClass = "Small",
			ThumbnailColor = Color3.fromRGB(140, 110, 70),
			Description = "Twin warehouses with a mid crate lane.",
			Lighting = {
				ClockTime = 14.5,
				FogStart = 80,
				FogEnd = 220,
				FogColor = Color3.fromRGB(180, 170, 150),
				Ambient = Color3.fromRGB(90, 85, 75),
				OutdoorAmbient = Color3.fromRGB(120, 115, 100),
				Brightness = 2,
			},
		},
		Voltage = {
			Id = "Voltage",
			DisplayName = "Voltage",
			SizeClass = "Small",
			ThumbnailColor = Color3.fromRGB(40, 200, 180),
			Description = "Neon rooftops linked by thin bridges.",
			Lighting = {
				ClockTime = 22,
				FogStart = 40,
				FogEnd = 160,
				FogColor = Color3.fromRGB(20, 40, 60),
				Ambient = Color3.fromRGB(40, 60, 90),
				OutdoorAmbient = Color3.fromRGB(30, 50, 80),
				Brightness = 1.5,
			},
		},
		Hollow = {
			Id = "Hollow",
			DisplayName = "Hollow",
			SizeClass = "Medium",
			ThumbnailColor = Color3.fromRGB(100, 90, 130),
			Description = "Indoor atrium with mezzanines — strong Splice angles.",
			Lighting = {
				ClockTime = 12,
				FogStart = 60,
				FogEnd = 180,
				FogColor = Color3.fromRGB(90, 95, 110),
				Ambient = Color3.fromRGB(70, 75, 95),
				OutdoorAmbient = Color3.fromRGB(80, 85, 100),
				Brightness = 1.8,
			},
		},
		Dredge = {
			Id = "Dredge",
			DisplayName = "Dredge",
			SizeClass = "Medium",
			ThumbnailColor = Color3.fromRGB(70, 95, 110),
			Description = "Dry dock / shipping — long AR lines and tight corridors.",
			Lighting = {
				ClockTime = 16.5,
				FogStart = 70,
				FogEnd = 200,
				FogColor = Color3.fromRGB(130, 140, 145),
				Ambient = Color3.fromRGB(75, 85, 90),
				OutdoorAmbient = Color3.fromRGB(100, 110, 115),
				Brightness = 2,
			},
		},
		Glassline = {
			Id = "Glassline",
			DisplayName = "Glassline",
			SizeClass = "Medium",
			ThumbnailColor = Color3.fromRGB(160, 200, 220),
			Description = "Office atrium with non-breakable glass sightlines.",
			Lighting = {
				ClockTime = 11,
				FogStart = 100,
				FogEnd = 280,
				FogColor = Color3.fromRGB(200, 210, 220),
				Ambient = Color3.fromRGB(110, 120, 130),
				OutdoorAmbient = Color3.fromRGB(140, 150, 160),
				Brightness = 2.2,
			},
		},
		Ridge = {
			Id = "Ridge",
			DisplayName = "Ridge",
			SizeClass = "Large",
			ThumbnailColor = Color3.fromRGB(120, 140, 90),
			Description = "Outdoor canyon — room for 3v3 / 4v4 later.",
			Lighting = {
				ClockTime = 17.2,
				FogStart = 120,
				FogEnd = 400,
				FogColor = Color3.fromRGB(190, 170, 140),
				Ambient = Color3.fromRGB(100, 95, 80),
				OutdoorAmbient = Color3.fromRGB(130, 120, 100),
				Brightness = 2.4,
			},
		},
	} :: { [string]: MapDef },
}

function Maps.Get(id: string): MapDef?
	return Maps.Maps[id]
end

function Maps.AllIds(): { string }
	local out = table.clone(Maps.Order)
	return out
end

return Maps
