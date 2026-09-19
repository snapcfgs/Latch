--!strict
--[[
	MatchService — lobby queue, multi-mode matches, bot fill, map vote, operator lock, recap.
	Phase 3: extends modes via Config/Modes.lua (no per-mode forks).
	Flow: Queue → MapVote → OperatorLock (8s) → Countdown → rounds/match → MatchRecap → Lobby
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local MatchSettings = require(game.ReplicatedStorage.Config.MatchSettings)
local ModesConfig = require(game.ReplicatedStorage.Config.Modes)
local OperatorsConfig = require(game.ReplicatedStorage.Config.Operators)
local BotsConfig = require(game.ReplicatedStorage.Config.Bots)
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local ArenaBuilder = require(script.Parent.ArenaBuilder)
local ActorUtil = require(script.Parent.ActorUtil)

type Actor = ActorUtil.Actor
type BotRecord = ActorUtil.BotRecord
type Phase = "Lobby" | "MapVote" | "OperatorLock" | "Countdown" | "Round" | "RoundEnd" | "MatchEnd" | "MatchRecap"

local MatchService = {}
MatchService.__index = MatchService

function MatchService.new(
	remotes: { [string]: RemoteEvent },
	weaponService: any,
	abilityService: any,
	botService: any?
)
	local self = setmetatable({
		_remotes = remotes,
		_weapons = weaponService,
		_abilities = abilityService,
		_bots = botService,
		_maps = nil :: any,
		_currentMapId = nil :: string?,
		_phase = "Lobby" :: Phase,
		_queuedModeId = MatchSettings.DefaultModeId, -- mode player queued
		_modeId = MatchSettings.DefaultModeId, -- resolved mode for the match
		_modeCfg = ModesConfig.Get(MatchSettings.DefaultModeId),
		_scoreA = 0,
		_scoreB = 0,
		_roundNumber = 0,
		_phaseEndsAt = nil :: number?,
		_teamA = {} :: { Actor },
		_teamB = {} :: { Actor },
		_participants = {} :: { Actor }, -- FFA / GunCycle flat list
		_elimScores = {} :: { [number]: number }, -- FFA elim counts / GunCycle index
		_gunIndex = {} :: { [number]: number }, -- 1-based index into GunCycleOrder
		_queue = {} :: { Player },
		_operators = {} :: { [Player]: string },
		_running = false,
		_fillStartedAt = nil :: number?,
		_fillModeId = nil :: string?,
		_matchWinner = nil :: string?, -- "A" | "B" | userId string for FFA
		_abortMatch = false,
		_pendingRespawns = {} :: { [number]: thread },
	}, MatchService)
	return self
end

function MatchService:SetBotService(botService: any)
	self._bots = botService
end

function MatchService:SetMapService(mapService: any)
	self._maps = mapService
end

function MatchService:Init()
	ArenaBuilder.Build()

	self._remotes.RequestQueue.OnServerEvent:Connect(function(player, modeId)
		self:_onQueue(player, modeId)
	end)
	self._remotes.RequestOperator.OnServerEvent:Connect(function(player, operatorId)
		self:_onOperator(player, operatorId)
	end)
	if self._remotes.RequestLeaveQueue then
		self._remotes.RequestLeaveQueue.OnServerEvent:Connect(function(player)
			self:_removeFromQueue(player)
			if self._phase == "Lobby" and #self._queue == 0 then
				self._fillStartedAt = nil
				self._fillModeId = nil
			end
			self:_broadcastSnapshot()
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute(Constants.AttributeAlive, false)
		self:_broadcastSnapshot()
		player.CharacterAdded:Connect(function(char)
			self:_onCharacter(player, char)
		end)
		task.defer(function()
			self:_tryReplaceStandIn(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_removeFromQueue(player)
		self._operators[player] = nil
		self:_stripFromTeams(player)
		self:_cancelRespawn(ActorUtil.UserId(player))
		if self._phase == "Lobby" and #self._queue == 0 then
			self._fillStartedAt = nil
			self._fillModeId = nil
		end
	end)

	self._weapons:SetOnKill(function(attacker, victim)
		self:_onActorEliminated(victim, attacker)
	end)

	task.spawn(function()
		self:_lobbyLoop()
	end)
end

function MatchService:_getMode(modeId: string?): any
	local id = modeId or self._modeId
	local cfg = ModesConfig.Get(id)
	if cfg then
		return cfg
	end
	return ModesConfig.Modes["1v1"]
end

function MatchService:_fighterInfo(actor: Actor): { [string]: any }
	local op = ActorUtil.GetAttribute(actor, Constants.AttributeOperator)
	local uid = ActorUtil.UserId(actor)
	return {
		UserId = uid,
		DisplayName = ActorUtil.DisplayName(actor),
		IsBot = ActorUtil.IsBot(actor),
		OperatorId = if typeof(op) == "string" then op else nil,
		Alive = ActorUtil.IsAlive(actor),
		Team = ActorUtil.GetAttribute(actor, Constants.AttributeTeam) or "A",
		Elims = self._elimScores[uid] or 0,
		GunIndex = self._gunIndex[uid],
	}
end

function MatchService:_broadcastSnapshot()
	local fighters = {}
	for _, a in self:_allMatchActors() do
		table.insert(fighters, self:_fighterInfo(a))
	end

	local cfg = self:_getMode(self._queuedModeId)
	local fillEndsAt: number? = nil
	if self._phase == "Lobby" and self._fillStartedAt and not self._running then
		fillEndsAt = self._fillStartedAt + (cfg.FillSeconds or MatchSettings.FillTimerDefaultSeconds)
	end

	local winTarget = cfg.WinTarget
	if cfg.WinType == "GunCycle" then
		winTarget = #ModesConfig.GunCycleOrder
	elseif cfg.WinType == "Rounds" then
		winTarget = cfg.WinTarget
	end

	local snap = {
		Phase = self._phase,
		CurrentMapId = self._currentMapId,
		ModeId = self._modeId,
		QueuedModeId = self._queuedModeId,
		RoundNumber = self._roundNumber,
		ScoreA = self._scoreA,
		ScoreB = self._scoreB,
		RoundsToWin = if cfg.WinType == "Rounds" then cfg.WinTarget else MatchSettings.RoundsToWin,
		WinTarget = winTarget,
		WinType = cfg.WinType,
		IsFFA = cfg.IsFFA == true,
		PhaseEndsAt = self._phaseEndsAt,
		TeamA = self:_userIds(self._teamA),
		TeamB = self:_userIds(self._teamB),
		Fighters = fighters,
		FillEndsAt = fillEndsAt,
		QueueCount = #self._queue,
	}
	self._remotes.MatchSnapshot:FireAllClients(snap)
end

function MatchService:_userIds(list: { Actor }): { number }
	local ids = {}
	for _, a in list do
		table.insert(ids, ActorUtil.UserId(a))
	end
	return ids
end

function MatchService:_onQueue(player: Player, modeId: any)
	if self._phase ~= "Lobby" then
		return
	end
	if typeof(modeId) == "string" and ModesConfig.Get(modeId) then
		self._queuedModeId = modeId
		self._modeId = modeId
		self._modeCfg = ModesConfig.Get(modeId)
	end
	if not table.find(self._queue, player) then
		table.insert(self._queue, player)
	end
	if not self._operators[player] then
		self._operators[player] = "Skid"
		self._abilities:ApplyOperatorPassives(player, "Skid")
	end

	local need = self:_neededPlayers()
	if #self._queue < need then
		if not self._fillStartedAt or self._fillModeId ~= self._queuedModeId then
			self._fillStartedAt = Workspace:GetServerTimeNow()
			self._fillModeId = self._queuedModeId
		end
	else
		self._fillStartedAt = nil
		self._fillModeId = nil
	end

	self:_broadcastSnapshot()
	self:_tryStart()
end

function MatchService:_onOperator(player: Player, operatorId: any)
	if typeof(operatorId) ~= "string" then
		return
	end
	if not OperatorsConfig.Operators[operatorId :: any] then
		return
	end
	-- Lock after OperatorLock window ends (Countdown / Round)
	if self._phase == "Round" or self._phase == "Countdown" or self._phase == "RoundEnd" then
		return
	end
	self._operators[player] = operatorId
	self._abilities:ApplyOperatorPassives(player, operatorId)
	self._remotes.PlayerState:FireClient(player, { OperatorId = operatorId })
	self:_broadcastSnapshot()
end

function MatchService:_removeFromQueue(player: Player)
	local i = table.find(self._queue, player)
	if i then
		table.remove(self._queue, i)
	end
end

function MatchService:_stripFromTeams(player: Player)
	local ia = table.find(self._teamA, player)
	if ia then
		table.remove(self._teamA, ia)
	end
	local ib = table.find(self._teamB, player)
	if ib then
		table.remove(self._teamB, ib)
	end
	local ip = table.find(self._participants, player)
	if ip then
		table.remove(self._participants, ip)
	end
end

function MatchService:_neededPlayers(): number
	local cfg = self:_getMode(self._queuedModeId)
	return cfg.MaxPlayers
end

function MatchService:_fillSeconds(): number
	local cfg = self:_getMode(self._queuedModeId)
	return cfg.FillSeconds or MatchSettings.FillTimerDefaultSeconds
end

function MatchService:_teamSize(): number
	local cfg = self:_getMode()
	return cfg.TeamSize
end

function MatchService:_tryStart()
	if self._running or self._phase ~= "Lobby" then
		return
	end
	local need = self:_neededPlayers()
	local count = #self._queue
	if count <= 0 then
		return
	end

	if count >= need then
		self._fillStartedAt = nil
		task.spawn(function()
			self:_startMatch(false)
		end)
		return
	end

	if not self._fillStartedAt then
		self._fillStartedAt = Workspace:GetServerTimeNow()
		self._fillModeId = self._queuedModeId
		self:_broadcastSnapshot()
		return
	end

	local elapsed = Workspace:GetServerTimeNow() - self._fillStartedAt
	if elapsed >= self:_fillSeconds() then
		self._fillStartedAt = nil
		task.spawn(function()
			self:_startMatch(true)
		end)
	end
end

function MatchService:_lobbyLoop()
	while true do
		task.wait(0.35)
		if self._phase == "Lobby" and not self._running then
			self:_tryStart()
			if self._fillStartedAt then
				self:_broadcastSnapshot()
			end
		end
	end
end

function MatchService:_resolveModeForMatch()
	local queued = self._queuedModeId
	local resolved = ModesConfig.ResolveCasualMix(queued)
	self._modeId = resolved
	self._modeCfg = ModesConfig.Get(resolved)
	if queued ~= resolved then
		self._remotes.Announce:FireAllClients({
			Kind = "CasualMix",
			Message = string.format("Casual Mix → %s", (self._modeCfg and self._modeCfg.DisplayName) or resolved),
		})
	end
end

function MatchService:_assignTeams(allowBots: boolean)
	self._teamA = {}
	self._teamB = {}
	self._participants = {}
	local cfg = self:_getMode()
	local teamSize = cfg.TeamSize
	-- Bot fill pads FFA/GunCycle to FillTarget; team modes always fill each side to TeamSize
	local need: number
	if not allowBots then
		need = cfg.MaxPlayers
	else
		need = math.max(#self._queue, cfg.FillTarget or cfg.MaxPlayers)
		need = math.min(need, cfg.MaxPlayers)
	end

	local picked: { Player } = {}
	for i = 1, math.min(need, #self._queue) do
		table.insert(picked, self._queue[i])
	end
	for _, p in picked do
		self:_removeFromQueue(p)
	end

	if cfg.IsFFA then
		for _, p in picked do
			local team = "F" .. tostring(p.UserId)
			table.insert(self._participants, p)
			p:SetAttribute(Constants.AttributeTeam, team)
		end
		if allowBots and self._bots then
			while #self._participants < need do
				local diff = self:_botDiffForFill(#self._participants)
				local bot = self._bots:SpawnBot({
					TeamId = "TEMP",
					Difficulty = diff,
					LobbyOnly = false,
				})
				local team = "F" .. tostring(bot.Id)
				bot.TeamId = team
				ActorUtil.SetAttribute(bot, Constants.AttributeTeam, team)
				table.insert(self._participants, bot)
			end
		end
		return
	end

	-- Team modes: alternate humans
	for _, p in picked do
		local team: string
		if #self._teamA < teamSize and (#self._teamA <= #self._teamB or #self._teamB >= teamSize) then
			team = "A"
		elseif #self._teamB < teamSize then
			team = "B"
		else
			team = "A"
		end
		if team == "A" then
			table.insert(self._teamA, p)
		else
			table.insert(self._teamB, p)
		end
		p:SetAttribute(Constants.AttributeTeam, team)
	end

	if allowBots and self._bots then
		while #self._teamA < teamSize do
			local diff = self:_botDiffForFill(#self._teamA)
			local bot = self._bots:SpawnBot({
				TeamId = "A",
				Difficulty = diff,
				LobbyOnly = false,
			})
			table.insert(self._teamA, bot)
		end
		while #self._teamB < teamSize do
			local diff = self:_botDiffForFill(#self._teamB)
			local bot = self._bots:SpawnBot({
				TeamId = "B",
				Difficulty = diff,
				LobbyOnly = false,
			})
			table.insert(self._teamB, bot)
		end
	end
end

function MatchService:_botDiffForFill(slotIndex: number): string
	local cfg = self:_getMode()
	if cfg.BotDifficulty then
		return cfg.BotDifficulty
	end
	return BotsConfig.FillOrder[math.min(slotIndex + 1, #BotsConfig.FillOrder)]
end

function MatchService:_applyBeginnerMults()
	local cfg = self:_getMode()
	local mult = cfg.DamageTakenMult
	if not mult or mult == 1 then
		return
	end
	for _, actor in self:_allMatchActors() do
		self._weapons:SetDamageTakenMult(actor, mult)
	end
end

function MatchService:_initGunCycle()
	local cfg = self:_getMode()
	if cfg.WinType ~= "GunCycle" then
		return
	end
	local first = ModesConfig.GunCycleOrder[1]
	for _, actor in self:_allMatchActors() do
		local uid = ActorUtil.UserId(actor)
		self._gunIndex[uid] = 1
		self._elimScores[uid] = 0
		self._weapons:ForceGunCycleWeapon(actor, first)
	end
end

function MatchService:_startMatch(fillWithBots: boolean)
	if self._running then
		return
	end
	self._running = true
	self._abortMatch = false
	self._matchWinner = nil
	self._elimScores = {}
	self._gunIndex = {}
	self._weapons:ResetMatchStats()
	self._weapons:ClearDamageTakenMults()
	self._weapons:ClearGunCycleLocks()

	if self._bots then
		self._bots:SetMatchActive(true)
	end

	self:_resolveModeForMatch()
	self:_assignTeams(fillWithBots)

	local cfg = self:_getMode()
	if cfg.IsFFA then
		if #self._participants < 2 then
			warn("[Latch] Match aborted — not enough FFA participants")
			self:_endToLobby()
			return
		end
	elseif #self._teamA == 0 or #self._teamB == 0 then
		warn("[Latch] Match aborted — empty team after assign")
		self:_endToLobby()
		return
	end

	self._scoreA = 0
	self._scoreB = 0
	self._roundNumber = 0

	local botCount = 0
	for _, a in self:_allMatchActors() do
		if ActorUtil.IsBot(a) then
			botCount += 1
		end
	end
	if botCount > 0 then
		self._remotes.Announce:FireAllClients({
			Kind = "BotFill",
			Message = string.format("%s starting with %d stand-in bot(s)", cfg.DisplayName, botCount),
		})
	end

	-- Map vote
	self._phase = "MapVote"
	self._phaseEndsAt = Workspace:GetServerTimeNow() + (MatchSettings.MapVoteSeconds or 8)
	self:_broadcastSnapshot()
	local mapId = "Splityard"
	if self._maps then
		mapId = self._maps:RunMapVote(botCount)
		self._maps:LoadMap(mapId)
		self._currentMapId = mapId
		if self._bots and self._bots.RefreshNav then
			self._bots:RefreshNav()
		end
		self._remotes.Announce:FireAllClients({
			Kind = "MapSelected",
			Message = string.format("Map: %s", mapId),
		})
	end

	-- Operator + loadout lock
	self._phase = "OperatorLock"
	self._phaseEndsAt = Workspace:GetServerTimeNow() + (MatchSettings.OperatorLockSeconds or 8)
	self:_broadcastSnapshot()
	self._remotes.Announce:FireAllClients({
		Kind = "OperatorLock",
		Message = "Lock operator & loadout!",
	})
	task.wait(MatchSettings.OperatorLockSeconds or 8)

	self:_applyBeginnerMults()
	self:_initGunCycle()

	-- Continuous modes (FFA / TDM / GunCycle) vs round-based
	if cfg.WinType == "Rounds" then
		self:_runRoundsMatch()
	else
		self:_runContinuousMatch()
	end

	self:_finishMatch()
end

function MatchService:_runRoundsMatch()
	local cfg = self:_getMode()
	local target = cfg.WinTarget
	while self._scoreA < target and self._scoreB < target and not self._abortMatch do
		if #self:_allMatchActors() == 0 then
			break
		end
		if self:_teamVacated("A") or self:_teamVacated("B") then
			break
		end
		self._roundNumber += 1
		self:_runRound()
		if self._scoreA >= target or self._scoreB >= target then
			break
		end
		self._phase = "RoundEnd"
		self._phaseEndsAt = Workspace:GetServerTimeNow() + MatchSettings.BetweenRoundSeconds
		self:_broadcastSnapshot()
		task.wait(MatchSettings.BetweenRoundSeconds)
	end
	self._matchWinner = if self._scoreA > self._scoreB then "A" else "B"
end

function MatchService:_runContinuousMatch()
	local cfg = self:_getMode()
	self._phase = "Countdown"
	self._phaseEndsAt = Workspace:GetServerTimeNow() + MatchSettings.MatchStartCountdown
	self:_broadcastSnapshot()

	for _, actor in self:_allMatchActors() do
		self:_prepareActorForLife(actor)
	end
	task.wait(MatchSettings.MatchStartCountdown)

	self._phase = "Round"
	self._phaseEndsAt = nil
	self._roundNumber = 1
	self:_broadcastSnapshot()
	for _, actor in self:_allMatchActors() do
		self:_unfreezeActor(actor)
	end

	local deadline = Workspace:GetServerTimeNow() + 900
	while Workspace:GetServerTimeNow() < deadline and not self._abortMatch and not self._matchWinner do
		task.wait(0.25)
		-- Win checked in _onActorEliminated for elim/score/guncycle
	end
end

function MatchService:_finishMatch()
	self._phase = "MatchEnd"
	local cfg = self:_getMode()
	local winner = self._matchWinner
	if not winner then
		if cfg.IsFFA or cfg.WinType == "GunCycle" or cfg.WinType == "Eliminations" then
			local bestId: number? = nil
			local bestScore = -1
			for _, actor in self:_allMatchActors() do
				local uid = ActorUtil.UserId(actor)
				local score = if cfg.WinType == "GunCycle"
					then (self._gunIndex[uid] or 1)
					else (self._elimScores[uid] or 0)
				if score > bestScore then
					bestScore = score
					bestId = uid
				end
			end
			winner = if bestId then tostring(bestId) else "A"
		else
			winner = if self._scoreA >= self._scoreB then "A" else "B"
		end
	end
	self._remotes.MatchResult:FireAllClients({
		Winner = winner,
		ScoreA = self._scoreA,
		ScoreB = self._scoreB,
		ModeId = self._modeId,
	})
	self:_broadcastSnapshot()

	-- Recap stub (Tokens/XP placeholders until Phase 4)
	self._phase = "MatchRecap"
	self._phaseEndsAt = Workspace:GetServerTimeNow() + (MatchSettings.MatchRecapSeconds or 8)
	local entries = self:_buildRecapEntries()
	if self._remotes.MatchRecap then
		self._remotes.MatchRecap:FireAllClients({
			ModeId = self._modeId,
			Winner = winner,
			ScoreA = self._scoreA,
			ScoreB = self._scoreB,
			Entries = entries,
			Tokens = 0, -- Phase 4
			XP = 0, -- Phase 4
		})
	end
	self:_broadcastSnapshot()
	task.wait(MatchSettings.MatchRecapSeconds or 8)
	self:_endToLobby()
end

function MatchService:_buildRecapEntries(): { any }
	local entries = {}
	local stats = self._weapons:GetMatchStats()
	for _, actor in self:_allMatchActors() do
		local uid = ActorUtil.UserId(actor)
		local s = stats[uid] or { Kills = 0, Deaths = 0, Damage = 0 }
		table.insert(entries, {
			UserId = uid,
			DisplayName = ActorUtil.DisplayName(actor),
			IsBot = ActorUtil.IsBot(actor),
			Team = ActorUtil.GetAttribute(actor, Constants.AttributeTeam),
			Kills = s.Kills,
			Deaths = s.Deaths,
			Damage = math.floor(s.Damage + 0.5),
			Elims = self._elimScores[uid] or s.Kills,
			GunIndex = self._gunIndex[uid],
			Tokens = 0,
			XP = 0,
		})
	end
	table.sort(entries, function(a, b)
		if a.Kills ~= b.Kills then
			return a.Kills > b.Kills
		end
		return a.Damage > b.Damage
	end)
	return entries
end

function MatchService:_teamVacated(team: string): boolean
	local list = if team == "A" then self._teamA else self._teamB
	return #list == 0
end

function MatchService:_endToLobby()
	for uid, th in self._pendingRespawns do
		task.cancel(th)
		self._pendingRespawns[uid] = nil
	end
	if self._bots then
		self._bots:DespawnMatchBots()
		self._bots:SetMatchActive(false)
	end
	if self._maps then
		self._maps:ReturnToLobby()
	end
	self._currentMapId = nil
	if self._bots and self._bots.RefreshNav then
		self._bots:RefreshNav()
	end
	self._weapons:ClearDamageTakenMults()
	self._weapons:ClearGunCycleLocks()
	self._phase = "Lobby"
	self._teamA = {}
	self._teamB = {}
	self._participants = {}
	self._elimScores = {}
	self._gunIndex = {}
	self._running = false
	self._phaseEndsAt = nil
	self._fillStartedAt = nil
	self._fillModeId = nil
	self._matchWinner = nil
	self._abortMatch = false
	self:_broadcastSnapshot()
end

function MatchService:_prepareActorForLife(actor: Actor)
	local cfg = self:_getMode()
	if ActorUtil.IsBot(actor) then
		local bot = actor :: BotRecord
		if self._bots then
			self._bots:RespawnBot(bot, bot.TeamId)
		end
		if cfg.WinType == "GunCycle" then
			local idx = self._gunIndex[bot.Id] or 1
			local wid = ModesConfig.GunCycleOrder[idx] or ModesConfig.GunCycleOrder[1]
			self._weapons:ForceGunCycleWeapon(bot, wid)
		end
	else
		local p = actor :: Player
		self:_spawnPlayer(p)
		self._weapons:SetupPlayer(p)
		self._weapons:Refill(p)
		self._abilities:ResetCooldown(p)
		local op = self._operators[p] or "Skid"
		self._abilities:ApplyOperatorPassives(p, op)
		p:SetAttribute(Constants.AttributeAlive, true)
		if cfg.DamageTakenMult then
			self._weapons:SetDamageTakenMult(p, cfg.DamageTakenMult)
		end
		if cfg.WinType == "GunCycle" then
			local idx = self._gunIndex[p.UserId] or 1
			local wid = ModesConfig.GunCycleOrder[idx] or ModesConfig.GunCycleOrder[1]
			self._weapons:ForceGunCycleWeapon(p, wid)
		end
	end
end

function MatchService:_unfreezeActor(actor: Actor)
	if ActorUtil.IsBot(actor) then
		if self._bots then
			self._bots:UnfreezeBot(actor :: BotRecord)
		end
	else
		local p = actor :: Player
		local char = p.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.WalkSpeed = MatchSettings.WalkSpeed
				hum.JumpPower = MatchSettings.JumpPower
			end
		end
	end
end

function MatchService:_runRound()
	self._phase = "Countdown"
	self._phaseEndsAt = Workspace:GetServerTimeNow() + MatchSettings.MatchStartCountdown
	self:_broadcastSnapshot()

	for _, actor in self:_allMatchActors() do
		self:_prepareActorForLife(actor)
	end

	task.wait(MatchSettings.MatchStartCountdown)

	self._phase = "Round"
	self._phaseEndsAt = nil
	self:_broadcastSnapshot()

	for _, actor in self:_allMatchActors() do
		self:_unfreezeActor(actor)
	end

	local deadline = Workspace:GetServerTimeNow() + 300
	while Workspace:GetServerTimeNow() < deadline do
		local aliveA = self:_aliveCount(self._teamA)
		local aliveB = self:_aliveCount(self._teamB)
		if aliveA == 0 or aliveB == 0 then
			if aliveA > 0 then
				self._scoreA += 1
				self._remotes.RoundResult:FireAllClients({
					Winner = "A",
					ScoreA = self._scoreA,
					ScoreB = self._scoreB,
				})
			elseif aliveB > 0 then
				self._scoreB += 1
				self._remotes.RoundResult:FireAllClients({
					Winner = "B",
					ScoreA = self._scoreA,
					ScoreB = self._scoreB,
				})
			end
			break
		end
		task.wait(0.25)
	end
end

function MatchService:_allMatchActors(): { Actor }
	local cfg = self:_getMode()
	if cfg.IsFFA then
		return self._participants
	end
	local list = {}
	for _, a in self._teamA do
		table.insert(list, a)
	end
	for _, a in self._teamB do
		table.insert(list, a)
	end
	return list
end

function MatchService:_aliveCount(team: { Actor }): number
	local n = 0
	for _, a in team do
		if ActorUtil.IsAlive(a) then
			n += 1
		end
	end
	return n
end

function MatchService:_cancelRespawn(uid: number)
	local th = self._pendingRespawns[uid]
	if th then
		task.cancel(th)
		self._pendingRespawns[uid] = nil
	end
end

function MatchService:_scheduleRespawn(actor: Actor)
	local cfg = self:_getMode()
	if cfg.RespawnRule ~= "Timed" then
		return
	end
	if self._phase ~= "Round" or self._matchWinner then
		return
	end
	local uid = ActorUtil.UserId(actor)
	self:_cancelRespawn(uid)
	local secs = cfg.RespawnSeconds or 3
	local th = task.delay(secs, function()
		self._pendingRespawns[uid] = nil
		if self._phase ~= "Round" or self._matchWinner then
			return
		end
		-- Still in match?
		local found = false
		for _, a in self:_allMatchActors() do
			if ActorUtil.UserId(a) == uid then
				found = true
				actor = a
				break
			end
		end
		if not found then
			return
		end
		self:_prepareActorForLife(actor)
		self:_unfreezeActor(actor)
		self:_broadcastSnapshot()
	end)
	self._pendingRespawns[uid] = th
end

function MatchService:_onActorEliminated(victim: Actor, attacker: Actor)
	ActorUtil.SetAttribute(victim, Constants.AttributeAlive, false)
	local cfg = self:_getMode()
	local attackerId = ActorUtil.UserId(attacker)
	local victimId = ActorUtil.UserId(victim)

	if cfg.WinType == "Eliminations" then
		self._elimScores[attackerId] = (self._elimScores[attackerId] or 0) + 1
		local elims = self._elimScores[attackerId]
		self:_broadcastSnapshot()
		if elims >= cfg.WinTarget then
			self._matchWinner = tostring(attackerId)
			self._remotes.Announce:FireAllClients({
				Kind = "MatchWin",
				Message = string.format("%s wins FFA!", ActorUtil.DisplayName(attacker)),
			})
		else
			self:_scheduleRespawn(victim)
		end
		return
	end

	if cfg.WinType == "TeamScore" then
		local team = ActorUtil.GetAttribute(attacker, Constants.AttributeTeam)
		if team == "A" then
			self._scoreA += 1
		elseif team == "B" then
			self._scoreB += 1
		end
		self:_broadcastSnapshot()
		if self._scoreA >= cfg.WinTarget then
			self._matchWinner = "A"
		elseif self._scoreB >= cfg.WinTarget then
			self._matchWinner = "B"
		else
			self:_scheduleRespawn(victim)
		end
		return
	end

	if cfg.WinType == "GunCycle" then
		-- Advance attacker's weapon; finishing list wins
		local idx = self._gunIndex[attackerId] or 1
		local order = ModesConfig.GunCycleOrder
		if idx >= #order then
			self._matchWinner = tostring(attackerId)
			self._elimScores[attackerId] = (self._elimScores[attackerId] or 0) + 1
			self._remotes.Announce:FireAllClients({
				Kind = "MatchWin",
				Message = string.format("%s finishes Gun Cycle!", ActorUtil.DisplayName(attacker)),
			})
			self:_broadcastSnapshot()
			return
		end
		idx += 1
		self._gunIndex[attackerId] = idx
		self._elimScores[attackerId] = idx - 1
		local nextW = order[idx]
		self._weapons:ForceGunCycleWeapon(attacker, nextW)
		self._remotes.Announce:FireAllClients({
			Kind = "GunCycle",
			Message = string.format("%s → %s (%d/%d)", ActorUtil.DisplayName(attacker), nextW, idx, #order),
		})
		self:_broadcastSnapshot()
		self:_scheduleRespawn(victim)
		return
	end

	-- Rounds mode: just mark dead; round loop checks alive counts
	self:_broadcastSnapshot()
end

function MatchService:_getSpawns(team: string): { SpawnLocation }
	if self._maps and self._maps:IsMatchMapLoaded() then
		if team:sub(1, 1) == "F" then
			-- FFA: merge both sides
			local a = self._maps:GetSpawns("A")
			local b = self._maps:GetSpawns("B")
			local merged = {}
			for _, s in a do
				table.insert(merged, s)
			end
			for _, s in b do
				table.insert(merged, s)
			end
			if #merged > 0 then
				return merged
			end
		else
			local spawns = self._maps:GetSpawns(team)
			if #spawns > 0 then
				return spawns
			end
		end
	end
	if team:sub(1, 1) == "F" then
		local a = ArenaBuilder.GetSpawns("A")
		local b = ArenaBuilder.GetSpawns("B")
		local merged = {}
		for _, s in a do
			table.insert(merged, s)
		end
		for _, s in b do
			table.insert(merged, s)
		end
		return merged
	end
	return ArenaBuilder.GetSpawns(team)
end

function MatchService:_spawnPlayer(player: Player)
	local teamAttr = player:GetAttribute(Constants.AttributeTeam)
	local team = if typeof(teamAttr) == "string" then teamAttr else "A"
	local spawns = self:_getSpawns(team)
	local spot = spawns[((player.UserId :: number) % math.max(#spawns, 1)) + 1] or spawns[1]

	if not player.Character then
		player:LoadCharacter()
		player.CharacterAdded:Wait()
	end
	local char = player.Character
	if not char then
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char:FindFirstChildOfClass("Humanoid")
	if root and spot then
		root.CFrame = spot.CFrame + Vector3.new(0, 3, 0)
	elseif root then
		root.CFrame = CFrame.new(0, 5, 0)
	end
	if hum then
		hum.MaxHealth = MatchSettings.PlayerHealth
		hum.Health = MatchSettings.PlayerHealth
		hum.WalkSpeed = 0
		hum.JumpPower = 0
	end
end

function MatchService:_onCharacter(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?
	if hum then
		hum.Died:Connect(function()
			player:SetAttribute(Constants.AttributeAlive, false)
		end)
	end
	for _, desc in char:GetDescendants() do
		if desc:IsA("BasePart") then
			pcall(function()
				desc.CollisionGroup = Constants.CollisionGroupPlayers
			end)
		end
	end
	char.DescendantAdded:Connect(function(desc)
		if desc:IsA("BasePart") then
			pcall(function()
				desc.CollisionGroup = Constants.CollisionGroupPlayers
			end)
		end
	end)
end

function MatchService:_tryReplaceStandIn(player: Player)
	if not self._bots or not self._running then
		return
	end
	if table.find(self._teamA, player) or table.find(self._teamB, player) or table.find(self._participants, player) then
		return
	end
	if self._phase ~= "Countdown" and self._phase ~= "Round" and self._phase ~= "RoundEnd" and self._phase ~= "OperatorLock" then
		return
	end

	local cfg = self:_getMode()
	if cfg.IsFFA then
		local candidates: { BotRecord } = {}
		for _, a in self._participants do
			if ActorUtil.IsBot(a) then
				table.insert(candidates, a :: BotRecord)
			end
		end
		if #candidates == 0 then
			return
		end
		local victim = self._bots:FindLowestDifficultyOnTeam((candidates[1] :: BotRecord).TeamId, candidates)
		if not victim then
			victim = candidates[1]
		end
		local replacedName = victim.DisplayName
		local idx = table.find(self._participants, victim)
		if idx then
			table.remove(self._participants, idx)
		end
		self._bots:DespawnBot(victim)
		local team = "F" .. tostring(player.UserId)
		table.insert(self._participants, player)
		player:SetAttribute(Constants.AttributeTeam, team)
		if not self._operators[player] then
			self._operators[player] = "Skid"
		end
		self._abilities:ApplyOperatorPassives(player, self._operators[player])
		if self._phase == "Countdown" or self._phase == "Round" then
			self:_prepareActorForLife(player)
			if self._phase == "Round" then
				self:_unfreezeActor(player)
			end
		end
		self._remotes.StandInReplaced:FireAllClients({
			PlayerUserId = player.UserId,
			PlayerName = player.DisplayName ~= "" and player.DisplayName or player.Name,
			ReplacedBotName = replacedName,
			Team = team,
		})
		self:_broadcastSnapshot()
		return
	end

	local function botsOn(team: { Actor }): { BotRecord }
		local list = {}
		for _, a in team do
			if ActorUtil.IsBot(a) then
				table.insert(list, a :: BotRecord)
			end
		end
		return list
	end

	local humansA, humansB = 0, 0
	for _, a in self._teamA do
		if ActorUtil.IsPlayer(a) then
			humansA += 1
		end
	end
	for _, a in self._teamB do
		if ActorUtil.IsPlayer(a) then
			humansB += 1
		end
	end

	local targetTeamId = if humansA <= humansB then "A" else "B"
	local teamList = if targetTeamId == "A" then self._teamA else self._teamB
	local candidates = botsOn(teamList)
	if #candidates == 0 then
		targetTeamId = if targetTeamId == "A" then "B" else "A"
		teamList = if targetTeamId == "A" then self._teamA else self._teamB
		candidates = botsOn(teamList)
	end
	if #candidates == 0 then
		return
	end

	local victim = self._bots:FindLowestDifficultyOnTeam(targetTeamId, candidates)
	if not victim then
		return
	end

	local replacedName = victim.DisplayName
	local idx = table.find(teamList, victim)
	if idx then
		table.remove(teamList, idx)
	end
	self._bots:DespawnBot(victim)

	table.insert(teamList, player)
	player:SetAttribute(Constants.AttributeTeam, targetTeamId)
	if not self._operators[player] then
		self._operators[player] = "Skid"
	end
	self._abilities:ApplyOperatorPassives(player, self._operators[player])

	if self._phase == "Countdown" or self._phase == "Round" then
		self:_spawnPlayer(player)
		self._weapons:SetupPlayer(player)
		self._weapons:Refill(player)
		self._abilities:ResetCooldown(player)
		player:SetAttribute(Constants.AttributeAlive, self._phase ~= "RoundEnd")
		if self._phase == "Round" then
			self:_unfreezeActor(player)
		end
	end

	self._remotes.StandInReplaced:FireAllClients({
		PlayerUserId = player.UserId,
		PlayerName = player.DisplayName ~= "" and player.DisplayName or player.Name,
		ReplacedBotName = replacedName,
		Team = targetTeamId,
	})
	self._remotes.Announce:FireAllClients({
		Kind = "StandInReplaced",
		Message = string.format(
			"%s replaced stand-in %s",
			player.DisplayName ~= "" and player.DisplayName or player.Name,
			replacedName
		),
	})
	self:_broadcastSnapshot()
end

return MatchService
