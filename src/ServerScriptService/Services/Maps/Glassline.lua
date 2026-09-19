--!strict
--[[ Glassline (Medium) — office/atrium, transparent non-breakable glass Parts. ]]

local MapBuildUtil = require(script.Parent.MapBuildUtil)

local Glassline = {}

local function glass(parent: Instance, name: string, size: Vector3, cframe: CFrame): Part
	-- Non-breakable; CanCollide true so it blocks movement + bullets (sightline only via transparency)
	return MapBuildUtil.Part(
		parent,
		name,
		size,
		cframe,
		Color3.fromRGB(180, 210, 230),
		Enum.Material.Glass,
		{ Transparency = 0.55, Tag = "Glass" }
	)
end

function Glassline.Build(): Folder
	local root = MapBuildUtil.NewRoot("Glassline")
	local tags = MapBuildUtil.MakeTagFolders(root)
	local geo = MapBuildUtil.Folder(root, "Geometry")
	local glassFolder = MapBuildUtil.Folder(root, "Glass")

	local office = Color3.fromRGB(200, 205, 215)
	local carpet = Color3.fromRGB(90, 100, 120)

	MapBuildUtil.Part(geo, "Floor", Vector3.new(120, 2, 90), CFrame.new(0, -1, 0), carpet, Enum.Material.Fabric)
	MapBuildUtil.BoxWalls(geo, 61, 46, 18, 2, Color3.fromRGB(160, 165, 175))
	MapBuildUtil.Part(geo, "Ceiling", Vector3.new(120, 1.5, 90), CFrame.new(0, 17, 0), Color3.fromRGB(230, 235, 240), Enum.Material.SmoothPlastic)

	-- Central atrium
	MapBuildUtil.Part(geo, "AtriumTile", Vector3.new(24, 1, 24), CFrame.new(0, 0.5, 0), Color3.fromRGB(220, 225, 235), Enum.Material.Marble)

	-- Glass partitions (non-breakable) — create sightlines without freefire
	glass(glassFolder, "GlassMidN", Vector3.new(20, 8, 0.6), CFrame.new(0, 4, -14))
	glass(glassFolder, "GlassMidS", Vector3.new(20, 8, 0.6), CFrame.new(0, 4, 14))
	glass(glassFolder, "GlassWest", Vector3.new(0.6, 8, 18), CFrame.new(-18, 4, 0))
	glass(glassFolder, "GlassEast", Vector3.new(0.6, 8, 18), CFrame.new(18, 4, 0))
	-- Side office glass walls
	glass(glassFolder, "OfficeAN", Vector3.new(22, 7, 0.5), CFrame.new(-40, 4, -20))
	glass(glassFolder, "OfficeAS", Vector3.new(22, 7, 0.5), CFrame.new(-40, 4, 20))
	glass(glassFolder, "OfficeBN", Vector3.new(22, 7, 0.5), CFrame.new(40, 4, -20))
	glass(glassFolder, "OfficeBS", Vector3.new(22, 7, 0.5), CFrame.new(40, 4, 20))

	-- Cubicle cover
	MapBuildUtil.TaggedPart(tags, "Cover", "DeskA1", Vector3.new(8, 3, 3), CFrame.new(-35, 1.5, -8), office)
	MapBuildUtil.TaggedPart(tags, "Cover", "DeskA2", Vector3.new(8, 3, 3), CFrame.new(-35, 1.5, 8), office)
	MapBuildUtil.TaggedPart(tags, "Cover", "DeskB1", Vector3.new(8, 3, 3), CFrame.new(35, 1.5, 8), office)
	MapBuildUtil.TaggedPart(tags, "Cover", "DeskB2", Vector3.new(8, 3, 3), CFrame.new(35, 1.5, -8), office)
	MapBuildUtil.TaggedPart(tags, "Cover", "Reception", Vector3.new(10, 3.5, 4), CFrame.new(0, 1.75, 0), Color3.fromRGB(180, 160, 140))
	MapBuildUtil.TaggedPart(tags, "Cover", "PlantA", Vector3.new(3, 4, 3), CFrame.new(-12, 2, -22), Color3.fromRGB(50, 120, 60))
	MapBuildUtil.TaggedPart(tags, "Cover", "PlantB", Vector3.new(3, 4, 3), CFrame.new(12, 2, 22), Color3.fromRGB(50, 120, 60))

	-- Upper loft / high ground
	MapBuildUtil.TaggedPart(tags, "HighGround", "LoftA", Vector3.new(28, 1.2, 24), CFrame.new(-42, 9, 0), Color3.fromRGB(190, 195, 205))
	MapBuildUtil.TaggedPart(tags, "HighGround", "StairsA", Vector3.new(8, 1, 12), CFrame.new(-24, 4.5, -16) * CFrame.Angles(math.rad(-25), 0, 0), office)
	MapBuildUtil.TaggedPart(tags, "HighGround", "LoftB", Vector3.new(28, 1.2, 24), CFrame.new(42, 9, 0), Color3.fromRGB(205, 190, 195))
	MapBuildUtil.TaggedPart(tags, "HighGround", "StairsB", Vector3.new(8, 1, 12), CFrame.new(24, 4.5, 16) * CFrame.Angles(math.rad(25), 0, 0), office)

	-- Glass loft railings (still non-breakable)
	glass(glassFolder, "RailA", Vector3.new(0.4, 3, 20), CFrame.new(-28, 11, 0))
	glass(glassFolder, "RailB", Vector3.new(0.4, 3, 20), CFrame.new(28, 11, 0))

	-- Door chokepoints
	MapBuildUtil.TaggedPart(tags, "Chokepoint", "DoorWest", Vector3.new(2, 7, 8), CFrame.new(-22, 3.5, 0), Color3.fromRGB(150, 155, 165))
	MapBuildUtil.TaggedPart(tags, "Chokepoint", "DoorEast", Vector3.new(2, 7, 8), CFrame.new(22, 3.5, 0), Color3.fromRGB(150, 155, 165))
	MapBuildUtil.TaggedPart(tags, "Chokepoint", "HallNorth", Vector3.new(16, 6, 2), CFrame.new(0, 3, -28), Color3.fromRGB(150, 155, 165))
	MapBuildUtil.TaggedPart(tags, "Chokepoint", "HallSouth", Vector3.new(16, 6, 2), CFrame.new(0, 3, 28), Color3.fromRGB(150, 155, 165))

	MapBuildUtil.MirroredSpawns(root, {
		CFrame.new(-52, 1, -10) * CFrame.Angles(0, math.rad(90), 0),
		CFrame.new(-52, 1, 10) * CFrame.Angles(0, math.rad(90), 0),
		CFrame.new(-48, 10, 0) * CFrame.Angles(0, math.rad(90), 0),
		CFrame.new(-50, 1, 0) * CFrame.Angles(0, math.rad(90), 0),
	}, {
		CFrame.new(52, 1, 10) * CFrame.Angles(0, math.rad(-90), 0),
		CFrame.new(52, 1, -10) * CFrame.Angles(0, math.rad(-90), 0),
		CFrame.new(48, 10, 0) * CFrame.Angles(0, math.rad(-90), 0),
		CFrame.new(50, 1, 0) * CFrame.Angles(0, math.rad(-90), 0),
	})

	MapBuildUtil.PlaceWaypointGrid(root, -50, 50, -36, 36, 12, 1.5)
	local wp = root:FindFirstChild("Waypoints") :: Folder
	MapBuildUtil.InvisibleMarker(wp, "WP_LoftA", Vector3.new(-42, 10.5, 0), "Waypoint")
	MapBuildUtil.InvisibleMarker(wp, "WP_LoftB", Vector3.new(42, 10.5, 0), "Waypoint")

	MapBuildUtil.PlaceCoverNodes(root, {
		Vector3.new(-35, 1.5, -8),
		Vector3.new(-35, 1.5, 8),
		Vector3.new(35, 1.5, 8),
		Vector3.new(35, 1.5, -8),
		Vector3.new(0, 1.5, 0),
		Vector3.new(-12, 2, -22),
		Vector3.new(12, 2, 22),
		Vector3.new(-42, 10.5, -8),
		Vector3.new(42, 10.5, 8),
		Vector3.new(-22, 1.5, 0),
		Vector3.new(22, 1.5, 0),
	})

	MapBuildUtil.KillFloor(root, Vector3.new(240, 2, 200), -25)
	return root
end

return Glassline
