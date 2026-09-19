--!strict
--[[
	AbilityService — rate-limited operator actives with real behavior.

	==========================================================================
	Splice CollisionGroups (Phase 5 — allies walk AND shoot through)
	==========================================================================
	Groups registered:
	  LatchPlayers          — all character BaseParts (players + bots)
	  LatchSpliceEnemy      — Splice panel Parts (enemy-facing blocker)
	  LatchSpliceFriendly   — reserved / unused for physics (ray pierce uses attrs)
	  LatchCover            — Anchor cover plates

	Collidability matrix (after Init):
	  LatchSpliceEnemy ↔ LatchPlayers  = true   (enemies blocked by panel)
	  LatchSpliceEnemy ↔ Default       = true   (panel rests against world)
	  LatchCover       ↔ LatchPlayers  = true

	Ally walk-through:
	  Panel is CanCollide=true on LatchSpliceEnemy (blocks LatchPlayers).
	  For every living ally (same LatchTeam as panel attribute LatchSpliceTeam),
	  we create NoCollisionConstraint(s) between the panel and each BasePart of
	  the ally character. Constraints are cleaned up when Debris destroys the
	  panel. New ally characters that spawn mid-lifetime also get constraints
	  via a short Heartbeat poll while the panel lives.

	Ally shoot-through:
	  Panel keeps Attribute LatchSpliceTeam = owner team.
	  WeaponService hitscan calls ShouldPierceSpliceActor — if attacker team
	  matches, the ray ignores the panel and continues. Enemies stop on hit.

	Enemy walk + shoot: blocked by physics collision and raycast respectively.
	==========================================================================

	Actors: Player | BotRecord via ActorUtil.
]]

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local OperatorsConfig = require(game.ReplicatedStorage.Config.Operators)
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local VFX = require(game.ReplicatedStorage.Util.VFX)
local ActorUtil = require(script.Parent.ActorUtil)

type Actor = ActorUtil.Actor
type BotRecord = ActorUtil.BotRecord

local AbilityService = {}
AbilityService.__index = AbilityService

local function ensureCollisionGroups()
	local groups = {
		Constants.CollisionGroupPlayers,
		Constants.CollisionGroupCover,
		Constants.CollisionGroupSpliceFriendly,
		Constants.CollisionGroupSpliceEnemy,
	}
	for _, name in groups do
		pcall(function()
			PhysicsService:RegisterCollisionGroup(name)
		end)
	end
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(Constants.CollisionGroupCover, Constants.CollisionGroupPlayers, true)
	end)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(Constants.CollisionGroupSpliceEnemy, Constants.CollisionGroupPlayers, true)
	end)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(Constants.CollisionGroupSpliceEnemy, Constants.CollisionGroupDefault, true)
	end)
	-- Friendly group does not collide with players (unused for panel physics; documented)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(Constants.CollisionGroupSpliceFriendly, Constants.CollisionGroupPlayers, false)
	end)
end

function AbilityService.new(remotes: { [string]: RemoteEvent })
	local self = setmetatable({
		_remotes = remotes,
		_cooldowns = {} :: { [number]: number },
		_botFromCharacter = nil :: ((Model) -> BotRecord?)?,
		_bots = nil :: any,
		_weapons = nil :: any,
		_wardenStill = {} :: { [number]: { Pos: Vector3, Since: number } },
		_activeSplice = {} :: { [Part]: { Team: any, EndsAt: number } },
		_heartbeat = nil :: RBXScriptConnection?,
	}, AbilityService)
	return self
end

function AbilityService:Init()
	ensureCollisionGroups()
	self._remotes.UseAbility.OnServerEvent:Connect(function(player, payload)
		self:ServerUse(player, payload)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self._cooldowns[player.UserId] = nil
		self._wardenStill[player.UserId] = nil
	end)
	self._heartbeat = RunService.Heartbeat:Connect(function()
		self:_tickPassives()
	end)
end

function AbilityService:SetBotResolver(fn: (Model) -> BotRecord?)
	self._botFromCharacter = fn
