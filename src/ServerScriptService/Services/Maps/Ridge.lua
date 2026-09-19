--!strict
--[[ Ridge (Large) — outdoor canyon for 3v3/4v4 later. ]]

local MapBuildUtil = require(script.Parent.MapBuildUtil)

local Ridge = {}

function Ridge.Build(): Folder
	local root = MapBuildUtil.NewRoot("Ridge")
	local tags = MapBuildUtil.MakeTagFolders(root)
	local geo = MapBuildUtil.Folder(root, "Geometry")

	local rock = Color3.fromRGB(110, 100, 85)
	local dirt = Color3.fromRGB(90, 100, 70)
	local cliff = Color3.fromRGB(85, 80, 70)

	-- Large canyon floor
	MapBuildUtil.Part(geo, "CanyonFloor", Vector3.new(180, 2, 120), CFrame.new(0, -1, 0), dirt, Enum.Material.Ground)
	-- Outer cliff walls (tall)
	MapBuildUtil.Part(geo, "CliffN", Vector3.new(184, 28, 8), CFrame.new(0, 12, -64), cliff, Enum.Material.Slate)
	MapBuildUtil.Part(geo, "CliffS", Vector3.new(184, 28, 8), CFrame.new(0, 12, 64), cliff, Enum.Material.Slate)
	MapBuildUtil.Part(geo, "CliffW", Vector3.new(8, 28, 120), CFrame.new(-92, 12, 0), cliff, Enum.Material.Slate)
	MapBuildUtil.Part(geo, "CliffE", Vector3.new(8, 28, 120), CFrame.new(92, 12, 0), cliff, Enum.Material.Slate)

	-- Central ridge spine (high ground spine)
	MapBuildUtil.TaggedPart(tags, "HighGround", "Spine", Vector3.new(30, 8, 16), CFrame.new(0, 4, 0), rock, Enum.Material.Slate)
	MapBuildUtil.TaggedPart(tags, "HighGround", "SpineTop", Vector3.new(20, 1.5, 12), CFrame.new(0, 9, 0), Color3.fromRGB(120, 110, 95))
	MapBuildUtil.TaggedPart(tags, "HighGround", "RampSpineA", Vector3.new(14, 1.2, 8), CFrame.new(-20, 3, 0) * CFrame.Angles(0, 0, math.rad(-18)), rock)
	MapBuildUtil.TaggedPart(tags, "HighGround", "RampSpineB", Vector3.new(14, 1.2, 8), CFrame.new(20, 3, 0) * CFrame.Angles(0, 0, math.rad(18)), rock)

	-- Side ridges / terraces
	MapBuildUtil.TaggedPart(tags, "HighGround", "TerraceAN", Vector3.new(40, 1.5, 18), CFrame.new(-50, 6, -30), rock)
	MapBuildUtil.TaggedPart(tags, "HighGround", "TerraceAS", Vector3.new(40, 1.5, 18), CFrame.new(-50, 6, 30), rock)
	MapBuildUtil.TaggedPart(tags, "HighGround", "TerraceBN", Vector3.new(40, 1.5, 18), CFrame.new(50, 6, -30), rock)
	MapBuildUtil.TaggedPart(tags, "HighGround", "TerraceBS", Vector3.new(40, 1.5, 18), CFrame.new(50, 6, 30), rock)
	MapBuildUtil.TaggedPart(tags, "HighGround", "ClimbAN", Vector3.new(10, 1, 8), CFrame.new(-35, 3, -30) * CFrame.Angles(0, 0, math.rad(-22)), rock)
	MapBuildUtil.TaggedPart(tags, "HighGround", "ClimbAS", Vector3.new(10, 1, 8), CFrame.new(-35, 3, 30) * CFrame.Angles(0, 0, math.rad(-22)), rock)
	MapBuildUtil.TaggedPart(tags, "HighGround", "ClimbBN", Vector3.new(10, 1, 8), CFrame.new(35, 3, -30) * CFrame.Angles(0, 0, math.rad(22)), rock)
	MapBuildUtil.TaggedPart(tags, "HighGround", "ClimbBS", Vector3.new(10, 1, 8), CFrame.new(35, 3, 30) * CFrame.Angles(0, 0, math.rad(22)), rock)

	-- Boulder cover clusters
	MapBuildUtil.TaggedPart(tags, "Cover", "BoulderA1", Vector3.new(8, 5, 7), CFrame.new(-55, 2.5, 0), rock)
	MapBuildUtil.TaggedPart(tags, "Cover", "BoulderA2", Vector3.new(6, 4, 6), CFrame.new(-40, 2, -18), rock)
	MapBuildUtil.TaggedPart(tags, "Cover", "BoulderA3", Vector3.new(7, 4, 5), CFrame.new(-40, 2, 18), rock)
	MapBuildUtil.TaggedPart(tags, "Cover", "BoulderB1", Vector3.new(8, 5, 7), CFrame.new(55, 2.5, 0), rock)
	MapBuildUtil.TaggedPart(tags, "Cover", "BoulderB2", Vector3.new(6, 4, 6), CFrame.new(40, 2, 18), rock)
	MapBuildUtil.TaggedPart(tags, "Cover", "BoulderB3", Vector3.new(7, 4, 5), CFrame.new(40, 2, -18), rock)
	MapBuildUtil.TaggedPart(tags, "Cover", "MidRockN", Vector3.new(5, 3, 5), CFrame.new(-8, 1.5, -22), rock)
	MapBuildUtil.TaggedPart(tags, "Cover", "MidRockS", Vector3.new(5, 3, 5), CFrame.new(8, 1.5, 22), rock)

	-- Canyon chokepoints (narrow passes)
	MapBuildUtil.TaggedPart(tags, "Chokepoint", "PassNorth", Vector3.new(16, 10, 4), CFrame.new(0, 4, -40), cliff)
	MapBuildUtil.TaggedPart(tags, "Chokepoint", "PassSouth", Vector3.new(16, 10, 4), CFrame.new(0, 4, 40), cliff)
	MapBuildUtil.TaggedPart(tags, "Chokepoint", "GullyW", Vector3.new(4, 8, 24), CFrame.new(-25, 3, 0), cliff)
	MapBuildUtil.TaggedPart(tags, "Chokepoint", "GullyE", Vector3.new(4, 8, 24), CFrame.new(25, 3, 0), cliff)

	-- Extra spawn pads for future 3v3/4v4
	MapBuildUtil.MirroredSpawns(root, {
		CFrame.new(-75, 1, -20) * CFrame.Angles(0, math.rad(90), 0),
		CFrame.new(-75, 1, 0) * CFrame.Angles(0, math.rad(90), 0),
		CFrame.new(-75, 1, 20) * CFrame.Angles(0, math.rad(90), 0),
		CFrame.new(-55, 7, -30) * CFrame.Angles(0, math.rad(90), 0),
		CFrame.new(-55, 7, 30) * CFrame.Angles(0, math.rad(90), 0),
	}, {
		CFrame.new(75, 1, 20) * CFrame.Angles(0, math.rad(-90), 0),
		CFrame.new(75, 1, 0) * CFrame.Angles(0, math.rad(-90), 0),
		CFrame.new(75, 1, -20) * CFrame.Angles(0, math.rad(-90), 0),
		CFrame.new(55, 7, 30) * CFrame.Angles(0, math.rad(-90), 0),
		CFrame.new(55, 7, -30) * CFrame.Angles(0, math.rad(-90), 0),
	})

	MapBuildUtil.PlaceWaypointGrid(root, -75, 75, -50, 50, 16, 1.5)
	local wp = root:FindFirstChild("Waypoints") :: Folder
	MapBuildUtil.InvisibleMarker(wp, "WP_Spine", Vector3.new(0, 10.5, 0), "Waypoint")
	MapBuildUtil.InvisibleMarker(wp, "WP_TerrAN", Vector3.new(-50, 7.5, -30), "Waypoint")
	MapBuildUtil.InvisibleMarker(wp, "WP_TerrBS", Vector3.new(50, 7.5, 30), "Waypoint")

	MapBuildUtil.PlaceCoverNodes(root, {
		Vector3.new(-55, 2.5, 0),
		Vector3.new(-40, 2, -18),
		Vector3.new(-40, 2, 18),
		Vector3.new(55, 2.5, 0),
		Vector3.new(40, 2, 18),
		Vector3.new(40, 2, -18),
		Vector3.new(-8, 1.5, -22),
		Vector3.new(8, 1.5, 22),
		Vector3.new(0, 10.5, 0),
		Vector3.new(-50, 7.5, -30),
		Vector3.new(-50, 7.5, 30),
		Vector3.new(50, 7.5, -30),
		Vector3.new(50, 7.5, 30),
		Vector3.new(-25, 1.5, 0),
		Vector3.new(25, 1.5, 0),
	})

	MapBuildUtil.KillFloor(root, Vector3.new(360, 2, 280), -30)
	return root
end

return Ridge
