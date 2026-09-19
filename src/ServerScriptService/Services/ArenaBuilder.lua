--!strict
--[[
	ArenaBuilder — constructs a mirrored Parts arena on server start.
	SpawnA / SpawnB folders with SpawnLocations for teams.
]]

local Workspace = game:GetService("Workspace")

local ArenaBuilder = {}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3?,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color or Color3.fromRGB(90, 95, 105)
	p.Material = material or Enum.Material.Concrete
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function spawnLocation(parent: Instance, name: string, cframe: CFrame): SpawnLocation
	local s = Instance.new("SpawnLocation")
	s.Name = name
	s.Anchored = true
	s.Size = Vector3.new(6, 1, 6)
	s.CFrame = cframe
	s.Duration = 0
	s.Neutral = false
	s.Transparency = 0.3
	s.BrickColor = BrickColor.new("Bright blue")
	s.Parent = parent
	return s
end

function ArenaBuilder.Build()
	local existing = Workspace:FindFirstChild("LatchArena")
	if existing then
		existing:Destroy()
	end

	local arena = Instance.new("Folder")
	arena.Name = "LatchArena"
	arena.Parent = Workspace

	-- Floor
	part(arena, "Floor", Vector3.new(120, 2, 80), CFrame.new(0, -1, 0), Color3.fromRGB(55, 58, 65), Enum.Material.Slate)

	-- Outer walls
	part(arena, "WallNorth", Vector3.new(120, 16, 2), CFrame.new(0, 7, -41), Color3.fromRGB(70, 74, 82))
	part(arena, "WallSouth", Vector3.new(120, 16, 2), CFrame.new(0, 7, 41), Color3.fromRGB(70, 74, 82))
	part(arena, "WallWest", Vector3.new(2, 16, 80), CFrame.new(-61, 7, 0), Color3.fromRGB(70, 74, 82))
	part(arena, "WallEast", Vector3.new(2, 16, 80), CFrame.new(61, 7, 0), Color3.fromRGB(70, 74, 82))

	-- Mid cover (mirrored)
	part(arena, "MidBlock", Vector3.new(10, 4, 8), CFrame.new(0, 2, 0), Color3.fromRGB(100, 90, 80))
	part(arena, "MidLowA", Vector3.new(8, 2, 3), CFrame.new(-12, 1, 8), Color3.fromRGB(95, 100, 90))
	part(arena, "MidLowB", Vector3.new(8, 2, 3), CFrame.new(12, 1, -8), Color3.fromRGB(95, 100, 90))

	-- Side high platforms (mirrored)
	part(arena, "PlatformA", Vector3.new(14, 1.5, 12), CFrame.new(-35, 5, 0), Color3.fromRGB(85, 100, 120))
	part(arena, "RampA", Vector3.new(10, 1.2, 6), CFrame.new(-26, 2.5, 0) * CFrame.Angles(0, 0, math.rad(-18)), Color3.fromRGB(85, 100, 120))
	part(arena, "PlatformB", Vector3.new(14, 1.5, 12), CFrame.new(35, 5, 0), Color3.fromRGB(120, 90, 85))
	part(arena, "RampB", Vector3.new(10, 1.2, 6), CFrame.new(26, 2.5, 0) * CFrame.Angles(0, 0, math.rad(18)), Color3.fromRGB(120, 90, 85))

	-- Corner cover
	part(arena, "CornerA1", Vector3.new(4, 5, 4), CFrame.new(-45, 2.5, -25), Color3.fromRGB(80, 85, 90))
	part(arena, "CornerA2", Vector3.new(4, 5, 4), CFrame.new(-45, 2.5, 25), Color3.fromRGB(80, 85, 90))
	part(arena, "CornerB1", Vector3.new(4, 5, 4), CFrame.new(45, 2.5, -25), Color3.fromRGB(90, 80, 85))
	part(arena, "CornerB2", Vector3.new(4, 5, 4), CFrame.new(45, 2.5, 25), Color3.fromRGB(90, 80, 85))

	-- Side walls for close corners
	part(arena, "LaneWallA", Vector3.new(2, 6, 16), CFrame.new(-20, 3, -20), Color3.fromRGB(75, 80, 88))
	part(arena, "LaneWallB", Vector3.new(2, 6, 16), CFrame.new(20, 3, 20), Color3.fromRGB(88, 75, 80))

	-- Spawns
	local spawnA = Instance.new("Folder")
	spawnA.Name = "SpawnA"
	spawnA.Parent = arena
	spawnLocation(spawnA, "SpawnA1", CFrame.new(-48, 1, -8) * CFrame.Angles(0, math.rad(90), 0))
	spawnLocation(spawnA, "SpawnA2", CFrame.new(-48, 1, 8) * CFrame.Angles(0, math.rad(90), 0))

	local spawnB = Instance.new("Folder")
	spawnB.Name = "SpawnB"
	spawnB.Parent = arena
	local sb1 = spawnLocation(spawnB, "SpawnB1", CFrame.new(48, 1, 8) * CFrame.Angles(0, math.rad(-90), 0))
	sb1.BrickColor = BrickColor.new("Bright red")
	local sb2 = spawnLocation(spawnB, "SpawnB2", CFrame.new(48, 1, -8) * CFrame.Angles(0, math.rad(-90), 0))
	sb2.BrickColor = BrickColor.new("Bright red")

	-- Lighting hint part (invisible marker)
	local mid = Instance.new("Part")
	mid.Name = "ArenaCenter"
	mid.Anchored = true
	mid.CanCollide = false
	mid.Transparency = 1
	mid.Size = Vector3.new(1, 1, 1)
	mid.Position = Vector3.new(0, 5, 0)
	mid.Parent = arena

	ArenaBuilder._placeWaypoints(arena)

	return arena