end

function AbilityService:SetBotService(bots: any)
	self._bots = bots
end

function AbilityService:SetWeaponService(weapons: any)
	self._weapons = weapons
end

function AbilityService:ClearActor(actor: Actor)
	local uid = ActorUtil.UserId(actor)
	self._cooldowns[uid] = nil
	self._wardenStill[uid] = nil
end

function AbilityService:ApplyOperatorPassives(player: Player, operatorId: string)
	self:ApplyOperatorPassivesActor(player, operatorId)
end

function AbilityService:ApplyOperatorPassivesActor(actor: Actor, operatorId: string)
	ActorUtil.SetAttribute(actor, Constants.AttributeOperator, operatorId)
	local cfg = OperatorsConfig.Operators[operatorId :: any]
	if not cfg then
		return
	end
	if operatorId == "Skid" then
		ActorUtil.SetAttribute(actor, Constants.AttributeSlideDurationBonus, cfg.SlideDurationBonus or 0.2)
	else
		ActorUtil.SetAttribute(actor, Constants.AttributeSlideDurationBonus, 0)
	end
	if operatorId == "Splice" then
		ActorUtil.SetAttribute(actor, Constants.AttributeQuietCrouch, true)
	else
		ActorUtil.SetAttribute(actor, Constants.AttributeQuietCrouch, false)
	end
	if operatorId == "Anchor" then
		ActorUtil.SetAttribute(actor, Constants.AttributeExplosiveKnockReduction, cfg.ExplosiveKnockReduction or 0.5)
	else
		ActorUtil.SetAttribute(actor, Constants.AttributeExplosiveKnockReduction, 0)
	end
	if operatorId == "Fuse" then
		ActorUtil.SetAttribute(actor, Constants.AttributeFragFuseBonus, cfg.FragFuseBonus or -0.3)
	else
		ActorUtil.SetAttribute(actor, Constants.AttributeFragFuseBonus, 0)
	end
	-- Clear planted armor when switching off Warden
	if operatorId ~= "Warden" then
		ActorUtil.SetAttribute(actor, Constants.AttributePlantedArmor, 0)
		ActorUtil.SetAttribute(actor, Constants.AttributePlanted, false)
	end
end

function AbilityService:_aliveRoot(actor: Actor): (Model?, BasePart?)
	local char = ActorUtil.Character(actor)
	if not char then
		return nil, nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or hum.Health <= 0 or not root then
		return nil, nil
	end
	if ActorUtil.GetAttribute(actor, Constants.AttributeAlive) == false then
		return nil, nil
	end
	return char, root
end

function AbilityService:_iterActors(): { Actor }
	local list: { Actor } = {}
	for _, plr in Players:GetPlayers() do
		table.insert(list, plr)
	end
	if self._bots and self._bots.GetAllMatchBots then
		for _, bot in self._bots:GetAllMatchBots() do
			table.insert(list, bot)
		end
	end
	return list
end

