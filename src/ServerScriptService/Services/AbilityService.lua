--!strict
--[[
	AbilityService — rate-limited operator actives with real behavior.

	Splice CollisionGroups approach (document):
	  We create groups LatchPlayers, LatchSpliceFriendly, LatchSpliceEnemy.
	  The one-way panel is actually TWO thin Parts stacked:
	    - "EnemyBlock" on LatchSpliceEnemy: collides with Default + players so
	      enemies cannot walk through; CanQuery=true so enemy bullets raycast-hit it.
	    - "AllyPass" is not used for physics; instead we set the panel's
	      CanQuery based on team via a custom raycast filter on the server:
	      WeaponService Exclude list includes panels tagged LatchSpliceOwner=<ally team>.
	  Simpler MVP approach used here:
	    Panel Part has Attribute LatchSpliceTeam = owner team.
	    Hitscan Filter: when casting, if hit part has LatchSpliceTeam matching
	    attacker team, ignore and continue ray (pierce). Enemies stop on panel.
	  CollisionGroup: panel collides with everyone for movement (blocks walks);
	  walk-through for allies is NOT implemented in MVP (shoot-through only) —
	  documented tradeoff for mobile simplicity.

	Actors: Player | BotRecord via ActorUtil.
]]

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

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
end

function AbilityService.new(remotes: { [string]: RemoteEvent })
	local self = setmetatable({
		_remotes = remotes,
		_cooldowns = {} :: { [number]: number },
		_botFromCharacter = nil :: ((Model) -> BotRecord?)?,
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
	end)
end

function AbilityService:SetBotResolver(fn: (Model) -> BotRecord?)
	self._botFromCharacter = fn
end

function AbilityService:ClearActor(actor: Actor)
	self._cooldowns[ActorUtil.UserId(actor)] = nil
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
		ActorUtil.SetAttribute(actor, "LatchExplosiveKnockReduction", cfg.ExplosiveKnockReduction or 0.5)
	else
		ActorUtil.SetAttribute(actor, "LatchExplosiveKnockReduction", 0)
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
	panel:SetAttribute("LatchSpliceTeam", team)
	panel.Parent = Workspace
	VFX.AttachHighlight(panel, Color3.fromRGB(40, 200, 255), Color3.fromRGB(180, 240, 255), lifetime)
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
			-- Resolve bot by scanning — BotService stores by id; ask via character scan
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
