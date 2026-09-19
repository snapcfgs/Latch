--!strict
--[[
	MatchService — lobby queue, 1v1/2v2, first to 5 rounds, bot fill timers.
	Rounds end when one team has 0 alive (humans + bots). No solo practice skip.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local MatchSettings = require(game.ReplicatedStorage.Config.MatchSettings)
local OperatorsConfig = require(game.ReplicatedStorage.Config.Operators)
local BotsConfig = require(game.ReplicatedStorage.Config.Bots)
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local ArenaBuilder = require(script.Parent.ArenaBuilder)
local ActorUtil = require(script.Parent.ActorUtil)

type Actor = ActorUtil.Actor
type BotRecord = ActorUtil.BotRecord
type Phase = "Lobby" | "Countdown" | "Round" | "RoundEnd" | "MatchEnd"

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
		_phase = "Lobby" :: Phase,
		_modeId = MatchSettings.DefaultModeId,
		_scoreA = 0,
		_scoreB = 0,
		_roundNumber = 0,
		_phaseEndsAt = nil :: number?,
		_teamA = {} :: { Actor },
		_teamB = {} :: { Actor },
		_queue = {} :: { Player },
		_operators = {} :: { [Player]: string },
		_running = false,
		_fillStartedAt = nil :: number?,
		_fillModeId = nil :: string?,
	}, MatchService)
	return self
end

function MatchService:SetBotService(botService: any)
	self._bots = botService
end