function AbilityService:ServerUse(actor: Actor, payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	local operatorId = ActorUtil.GetAttribute(actor, Constants.AttributeOperator)
	if typeof(operatorId) ~= "string" then
		return
	end
	local cfg = OperatorsConfig.Operators[operatorId :: any]
	if not cfg then
		return
	end

	local now = Workspace:GetServerTimeNow()
	local uid = ActorUtil.UserId(actor)
	local readyAt = self._cooldowns[uid] or 0
	if now < readyAt then
		return
	end

	local look = payload.LookDirection
	local origin = payload.Origin
	if typeof(look) ~= "Vector3" or look.Magnitude < 0.1 then
		return
	end

	local char, root = self:_aliveRoot(actor)
	if not char or not root then
		return
	end
	if typeof(origin) ~= "Vector3" or (origin - root.Position).Magnitude > 25 then
		origin = root.Position
	end

	local ok = false
	if operatorId == "Skid" then
		ok = self:_skid(actor, char, root, look.Unit, cfg)
	elseif operatorId == "Anchor" then
		ok = self:_anchor(actor, root, look.Unit, cfg)
	elseif operatorId == "Splice" then
		ok = self:_splice(actor, root, look.Unit, cfg)
	elseif operatorId == "Jolt" then
		ok = self:_jolt(actor, root, look.Unit, payload.TargetUserId, cfg)
	elseif operatorId == "Fuse" then
		ok = self:_fuse(actor, char, root, look.Unit, cfg)
	elseif operatorId == "Warden" then
		ok = self:_warden(actor, root, cfg)
	end

	if ok then
		self._cooldowns[uid] = now + cfg.Cooldown
		self._remotes.AbilityFx:FireAllClients({
			UserId = uid,
			OperatorId = operatorId,
			CooldownEndsAt = self._cooldowns[uid],
		})
		if ActorUtil.IsPlayer(actor) then
			self._remotes.PlayerState:FireClient(actor :: Player, {
				AbilityCooldownEndsAt = self._cooldowns[uid],
			})
		end
	end
end

function AbilityService:_skid(_actor: Actor, char: Model, root: BasePart, dir: Vector3, cfg: any): boolean
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 0.1 then
		flat = root.CFrame.LookVector
		flat = Vector3.new(flat.X, 0, flat.Z)
	end
	flat = flat.Unit

	local duration = cfg.DashDuration or 0.22
	local speed = cfg.DashSpeed or 80
	local maxDist = cfg.DashMaxDistance or 28

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local hit = Workspace:Raycast(root.Position, flat * maxDist, params)
	local travel = if hit then math.max(0, (hit.Position - root.Position).Magnitude - 2) else maxDist
	travel = math.min(travel, maxDist)

	VFX.DashTrail(root.Position, flat, travel)
	VFX.BeamStreak(root.Position, root.Position + flat * travel, Color3.fromRGB(80, 200, 255))

	local att = root:FindFirstChild("LatchDashAtt") :: Attachment?
	if not att then
		att = Instance.new("Attachment")
		att.Name = "LatchDashAtt"
		att.Parent = root
	end
	local lv = Instance.new("LinearVelocity")
	lv.Name = "LatchDashVel"
	lv.Attachment0 = att
	lv.MaxForce = 1e6
	lv.VectorVelocity = flat * speed
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = root
	Debris:AddItem(lv, duration)

	task.delay(duration, function()
		if lv.Parent then
			lv:Destroy()
		end
	end)
	return true
end

function AbilityService:_anchor(_actor: Actor, root: BasePart, dir: Vector3, cfg: any): boolean
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 0.1 then
		flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	flat = flat.Unit
	local size: Vector3 = cfg.CoverSize or Vector3.new(8, 5, 0.6)
	local lifetime = cfg.CoverLifetime or 4
	local pos = root.Position + flat * 6 + Vector3.new(0, size.Y / 2 - 1, 0)

	local plate = Instance.new("Part")
	plate.Name = "LatchCoverPlate"
	plate.Anchored = true
	plate.Size = size
	plate.CFrame = CFrame.lookAt(pos, pos + flat)
	plate.Color = Color3.fromRGB(110, 115, 130)
	plate.Material = Enum.Material.Metal
	plate.Parent = Workspace
	pcall(function()
		plate.CollisionGroup = Constants.CollisionGroupCover
	end)
	VFX.AttachHighlight(plate, Color3.fromRGB(150, 160, 180), Color3.fromRGB(200, 210, 230), 0.5)
	Debris:AddItem(plate, lifetime)

	self._remotes.AbilityFx:FireAllClients({
		Kind = "AnchorCover",
		Position = pos,
		Lifetime = lifetime,
	})
	return true
end

--[[
	Wire NoCollisionConstraints so allies pass through the Splice panel.
]]
function AbilityService:_wireSpliceAllyPass(panel: BasePart, team: any)
	local function alreadyWired(part: BasePart): boolean
		for _, c in panel:GetChildren() do
			if c:IsA("NoCollisionConstraint") and (c :: NoCollisionConstraint).Part1 == part then
				return true
			end
		end
		return false
	end

	local function wireChar(char: Model)
		for _, desc in char:GetDescendants() do
			if desc:IsA("BasePart") and not alreadyWired(desc) then
				local ncc = Instance.new("NoCollisionConstraint")
				ncc.Name = "LatchSpliceNCC"
				ncc.Part0 = panel
				ncc.Part1 = desc
				ncc.Parent = panel
			end
		end
	end

	for _, actor in self:_iterActors() do
		if ActorUtil.GetAttribute(actor, Constants.AttributeTeam) == team then
			local char = ActorUtil.Character(actor)
			if char then
				wireChar(char)
			end
		end
	end
end

function AbilityService:_splice(actor: Actor, root: BasePart, dir: Vector3, cfg: any): boolean
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 0.1 then
		flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	flat = flat.Unit
	local size: Vector3 = cfg.PanelSize or Vector3.new(6, 5, 0.4)
	local lifetime = cfg.PanelLifetime or 5
	local team = ActorUtil.GetAttribute(actor, Constants.AttributeTeam)
	local pos = root.Position + flat * 5 + Vector3.new(0, size.Y / 2 - 1, 0)

	local panel = Instance.new("Part")
	panel.Name = "LatchSplicePanel"
	panel.Anchored = true
	panel.Size = size
	panel.CFrame = CFrame.lookAt(pos, pos + flat)
	panel.Color = Color3.fromRGB(60, 180, 220)
	panel.Material = Enum.Material.ForceField
	panel.Transparency = 0.45
	panel.CanCollide = true
	panel.CanQuery = true
	panel:SetAttribute("LatchSpliceTeam", team)
	panel.Parent = Workspace
	pcall(function()
		panel.CollisionGroup = Constants.CollisionGroupSpliceEnemy
	end)
	VFX.AttachHighlight(panel, Color3.fromRGB(40, 200, 255), Color3.fromRGB(180, 240, 255), lifetime)

	self:_wireSpliceAllyPass(panel, team)
	local endsAt = Workspace:GetServerTimeNow() + lifetime
	self._activeSplice[panel] = { Team = team, EndsAt = endsAt }

	-- Refresh ally pass for late spawns while panel lives
	task.spawn(function()
		while panel.Parent and Workspace:GetServerTimeNow() < endsAt do
			self:_wireSpliceAllyPass(panel, team)
			task.wait(0.5)
		end
		self._activeSplice[panel] = nil
	end)

	Debris:AddItem(panel, lifetime)
	return true
end

function AbilityService.ShouldPierceSplice(attacker: Player, hitInstance: Instance): boolean
	return AbilityService.ShouldPierceSpliceActor(attacker, hitInstance)
end

function AbilityService.ShouldPierceSpliceActor(attacker: Actor, hitInstance: Instance): boolean
	local team = hitInstance:GetAttribute("LatchSpliceTeam")
	if team == nil then
		return false
	end
	return ActorUtil.GetAttribute(attacker, Constants.AttributeTeam) == team
end

function AbilityService:_jolt(actor: Actor, root: BasePart, dir: Vector3, targetUserId: any, cfg: any): boolean
	local range = cfg.MarkRange or 120
	local duration = cfg.MarkDuration or 3
	local victim: Actor? = nil

	if typeof(targetUserId) == "number" then
		local plr = Players:GetPlayerByUserId(targetUserId)
		if plr then
			victim = plr
		elseif self._botFromCharacter then
			for _, inst in Workspace:GetDescendants() do
				if inst:IsA("Model") and inst:GetAttribute(Constants.AttributeBotId) == targetUserId then
					victim = self._botFromCharacter(inst)
					break
				end
			end
		end
	end

	if not victim then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local char = ActorUtil.Character(actor)
		params.FilterDescendantsInstances = if char then { char } else {}
		local result = Workspace:Raycast(root.Position + Vector3.new(0, 1.5, 0), dir.Unit * range, params)
		if result then
			local model = result.Instance:FindFirstAncestorOfClass("Model")
			if model then
				victim = ActorUtil.FromCharacter(model, self._botFromCharacter)
			end
		end
	end

	if not victim or ActorUtil.UserId(victim) == ActorUtil.UserId(actor) then
		return false
	end
	if ActorUtil.GetAttribute(victim, Constants.AttributeTeam) == ActorUtil.GetAttribute(actor, Constants.AttributeTeam) then
		return false
	end
	local vChar = ActorUtil.Character(victim)
	if not vChar then
		return false
	end

	VFX.AttachHighlight(vChar, Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 200, 50), duration)
	self._remotes.AbilityFx:FireAllClients({
		Kind = "JoltMark",
		TargetUserId = ActorUtil.UserId(victim),
		Duration = duration,
	})
	return true
