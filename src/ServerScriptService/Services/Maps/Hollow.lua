--!strict
--[[ Hollow (Medium) — indoor atrium + mezzanines (good for Splice). ]]

local MapBuildUtil = require(script.Parent.MapBuildUtil)

local Hollow = {}

function Hollow.Build(): Folder
	local root = MapBuildUtil.NewRoot("Hollow")
	local tags = MapBuildUtil.MakeTagFolders(root)
	local geo = MapBuildUtil.Folder(root, "Geometry")

	local wall = Color3.fromRGB(95, 90, 110)
	local floor = Color3.fromRGB(70, 68, 80)

	MapBuildUtil.Part(geo, "Floor", Vector3.new(120, 2, 90), CFrame.new(0, -1, 0), floor, Enum.Material.Slate)
	MapBuildUtil.BoxWalls(geo, 61, 46, 22, 2, wall)
	MapBuildUtil.Part(geo, "Ceiling", Vector3.new(120, 2, 90), CFrame.new(0, 20, 0), Color3.fromRGB(60, 58, 75), Enum.Material.Concrete)

	-- Central atrium void (sunken feel with rail ring)
	MapBuildUtil.Part(geo, "AtriumFloor", Vector3.new(28, 1, 28), CFrame.new(0, 0.5, 0), Color3.fromRGB(85, 80, 100), Enum.Material.Marble)
	MapBuildUtil.TaggedPart(tags, "Cover", "AtriumPillarN", Vector3.new(3, 8, 3), CFrame.new(0, 4, -10), Color3.fromRGB(100, 95, 120))
	MapBuildUtil.TaggedPart(tags, "Cover", "AtriumPillarS", Vector3.new(3, 8, 3), CFrame.new(0, 4, 10), Color3.fromRGB(100, 95, 120))
	MapBuildUtil.TaggedPart(tags, "Cover", "AtriumPillarW", Vector3.new(3, 8, 3), CFrame.new(-10, 4, 0), Color3.fromRGB(100, 95, 120))
	MapBuildUtil.TaggedPart(tags, "Cover", "AtriumPillarE", Vector3.new(3, 8, 3), CFrame.new(10, 4, 0), Color3.fromRGB(100, 95, 120))

	-- Mezzanines (high ground) each side
	MapBuildUtil.TaggedPart(tags, "HighGround", "MezzA", Vector3.new(30, 1.5, 50), CFrame.new(-40, 9, 0), Color3.fromRGB(80, 85, 105))
	MapBuildUtil.TaggedPart(tags, "HighGround", "MezzB", Vector3.new(30, 1.5, 50), CFrame.new(40, 9, 0), Color3.fromRGB(105, 80, 95))
	MapBuildUtil.TaggedPart(tags, "HighGround", "StairsA1", Vector3.new(8, 1.2, 10), CFrame.new(-22, 4, -18) * CFrame.Angles(math.rad(-28), 0, 0), Color3.fromRGB(80, 85, 105))
	MapBuildUtil.TaggedPart(tags, "HighGround", "StairsA2", Vector3.new(8, 1.2, 10), CFrame.new(-22, 4, 18) * CFrame.Angles(math.rad(28), 0, 0), Color3.fromRGB(80, 85, 105))
	MapBuildUtil.TaggedPart(tags, "HighGround", "StairsB1", Vector3.new(8, 1.2, 10), CFrame.new(22, 4, 18) * CFrame.Angles(math.rad(28), 0, 0), Color3.fromRGB(105, 80, 95))
	MapBuildUtil.TaggedPart(tags, "HighGround", "StairsB2", Vector3.new(8, 1.2, 10), CFrame.new(22, 4, -18) * CFrame.Angles(math.rad(-28), 0, 0), Color3.fromRGB(105, 80, 95))

	-- Side halls / chokepoints
	MapBuildUtil.TaggedPart(tags, "Chokepoint", "HallN", Vector3.new(40, 6, 2), CFrame.new(0, 3, -30), Color3.fromRGB(75, 70, 90))
	MapBuildUtil.TaggedPart(tags, "Chokepoint", "HallS", Vector3.new(40, 6, 2), CFrame.new(0, 3, 30), Color3.fromRGB(75, 70, 90))
	MapBuildUtil.TaggedPart(tags, "Chokepoint", "ArchW", Vector3.new(2, 8, 12), CFrame.new(-20, 4, 0), Color3.fromRGB(90, 85, 105))
	MapBuildUtil.TaggedPart(tags, "Chokepoint", "ArchE", Vector3.new(2, 8, 12), CFrame.new(20, 4, 0), Color3.fromRGB(90, 85, 105))

	-- Ground cover blocks (Splice-friendly corners)
	MapBuildUtil.TaggedPart(tags, "Cover", "BlockA1", Vector3.new(6, 4, 4), CFrame.new(-28, 2, -12), Color3.fromRGB(110, 100, 120))
	MapBuildUtil.TaggedPart(tags, "Cover", "BlockA2", Vector3.new(5, 3, 6), CFrame.new(-28, 1.5, 14), Color3.fromRGB(110, 100, 120))
	MapBuildUtil.TaggedPart(tags, "Cover", "BlockB1", Vector3.new(6, 4, 4), CFrame.new(28, 2, 12), Color3.fromRGB(120, 100, 110))
	MapBuildUtil.TaggedPart(tags, "Cover", "BlockB2", Vector3.new(5, 3, 6), CFrame.new(28, 1.5, -14), Color3.fromRGB(120, 100, 110))
	MapBuildUtil.TaggedPart(tags, "Cover", "PlanterN", Vector3.new(10, 2, 3), CFrame.new(0, 1, -20), Color3.fromRGB(60, 100, 70))
	MapBuildUtil.TaggedPart(tags, "Cover", "PlanterS", Vector3.new(10, 2, 3), CFrame.new(0, 1, 20), Color3.fromRGB(60, 100, 70))

	-- Mezz rail cover
	MapBuildUtil.TaggedPart(tags, "Cover", "RailA", Vector3.new(1, 3, 20), CFrame.new(-25, 11.5, 0), Color3.fromRGB(140, 140, 160))
	MapBuildUtil.TaggedPart(tags, "Cover", "RailB", Vector3.new(1, 3, 20), CFrame.new(25, 11.5, 0), Color3.fromRGB(160, 140, 150))

	MapBuildUtil.MirroredSpawns(root, {
		CFrame.new(-52, 1, -12) * CFrame.Angles(0, math.rad(90), 0),
		CFrame.new(-52, 1, 12) * CFrame.Angles(0, math.rad(90), 0),
		CFrame.new(-48, 10, 0) * CFrame.Angles(0, math.rad(90), 0),
	}, {
		CFrame.new(52, 1, 12) * CFrame.Angles(0, math.rad(-90), 0),
		CFrame.new(52, 1, -12) * CFrame.Angles(0, math.rad(-90), 0),
		CFrame.new(48, 10, 0) * CFrame.Angles(0, math.rad(-90), 0),
	})

	MapBuildUtil.PlaceWaypointGrid(root, -50, 50, -36, 36, 12, 1.5)
	local wp = root:FindFirstChild("Waypoints") :: Folder
	MapBuildUtil.InvisibleMarker(wp, "WP_MezzA", Vector3.new(-40, 10.5, 0), "Waypoint")
	MapBuildUtil.InvisibleMarker(wp, "WP_MezzB", Vector3.new(40, 10.5, 0), "Waypoint")
	MapBuildUtil.InvisibleMarker(wp, "WP_Atrium", Vector3.new(0, 1.5, 0), "Waypoint")

	MapBuildUtil.PlaceCoverNodes(root, {
		Vector3.new(-28, 2, -12),
		Vector3.new(-28, 2, 14),
		Vector3.new(28, 2, 12),
		Vector3.new(28, 2, -14),
		Vector3.new(0, 1.5, -20),
		Vector3.new(0, 1.5, 20),
		Vector3.new(-10, 1.5, 0),
		Vector3.new(10, 1.5, 0),
		Vector3.new(-40, 10.5, -10),
		Vector3.new(40, 10.5, 10),
		Vector3.new(-26, 10.5, 0),
		Vector3.new(26, 10.5, 0),
	})

	MapBuildUtil.KillFloor(root, Vector3.new(240, 2, 200), -25)
	return root
end

return Hollow
