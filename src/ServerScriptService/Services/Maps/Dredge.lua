--!strict
--[[ Dredge (Medium) — dry dock / shipping, long AR lines + tight corridors. ]]

local MapBuildUtil = require(script.Parent.MapBuildUtil)

local Dredge = {}

function Dredge.Build(): Folder
	local root = MapBuildUtil.NewRoot("Dredge")
	local tags = MapBuildUtil.MakeTagFolders(root)
	local geo = MapBuildUtil.Folder(root, "Geometry")

	local steel = Color3.fromRGB(80, 95, 105)
	local rust = Color3.fromRGB(110, 80, 55)

	MapBuildUtil.Part(geo, "DockFloor", Vector3.new(140, 2, 80), CFrame.new(0, -1, 0), Color3.fromRGB(60, 70, 75), Enum.Material.Concrete)
	MapBuildUtil.BoxWalls(geo, 71, 41, 16, 2, Color3.fromRGB(55, 65, 70))

	-- Dry dock trench down the middle (long AR sightline over it)
	MapBuildUtil.Part(geo, "TrenchFloor", Vector3.new(100, 1, 16), CFrame.new(0, -4, 0), Color3.fromRGB(40, 50, 55), Enum.Material.Slate)
	MapBuildUtil.Part(geo, "TrenchWallN", Vector3.new(100, 5, 1), CFrame.new(0, -1.5, -8), steel)
	MapBuildUtil.Part(geo, "TrenchWallS", Vector3.new(100, 5, 1), CFrame.new(0, -1.5, 8), steel)
	-- Cross bridges over trench
	MapBuildUtil.TaggedPart(tags, "Chokepoint", "CatwalkW", Vector3.new(8, 1, 18), CFrame.new(-20, 0.5, 0), Color3.fromRGB(100, 110, 120), Enum.Material.Metal)
	MapBuildUtil.TaggedPart(tags, "Chokepoint", "CatwalkM", Vector3.new(8, 1, 18), CFrame.new(0, 0.5, 0), Color3.fromRGB(100, 110, 120), Enum.Material.Metal)
	MapBuildUtil.TaggedPart(tags, "Chokepoint", "CatwalkE", Vector3.new(8, 1, 18), CFrame.new(20, 0.5, 0), Color3.fromRGB(100, 110, 120), Enum.Material.Metal)

	-- Shipping containers (cover) — mirrored clusters
	local function container(name: string, cf: CFrame, color: Color3)
		MapBuildUtil.TaggedPart(tags, "Cover", name, Vector3.new(12, 6, 6), cf, color, Enum.Material.Metal)
	end
	container("BoxA1", CFrame.new(-45, 3, -22), Color3.fromRGB(40, 90, 140))
	container("BoxA2", CFrame.new(-45, 3, 22), Color3.fromRGB(140, 50, 40))
	container("BoxA3", CFrame.new(-30, 3, -18), rust)
	container("BoxB1", CFrame.new(45, 3, 22), Color3.fromRGB(40, 90, 140))
	container("BoxB2", CFrame.new(45, 3, -22), Color3.fromRGB(140, 50, 40))
	container("BoxB3", CFrame.new(30, 3, 18), rust)

	-- Stacked containers = high ground
	MapBuildUtil.TaggedPart(tags, "HighGround", "StackA", Vector3.new(12, 1, 6), CFrame.new(-45, 7, -22), Color3.fromRGB(50, 100, 150), Enum.Material.Metal)
	MapBuildUtil.TaggedPart(tags, "HighGround", "ClimbA", Vector3.new(4, 1, 8), CFrame.new(-38, 3.5, -22) * CFrame.Angles(0, 0, math.rad(-35)), steel)
	MapBuildUtil.TaggedPart(tags, "HighGround", "StackB", Vector3.new(12, 1, 6), CFrame.new(45, 7, 22), Color3.fromRGB(50, 100, 150), Enum.Material.Metal)
	MapBuildUtil.TaggedPart(tags, "HighGround", "ClimbB", Vector3.new(4, 1, 8), CFrame.new(38, 3.5, 22) * CFrame.Angles(0, 0, math.rad(35)), steel)

	-- Crane gantries / long corridor walls for tight fights
	MapBuildUtil.TaggedPart(tags, "Chokepoint", "CorridorN1", Vector3.new(50, 8, 2), CFrame.new(-10, 4, -32), steel)
	MapBuildUtil.TaggedPart(tags, "Chokepoint", "CorridorS1", Vector3.new(50, 8, 2), CFrame.new(10, 4, 32), steel)
	MapBuildUtil.Part(geo, "CraneBeam", Vector3.new(80, 2, 3), CFrame.new(0, 14, 0), Color3.fromRGB(200, 160, 40), Enum.Material.Metal)
	MapBuildUtil.Part(geo, "CraneLegA", Vector3.new(2, 14, 2), CFrame.new(-40, 6, 0), Color3.fromRGB(180, 140, 30))
	MapBuildUtil.Part(geo, "CraneLegB", Vector3.new(2, 14, 2), CFrame.new(40, 6, 0), Color3.fromRGB(180, 140, 30))

	-- Low crates along AR lanes
	MapBuildUtil.TaggedPart(tags, "Cover", "LowA1", Vector3.new(6, 2, 3), CFrame.new(-15, 1, -14), rust)
	MapBuildUtil.TaggedPart(tags, "Cover", "LowA2", Vector3.new(6, 2, 3), CFrame.new(-15, 1, 14), rust)
	MapBuildUtil.TaggedPart(tags, "Cover", "LowB1", Vector3.new(6, 2, 3), CFrame.new(15, 1, 14), rust)
	MapBuildUtil.TaggedPart(tags, "Cover", "LowB2", Vector3.new(6, 2, 3), CFrame.new(15, 1, -14), rust)

	MapBuildUtil.MirroredSpawns(root, {
		CFrame.new(-60, 1, -12) * CFrame.Angles(0, math.rad(90), 0),
		CFrame.new(-60, 1, 12) * CFrame.Angles(0, math.rad(90), 0),
		CFrame.new(-55, 1, 0) * CFrame.Angles(0, math.rad(90), 0),
		CFrame.new(-45, 8, -22) * CFrame.Angles(0, math.rad(90), 0),
	}, {
		CFrame.new(60, 1, 12) * CFrame.Angles(0, math.rad(-90), 0),
		CFrame.new(60, 1, -12) * CFrame.Angles(0, math.rad(-90), 0),
		CFrame.new(55, 1, 0) * CFrame.Angles(0, math.rad(-90), 0),
		CFrame.new(45, 8, 22) * CFrame.Angles(0, math.rad(-90), 0),
	})

	MapBuildUtil.PlaceWaypointGrid(root, -58, 58, -32, 32, 12, 1.5)
	local wp = root:FindFirstChild("Waypoints") :: Folder
	MapBuildUtil.InvisibleMarker(wp, "WP_Trench", Vector3.new(0, -2.5, 0), "Waypoint")
	MapBuildUtil.InvisibleMarker(wp, "WP_CatW", Vector3.new(-20, 1.5, 0), "Waypoint")
	MapBuildUtil.InvisibleMarker(wp, "WP_CatE", Vector3.new(20, 1.5, 0), "Waypoint")

	MapBuildUtil.PlaceCoverNodes(root, {
		Vector3.new(-45, 3, -22),
		Vector3.new(-45, 3, 22),
		Vector3.new(45, 3, 22),
		Vector3.new(45, 3, -22),
		Vector3.new(-15, 1.5, -14),
		Vector3.new(15, 1.5, 14),
		Vector3.new(-20, 1.5, 0),
		Vector3.new(0, 1.5, 0),
		Vector3.new(20, 1.5, 0),
		Vector3.new(-45, 8, -22),
		Vector3.new(45, 8, 22),
	})

	MapBuildUtil.KillFloor(root, Vector3.new(280, 2, 180), -18)
	return root
end

return Dredge
