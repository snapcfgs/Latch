--!strict
--[[
	LobbyBuilder — real lobby space (Phase 3).
	Central floor, kiosk stubs, queue pads, operator alcove, party stub.
	Produces Workspace.LatchArena (MapService parks/restores this folder).
]]

local Workspace = game:GetService("Workspace")

local ModesConfig = require(game.ReplicatedStorage.Config.Modes)

local LobbyBuilder = {}

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

local function spawnLocation(parent: Instance, name: string, cframe: CFrame, team: string): SpawnLocation
	local s = Instance.new("SpawnLocation")
	s.Name = name
	s.Anchored = true
	s.Size = Vector3.new(6, 1, 6)
	s.CFrame = cframe
	s.Duration = 0
	s.Neutral = true
	s.Transparency = 0.35
	s.BrickColor = if team == "B" then BrickColor.new("Bright red") else BrickColor.new("Bright blue")
	s.Parent = parent
	return s
end

local function billboard(adornee: BasePart, text: string, color: Color3?)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Size = UDim2.fromOffset(160, 40)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = adornee
	bb.Parent = adornee
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 0.35
	t.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.Font = Enum.Font.GothamBold
	t.TextSize = 16
	t.Text = text
	t.Parent = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = t
end

local function kiosk(parent: Instance, name: string, pos: Vector3, label: string, color: Color3)
	local base = part(parent, name, Vector3.new(6, 4, 4), CFrame.new(pos + Vector3.new(0, 2, 0)), color, Enum.Material.SmoothPlastic)
	base:SetAttribute("KioskStub", true)
	billboard(base, label, Color3.new(1, 1, 1))
	return base
end

