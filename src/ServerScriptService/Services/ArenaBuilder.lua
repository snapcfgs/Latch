--!strict
--[[
	ArenaBuilder — lobby facade.
	Phase 3: real lobby lives in LobbyBuilder (pads, kiosks, alcove).
	Kept so MapService / BotService / MatchService call sites stay stable.
]]

local LobbyBuilder = require(script.Parent.LobbyBuilder)

local ArenaBuilder = {}

function ArenaBuilder.Build()
	return LobbyBuilder.Build()
end

function ArenaBuilder.EnsureWaypoints()
	LobbyBuilder.EnsureWaypoints()
end

function ArenaBuilder.GetWaypointPositions(): { Vector3 }
	return LobbyBuilder.GetWaypointPositions()
end

function ArenaBuilder.GetSpawns(team: string): { SpawnLocation }
	return LobbyBuilder.GetSpawns(team)
end

function ArenaBuilder.GetPadPositions(): { { ModeId: string, Position: Vector3 } }
	return LobbyBuilder.GetPadPositions()
end

return ArenaBuilder
