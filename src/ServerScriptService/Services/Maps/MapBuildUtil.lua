--!strict
--[[
	Shared Part helpers for code-generated Latch maps.
	Tags: Cover / HighGround / Chokepoint via folder names + attributes.
]]

local MapBuildUtil = {}

export type MapRoot = Folder

function MapBuildUtil.NewRoot(mapId: string): Folder
	local root = Instance.new("Folder")
	root.Name = "LatchMap"
	root:SetAttribute("MapId", mapId)
	return root
end

function MapBuildUtil.Folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function MapBuildUtil.Part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3?,
	material: Enum.Material?,
	opts: {
		Transparency: number?,
		CanCollide: boolean?,
		CanQuery: boolean?,
		Tag: string?,
	}?
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
	if opts then
		if opts.Transparency ~= nil then
			p.Transparency = opts.Transparency
		end
		if opts.CanCollide ~= nil then
			p.CanCollide = opts.CanCollide
		end
		if opts.CanQuery ~= nil then
			p.CanQuery = opts.CanQuery
		end
		if opts.Tag then
			p:SetAttribute("LatchTag", opts.Tag)
		end
	end
	p.Parent = parent
	return p
end

function MapBuildUtil.Spawn(parent: Instance, name: string, cframe: CFrame, team: string): SpawnLocation
	local s = Instance.new("SpawnLocation")
	s.Name = name
	s.Anchored = true
	s.Size = Vector3.new(6, 1, 6)
	s.CFrame = cframe
	s.Duration = 0
	s.Neutral = false
	s.Transparency = 0.35
	s.BrickColor = if team == "B" then BrickColor.new("Bright red") else BrickColor.new("Bright blue")
	s:SetAttribute("Team", team)
	s.Parent = parent
	return s
end

function MapBuildUtil.InvisibleMarker(
	parent: Instance,
	name: string,
	position: Vector3,
	tag: string?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.Position = position
	if tag then
		p:SetAttribute("LatchTag", tag)
	end
	local att = Instance.new("Attachment")
	att.Name = if tag == "CoverNode" then "CoverNode" else "Waypoint"
	att.Parent = p
	p.Parent = parent
	return p
end

--[[ Grid waypoints across a rectangular floor. ]]
function MapBuildUtil.PlaceWaypointGrid(
	parent: Instance,
	xMin: number,
	xMax: number,
	zMin: number,
	zMax: number,
	spacing: number,
	y: number?
): Folder
	local folder = MapBuildUtil.Folder(parent, "Waypoints")
	local idx = 0
	local height = y or 1.5
	for x = xMin, xMax, spacing do
		for z = zMin, zMax, spacing do
			idx += 1
			MapBuildUtil.InvisibleMarker(folder, "WP_" .. tostring(idx), Vector3.new(x, height, z), "Waypoint")
		end
	end
	return folder
end

function MapBuildUtil.PlaceCoverNodes(parent: Instance, positions: { Vector3 }): Folder
	local folder = MapBuildUtil.Folder(parent, "CoverNodes")
	for i, pos in positions do
		MapBuildUtil.InvisibleMarker(folder, "CN_" .. tostring(i), pos, "CoverNode")
	end
	return folder
end

--[[ Large kill floor below the map — touches teleport / kill via TouchInterest handler in MapService. ]]
function MapBuildUtil.KillFloor(parent: Instance, size: Vector3, y: number): Part
	local p = MapBuildUtil.Part(
		parent,
		"KillFloor",
		size,
		CFrame.new(0, y, 0),
		Color3.fromRGB(30, 10, 10),
		Enum.Material.SmoothPlastic,
		{ Transparency = 1, CanCollide = false, Tag = "KillFloor" }
	)
	p.CanTouch = true
	return p
end

function MapBuildUtil.BoxWalls(
	parent: Instance,
	halfX: number,
	halfZ: number,
	height: number,
	thickness: number,
	color: Color3?
)
	local c = color or Color3.fromRGB(70, 74, 82)
	local midY = height / 2
	MapBuildUtil.Part(parent, "WallNorth", Vector3.new(halfX * 2 + thickness * 2, height, thickness), CFrame.new(0, midY, -halfZ), c)
	MapBuildUtil.Part(parent, "WallSouth", Vector3.new(halfX * 2 + thickness * 2, height, thickness), CFrame.new(0, midY, halfZ), c)
	MapBuildUtil.Part(parent, "WallWest", Vector3.new(thickness, height, halfZ * 2), CFrame.new(-halfX, midY, 0), c)
	MapBuildUtil.Part(parent, "WallEast", Vector3.new(thickness, height, halfZ * 2), CFrame.new(halfX, midY, 0), c)
end

--[[ Tag a part as cover / high ground / chokepoint and parent under the right folder. ]]
function MapBuildUtil.TaggedPart(
	folders: { Cover: Folder, HighGround: Folder, Chokepoints: Folder },
	tag: "Cover" | "HighGround" | "Chokepoint",
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3?,
	material: Enum.Material?
): Part
	local parent = if tag == "Cover"
		then folders.Cover
		elseif tag == "HighGround" then folders.HighGround
		else folders.Chokepoints
	return MapBuildUtil.Part(parent, name, size, cframe, color, material, { Tag = tag })
end

function MapBuildUtil.MakeTagFolders(root: Folder): { Cover: Folder, HighGround: Folder, Chokepoints: Folder }
	return {
		Cover = MapBuildUtil.Folder(root, "Cover"),
		HighGround = MapBuildUtil.Folder(root, "HighGround"),
		Chokepoints = MapBuildUtil.Folder(root, "Chokepoints"),
	}
end

function MapBuildUtil.MirroredSpawns(
	root: Folder,
	aPositions: { CFrame },
	bPositions: { CFrame }
)
	local spawnA = MapBuildUtil.Folder(root, "SpawnA")
	local spawnB = MapBuildUtil.Folder(root, "SpawnB")
	for i, cf in aPositions do
		MapBuildUtil.Spawn(spawnA, "SpawnA" .. tostring(i), cf, "A")
	end
	for i, cf in bPositions do
		MapBuildUtil.Spawn(spawnB, "SpawnB" .. tostring(i), cf, "B")
	end
end

return MapBuildUtil
