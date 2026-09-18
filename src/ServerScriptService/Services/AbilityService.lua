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
]]

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local OperatorsConfig = require(game.ReplicatedStorage.Config.Operators)
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local VFX = require(game.ReplicatedStorage.Util.VFX)

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
	-- Cover blocks everyone
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(Constants.CollisionGroupCover, Constants.CollisionGroupPlayers, true)
	end)
end

function AbilityService.new(remotes: { [string]: RemoteEvent })
	local self = setmetatable({
		_remotes = remotes,
		_cooldowns = {} :: { [Player]: number },
	}, AbilityService)
	return self
end

function AbilityService:Init()
	ensureCollisionGroups()
	self._remotes.UseAbility.OnServerEvent:Connect(function(player, payload)
		self:_onUse(player, payload)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self._cooldowns[player] = nil
	end)
end

function AbilityService:ApplyOperatorPassives(player: Player, operatorId: string)
	player:SetAttribute(Constants.AttributeOperator, operatorId)
	local cfg = OperatorsConfig.Operators[operatorId :: any]
	if not cfg then
		return
	end
	if operatorId == "Skid" then
		player:SetAttribute(Constants.AttributeSlideDurationBonus, cfg.SlideDurationBonus or 0.2)
	else
		player:SetAttribute(Constants.AttributeSlideDurationBonus, 0)
	end
	if operatorId == "Splice" then
		player:SetAttribute(Constants.AttributeQuietCrouch, true)
	else
		player:SetAttribute(Constants.AttributeQuietCrouch, false)
	end
	-- Anchor explosive resistance is stubbed via attribute for future knockback
	if operatorId == "Anchor" then
		player:SetAttribute("LatchExplosiveKnockReduction", cfg.ExplosiveKnockReduction or 0.5)
	else
		player:SetAttribute("LatchExplosiveKnockReduction", 0)
	end
end

function AbilityService:_aliveRoot(player: Player): (Model?, BasePart?)
	local char = player.Character
	if not char then
		return nil, nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or hum.Health <= 0 or not root then
		return nil, nil
	end
	if player:GetAttribute(Constants.AttributeAlive) == false then
		return nil, nil
	end
	return char, root
end

