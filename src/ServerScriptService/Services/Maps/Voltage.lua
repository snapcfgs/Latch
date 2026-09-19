--!strict
--[[ Voltage (Small) — neon rooftops, thin bridges. ]]

local MapBuildUtil = require(script.Parent.MapBuildUtil)

local Voltage = {}

function Voltage.Build(): Folder
	local root = MapBuildUtil.NewRoot("Voltage")
	local tags = MapBuildUtil.MakeTagFolders(root)
	local geo = MapBuildUtil.Folder(root, "Geometry")

	-- Void under + neon pads as rooftops
	MapBuildUtil.Part(geo, "VoidPad", Vector3.new(110, 2, 80), CFrame.new(0, -8, 0), Color3.fromRGB(15, 20, 35), Enum.Material.SmoothPlastic)

	local neon = Color3.fromRGB(40, 220, 200)
	local roof = Color3.fromRGB(45, 50, 70)

	-- Twin rooftop slabs
	MapBuildUtil.Part(geo, "RoofA", Vector3.new(36, 2, 40), CFrame.new(-30, 8, 0), roof, Enum.Material.Metal)
	MapBuildUtil.Part(geo, "RoofB", Vector3.new(36, 2, 40), CFrame.new(30, 8, 0), roof, Enum.Material.Metal)
	-- Mid island
	MapBuildUtil.Part(geo, "RoofMid", Vector3.new(18, 2, 22), CFrame.new(0, 10, 0), Color3.fromRGB(50, 55, 80), Enum.Material.Metal)

	-- Neon edge strips
	MapBuildUtil.Part(geo, "NeonA1", Vector3.new(36, 0.4, 0.6), CFrame.new(-30, 9.2, -20), neon, Enum.Material.Neon)
	MapBuildUtil.Part(geo, "NeonA2", Vector3.new(36, 0.4, 0.6), CFrame.new(-30, 9.2, 20), neon, Enum.Material.Neon)
	MapBuildUtil.Part(geo, "NeonB1", Vector3.new(36, 0.4, 0.6), CFrame.new(30, 9.2, -20), neon, Enum.Material.Neon)
	MapBuildUtil.Part(geo, "NeonB2", Vector3.new(36, 0.4, 0.6), CFrame.new(30, 9.2, 20), neon, Enum.Material.Neon)

	-- Thin bridges
	MapBuildUtil.TaggedPart(tags, "Chokepoint", "BridgeNorth", Vector3.new(24, 1, 3), CFrame.new(0, 9, -10), Color3.fromRGB(60, 70, 90), Enum.Material.Metal)
	MapBuildUtil.TaggedPart(tags, "Chokepoint", "BridgeSouth", Vector3.new(24, 1, 3), CFrame.new(0, 9, 10), Color3.fromRGB(60, 70, 90), Enum.Material.Metal)
	MapBuildUtil.TaggedPart(tags, "Chokepoint", "BridgeMidA", Vector3.new(12, 1, 2.5), CFrame.new(-12, 9.5, 0), Color3.fromRGB(55, 200, 180), Enum.Material.Neon)
	MapBuildUtil.TaggedPart(tags, "Chokepoint", "BridgeMidB", Vector3.new(12, 1, 2.5), CFrame.new(12, 9.5, 0), Color3.fromRGB(55, 200, 180), Enum.Material.Neon)

	-- Cover AC units / crates on roofs
	MapBuildUtil.TaggedPart(tags, "Cover", "AC_A1", Vector3.new(5, 3, 4), CFrame.new(-35, 10.5, -8), Color3.fromRGB(70, 80, 95))
	MapBuildUtil.TaggedPart(tags, "Cover", "AC_A2", Vector3.new(4, 2.5, 5), CFrame.new(-25, 10.25, 10), Color3.fromRGB(70, 80, 95))
	MapBuildUtil.TaggedPart(tags, "Cover", "AC_B1", Vector3.new(5, 3, 4), CFrame.new(35, 10.5, 8), Color3.fromRGB(80, 70, 95))
	MapBuildUtil.TaggedPart(tags, "Cover", "AC_B2", Vector3.new(4, 2.5, 5), CFrame.new(25, 10.25, -10), Color3.fromRGB(80, 70, 95))
	MapBuildUtil.TaggedPart(tags, "Cover", "VentMid", Vector3.new(4, 3, 4), CFrame.new(0, 12.5, 0), Color3.fromRGB(90, 100, 120))

	-- High ground towers
	MapBuildUtil.TaggedPart(tags, "HighGround", "TowerA", Vector3.new(8, 1.2, 8), CFrame.new(-38, 14, 0), Color3.fromRGB(55, 60, 85))
	MapBuildUtil.TaggedPart(tags, "HighGround", "LadderA", Vector3.new(2, 5, 4), CFrame.new(-34, 11.5, 0) * CFrame.Angles(0, 0, math.rad(-30)), Color3.fromRGB(55, 60, 85))
	MapBuildUtil.TaggedPart(tags, "HighGround", "TowerB", Vector3.new(8, 1.2, 8), CFrame.new(38, 14, 0), Color3.fromRGB(85, 55, 70))
	MapBuildUtil.TaggedPart(tags, "HighGround", "LadderB", Vector3.new(2, 5, 4), CFrame.new(34, 11.5, 0) * CFrame.Angles(0, 0, math.rad(30)), Color3.fromRGB(85, 55, 70))

	-- Soft outer rails (keep players on roofs)
	MapBuildUtil.Part(geo, "RailAW", Vector3.new(1, 3, 40), CFrame.new(-48, 10.5, 0), Color3.fromRGB(30, 180, 160), Enum.Material.Neon)
	MapBuildUtil.Part(geo, "RailBE", Vector3.new(1, 3, 40), CFrame.new(48, 10.5, 0), Color3.fromRGB(30, 180, 160), Enum.Material.Neon)

	MapBuildUtil.MirroredSpawns(root, {
		CFrame.new(-40, 10, -10) * CFrame.Angles(0, math.rad(90), 0),
		CFrame.new(-40, 10, 10) * CFrame.Angles(0, math.rad(90), 0),
		CFrame.new(-36, 15, 0) * CFrame.Angles(0, math.rad(90), 0),
		CFrame.new(-38, 10, 0) * CFrame.Angles(0, math.rad(90), 0),
	}, {
		CFrame.new(40, 10, 10) * CFrame.Angles(0, math.rad(-90), 0),
		CFrame.new(40, 10, -10) * CFrame.Angles(0, math.rad(-90), 0),
		CFrame.new(36, 15, 0) * CFrame.Angles(0, math.rad(-90), 0),
		CFrame.new(38, 10, 0) * CFrame.Angles(0, math.rad(-90), 0),
	})

	MapBuildUtil.PlaceWaypointGrid(root, -42, 42, -16, 16, 10, 10)
	-- Extra mid / bridge waypoints
	local wp = root:FindFirstChild("Waypoints") :: Folder
	MapBuildUtil.InvisibleMarker(wp, "WP_BridgeN", Vector3.new(0, 10, -10), "Waypoint")
	MapBuildUtil.InvisibleMarker(wp, "WP_BridgeS", Vector3.new(0, 10, 10), "Waypoint")
	MapBuildUtil.InvisibleMarker(wp, "WP_Mid", Vector3.new(0, 12, 0), "Waypoint")

	MapBuildUtil.PlaceCoverNodes(root, {
		Vector3.new(-35, 10.5, -8),
		Vector3.new(-25, 10.5, 10),
		Vector3.new(35, 10.5, 8),
		Vector3.new(25, 10.5, -10),
		Vector3.new(0, 12.5, 0),
		Vector3.new(-38, 15, 0),
		Vector3.new(38, 15, 0),
		Vector3.new(-12, 10.5, 0),
		Vector3.new(12, 10.5, 0),
	})

	MapBuildUtil.KillFloor(root, Vector3.new(220, 2, 160), -4)
	return root
end

return Voltage
