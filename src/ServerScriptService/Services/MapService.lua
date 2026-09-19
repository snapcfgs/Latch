--!strict
--[[
	MapService — load/clear match maps, lighting, spawns, bot waypoints/cover, map vote.
	Lobby space stays via ArenaBuilder (LatchArena); match arenas are Parts maps (LatchMap).
]]

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local MapsConfig = require(game.ReplicatedStorage.Config.Maps)
local MatchSettings = require(game.ReplicatedStorage.Config.MatchSettings)

local MapsFolder = script.Parent:WaitForChild("Maps")

local BUILDERS: { [string]: { Build: () -> Folder } } = {
	Splityard = require(MapsFolder.Splityard),
	Voltage = require(MapsFolder.Voltage),
	Hollow = require(MapsFolder.Hollow),
	Dredge = require(MapsFolder.Dredge),
	Glassline = require(MapsFolder.Glassline),
	Ridge = require(MapsFolder.Ridge),
}

type LightingTable = {
	ClockTime: number,
	FogStart: number,
	FogEnd: number,
	FogColor: Color3,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	Brightness: number?,
}

local DEFAULT_LIGHTING: LightingTable = {
	ClockTime = 14,
	FogStart = 0,
	FogEnd = 100000,
	FogColor = Color3.fromRGB(192, 192, 192),
	Ambient = Color3.fromRGB(128, 128, 128),
	OutdoorAmbient = Color3.fromRGB(128, 128, 128),
	Brightness = 2,
}

local MapService = {}
MapService.__index = MapService

function MapService.new()
	local self = setmetatable({
		_remotes = nil :: { [string]: RemoteEvent }?,
		_currentMapId = nil :: string?,
		_mapRoot = nil :: Folder?,
		_lastPlayedMapId = nil :: string?,
		_killConn = nil :: RBXScriptConnection?,
		_voteOptions = {} :: { string },
		_voteTallies = {} :: { [string]: number },
		_voteEndsAt = nil :: number?,
		_playerVotes = {} :: { [Player]: string },
	}, MapService)
	return self
end

function MapService:Init()
	self:_applyLightingTable(DEFAULT_LIGHTING)
	print("[Latch] MapService ready")
end

function MapService:BindRemotes(remotes: { [string]: RemoteEvent })
	self._remotes = remotes
	if remotes.MapVoteCast then
		remotes.MapVoteCast.OnServerEvent:Connect(function(player, mapId)
			self:CastPlayerVote(player, mapId)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		local prev = self._playerVotes[player]
		if prev and self._voteEndsAt then
			self._voteTallies[prev] = math.max(0, (self._voteTallies[prev] or 0) - 1)
			self._playerVotes[player] = nil
		end
	end)
end

function MapService:GetCurrentMapId(): string?
	return self._currentMapId
end

function MapService:GetLastPlayedMapId(): string?
	return self._lastPlayedMapId
end

function MapService:GetMapRoot(): Folder?
	return self._mapRoot
end

function MapService:IsMatchMapLoaded(): boolean
	return self._mapRoot ~= nil and self._currentMapId ~= nil
end

function MapService:_disconnectKill()
	if self._killConn then
		self._killConn:Disconnect()
		self._killConn = nil
	end
end

function MapService:_applyLightingTable(hints: LightingTable)
	Lighting.ClockTime = hints.ClockTime
	Lighting.FogStart = hints.FogStart
	Lighting.FogEnd = hints.FogEnd
	Lighting.FogColor = hints.FogColor
	Lighting.Ambient = hints.Ambient
	Lighting.OutdoorAmbient = hints.OutdoorAmbient
	if hints.Brightness ~= nil then
		Lighting.Brightness = hints.Brightness
	end
end

function MapService:ApplyLighting(mapId: string)
	local def = MapsConfig.Get(mapId)
	if not def then
		self:_applyLightingTable(DEFAULT_LIGHTING)
		return
	end
	local L = def.Lighting
	self:_applyLightingTable({
		ClockTime = L.ClockTime,
		FogStart = L.FogStart,
		FogEnd = L.FogEnd,
		FogColor = L.FogColor,
		Ambient = L.Ambient,
		OutdoorAmbient = L.OutdoorAmbient,
		Brightness = L.Brightness,
	})
end

function MapService:_hideLobbyArena()
	local lobby = Workspace:FindFirstChild("LatchArena")
	if not lobby then
		return
	end
	local park = Workspace:FindFirstChild("LatchLobbyParked")
	if not park then
		park = Instance.new("Folder")
		park.Name = "LatchLobbyParked"
		park.Parent = Workspace
	end
	lobby.Parent = park