function MatchService:Init()
	ArenaBuilder.Build()

	self._remotes.RequestQueue.OnServerEvent:Connect(function(player, modeId)
		self:_onQueue(player, modeId)
	end)
	self._remotes.RequestOperator.OnServerEvent:Connect(function(player, operatorId)
		self:_onOperator(player, operatorId)
	end)

	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute(Constants.AttributeAlive, false)
		self:_broadcastSnapshot()
		player.CharacterAdded:Connect(function(char)
			self:_onCharacter(player, char)
		end)
		-- Mid-fill / mid-match human join: try replace a stand-in
		task.defer(function()
			self:_tryReplaceStandIn(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_removeFromQueue(player)
		self._operators[player] = nil
		self:_stripFromTeams(player)
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

function MatchService:_fighterInfo(actor: Actor): { [string]: any }
	local op = ActorUtil.GetAttribute(actor, Constants.AttributeOperator)
	return {
		UserId = ActorUtil.UserId(actor),
		DisplayName = ActorUtil.DisplayName(actor),
		IsBot = ActorUtil.IsBot(actor),
		OperatorId = if typeof(op) == "string" then op else nil,
		Alive = ActorUtil.IsAlive(actor),
		Team = ActorUtil.GetAttribute(actor, Constants.AttributeTeam) or "A",
	}
end

function MatchService:_broadcastSnapshot()
	local fighters = {}
	for _, a in self._teamA do
		table.insert(fighters, self:_fighterInfo(a))
	end
	for _, a in self._teamB do
		table.insert(fighters, self:_fighterInfo(a))
	end

	local fillEndsAt: number? = nil
	if self._phase == "Lobby" and self._fillStartedAt and not self._running then
		local fillSecs = if self._modeId == "2v2"
			then MatchSettings.FillTimer2v2Seconds
			else MatchSettings.FillTimer1v1Seconds
		fillEndsAt = self._fillStartedAt + fillSecs
	end

	local snap = {
		Phase = self._phase,
		ModeId = self._modeId,
		RoundNumber = self._roundNumber,
		ScoreA = self._scoreA,
		ScoreB = self._scoreB,
		RoundsToWin = MatchSettings.RoundsToWin,
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
	if typeof(modeId) == "string" and (modeId == "1v1" or modeId == "2v2") then
		self._modeId = modeId
	end
	if not table.find(self._queue, player) then
		table.insert(self._queue, player)
	end
	if not self._operators[player] then
		self._operators[player] = "Skid"
		self._abilities:ApplyOperatorPassives(player, "Skid")
	end

	-- Start / refresh fill timer when undersized
	local need = self:_neededPlayers()
	if #self._queue < need then
		if not self._fillStartedAt or self._fillModeId ~= self._modeId then
			self._fillStartedAt = Workspace:GetServerTimeNow()
			self._fillModeId = self._modeId
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
	if self._phase == "Round" or self._phase == "Countdown" then
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
end

function MatchService:_neededPlayers(): number
	if self._modeId == "2v2" then
		return 4
	end
	return 2
end

function MatchService:_fillSeconds(): number
	if self._modeId == "2v2" then
		return MatchSettings.FillTimer2v2Seconds
	end
	return MatchSettings.FillTimer1v1Seconds
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

	-- Undersized: wait for fill timer then pad with bots
	if not self._fillStartedAt then
		self._fillStartedAt = Workspace:GetServerTimeNow()
		self._fillModeId = self._modeId
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

function MatchService:_assignTeams(allowBots: boolean)
	self._teamA = {}
	self._teamB = {}
	local need = self:_neededPlayers()
	local teamSize = if self._modeId == "2v2" then 2 else 1

	local picked: { Player } = {}
	for i = 1, math.min(need, #self._queue) do
		table.insert(picked, self._queue[i])
	end
	for _, p in picked do
		self:_removeFromQueue(p)
	end

	-- Alternate humans onto teams so solo queues aren't stacked on one side
	for i, p in picked do
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
			local diff = BotsConfig.FillOrder[math.min(#self._teamA + 1, #BotsConfig.FillOrder)]
			local bot = self._bots:SpawnBot({
				TeamId = "A",
				Difficulty = diff,
				LobbyOnly = false,
			})
			table.insert(self._teamA, bot)
		end
		while #self._teamB < teamSize do
			local diff = BotsConfig.FillOrder[math.min(#self._teamB + 1, #BotsConfig.FillOrder)]
			local bot = self._bots:SpawnBot({
				TeamId = "B",
				Difficulty = diff,
				LobbyOnly = false,
			})
			table.insert(self._teamB, bot)
		end
	end
end

function MatchService:_startMatch(fillWithBots: boolean)
	if self._running then
		return
	end
	self._running = true
	if self._bots then
		self._bots:SetMatchActive(true)
	end

	self:_assignTeams(fillWithBots)
	-- Ensure both teams have someone (bot fill should guarantee this)
	if #self._teamA == 0 or #self._teamB == 0 then
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
			Message = string.format("Match starting with %d stand-in bot(s)", botCount),
		})
	end

	while self._scoreA < MatchSettings.RoundsToWin and self._scoreB < MatchSettings.RoundsToWin do
		if #self._teamA + #self._teamB == 0 then
			break
		end
		-- Abort if a team lost all humans AND all bots somehow emptied mid-match
		if self:_teamVacated("A") or self:_teamVacated("B") then
			break
		end
		self._roundNumber += 1
		self:_runRound()
		if self._scoreA >= MatchSettings.RoundsToWin or self._scoreB >= MatchSettings.RoundsToWin then
			break
		end
		self._phase = "RoundEnd"
		self._phaseEndsAt = Workspace:GetServerTimeNow() + MatchSettings.BetweenRoundSeconds
		self:_broadcastSnapshot()
		task.wait(MatchSettings.BetweenRoundSeconds)
	end

	self._phase = "MatchEnd"
	local winner = if self._scoreA > self._scoreB then "A" else "B"
	self._remotes.MatchResult:FireAllClients({
		Winner = winner,
		ScoreA = self._scoreA,
		ScoreB = self._scoreB,
	})
	self:_broadcastSnapshot()
	task.wait(5)
	self:_endToLobby()
end

function MatchService:_teamVacated(team: string): boolean
	local list = if team == "A" then self._teamA else self._teamB
	return #list == 0
end

function MatchService:_endToLobby()
	if self._bots then
		self._bots:DespawnMatchBots()
		self._bots:SetMatchActive(false)
	end
	self._phase = "Lobby"
	self._teamA = {}
	self._teamB = {}
	self._running = false
	self._phaseEndsAt = nil
	self._fillStartedAt = nil
	self._fillModeId = nil
	self:_broadcastSnapshot()
end

function MatchService:_runRound()
	self._phase = "Countdown"
	self._phaseEndsAt = Workspace:GetServerTimeNow() + MatchSettings.MatchStartCountdown
	self:_broadcastSnapshot()

	for _, actor in self:_allMatchActors() do
		if ActorUtil.IsBot(actor) then
			local bot = actor :: BotRecord
			if self._bots then
				self._bots:RespawnBot(bot, bot.TeamId)
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
		end
	end

	task.wait(MatchSettings.MatchStartCountdown)

	self._phase = "Round"
	self._phaseEndsAt = nil
	self:_broadcastSnapshot()

	for _, actor in self:_allMatchActors() do
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

	-- Wait until one team eliminated (humans + bots). No empty-B practice skip.
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

function MatchService:_onActorEliminated(victim: Actor, _attacker: Actor)
	ActorUtil.SetAttribute(victim, Constants.AttributeAlive, false)
	self:_broadcastSnapshot()
end

function MatchService:_spawnPlayer(player: Player)
	local team = player:GetAttribute(Constants.AttributeTeam)
	local spawns = ArenaBuilder.GetSpawns(if team == "B" then "B" else "A")
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

--[[
	When a human joins during fill or early match, replace the lowest-difficulty
	bot on the team that needs a human (prefer opponent team for 1v1 solo).
]]
function MatchService:_tryReplaceStandIn(player: Player)
	if not self._bots or not self._running then
		return
	end
	-- Already on a team?
	if table.find(self._teamA, player) or table.find(self._teamB, player) then
		return
	end
	if self._phase ~= "Countdown" and self._phase ~= "Round" and self._phase ~= "RoundEnd" then
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

	-- Prefer replacing on the team with fewer humans
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
		-- Try other team
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
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.WalkSpeed = MatchSettings.WalkSpeed
				hum.JumpPower = MatchSettings.JumpPower
			end
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
