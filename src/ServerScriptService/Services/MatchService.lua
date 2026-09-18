--!strict
--[[
	MatchService — lobby queue, 1v1/2v2, first to 5 rounds, resets between rounds.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local MatchSettings = require(game.ReplicatedStorage.Config.MatchSettings)
local OperatorsConfig = require(game.ReplicatedStorage.Config.Operators)
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local ArenaBuilder = require(script.Parent.ArenaBuilder)

local MatchService = {}
MatchService.__index = MatchService

type Phase = "Lobby" | "Countdown" | "Round" | "RoundEnd" | "MatchEnd"

function MatchService.new(remotes: { [string]: RemoteEvent }, weaponService: any, abilityService: any)
	local self = setmetatable({
		_remotes = remotes,
		_weapons = weaponService,
		_abilities = abilityService,
		_phase = "Lobby" :: Phase,
		_modeId = MatchSettings.DefaultModeId,
		_scoreA = 0,
		_scoreB = 0,
		_roundNumber = 0,
		_phaseEndsAt = nil :: number?,
		_teamA = {} :: { Player },
		_teamB = {} :: { Player },
		_queue = {} :: { Player },
		_operators = {} :: { [Player]: string },
		_running = false,
	}, MatchService)
	return self
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
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_removeFromQueue(player)
		self._operators[player] = nil
		self:_stripFromTeams(player)
	end)

	self._weapons:SetOnKill(function(attacker, victim)
		self:_onPlayerEliminated(victim, attacker)
	end)

	task.spawn(function()
		self:_lobbyLoop()
	end)
end

function MatchService:_broadcastSnapshot()
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
	}
	self._remotes.MatchSnapshot:FireAllClients(snap)
end

function MatchService:_userIds(list: { Player }): { number }
	local ids = {}
	for _, p in list do
		table.insert(ids, p.UserId)
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
	-- Lock operator once round is live
	if self._phase == "Round" or self._phase == "Countdown" then
		return
	end
	self._operators[player] = operatorId
	self._abilities:ApplyOperatorPassives(player, operatorId)
	self._remotes.PlayerState:FireClient(player, { OperatorId = operatorId })
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

function MatchService:_tryStart()
	if self._running or self._phase ~= "Lobby" then
		return
	end
	local need = self:_neededPlayers()
	local count = #self._queue
	-- Full lobby, or Studio solo practice (1 local player queued)
	local soloPractice = count >= 1 and #Players:GetPlayers() == 1
	if count >= need or soloPractice then
		task.spawn(function()
			self:_startMatch()
		end)
	end
end

function MatchService:_lobbyLoop()
	while true do
		task.wait(1)
		if self._phase == "Lobby" and not self._running then
			self:_tryStart()
		end
	end
end

function MatchService:_assignTeams()
	self._teamA = {}
	self._teamB = {}
	local need = self:_neededPlayers()
	local picked = {}
	for i = 1, math.min(need, #self._queue) do
		table.insert(picked, self._queue[i])
	end
	-- Clear queue of picked
	for _, p in picked do
		self:_removeFromQueue(p)
	end
	local teamSize = if self._modeId == "2v2" then 2 else 1
	for i, p in picked do
		if i <= teamSize then
			table.insert(self._teamA, p)
			p:SetAttribute(Constants.AttributeTeam, "A")
		else
			table.insert(self._teamB, p)
			p:SetAttribute(Constants.AttributeTeam, "B")
		end
	end
end

function MatchService:_startMatch()
	if self._running then
		return
	end
	self._running = true
	self:_assignTeams()
	self._scoreA = 0
	self._scoreB = 0
	self._roundNumber = 0

	while self._scoreA < MatchSettings.RoundsToWin and self._scoreB < MatchSettings.RoundsToWin do
		if #self._teamA + #self._teamB == 0 then
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

	self._phase = "Lobby"
	self._teamA = {}
	self._teamB = {}
	self._running = false
	self._phaseEndsAt = nil
	self:_broadcastSnapshot()
end

function MatchService:_runRound()
	self._phase = "Countdown"
	self._phaseEndsAt = Workspace:GetServerTimeNow() + MatchSettings.MatchStartCountdown
	self:_broadcastSnapshot()

	for _, p in self:_allMatchPlayers() do
		self:_spawnPlayer(p)
		self._weapons:SetupPlayer(p)
		self._weapons:Refill(p)
		self._abilities:ResetCooldown(p)
		local op = self._operators[p] or "Skid"
		self._abilities:ApplyOperatorPassives(p, op)
		p:SetAttribute(Constants.AttributeAlive, true)
	end

	task.wait(MatchSettings.MatchStartCountdown)

	self._phase = "Round"
	self._phaseEndsAt = nil
	self:_broadcastSnapshot()

	-- Freeze ends: restore walk speeds
	for _, p in self:_allMatchPlayers() do
		local char = p.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.WalkSpeed = MatchSettings.WalkSpeed
				hum.JumpPower = MatchSettings.JumpPower
			end
		end
	end

	-- Wait until one team eliminated (or solo practice timeout skip)
	local deadline = Workspace:GetServerTimeNow() + 300
	while Workspace:GetServerTimeNow() < deadline do
		local aliveA = self:_aliveCount(self._teamA)
		local aliveB = self:_aliveCount(self._teamB)
		if #self._teamB == 0 and aliveA > 0 then
			-- Solo practice: don't end round on empty B
			task.wait(0.5)
			continue
		end
		if aliveA == 0 or aliveB == 0 then
			if aliveA > 0 then
				self._scoreA += 1
				self._remotes.RoundResult:FireAllClients({ Winner = "A", ScoreA = self._scoreA, ScoreB = self._scoreB })
			elseif aliveB > 0 then
				self._scoreB += 1
				self._remotes.RoundResult:FireAllClients({ Winner = "B", ScoreA = self._scoreA, ScoreB = self._scoreB })
			end
			break
		end
		task.wait(0.25)
	end
end

function MatchService:_allMatchPlayers(): { Player }
	local list = {}
	for _, p in self._teamA do
		table.insert(list, p)
	end
	for _, p in self._teamB do
		table.insert(list, p)
	end
	return list
end

function MatchService:_aliveCount(team: { Player }): number
	local n = 0
	for _, p in team do
		if p.Parent and p:GetAttribute(Constants.AttributeAlive) ~= false then
			local char = p.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				n += 1
			end
		end
	end
	return n
end

function MatchService:_onPlayerEliminated(victim: Player, _attacker: Player)
	victim:SetAttribute(Constants.AttributeAlive, false)
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
		hum.WalkSpeed = 0 -- freeze during countdown
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
	-- Tag player collision group
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

return MatchService