end

function MapService:_restoreLobbyArena()
	local park = Workspace:FindFirstChild("LatchLobbyParked")
	if not park then
		return
	end
	local lobby = park:FindFirstChild("LatchArena")
	if lobby then
		lobby.Parent = Workspace
	end
end

function MapService:ClearMap()
	self:_disconnectKill()
	if self._mapRoot then
		self._mapRoot:Destroy()
		self._mapRoot = nil
	end
	local existing = Workspace:FindFirstChild("LatchMap")
	if existing then
		existing:Destroy()
	end
	self._currentMapId = nil
	self:_applyLightingTable(DEFAULT_LIGHTING)
end

function MapService:ReturnToLobby()
	self:ClearMap()
	self:_restoreLobbyArena()
end

function MapService:LoadMap(mapId: string): Folder?
	local builder = BUILDERS[mapId]
	if not builder then
		warn("[Latch] Unknown map:", mapId)
		return nil
	end

	self:ClearMap()
	self:_hideLobbyArena()

	local root = builder.Build()
	root.Name = "LatchMap"
	root:SetAttribute("MapId", mapId)
	root.Parent = Workspace

	self._mapRoot = root
	self._currentMapId = mapId
	self._lastPlayedMapId = mapId
	self:ApplyLighting(mapId)
	self:_bindKillFloor(root)

	print("[Latch] Loaded map:", mapId)
	return root
end

function MapService:_bindKillFloor(root: Folder)
	self:_disconnectKill()
	local kill = root:FindFirstChild("KillFloor", true)
	if not kill or not kill:IsA("BasePart") then
		return
	end
	self._killConn = kill.Touched:Connect(function(hit)
		local model = hit:FindFirstAncestorOfClass("Model")
		if not model then
			return
		end
		local hum = model:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then
			return
		end
		hum.Health = 0
	end)
end

function MapService:GetSpawns(team: string): { SpawnLocation }
	local root = self._mapRoot
	if not root then
		return {}
	end
	local folderName = if team == "B" then "SpawnB" else "SpawnA"
	local folder = root:FindFirstChild(folderName)
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

function MapService:GetWaypointPositions(): { Vector3 }
	local root = self._mapRoot
	if not root then
		return {}
	end
	local folder = root:FindFirstChild("Waypoints")
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

function MapService:GetCoverNodePositions(): { Vector3 }
	local root = self._mapRoot
	if not root then
		return {}
	end
	local folder = root:FindFirstChild("CoverNodes")
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

--[[ Prefer cover nodes for TakeCover; fall back to waypoints. ]]
function MapService:GetBotNavPositions(): { Vector3 }
	local cover = self:GetCoverNodePositions()
	local waypoints = self:GetWaypointPositions()
	if #cover == 0 then
		return waypoints
	end
	-- Merge: waypoints for roam, cover nodes included
	local seen: { [string]: boolean } = {}
	local out: { Vector3 } = {}
	local function add(pos: Vector3)
		local key = string.format("%.0f_%.0f_%.0f", pos.X, pos.Y, pos.Z)
		if seen[key] then
			return
		end
		seen[key] = true
		table.insert(out, pos)
	end
	for _, p in waypoints do
		add(p)
	end
	for _, p in cover do
		add(p)
	end
	return out
end