function AbilityService:_onUse(player: Player, payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	local operatorId = player:GetAttribute(Constants.AttributeOperator)
	if typeof(operatorId) ~= "string" then
		return
	end
	local cfg = OperatorsConfig.Operators[operatorId :: any]
	if not cfg then
		return
	end

	local now = Workspace:GetServerTimeNow()
	local readyAt = self._cooldowns[player] or 0
	if now < readyAt then
		return
	end

	local look = payload.LookDirection
	local origin = payload.Origin
	if typeof(look) ~= "Vector3" or look.Magnitude < 0.1 then
		return
	end

	local char, root = self:_aliveRoot(player)
	if not char or not root then
		return
	end
	if typeof(origin) ~= "Vector3" or (origin - root.Position).Magnitude > 25 then
		origin = root.Position
	end

	local ok = false
	if operatorId == "Skid" then
		ok = self:_skid(player, char, root, look.Unit, cfg)
	elseif operatorId == "Anchor" then
		ok = self:_anchor(player, root, look.Unit, cfg)
	elseif operatorId == "Splice" then
		ok = self:_splice(player, root, look.Unit, cfg)
	elseif operatorId == "Jolt" then
		ok = self:_jolt(player, root, look.Unit, payload.TargetUserId, cfg)
	end

	if ok then
		self._cooldowns[player] = now + cfg.Cooldown
		self._remotes.AbilityFx:FireAllClients({
			UserId = player.UserId,
			OperatorId = operatorId,
			CooldownEndsAt = self._cooldowns[player],
		})
		self._remotes.PlayerState:FireClient(player, {
			AbilityCooldownEndsAt = self._cooldowns[player],
		})
	end
end

function AbilityService:_skid(player: Player, char: Model, root: BasePart, dir: Vector3, cfg: any): boolean
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 0.1 then
		flat = root.CFrame.LookVector
		flat = Vector3.new(flat.X, 0, flat.Z)
	end
	flat = flat.Unit

	local duration = cfg.DashDuration or 0.22
	local speed = cfg.DashSpeed or 80
	local maxDist = cfg.DashMaxDistance or 28

	-- Validate distance via short ray
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

	-- Soft cap: stop if traveled enough
	task.delay(duration, function()
		if lv.Parent then
			lv:Destroy()
		end
	end)
	return true
end

function AbilityService:_anchor(player: Player, root: BasePart, dir: Vector3, cfg: any): boolean
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

function AbilityService:_splice(player: Player, root: BasePart, dir: Vector3, cfg: any): boolean
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 0.1 then
		flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	flat = flat.Unit
	local size: Vector3 = cfg.PanelSize or Vector3.new(6, 5, 0.4)
	local lifetime = cfg.PanelLifetime or 5
	local team = player:GetAttribute(Constants.AttributeTeam)
	local pos = root.Position + flat * 5 + Vector3.new(0, size.Y / 2 - 1, 0)

	local panel = Instance.new("Part")
	panel.Name = "LatchSplicePanel"
	panel.Anchored = true
	panel.Size = size
	panel.CFrame = CFrame.lookAt(pos, pos + flat)
	panel.Color = Color3.fromRGB(60, 180, 220)
	panel.Material = Enum.Material.ForceField
	panel.Transparency = 0.45
	panel.CanCollide = true -- blocks movement for all (MVP tradeoff)
	panel:SetAttribute("LatchSpliceTeam", team)
	--[[
		Raycast pierce: WeaponService / custom cast should skip this part when
		attacker:GetAttribute(Team) == LatchSpliceTeam. See pierce helper below.
	]]
	panel.Parent = Workspace
	VFX.AttachHighlight(panel, Color3.fromRGB(40, 200, 255), Color3.fromRGB(180, 240, 255), lifetime)
	Debris:AddItem(panel, lifetime)
	return true
end

--[[
	Pierce helper for hitscan: call from WeaponService ray loop if desired.
	Returns true if this instance should be ignored (ally one-way).
]]
function AbilityService.ShouldPierceSplice(attacker: Player, hitInstance: Instance): boolean
	local team = hitInstance:GetAttribute("LatchSpliceTeam")
	if team == nil then
		return false
	end
	return attacker:GetAttribute(Constants.AttributeTeam) == team
end

function AbilityService:_jolt(player: Player, root: BasePart, dir: Vector3, targetUserId: any, cfg: any): boolean
	local range = cfg.MarkRange or 120
	local duration = cfg.MarkDuration or 3
	local victim: Player? = nil

	if typeof(targetUserId) == "number" then
		victim = Players:GetPlayerByUserId(targetUserId)
	end

	if not victim then
		-- Raycast find target
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character :: Instance }
		local result = Workspace:Raycast(root.Position + Vector3.new(0, 1.5, 0), dir.Unit * range, params)
		if result then
			local model = result.Instance:FindFirstAncestorOfClass("Model")
			if model then
				victim = Players:GetPlayerFromCharacter(model)
			end
		end
	end

	if not victim or victim == player then
		return false
	end
	if victim:GetAttribute(Constants.AttributeTeam) == player:GetAttribute(Constants.AttributeTeam) then
		return false
	end
	local vChar = victim.Character
	if not vChar then
		return false
	end

	VFX.AttachHighlight(vChar, Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 200, 50), duration)
	self._remotes.AbilityFx:FireAllClients({
		Kind = "JoltMark",
		TargetUserId = victim.UserId,
		Duration = duration,
	})
	return true
end

function AbilityService:GetCooldownEndsAt(player: Player): number
	return self._cooldowns[player] or 0
end

function AbilityService:ResetCooldown(player: Player)
	self._cooldowns[player] = 0
end

return AbilityService
