--!strict
--[[ Splityard (Small) — two warehouses, mid crate lane. ]]

local MapBuildUtil = require(script.Parent.MapBuildUtil)

local Splityard = {}

function Splityard.Build(): Folder
	local root = MapBuildUtil.NewRoot("Splityard")
	local tags = MapBuildUtil.MakeTagFolders(root)
	local geo = MapBuildUtil.Folder(root, "Geometry")

	-- Floor
	MapBuildUtil.Part(geo, "Floor", Vector3.new(100, 2, 70), CFrame.new(0, -1, 0), Color3.fromRGB(75, 70, 60), Enum.Material.Concrete)
	MapBuildUtil.BoxWalls(geo, 51, 36, 14, 2, Color3.fromRGB(65, 60, 55))

	-- Warehouse A (west)
	MapBuildUtil.Part(geo, "WarehouseA_Floor", Vector3.new(28, 1, 32), CFrame.new(-32, 0.5, 0), Color3.fromRGB(90, 85, 70), Enum.Material.Metal)
	MapBuildUtil.Part(geo, "WarehouseA_Roof", Vector3.new(28, 1, 32), CFrame.new(-32, 10, 0), Color3.fromRGB(80, 75, 65), Enum.Material.Metal)
	MapBuildUtil.Part(geo, "WarehouseA_Back", Vector3.new(2, 10, 32), CFrame.new(-45, 5, 0), Color3.fromRGB(85, 80, 70))
	MapBuildUtil.Part(geo, "WarehouseA_SideN", Vector3.new(26, 10, 2), CFrame.new(-32, 5, -16), Color3.fromRGB(85, 80, 70))
	MapBuildUtil.Part(geo, "WarehouseA_SideS", Vector3.new(26, 10, 2), CFrame.new(-32, 5, 16), Color3.fromRGB(85, 80, 70))
	-- Open face toward mid (partial)
	MapBuildUtil.Part(geo, "WarehouseA_LipN", Vector3.new(2, 10, 8), CFrame.new(-18, 5, -12), Color3.fromRGB(85, 80, 70))
	MapBuildUtil.Part(geo, "WarehouseA_LipS", Vector3.new(2, 10, 8), CFrame.new(-18, 5, 12), Color3.fromRGB(85, 80, 70))

	-- Warehouse B (east) — mirror
	MapBuildUtil.Part(geo, "WarehouseB_Floor", Vector3.new(28, 1, 32), CFrame.new(32, 0.5, 0), Color3.fromRGB(90, 85, 70), Enum.Material.Metal)
	MapBuildUtil.Part(geo, "WarehouseB_Roof", Vector3.new(28, 1, 32), CFrame.new(32, 10, 0), Color3.fromRGB(80, 75, 65), Enum.Material.Metal)
	MapBuildUtil.Part(geo, "WarehouseB_Back", Vector3.new(2, 10, 32), CFrame.new(45, 5, 0), Color3.fromRGB(85, 80, 70))
	MapBuildUtil.Part(geo, "WarehouseB_SideN", Vector3.new(26, 10, 2), CFrame.new(32, 5, -16), Color3.fromRGB(85, 80, 70))
	MapBuildUtil.Part(geo, "WarehouseB_SideS", Vector3.new(26, 10, 2), CFrame.new(32, 5, 16), Color3.fromRGB(85, 80, 70))
	MapBuildUtil.Part(geo, "WarehouseB_LipN", Vector3.new(2, 10, 8), CFrame.new(18, 5, -12), Color3.fromRGB(85, 80, 70))
	MapBuildUtil.Part(geo, "WarehouseB_LipS", Vector3.new(2, 10, 8), CFrame.new(18, 5, 12), Color3.fromRGB(85, 80, 70))

	-- Mid crate lane
	MapBuildUtil.TaggedPart(tags, "Cover", "CrateMid1", Vector3.new(5, 4, 5), CFrame.new(0, 2, 0), Color3.fromRGB(150, 110, 60), Enum.Material.Wood)
	MapBuildUtil.TaggedPart(tags, "Cover", "CrateMid2", Vector3.new(4, 3, 4), CFrame.new(-6, 1.5, 8), Color3.fromRGB(140, 100, 55), Enum.Material.Wood)
	MapBuildUtil.TaggedPart(tags, "Cover", "CrateMid3", Vector3.new(4, 3, 4), CFrame.new(6, 1.5, -8), Color3.fromRGB(140, 100, 55), Enum.Material.Wood)
	MapBuildUtil.TaggedPart(tags, "Cover", "CrateLaneA", Vector3.new(3, 2.5, 6), CFrame.new(-10, 1.25, -4), Color3.fromRGB(130, 95, 50), Enum.Material.Wood)
	MapBuildUtil.TaggedPart(tags, "Cover", "CrateLaneB", Vector3.new(3, 2.5, 6), CFrame.new(10, 1.25, 4), Color3.fromRGB(130, 95, 50), Enum.Material.Wood)

	-- High ground: warehouse mezzanine shelves
	MapBuildUtil.TaggedPart(tags, "HighGround", "ShelfA", Vector3.new(10, 1, 8), CFrame.new(-30, 5, 0), Color3.fromRGB(100, 95, 80), Enum.Material.Metal)
	MapBuildUtil.TaggedPart(tags, "HighGround", "RampA", Vector3.new(8, 1, 4), CFrame.new(-22, 2.8, 0) * CFrame.Angles(0, 0, math.rad(-22)), Color3.fromRGB(100, 95, 80))
	MapBuildUtil.TaggedPart(tags, "HighGround", "ShelfB", Vector3.new(10, 1, 8), CFrame.new(30, 5, 0), Color3.fromRGB(110, 90, 80), Enum.Material.Metal)
	MapBuildUtil.TaggedPart(tags, "HighGround", "RampB", Vector3.new(8, 1, 4), CFrame.new(22, 2.8, 0) * CFrame.Angles(0, 0, math.rad(22)), Color3.fromRGB(110, 90, 80))

	-- Chokepoints: warehouse door gaps
	MapBuildUtil.TaggedPart(tags, "Chokepoint", "DoorFrameA", Vector3.new(1, 6, 2), CFrame.new(-18, 3, 0), Color3.fromRGB(60, 55, 50))
	MapBuildUtil.TaggedPart(tags, "Chokepoint", "DoorFrameB", Vector3.new(1, 6, 2), CFrame.new(18, 3, 0), Color3.fromRGB(60, 55, 50))

	MapBuildUtil.MirroredSpawns(root, {
		CFrame.new(-40, 1.5, -8) * CFrame.Angles(0, math.rad(90), 0),
		CFrame.new(-40, 1.5, 8) * CFrame.Angles(0, math.rad(90), 0),
		CFrame.new(-38, 1.5, 0) * CFrame.Angles(0, math.rad(90), 0),
	}, {
		CFrame.new(40, 1.5, 8) * CFrame.Angles(0, math.rad(-90), 0),
		CFrame.new(40, 1.5, -8) * CFrame.Angles(0, math.rad(-90), 0),
		CFrame.new(38, 1.5, 0) * CFrame.Angles(0, math.rad(-90), 0),
	})

	MapBuildUtil.PlaceWaypointGrid(root, -42, 42, -28, 28, 12, 1.5)
	MapBuildUtil.PlaceCoverNodes(root, {
		Vector3.new(-6, 1.5, 8),
		Vector3.new(6, 1.5, -8),
		Vector3.new(0, 1.5, 0),
		Vector3.new(-10, 1.5, -4),
		Vector3.new(10, 1.5, 4),
		Vector3.new(-30, 5.5, 0),
		Vector3.new(30, 5.5, 0),
		Vector3.new(-22, 1.5, 10),
		Vector3.new(22, 1.5, -10),
	})

	MapBuildUtil.KillFloor(root, Vector3.new(200, 2, 160), -20)
	return root
end

return Splityard