function MapService:PickVoteOptions(count: number?): { string }
	local n = count or 3
	local last = self._lastPlayedMapId
	local pool: { string } = {}
	local weights: { number } = {}
	for _, id in MapsConfig.Order do
		table.insert(pool, id)
		table.insert(weights, if id == last then 0.25 else 1)
	end

	local picked: { string } = {}
	local function already(id: string): boolean
		return table.find(picked, id) ~= nil
	end

	for _ = 1, math.min(n, #pool) do
		local total = 0
		for i, id in pool do
			if not already(id) then
				total += weights[i]
			end
		end
		if total <= 0 then
			break
		end
		local roll = math.random() * total
		local acc = 0
		local chosen: string? = nil
		for i, id in pool do
			if already(id) then
				continue
			end
			acc += weights[i]
			if roll <= acc then
				chosen = id
				break
			end
		end
		if chosen then
			table.insert(picked, chosen)
		end
	end

	for _, id in MapsConfig.Order do
		if #picked >= n then
			break
		end
		if not already(id) then
			table.insert(picked, id)
		end
	end
	return picked
end

function MapService:_tallyPayload(): { [string]: number }
	local out: { [string]: number } = {}
	for k, v in self._voteTallies do
		out[k] = v
	end
	return out
end

function MapService:_botPick(options: { string }): string
	local last = self._lastPlayedMapId
	local weights: { [string]: number } = {}
	local total = 0
	for _, id in options do
		local w = 1.0
		if id == last then
			w = 0.35
		end
		local def = MapsConfig.Get(id)
		if def and def.SizeClass == "Medium" then
			w *= 1.15
		elseif def and def.SizeClass == "Large" then
			w *= 0.95
		end
		-- Variety: slight boost if not recently played (same as last penalty inverse)
		weights[id] = w
		total += w
	end
	local roll = math.random() * total
	local acc = 0
	for _, id in options do
		acc += weights[id]
		if roll <= acc then
			return id
		end
	end
	return options[1]
end

function MapService:_winningMap(options: { string }): string
	local bestScore = -1
	local tied: { string } = {}
	for _, id in options do
		local score = self._voteTallies[id] or 0
		if score > bestScore then
			bestScore = score
			tied = { id }
		elseif score == bestScore then
			table.insert(tied, id)
		end
	end
	if #tied == 0 then
		return options[1]
	end
	if #tied == 1 then
		return tied[1]
	end
	local filtered: { string } = {}
	for _, id in tied do
		if id ~= self._lastPlayedMapId then
			table.insert(filtered, id)
		end
	end
	local pool = if #filtered > 0 then filtered else tied
	return pool[math.random(1, #pool)]
end

--[[
	Run map vote. Humans vote via MapVoteCast; bots vote weighted toward variety.
	Returns winning mapId.
]]
function MapService:RunMapVote(botVoteCount: number): string
	local options = self:PickVoteOptions(3)
	self._voteOptions = options
	self._voteTallies = {}
	self._playerVotes = {}
	for _, id in options do
		self._voteTallies[id] = 0
	end

	local duration = MatchSettings.MapVoteSeconds
	local endsAt = Workspace:GetServerTimeNow() + duration
	self._voteEndsAt = endsAt

	local payloadOptions = {}
	for _, id in options do
		local def = MapsConfig.Get(id)
		local color = if def then def.ThumbnailColor else Color3.fromRGB(80, 80, 80)
		table.insert(payloadOptions, {
			Id = id,
			DisplayName = if def then def.DisplayName else id,
			SizeClass = if def then def.SizeClass else "Medium",
			ThumbnailColor = { color.R, color.G, color.B },
			Description = if def then def.Description else "",
		})
	end

	local remotes = self._remotes
	if remotes and remotes.MapVoteStart then
		remotes.MapVoteStart:FireAllClients({
			Options = payloadOptions,
			EndsAt = endsAt,
			Duration = duration,
		})
	end

	-- Bot votes stagger in
	local bots = math.max(0, botVoteCount)
	task.spawn(function()
		task.wait(0.35 + math.random() * 0.8)
		for _ = 1, bots do
			if not self._voteEndsAt then
				break
			end
			local choice = self:_botPick(options)
			self._voteTallies[choice] = (self._voteTallies[choice] or 0) + 1
			if remotes and remotes.MapVoteUpdate then
				remotes.MapVoteUpdate:FireAllClients({
					Tallies = self:_tallyPayload(),
					EndsAt = endsAt,
				})
			end
			task.wait(0.12 + math.random() * 0.4)
		end
	end)

	while Workspace:GetServerTimeNow() < endsAt do
		task.wait(0.2)
	end

	local winner = self:_winningMap(options)
	if remotes and remotes.MapVoteResult then
		remotes.MapVoteResult:FireAllClients({
			MapId = winner,
			Tallies = self:_tallyPayload(),
		})
	end

	self._voteEndsAt = nil
	self._playerVotes = {}
	return winner
end

function MapService:CastPlayerVote(player: Player, mapId: any)
	if typeof(mapId) ~= "string" then
		return
	end
	local id = mapId :: string
	if not self._voteEndsAt or Workspace:GetServerTimeNow() >= self._voteEndsAt then
		return
	end
	if not table.find(self._voteOptions, id) then
		return
	end
	local prev = self._playerVotes[player]
	if prev == id then
		return
	end
	if prev then
		self._voteTallies[prev] = math.max(0, (self._voteTallies[prev] or 0) - 1)
	end
	self._playerVotes[player] = id
	self._voteTallies[id] = (self._voteTallies[id] or 0) + 1

	local remotes = self._remotes
	if remotes and remotes.MapVoteUpdate then
		remotes.MapVoteUpdate:FireAllClients({
			Tallies = self:_tallyPayload(),
			EndsAt = self._voteEndsAt,
			VoterUserId = player.UserId,
			MapId = id,
		})
	end
end

return MapService