function LobbyBuilder.Build(): Folder
	local existing = Workspace:FindFirstChild("LatchArena")
	if existing then
		existing:Destroy()
	end

	local arena = Instance.new("Folder")
	arena.Name = "LatchArena"
	arena.Parent = Workspace

	-- Central lobby floor (larger than old duel arena)
	part(arena, "Floor", Vector3.new(140, 2, 100), CFrame.new(0, -1, 0), Color3.fromRGB(48, 52, 62), Enum.Material.Slate)

	-- Soft perimeter
	part(arena, "WallNorth", Vector3.new(140, 12, 2), CFrame.new(0, 5, -51), Color3.fromRGB(65, 70, 80))
	part(arena, "WallSouth", Vector3.new(140, 12, 2), CFrame.new(0, 5, 51), Color3.fromRGB(65, 70, 80))
	part(arena, "WallWest", Vector3.new(2, 12, 100), CFrame.new(-71, 5, 0), Color3.fromRGB(65, 70, 80))
	part(arena, "WallEast", Vector3.new(2, 12, 100), CFrame.new(71, 5, 0), Color3.fromRGB(65, 70, 80))

	-- Central plaza ring
	part(arena, "PlazaRing", Vector3.new(28, 0.4, 28), CFrame.new(0, 0.2, 0), Color3.fromRGB(70, 78, 95), Enum.Material.Basalt)
	part(arena, "PlazaCore", Vector3.new(10, 0.5, 10), CFrame.new(0, 0.3, 0), Color3.fromRGB(90, 100, 120), Enum.Material.Neon)

	-- Operator alcove (north)
	local alcove = Instance.new("Folder")
	alcove.Name = "OperatorAlcove"
	alcove.Parent = arena
	part(alcove, "AlcoveFloor", Vector3.new(24, 1, 14), CFrame.new(0, 0.5, -38), Color3.fromRGB(55, 70, 100))
	part(alcove, "AlcoveBack", Vector3.new(24, 10, 1.5), CFrame.new(0, 5, -45), Color3.fromRGB(40, 55, 85))
	local alcoveMark = part(alcove, "AlcoveMarker", Vector3.new(4, 0.4, 4), CFrame.new(0, 1.2, -38), Color3.fromRGB(80, 140, 255), Enum.Material.Neon)
	alcoveMark.CanCollide = false
	billboard(alcoveMark, "Operators", Color3.fromRGB(160, 200, 255))

	-- Kiosk stubs (Phase 4+ content)
	local kiosks = Instance.new("Folder")
	kiosks.Name = "Kiosks"
	kiosks.Parent = arena
	kiosk(kiosks, "ShopKiosk", Vector3.new(-28, 0, -18), "Shop (soon)", Color3.fromRGB(80, 160, 120))
	kiosk(kiosks, "PassKiosk", Vector3.new(-28, 0, 0), "Pass (soon)", Color3.fromRGB(160, 120, 200))
	kiosk(kiosks, "ContractBoard", Vector3.new(-28, 0, 18), "Contracts (soon)", Color3.fromRGB(200, 140, 80))

	-- Leaderboard wall stub (east)
	local lb = part(arena, "LeaderboardWall", Vector3.new(2, 12, 22), CFrame.new(55, 6, 0), Color3.fromRGB(35, 40, 55), Enum.Material.Metal)
	lb:SetAttribute("LeaderboardStub", true)
	billboard(lb, "Leaderboard (soon)", Color3.fromRGB(220, 220, 230))

	-- Party stub — Ready Together
	local party = part(arena, "ReadyTogether", Vector3.new(10, 1.2, 10), CFrame.new(28, 0.6, -22), Color3.fromRGB(90, 180, 220), Enum.Material.SmoothPlastic)
	party:SetAttribute("PartyStub", true)
	billboard(party, "Ready Together (party stub)", Color3.fromRGB(180, 230, 255))
	-- Soft stub: no real party sync yet; documented in DESIGN_SPEC / README

	-- Queue pads
	local padsFolder = Instance.new("Folder")
	padsFolder.Name = "QueuePads"
	padsFolder.Parent = arena

	local padSpacing = 16
	local startX = -((#ModesConfig.PadOrder - 1) * padSpacing) / 2
	for i, modeId in ModesConfig.PadOrder do
		local cfg = ModesConfig.Modes[modeId]
		if cfg then
			local x = startX + (i - 1) * padSpacing
			local color = cfg.PadColor or Color3.fromRGB(100, 100, 100)
			local pad = part(
				padsFolder,
				"Pad_" .. modeId,
				Vector3.new(12, 1.2, 12),
				CFrame.new(x, 0.6, 28),
				color,
				Enum.Material.Neon
			)
			pad.Transparency = 0.15
			pad:SetAttribute("QueueModeId", modeId)
			pad:SetAttribute("IsQueuePad", true)
			-- ProximityPrompt for pad queue (client also listens)
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Queue " .. cfg.DisplayName
			prompt.ObjectText = "Latch"
			prompt.HoldDuration = 0.2
			prompt.MaxActivationDistance = 14
			prompt.RequiresLineOfSight = false
			prompt.Parent = pad
			billboard(pad, cfg.DisplayName, Color3.new(1, 1, 1))
		end
	end

	-- Default player spawns near plaza (neutral lobby)
	local spawnA = Instance.new("Folder")
	spawnA.Name = "SpawnA"
	spawnA.Parent = arena
	spawnLocation(spawnA, "LobbySpawn1", CFrame.new(-8, 1, -8), "A")
	spawnLocation(spawnA, "LobbySpawn2", CFrame.new(-8, 1, 8), "A")
	spawnLocation(spawnA, "LobbySpawn3", CFrame.new(8, 1, -8), "A")
	spawnLocation(spawnA, "LobbySpawn4", CFrame.new(8, 1, 8), "A")

	local spawnB = Instance.new("Folder")
	spawnB.Name = "SpawnB"
	spawnB.Parent = arena
	spawnLocation(spawnB, "LobbySpawnB1", CFrame.new(18, 1, 8), "B")
	spawnLocation(spawnB, "LobbySpawnB2", CFrame.new(18, 1, -8), "B")

	local mid = Instance.new("Part")
	mid.Name = "ArenaCenter"
	mid.Anchored = true
	mid.CanCollide = false
	mid.Transparency = 1
	mid.Size = Vector3.new(1, 1, 1)
	mid.Position = Vector3.new(0, 5, 0)
	mid.Parent = arena

	LobbyBuilder._placeWaypoints(arena)
	LobbyBuilder._placePadWaypoints(arena)

	return arena
end

function LobbyBuilder._placeWaypoints(arena: Instance)
	local existing = arena:FindFirstChild("Waypoints")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Waypoints"
	folder.Parent = arena

	local spacing = 16
	local idx = 0
	for x = -56, 56, spacing do
		for z = -40, 40, spacing do
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

-- Extra waypoints on/near queue pads so LobbyBotDirector can wander between pads
function LobbyBuilder._placePadWaypoints(arena: Instance)
	local pads = arena:FindFirstChild("QueuePads")
	local wpFolder = arena:FindFirstChild("Waypoints")
	if not pads or not wpFolder then
		return
	end
	local padWp = Instance.new("Folder")
	padWp.Name = "PadWaypoints"
	padWp.Parent = arena
	for _, pad in pads:GetChildren() do
		if pad:IsA("BasePart") then
			local p = Instance.new("Part")
			p.Name = "PadWP_" .. pad.Name
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Transparency = 1
			p.Size = Vector3.new(1, 1, 1)
			p.Position = pad.Position + Vector3.new(0, 2, 0)
			p.Parent = padWp
			p:SetAttribute("QueueModeId", pad:GetAttribute("QueueModeId"))
			local att = Instance.new("Attachment")
			att.Name = "Waypoint"
			att.Parent = p
			-- Also add into main waypoints for random wander mix
			local copy = p:Clone()
			copy.Parent = wpFolder
		end
	end
end

function LobbyBuilder.EnsureWaypoints()
	local arena = Workspace:FindFirstChild("LatchArena")
	if not arena then
		return
	end
	if not arena:FindFirstChild("Waypoints") then
		LobbyBuilder._placeWaypoints(arena)
		LobbyBuilder._placePadWaypoints(arena)
	end
end

function LobbyBuilder.GetWaypointPositions(): { Vector3 }
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

function LobbyBuilder.GetPadPositions(): { { ModeId: string, Position: Vector3 } }
	local arena = Workspace:FindFirstChild("LatchArena")
	if not arena then
		return {}
	end
	local pads = arena:FindFirstChild("QueuePads")
	if not pads then
		return {}
	end
	local list = {}
	for _, pad in pads:GetChildren() do
		if pad:IsA("BasePart") then
			local modeId = pad:GetAttribute("QueueModeId")
			if typeof(modeId) == "string" then
				table.insert(list, { ModeId = modeId, Position = pad.Position })
			end
		end
	end
	return list
end

function LobbyBuilder.GetSpawns(team: string): { SpawnLocation }
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

return LobbyBuilder
