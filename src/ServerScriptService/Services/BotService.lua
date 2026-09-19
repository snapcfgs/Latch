--!strict
--[[
	BotService — AI stand-ins for solo / undersized queues + lobby wanderers.
	Bots use the same WeaponService / AbilityService server APIs as players.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local BotNames = require(game.ReplicatedStorage.Config.BotNames)
local BotsConfig = require(game.ReplicatedStorage.Config.Bots)
local OperatorsConfig = require(game.ReplicatedStorage.Config.Operators)
local MatchSettings = require(game.ReplicatedStorage.Config.MatchSettings)
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local ActorUtil = require(script.Parent.ActorUtil)
local ArenaBuilder = require(script.Parent.ArenaBuilder)

type BotRecord = ActorUtil.BotRecord
type AiState =
	"Idle"
	| "Hunt"
	| "TakeCover"
	| "Peek"
	| "Shoot"
	| "Reload"
	| "Ability"
	| "Retreat"
	| "Rotate"

type BotBrain = {
	State: AiState,
	StateEnteredAt: number,
	TargetUserId: number?,
	WaypointIndex: number,
	NextDecisionAt: number,
	ReactionReadyAt: number,
	LastShotAt: number,
	CoverUntil: number,
	EmoteUntil: number,
}

local BotService = {}
BotService.__index = BotService

local nextBotId = Constants.BotIdMin

local function allocBotId(): number
	local id = nextBotId
	nextBotId += 1
	if nextBotId > Constants.BotIdMax then
		nextBotId = Constants.BotIdMin
	end
	return id
end

local function randomOperator(): string
	local order = OperatorsConfig.OperatorOrder
	return order[math.random(1, #order)]
end

local function pickDifficulty(preferred: string?): string
	if preferred and BotsConfig.Difficulties[preferred :: any] then
		return preferred
	end
	-- Weighted: more Recruits than Sweats when auto-picking
	local roll = math.random()
	if roll < 0.45 then
		return "Recruit"
	elseif roll < 0.85 then
		return "Standard"
	end
	return "Sweat"
end

function BotService.new(
	remotes: { [string]: RemoteEvent },
	weaponService: any,
	abilityService: any
)
	local self = setmetatable({
		_remotes = remotes,
		_weapons = weaponService,
		_abilities = abilityService,
		_bots = {} :: { [number]: BotRecord },
		_byCharacter = {} :: { [Model]: BotRecord },
		_brains = {} :: { [number]: BotBrain },
		_waypoints = {} :: { Vector3 },
		_lobbyFolder = nil :: Folder?,
		_matchFolder = nil :: Folder?,
		_heartbeat = nil :: RBXScriptConnection?,
		_matchActive = false,
		_maps = nil :: any,
	}, BotService)
	return self
end

function BotService:SetMapService(mapService: any)
	self._maps = mapService
end

function BotService:Init()
	self._lobbyFolder = Instance.new("Folder")
	self._lobbyFolder.Name = "LatchLobbyBots"
	self._lobbyFolder.Parent = Workspace

	self._matchFolder = Instance.new("Folder")
	self._matchFolder.Name = "LatchMatchBots"
	self._matchFolder.Parent = Workspace

	self:RefreshNav()

	-- Register victim resolver + kill path for bots
	self._weapons:SetBotResolver(function(model: Model)
		return self._byCharacter[model]
	end)
	self._abilities:SetBotResolver(function(model: Model)
		return self._byCharacter[model]
	end)

	self._heartbeat = RunService.Heartbeat:Connect(function(dt)
		self:_tick(dt)
	end)

	task.spawn(function()
		self:_lobbyDirectorLoop()
	end)

	print("[Latch] BotService ready")
end


function BotService:RefreshNav()
	if self._maps and self._maps:IsMatchMapLoaded() then
		local nav = self._maps:GetBotNavPositions()
		if #nav > 0 then
			self._waypoints = nav
			return
		end
		local wps = self._maps:GetWaypointPositions()
		if #wps > 0 then
			self._waypoints = wps
			return
		end
	end
	ArenaBuilder.EnsureWaypoints()
	self._waypoints = ArenaBuilder.GetWaypointPositions()
end

function BotService:_resolveSpawns(teamId: string): { SpawnLocation }
	local function mergeAB(): { SpawnLocation }
		local a = if self._maps and self._maps:IsMatchMapLoaded() then self._maps:GetSpawns("A") else ArenaBuilder.GetSpawns("A")
		local b = if self._maps and self._maps:IsMatchMapLoaded() then self._maps:GetSpawns("B") else ArenaBuilder.GetSpawns("B")
		local merged: { SpawnLocation } = {}
		for _, s in a do
			table.insert(merged, s)
		end
		for _, s in b do
			table.insert(merged, s)
		end
		return merged
	end
	-- FFA unique teams start with "F"
	if string.sub(teamId, 1, 1) == "F" then
		local merged = mergeAB()
		if #merged > 0 then
			return merged
		end
	end
	if self._maps and self._maps:IsMatchMapLoaded() then
		local spawns = self._maps:GetSpawns(teamId)
		if #spawns > 0 then
			return spawns
		end
	end
	return ArenaBuilder.GetSpawns(teamId)
end

function BotService:SetMatchActive(active: boolean)
	self._matchActive = active
	if active then
		-- Despawn lobby wanderers during a match to cut clutter
		self:DespawnLobbyBots()
	else
		-- Restore lobby waypoint graph after match map is cleared
		self:RefreshNav()
	end
end

function BotService:GetBot(id: number): BotRecord?
	return self._bots[id]
end

function BotService:GetBotFromCharacter(model: Model): BotRecord?
	return self._byCharacter[model]
end

function BotService:GetAllMatchBots(): { BotRecord }
	local list = {}
	for _, bot in self._bots do
		if not bot.LobbyOnly then
			table.insert(list, bot)
		end
	end
	return list
end

function BotService:_register(bot: BotRecord)
	self._bots[bot.Id] = bot
	if bot.Character then
		self._byCharacter[bot.Character] = bot
	end
	self._brains[bot.Id] = {
		State = "Idle",
		StateEnteredAt = Workspace:GetServerTimeNow(),
		TargetUserId = nil,
		WaypointIndex = math.random(1, math.max(1, #self._waypoints)),
		NextDecisionAt = 0,
		ReactionReadyAt = 0,
		LastShotAt = 0,
		CoverUntil = 0,
		EmoteUntil = 0,
	}
end

function BotService:_unregister(bot: BotRecord)
	if bot.Character then
		self._byCharacter[bot.Character] = nil
	end
	self._bots[bot.Id] = nil
	self._brains[bot.Id] = nil
	BotNames.Release(bot.DisplayName)
end

function BotService:_buildCharacter(displayName: string, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Bot_" .. displayName

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = true
	root.Anchored = false
	root.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 1, 1)
	head.Color = Color3.fromRGB(200, 180, 150)
	head.CanCollide = true
	head.Parent = model

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Color = Color3.fromRGB(60, 90, 140)
	torso.CanCollide = true
	torso.Parent = model

	local function limb(name: string, size: Vector3, color: Color3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.CanCollide = true
		p.Parent = model
		return p
	end
	limb("Left Arm", Vector3.new(1, 2, 1), Color3.fromRGB(200, 180, 150))
	limb("Right Arm", Vector3.new(1, 2, 1), Color3.fromRGB(200, 180, 150))
	limb("Left Leg", Vector3.new(1, 2, 1), Color3.fromRGB(40, 45, 60))
	limb("Right Leg", Vector3.new(1, 2, 1), Color3.fromRGB(40, 45, 60))

	-- R6-style weld layout (simple blocky)
	local function weld(a: BasePart, b: BasePart, c0: CFrame)
		local w = Instance.new("Weld")
		w.Part0 = a
		w.Part1 = b
		w.C0 = c0
		w.Parent = a
	end
	weld(root, torso, CFrame.new())
	weld(torso, head, CFrame.new(0, 1.5, 0))
	weld(torso, model["Left Arm"] :: BasePart, CFrame.new(-1.5, 0, 0))
	weld(torso, model["Right Arm"] :: BasePart, CFrame.new(1.5, 0, 0))
	weld(torso, model["Left Leg"] :: BasePart, CFrame.new(-0.5, -2, 0))
	weld(torso, model["Right Leg"] :: BasePart, CFrame.new(0.5, -2, 0))

	local hum = Instance.new("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Subject
	hum.NameDisplayDistance = 100
	hum.HealthDisplayDistance = 100
	hum.MaxHealth = MatchSettings.PlayerHealth
	hum.Health = MatchSettings.PlayerHealth
	hum.WalkSpeed = MatchSettings.WalkSpeed
	hum.JumpPower = MatchSettings.JumpPower
	hum.Parent = model

	model.PrimaryPart = root
	model.Parent = parent

	-- Nametag
	local bb = Instance.new("BillboardGui")
	bb.Name = "BotNameTag"
	bb.Size = UDim2.fromOffset(160, 40)
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.AlwaysOnTop = false
	bb.Adornee = head
	bb.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(180, 220, 255)
	label.TextStrokeTransparency = 0.4
	label.Text = displayName
	label.Parent = bb

	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			pcall(function()
				desc.CollisionGroup = Constants.CollisionGroupPlayers
			end)
		end
	end

	return model
end

function BotService:SpawnBot(opts: {
	TeamId: string,
	Difficulty: string?,
	OperatorId: string?,
	LobbyOnly: boolean?,
	Position: Vector3?,
}): BotRecord
	local difficulty = pickDifficulty(opts.Difficulty)
	local operatorId = opts.OperatorId or randomOperator()
	local displayName = BotNames.GenerateDisplayName()
	local id = allocBotId()
	local lobbyOnly = opts.LobbyOnly == true
	local parent = if lobbyOnly then self._lobbyFolder else self._matchFolder

	local char = self:_buildCharacter(displayName, parent :: Instance)
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart
	local pos = opts.Position
	if not pos then
		local spawns = self:_resolveSpawns(opts.TeamId)
		if #spawns > 0 then
			local spot = spawns[math.random(1, #spawns)]
			pos = spot.Position + Vector3.new(0, 3, 0)
		else
			pos = Vector3.new(0, 5, 0)
		end
	end
	root.CFrame = CFrame.new(pos)

	local bot: BotRecord = {
		IsBot = true,
		Id = id,
		DisplayName = displayName,
		Character = char,
		TeamId = opts.TeamId,
		OperatorId = operatorId,
		Difficulty = difficulty,
		Alive = true,
		LobbyOnly = lobbyOnly,
	}

	char:SetAttribute(Constants.AttributeIsBot, true)
	char:SetAttribute(Constants.AttributeBotId, id)
	char:SetAttribute(Constants.AttributeTeam, opts.TeamId)
	char:SetAttribute(Constants.AttributeOperator, operatorId)
	char:SetAttribute(Constants.AttributeAlive, true)
	char:SetAttribute(Constants.AttributeDifficulty, difficulty)
	char:SetAttribute(Constants.AttributeDisplayName, displayName)

	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayName = displayName
		hum.Died:Connect(function()
			bot.Alive = false
			char:SetAttribute(Constants.AttributeAlive, false)
		end)
	end

	self:_register(bot)

	if not lobbyOnly then
		self._weapons:SetupActor(bot)
		self._abilities:ApplyOperatorPassivesActor(bot, operatorId)
		self._abilities:ResetCooldownActor(bot)
	end

	return bot
end

function BotService:DespawnBot(bot: BotRecord)
	self._weapons:ClearActor(bot)
	self._abilities:ClearActor(bot)
	local char = bot.Character
	self:_unregister(bot)
	if char then
		char:Destroy()
	end
	bot.Character = nil
end

function BotService:DespawnLobbyBots()
	local toRemove = {}
	for _, bot in self._bots do
		if bot.LobbyOnly then
			table.insert(toRemove, bot)
		end
	end
	for _, bot in toRemove do
		self:DespawnBot(bot)
	end
end

function BotService:DespawnMatchBots()
	local toRemove = {}
	for _, bot in self._bots do
		if not bot.LobbyOnly then
			table.insert(toRemove, bot)
		end
	end
	for _, bot in toRemove do
		self:DespawnBot(bot)
	end
end

function BotService:RespawnBot(bot: BotRecord, teamId: string)
	bot.TeamId = teamId
	bot.Alive = true
	local char = bot.Character
	if not char or not char.Parent then
		-- Rebuild
		local parent = self._matchFolder :: Instance
		char = self:_buildCharacter(bot.DisplayName, parent)
		bot.Character = char
		self._byCharacter[char] = bot
		char:SetAttribute(Constants.AttributeIsBot, true)
		char:SetAttribute(Constants.AttributeBotId, bot.Id)
		char:SetAttribute(Constants.AttributeDisplayName, bot.DisplayName)
		char:SetAttribute(Constants.AttributeDifficulty, bot.Difficulty)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.DisplayName = bot.DisplayName
			hum.Died:Connect(function()
				bot.Alive = false
				char:SetAttribute(Constants.AttributeAlive, false)
			end)
		end
	end

	char:SetAttribute(Constants.AttributeTeam, teamId)
	char:SetAttribute(Constants.AttributeOperator, bot.OperatorId)
	char:SetAttribute(Constants.AttributeAlive, true)

	local spawns = self:_resolveSpawns(teamId)
	local spot = if #spawns > 0 then spawns[math.random(1, #spawns)] else nil
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

	self._weapons:SetupActor(bot)
	self._weapons:RefillActor(bot)
	self._abilities:ResetCooldownActor(bot)
	self._abilities:ApplyOperatorPassivesActor(bot, bot.OperatorId)

	local brain = self._brains[bot.Id]
	if brain then
		brain.State = "Idle"
		brain.TargetUserId = nil
		brain.NextDecisionAt = 0
	end
end

function BotService:UnfreezeBot(bot: BotRecord)
	local hum = ActorUtil.Humanoid(bot)
	if hum and bot.Alive then
		local diff = BotsConfig.Difficulties[bot.Difficulty :: any]
		local jitter = if diff then diff.MoveJitter else 0.2
		hum.WalkSpeed = MatchSettings.WalkSpeed * (1 + (math.random() * 2 - 1) * jitter)
		hum.JumpPower = MatchSettings.JumpPower
	end
end

--[[ Lowest DifficultyRank first — used when a human replaces a stand-in. ]]
function BotService:FindLowestDifficultyOnTeam(teamId: string, botsOnTeam: { BotRecord }): BotRecord?
	local best: BotRecord? = nil
	local bestRank = math.huge
	for _, bot in botsOnTeam do
		if bot.TeamId == teamId and not bot.LobbyOnly then
			local rank = BotsConfig.DifficultyRank[bot.Difficulty :: any] or 99
			if rank < bestRank then
				bestRank = rank
				best = bot
			end
		end
	end
	return best
end

function BotService:_lobbyDirectorLoop()
	while true do
		task.wait(2)
		if self._matchActive then
			continue
		end
		local lobbyCount = 0
		for _, bot in self._bots do
			if bot.LobbyOnly then
				lobbyCount += 1
			end
		end
		local target = math.random(MatchSettings.LobbyBotMin, MatchSettings.LobbyBotMax)
		while lobbyCount < target do
			local team = if math.random() < 0.5 then "A" else "B"
			local spawns = self:_resolveSpawns(team)
			local pos: Vector3?
			if #spawns > 0 then
				local s = spawns[math.random(1, #spawns)]
				pos = s.Position + Vector3.new(math.random(-8, 8), 3, math.random(-8, 8))
			elseif #self._waypoints > 0 then
				pos = self._waypoints[math.random(1, #self._waypoints)] + Vector3.new(0, 3, 0)
			end
			self:SpawnBot({
				TeamId = team,
				Difficulty = "Recruit",
				LobbyOnly = true,
				Position = pos,
			})
			lobbyCount += 1
		end
		while lobbyCount > MatchSettings.LobbyBotMax do
			for _, bot in self._bots do
				if bot.LobbyOnly then
					self:DespawnBot(bot)
					lobbyCount -= 1
					break
				end
			end
		end
	end
end

function BotService:_allCombatActors(): { ActorUtil.Actor }
	local list: { ActorUtil.Actor } = {}
	for _, p in Players:GetPlayers() do
		if p:GetAttribute(Constants.AttributeAlive) ~= false and p.Character then
			table.insert(list, p)
		end
	end
	for _, bot in self._bots do
		if not bot.LobbyOnly and bot.Alive and bot.Character then
			table.insert(list, bot)
		end
	end
	return list
end

function BotService:_findEnemy(bot: BotRecord): ActorUtil.Actor?
	local root = ActorUtil.Root(bot)
	if not root then
		return nil
	end
	local best: ActorUtil.Actor? = nil
	local bestDist = math.huge
	for _, actor in self:_allCombatActors() do
		if ActorUtil.UserId(actor) == bot.Id then
			continue
		end
		if ActorUtil.GetAttribute(actor, Constants.AttributeTeam) == bot.TeamId then
			continue
		end
		if not ActorUtil.IsAlive(actor) then
			continue
		end
		local otherRoot = ActorUtil.Root(actor)
		if not otherRoot then
			continue
		end
		-- Line of sight
		local origin = root.Position + Vector3.new(0, 1.5, 0)
		local target = otherRoot.Position + Vector3.new(0, 1.5, 0)
		local delta = target - origin
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { bot.Character :: Instance }
		local result = Workspace:Raycast(origin, delta, params)
		local visible = true
		if result then
			local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
			local victim = if hitModel then ActorUtil.FromCharacter(hitModel, function(m)
				return self._byCharacter[m]
			end) else nil
			if not victim or ActorUtil.UserId(victim) ~= ActorUtil.UserId(actor) then
				visible = false
			end
		end
		if not visible then
			continue
		end
		local dist = delta.Magnitude
		if dist < bestDist then
			bestDist = dist
			best = actor
		end
	end
	return best
end

function BotService:_setState(brain: BotBrain, state: AiState)
	if brain.State ~= state then
		brain.State = state
		brain.StateEnteredAt = Workspace:GetServerTimeNow()
	end
end

function BotService:_aimWithCone(from: Vector3, to: Vector3, coneDeg: number): Vector3
	local dir = (to - from)
	if dir.Magnitude < 0.1 then
		return Vector3.new(0, 0, -1)
	end
	dir = dir.Unit
	local yaw = math.rad((math.random() * 2 - 1) * coneDeg)
	local pitch = math.rad((math.random() * 2 - 1) * coneDeg * 0.5)
	local cf = CFrame.lookAt(Vector3.zero, dir) * CFrame.Angles(pitch, yaw, 0)
	return cf.LookVector
end

function BotService:_moveToward(bot: BotRecord, targetPos: Vector3)
	local hum = ActorUtil.Humanoid(bot)
	if hum and bot.Alive then
		hum:MoveTo(targetPos)
	end
end

function BotService:_nearestWaypoint(pos: Vector3): Vector3?
	if #self._waypoints == 0 then
		return nil
	end
	local best = self._waypoints[1]
	local bestDist = (best - pos).Magnitude
	for i = 2, #self._waypoints do
		local wp = self._waypoints[i]
		local d = (wp - pos).Magnitude
		if d < bestDist then
			bestDist = d
			best = wp
		end
	end
	return best
end

function BotService:_coverWaypoint(bot: BotRecord, awayFrom: Vector3): Vector3?
	local root = ActorUtil.Root(bot)
	if not root or #self._waypoints == 0 then
		return nil
	end
	local best: Vector3? = nil
	local bestScore = -math.huge
	for _, wp in self._waypoints do
		local away = (wp - awayFrom).Magnitude
		local near = (wp - root.Position).Magnitude
		local score = away - near * 0.3
		if score > bestScore then
			bestScore = score
			best = wp
		end
	end
	return best
end

function BotService:_tickLobbyBot(bot: BotRecord, brain: BotBrain, now: number)
	local root = ActorUtil.Root(bot)
	local hum = ActorUtil.Humanoid(bot)
	if not root or not hum then
		return
	end
	hum.WalkSpeed = BotsConfig.LobbyWanderSpeed

	if now < brain.EmoteUntil then
		-- Sit / idle emote stub — looks like "joined" a queue pad
		if hum.Sit ~= true and math.random() < 0.02 then
			hum.Sit = true
			task.delay(2, function()
				if hum.Parent then
					hum.Sit = false
				end
			end)
		end
		return
	end

	if now >= brain.NextDecisionAt then
		brain.NextDecisionAt = now + math.random(2, 5)
		if math.random() < 0.15 then
			brain.EmoteUntil = now + math.random(2, 4)
			local head = bot.Character and bot.Character:FindFirstChild("Head")
			if head then
				local flash = Instance.new("BillboardGui")
				flash.Size = UDim2.fromOffset(40, 40)
				flash.StudsOffset = Vector3.new(0, 4, 0)
				flash.Adornee = head :: BasePart
				flash.Parent = head
				local t = Instance.new("TextLabel")
				t.Size = UDim2.fromScale(1, 1)
				t.BackgroundTransparency = 1
				t.Text = ({ "👋", "🔥", "😎", "💤" })[math.random(1, 4)]
				t.TextSize = 28
				t.Parent = flash
				Debris:AddItem(flash, 2)
			end
			return
		end
		-- Prefer queue pads ~55% of the time (visual "joining" queues)
		local pads = ArenaBuilder.GetPadPositions and ArenaBuilder.GetPadPositions() or {}
		if #pads > 0 and math.random() < 0.55 then
			local pad = pads[math.random(1, #pads)]
			-- Store as synthetic waypoint via Position override on brain using WaypointIndex = 0 + TargetPad
			brain.WaypointIndex = 0
			;(brain :: any).PadTarget = pad.Position
			;(brain :: any).PadModeId = pad.ModeId
		elseif #self._waypoints > 0 then
			brain.WaypointIndex = math.random(1, #self._waypoints)
			;(brain :: any).PadTarget = nil
		end
	end

	local padTarget = (brain :: any).PadTarget :: Vector3?
	if padTarget then
		self:_moveToward(bot, padTarget)
		-- Linger on pad = visual queue join
		if (root.Position - padTarget).Magnitude < 4 then
			brain.EmoteUntil = now + math.random(3, 6)
			;(brain :: any).PadTarget = nil
		end
		return
	end

	local wp = self._waypoints[brain.WaypointIndex]
	if wp then
		self:_moveToward(bot, wp)
	end
end

function BotService:_tickMatchBot(bot: BotRecord, brain: BotBrain, now: number)
	if not bot.Alive then
		return
	end
	local root = ActorUtil.Root(bot)
	local hum = ActorUtil.Humanoid(bot)
	if not root or not hum or hum.Health <= 0 then
		return
	end
	if hum.WalkSpeed == 0 then
		return -- frozen in countdown
	end

	local diff = BotsConfig.Difficulties[bot.Difficulty :: any] or BotsConfig.Difficulties.Standard
	local enemy = self:_findEnemy(bot)

	if enemy then
		local eid = ActorUtil.UserId(enemy)
		if brain.TargetUserId ~= eid then
			brain.TargetUserId = eid
			brain.ReactionReadyAt = now + diff.ReactionDelay
			self:_setState(brain, "Hunt")
		end
	else
		brain.TargetUserId = nil
	end

	-- Ability chance
	if enemy and now >= brain.NextDecisionAt and math.random() < diff.AbilityUseChance then
		local endsAt = self._abilities:GetCooldownEndsAtActor(bot)
		if now >= endsAt then
			self:_setState(brain, "Ability")
			local eRoot = ActorUtil.Root(enemy)
			if eRoot then
				local look = (eRoot.Position - root.Position)
				if look.Magnitude > 0.1 then
					self._abilities:ServerUse(bot, {
						LookDirection = look.Unit,
						Origin = root.Position,
						TargetUserId = ActorUtil.UserId(enemy),
					})
				end
			end
			brain.NextDecisionAt = now + BotsConfig.AiTickSeconds
			return
		end
	end

	-- Reload if empty
	local needReload = self._weapons:ActorNeedsReload(bot)
	if needReload then
		self:_setState(brain, "Reload")
		self._weapons:ServerReload(bot)
	end

	if enemy and now >= brain.ReactionReadyAt then
		local eRoot = ActorUtil.Root(enemy)
		if not eRoot then
			return
		end
		local dist = (eRoot.Position - root.Position).Magnitude

		-- Face target
		root.CFrame = CFrame.lookAt(
			root.Position,
			Vector3.new(eRoot.Position.X, root.Position.Y, eRoot.Position.Z)
		)

		if dist < 10 and math.random() < 0.08 then
			self:_setState(brain, "Retreat")
			local cover = self:_coverWaypoint(bot, eRoot.Position)
			if cover then
				self:_moveToward(bot, cover)
			end
			return
		end

		if now < brain.CoverUntil then
			self:_setState(brain, "TakeCover")
			return
		end

		if math.random() < diff.PeekChance * 0.05 then
			self:_setState(brain, "Peek")
			local side = if math.random() < 0.5 then 1 else -1
			local right = root.CFrame.RightVector * side * 6
			self:_moveToward(bot, root.Position + right)
		elseif dist > 45 then
			self:_setState(brain, "Hunt")
			self:_moveToward(bot, eRoot.Position)
		elseif dist < 18 and math.random() < 0.2 then
			self:_setState(brain, "TakeCover")
			brain.CoverUntil = now + diff.CoverHoldSeconds
			local cover = self:_coverWaypoint(bot, eRoot.Position)
			if cover then
				self:_moveToward(bot, cover)
			end
		else
			self:_setState(brain, "Shoot")
			-- Strafe slightly
			if math.random() < 0.3 then
				local side = if math.random() < 0.5 then 1 else -1
				self:_moveToward(bot, root.Position + root.CFrame.RightVector * side * 4)
			end

			local fireInterval = (1 / 9) / math.max(diff.FireRateScale, 0.2)
			if now - brain.LastShotAt >= fireInterval then
				brain.LastShotAt = now
				local origin = root.Position + Vector3.new(0, 1.5, 0)
				local aimPoint = eRoot.Position + Vector3.new(0, 1.2, 0)
				local dir = self:_aimWithCone(origin, aimPoint, diff.AccuracyConeDegrees)
				self._weapons:ServerFire(bot, {
					WeaponId = (self._weapons:GetEquipped(bot) or "AssaultRifle"),
					Origin = origin,
					Direction = dir,
				})
			end
		end
	else
		-- No visible enemy: rotate / hunt waypoints
		if now >= brain.NextDecisionAt then
			brain.NextDecisionAt = now + math.random(1, 3)
			self:_setState(brain, if math.random() < 0.5 then "Rotate" else "Hunt")
			if #self._waypoints > 0 then
				brain.WaypointIndex = (brain.WaypointIndex % #self._waypoints) + 1
			end
		end
		local wp = self._waypoints[brain.WaypointIndex]
		if wp then
			self:_moveToward(bot, wp)
		end
	end
end

function BotService:_tick(_dt: number)
	local now = Workspace:GetServerTimeNow()
	-- Refresh waypoints occasionally if arena rebuilt
	if #self._waypoints == 0 then
		self:RefreshNav()
	end

	for id, bot in self._bots do
		local brain = self._brains[id]
		if not brain or not bot.Character or not bot.Character.Parent then
			continue
		end
		if bot.LobbyOnly then
			self:_tickLobbyBot(bot, brain, now)
		else
			self:_tickMatchBot(bot, brain, now)
		end
	end
end

return BotService