end

function ArenaBuilder._placeWaypoints(arena: Instance)
	local existing = arena:FindFirstChild("Waypoints")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Waypoints"
	folder.Parent = arena

	-- Grid across playable floor (inside walls ~±58 x, ±38 z)
	local spacing = 14
	local idx = 0
	for x = -49, 49, spacing do
		for z = -28, 28, spacing do
			-- Skip extreme corners outside lane feel
			if math.abs(x) > 55 then
				continue
			end
			idx += 1
			local p = Instance.new("Part")
			p.Name = "WP_" .. tostring(idx)
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Transparency = 1
			p.Size = Vector3.new(1, 1, 1)
			p.Position = Vector3.new(x, 1.5, z)
			p.Parent = folder
			local att = Instance.new("Attachment")
			att.Name = "Waypoint"
			att.Parent = p
		end
	end
end

function ArenaBuilder.EnsureWaypoints()
	local arena = Workspace:FindFirstChild("LatchArena")
	if not arena then
		return
	end
	if not arena:FindFirstChild("Waypoints") then
		ArenaBuilder._placeWaypoints(arena)
	end
end

function ArenaBuilder.GetWaypointPositions(): { Vector3 }
	local arena = Workspace:FindFirstChild("LatchArena")
	if not arena then
		return {}
	end
	local folder = arena:FindFirstChild("Waypoints")
	if not folder then
		return {}
	end
	local list: { Vector3 } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(list, child.Position)
		end
	end
	return list
end

function ArenaBuilder.GetSpawns(team: string): { SpawnLocation }
	local arena = Workspace:FindFirstChild("LatchArena")
	if not arena then
		return {}
	end
	local folderName = if team == "A" then "SpawnA" else "SpawnB"
	local folder = arena:FindFirstChild(folderName)
	if not folder then
		return {}
	end
	local list: { SpawnLocation } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("SpawnLocation") then
			table.insert(list, child)
		end
	end
	return list
end

return ArenaBuilder