end

--[[ Fuse active: sticky delayed pop — ray to surface/actor, wait, small sphere damage. ]]
function AbilityService:_fuse(actor: Actor, char: Model, root: BasePart, dir: Vector3, cfg: any): boolean
	local maxRange = cfg.StickyMaxRange or 55
	local delaySec = cfg.StickyDelay or 1.15
	local radius = cfg.StickyRadius or 10
	local damage = cfg.StickyDamage or 45

	local origin = root.Position + Vector3.new(0, 1.4, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local result = Workspace:Raycast(origin, dir.Unit * maxRange, params)
	local hitPos = if result then result.Position else origin + dir.Unit * math.min(28, maxRange)
	local hitPart = if result then result.Instance else nil

	local sticky = Instance.new("Part")
	sticky.Name = "LatchStickyPop"
	sticky.Shape = Enum.PartType.Ball
	sticky.Size = Vector3.new(0.9, 0.9, 0.9)
	sticky.Color = Color3.fromRGB(255, 120, 40)
	sticky.Material = Enum.Material.Neon
	sticky.CanCollide = false
	sticky.CanQuery = false
	sticky.Anchored = hitPart == nil
	sticky.Position = hitPos
	sticky.Parent = Workspace
	VFX.AttachHighlight(sticky, Color3.fromRGB(255, 140, 40), Color3.fromRGB(255, 220, 120), delaySec)

	if hitPart and hitPart:IsA("BasePart") and not hitPart.Anchored then
		sticky.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = sticky
		weld.Part1 = hitPart
		weld.Parent = sticky
	elseif hitPart and hitPart:IsA("BasePart") then
		sticky.Anchored = true
		sticky.CFrame = CFrame.new(hitPos)
	end

	Debris:AddItem(sticky, delaySec + 0.6)
	VFX.BeamStreak(origin, hitPos, Color3.fromRGB(255, 160, 60))

	task.delay(delaySec, function()
		if not sticky.Parent then
			return
		end
		local pos = sticky.Position
		sticky:Destroy()
		VFX.ExplosionSphere(pos, radius, Color3.fromRGB(255, 100, 30))
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Exclude
		local hits = Workspace:GetPartBoundsInRadius(pos, radius, overlap)
		local damaged: { [number]: boolean } = {}
		for _, p in hits do
			local model = p:FindFirstAncestorOfClass("Model")
			if not model then
				continue
			end
			local victim = ActorUtil.FromCharacter(model, self._botFromCharacter)
			if not victim then
				continue
			end
			local vid = ActorUtil.UserId(victim)
			if damaged[vid] then
				continue
			end
			if ActorUtil.GetAttribute(victim, Constants.AttributeTeam) == ActorUtil.GetAttribute(actor, Constants.AttributeTeam) then
				continue
			end
			damaged[vid] = true
			local vRoot = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			local dist = if vRoot then (vRoot.Position - pos).Magnitude else 0
			local falloff = 1 - math.clamp(dist / radius, 0, 1) * 0.55
			if self._weapons and self._weapons.DealDamage then
				self._weapons:DealDamage(actor, victim, damage * falloff, "FuseSticky", false)
			else
				local hum = model:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					hum:TakeDamage(damage * falloff)
				end
			end
		end
	end)

	self._remotes.AbilityFx:FireAllClients({
		Kind = "FuseSticky",
		Position = hitPos,
		Delay = delaySec,
	})
	return true
end

--[[ Warden active: highlight all hostiles in range. ]]
function AbilityService:_warden(actor: Actor, root: BasePart, cfg: any): boolean
	local range = cfg.VisionPulseRange or 40
	local duration = cfg.VisionPulseDuration or 4
	local myTeam = ActorUtil.GetAttribute(actor, Constants.AttributeTeam)
	local marked = 0

	for _, other in self:_iterActors() do
		if ActorUtil.UserId(other) == ActorUtil.UserId(actor) then
			continue
		end
		if ActorUtil.GetAttribute(other, Constants.AttributeTeam) == myTeam then
			continue
		end
		if not ActorUtil.IsAlive(other) then
			continue
		end
		local oRoot = ActorUtil.Root(other)
		local oChar = ActorUtil.Character(other)
		if not oRoot or not oChar then
			continue
		end
		if (oRoot.Position - root.Position).Magnitude > range then
			continue
		end
		VFX.AttachHighlight(oChar, Color3.fromRGB(80, 255, 140), Color3.fromRGB(200, 255, 120), duration)
		marked += 1
	end

	self._remotes.AbilityFx:FireAllClients({
		Kind = "WardenPulse",
		UserId = ActorUtil.UserId(actor),
		Range = range,
		Duration = duration,
		Marked = marked,
	})
	return true
end

function AbilityService:_tickPassives()
	local now = Workspace:GetServerTimeNow()
	for _, actor in self:_iterActors() do
		local op = ActorUtil.GetAttribute(actor, Constants.AttributeOperator)
		if op ~= "Warden" then
			continue
		end
		local cfg = OperatorsConfig.Operators.Warden
		if not cfg then
			continue
		end
		local root = ActorUtil.Root(actor)
		if not root or not ActorUtil.IsAlive(actor) then
			ActorUtil.SetAttribute(actor, Constants.AttributePlantedArmor, 0)
			ActorUtil.SetAttribute(actor, Constants.AttributePlanted, false)
			continue
		end
		local uid = ActorUtil.UserId(actor)
		local still = self._wardenStill[uid]
		local pos = root.Position
		local moving = false
		if still then
			local delta = (pos - still.Pos).Magnitude
			local horizVel = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
			moving = delta > 0.35 or horizVel > 2.5
		end
		if not still or moving then
			self._wardenStill[uid] = { Pos = pos, Since = now }
			ActorUtil.SetAttribute(actor, Constants.AttributePlantedArmor, 0)
			ActorUtil.SetAttribute(actor, Constants.AttributePlanted, false)
		else
			self._wardenStill[uid].Pos = pos
			local stillFor = now - still.Since
			local need = cfg.PlantedStillSeconds or 0.6
			if stillFor >= need then
				ActorUtil.SetAttribute(actor, Constants.AttributePlantedArmor, cfg.PlantedArmor or 10)
				ActorUtil.SetAttribute(actor, Constants.AttributePlanted, true)
			else
				ActorUtil.SetAttribute(actor, Constants.AttributePlantedArmor, 0)
				ActorUtil.SetAttribute(actor, Constants.AttributePlanted, false)
			end
		end
	end
end

function AbilityService:GetCooldownEndsAt(player: Player): number
	return self:GetCooldownEndsAtActor(player)
end

function AbilityService:GetCooldownEndsAtActor(actor: Actor): number
	return self._cooldowns[ActorUtil.UserId(actor)] or 0
end

function AbilityService:ResetCooldown(player: Player)
	self:ResetCooldownActor(player)
end

function AbilityService:ResetCooldownActor(actor: Actor)
	self._cooldowns[ActorUtil.UserId(actor)] = 0
end

return AbilityService
