--!strict
--[[
	WeaponService — server-authoritative hitscan, melee, grenades.
	Validates fire rate, range, and ownership. Damage applied here only.
	Actors: Player | BotRecord (via ActorUtil). State keyed by UserId.
]]

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local WeaponsConfig = require(game.ReplicatedStorage.Config.Weapons)
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local VFX = require(game.ReplicatedStorage.Util.VFX)
local AbilityService = require(script.Parent.AbilityService)
local ActorUtil = require(script.Parent.ActorUtil)

type Actor = ActorUtil.Actor
type BotRecord = ActorUtil.BotRecord

type AmmoState = {
	Mag: number,
	Reserve: number,
	LastFire: number,
	Reloading: boolean,
}

type WeaponState = {
	Equipped: string,
	Ammo: { [string]: AmmoState },
	GrenadeReadyAt: number,
}

local WeaponService = {}
WeaponService.__index = WeaponService

function WeaponService.new(remotes: { [string]: RemoteEvent }, deps: { [string]: any })
	local self = setmetatable({
		_remotes = remotes,
		_deps = deps,
		_states = {} :: { [number]: WeaponState },
		_onKill = nil :: ((Actor, Actor) -> ())?,
		_botFromCharacter = nil :: ((Model) -> BotRecord?)?,
	}, WeaponService)
	return self
end

function WeaponService:Init()
	self._remotes.FireWeapon.OnServerEvent:Connect(function(player, payload)
		self:ServerFire(player, payload)
	end)
	self._remotes.ReloadWeapon.OnServerEvent:Connect(function(player)
		self:ServerReload(player)
	end)
	self._remotes.SwitchWeapon.OnServerEvent:Connect(function(player, weaponId)
		self:_onSwitch(player, weaponId)
	end)
	self._remotes.ThrowGrenade.OnServerEvent:Connect(function(player, origin, velocity)
		self:_onGrenade(player, origin, velocity)
	end)
	self._remotes.MeleeSwing.OnServerEvent:Connect(function(player, lookDir)
		self:_onMelee(player, lookDir)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self._states[player.UserId] = nil
	end)
end

function WeaponService:SetOnKill(callback: (Actor, Actor) -> ())
	self._onKill = callback
end

function WeaponService:SetBotResolver(fn: (Model) -> BotRecord?)
	self._botFromCharacter = fn
end

function WeaponService:_resolveFromModel(model: Model): Actor?
	return ActorUtil.FromCharacter(model, self._botFromCharacter)
end

function WeaponService:SetupPlayer(player: Player)
	self:SetupActor(player)
end

function WeaponService:SetupActor(actor: Actor)
	local uid = ActorUtil.UserId(actor)
	local ammo: { [string]: AmmoState } = {}
	for id, cfg in WeaponsConfig.Weapons do
		ammo[id] = {
			Mag = cfg.MagSize,
			Reserve = cfg.ReserveAmmo,
			LastFire = 0,
			Reloading = false,
		}
	end
	self._states[uid] = {
		Equipped = "AssaultRifle",
		Ammo = ammo,
		GrenadeReadyAt = 0,
	}
	self:_syncActorState(actor)
end

function WeaponService:ClearActor(actor: Actor)
	self._states[ActorUtil.UserId(actor)] = nil
end

function WeaponService:Refill(player: Player)
	self:RefillActor(player)
end

function WeaponService:RefillActor(actor: Actor)
	local uid = ActorUtil.UserId(actor)
	local state = self._states[uid]
	if not state then
		self:SetupActor(actor)
		return
	end
	for id, cfg in WeaponsConfig.Weapons do
		local a = state.Ammo[id]
		if a then
			a.Mag = cfg.MagSize
			a.Reserve = cfg.ReserveAmmo
			a.Reloading = false
		end
	end
	state.GrenadeReadyAt = 0
	self:_syncActorState(actor)
end

function WeaponService:ActorNeedsReload(actor: Actor): boolean
	local state = self._states[ActorUtil.UserId(actor)]
	if not state then
		return false
	end
	local ammo = state.Ammo[state.Equipped]
	local cfg = WeaponsConfig.Weapons[state.Equipped :: any]
	if not ammo or not cfg or cfg.Kind ~= "Hitscan" then
		return false
	end
	return ammo.Mag <= 0 and ammo.Reserve > 0 and not ammo.Reloading
end

function WeaponService:_syncActorState(actor: Actor)
	local state = self._states[ActorUtil.UserId(actor)]
	if not state then
		return
	end
	if ActorUtil.IsPlayer(actor) then
		self._remotes.PlayerState:FireClient(actor :: Player, {
			Equipped = state.Equipped,
			Ammo = state.Ammo,
			GrenadeReadyAt = state.GrenadeReadyAt,
		})
	end
end

function WeaponService:_characterAlive(actor: Actor): (Model?, Humanoid?, BasePart?)
	local char = ActorUtil.Character(actor)
	if not char then
		return nil, nil, nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or hum.Health <= 0 or not root then
		return nil, nil, nil
	end
	if ActorUtil.GetAttribute(actor, Constants.AttributeAlive) == false then
		return nil, nil, nil
	end
	return char, hum, root
end

function WeaponService:_sameTeam(a: Actor, b: Actor): boolean
	return ActorUtil.GetAttribute(a, Constants.AttributeTeam) == ActorUtil.GetAttribute(b, Constants.AttributeTeam)
end

function WeaponService:_applyDamage(attacker: Actor, victim: Actor, amount: number, _weaponId: string, headshot: boolean)
	local char = ActorUtil.Character(victim)
	if not char then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	if self:_sameTeam(attacker, victim) then
		return
	end

	local before = hum.Health
	hum:TakeDamage(amount)
	self._remotes.DamageNumber:FireAllClients({
		TargetUserId = ActorUtil.UserId(victim),
		Amount = math.floor(amount + 0.5),
		Headshot = headshot,
		Position = if char:FindFirstChild("Head") then (char.Head :: BasePart).Position else nil,
	})
	if ActorUtil.IsPlayer(attacker) then
		self._remotes.WeaponHit:FireClient(attacker :: Player, {
			Hit = true,
			Headshot = headshot,
			Damage = amount,
		})
	end

	if before > 0 and hum.Health <= 0 then
		ActorUtil.SetAttribute(victim, Constants.AttributeAlive, false)
		if self._onKill then
			self._onKill(attacker, victim)
		end
	end
end

function WeaponService:_reloadMultiplier(actor: Actor): number
	local untilT = ActorUtil.GetAttribute(actor, Constants.AttributeMeleeReloadBuffUntil)
	local mult = ActorUtil.GetAttribute(actor, Constants.AttributeMeleeReloadMult)
	if typeof(untilT) == "number" and typeof(mult) == "number" then
		if Workspace:GetServerTimeNow() < untilT then
			return mult :: number
		end
	end
	return 1
end

function WeaponService:_onSwitch(player: Player, weaponId: any)
	if typeof(weaponId) ~= "string" then
		return
	end
	if not WeaponsConfig.Weapons[weaponId :: any] then
		return
	end
	local state = self._states[player.UserId]
	if not state then
		return
	end
	state.Equipped = weaponId
	self:_syncActorState(player)
end

function WeaponService:ServerReload(actor: Actor)
	local uid = ActorUtil.UserId(actor)
	local state = self._states[uid]
	if not state then
		return
	end
	local id = state.Equipped
	local cfg = WeaponsConfig.Weapons[id :: any]
	local ammo = state.Ammo[id]
	if not cfg or not ammo or cfg.Kind == "Melee" or cfg.Kind == "Projectile" then
		return
	end
	if ammo.Reloading or ammo.Mag >= cfg.MagSize or ammo.Reserve <= 0 then
		return
	end
	ammo.Reloading = true
	ActorUtil.SetAttribute(actor, Constants.AttributeReloading, true)
	self:_syncActorState(actor)

	local reloadTime = cfg.ReloadTime * self:_reloadMultiplier(actor)
	task.delay(reloadTime, function()
		if not self._states[uid] then
			return
		end
		local need = cfg.MagSize - ammo.Mag
		local take = math.min(need, ammo.Reserve)
		ammo.Mag += take
		ammo.Reserve -= take
		ammo.Reloading = false
		ActorUtil.SetAttribute(actor, Constants.AttributeReloading, false)
		self:_syncActorState(actor)
	end)
end

function WeaponService:ServerFire(actor: Actor, payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	local weaponId = payload.WeaponId
	local origin = payload.Origin
	local direction = payload.Direction
	if typeof(weaponId) ~= "string" or typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end
	if direction.Magnitude < 0.1 then
		return
	end

	local char, _, root = self:_characterAlive(actor)
	if not root or not char then
		return
	end
	if (origin - root.Position).Magnitude > 20 then
		origin = root.Position + Vector3.new(0, 1.5, 0)
	end

	local uid = ActorUtil.UserId(actor)
	local state = self._states[uid]
	if not state then
		return
	end
	local cfg = WeaponsConfig.Weapons[weaponId :: any]
	if not cfg or cfg.Kind ~= "Hitscan" then
		return
	end
	if state.Equipped ~= weaponId then
		-- Bots may fire equipped only; allow auto-equip AR for bots
		if ActorUtil.IsBot(actor) and WeaponsConfig.Weapons[weaponId :: any] then
			state.Equipped = weaponId
		else
			return
		end
	end
	local ammo = state.Ammo[weaponId]
	if not ammo or ammo.Reloading or ammo.Mag <= 0 then
		return
	end

	local now = Workspace:GetServerTimeNow()
	local minInterval = 1 / math.max(cfg.FireRate, 0.1)
	if now - ammo.LastFire < minInterval * 0.85 then
		return
	end
	ammo.LastFire = now
	ammo.Mag -= 1

	local dir = direction.Unit
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true

	local remaining = cfg.Range
	local cursor = origin
	local hitPos: Vector3? = nil
	local filterList: { Instance } = { char }
	params.FilterDescendantsInstances = filterList
	for _ = 1, 6 do
		local result = Workspace:Raycast(cursor, dir * remaining, params)
		if not result then
			hitPos = cursor + dir * remaining
			break
		end
		if AbilityService.ShouldPierceSpliceActor(actor, result.Instance) then
			table.insert(filterList, result.Instance)
			params.FilterDescendantsInstances = filterList
			local step = (result.Position - cursor).Magnitude + 0.05
			remaining -= step
			cursor = result.Position + dir * 0.05
			continue
		end
		hitPos = result.Position
		local hitPart = result.Instance
		local model = hitPart:FindFirstAncestorOfClass("Model")
		if model then
			local victim = self:_resolveFromModel(model)
			if victim then
				local headshot = hitPart.Name == "Head"
				local dmg = cfg.Damage * (if headshot then cfg.HeadMultiplier else 1)
				self:_applyDamage(actor, victim, dmg, weaponId, headshot)
			end
		end
		break
	end
	if hitPos then
		VFX.BeamStreak(origin, hitPos, Color3.fromRGB(255, 230, 120))
	end

	self:_syncActorState(actor)
	if ammo.Mag <= 0 then
		self:ServerReload(actor)
	end
end

function WeaponService:_onMelee(player: Player, lookDir: any)
	if typeof(lookDir) ~= "Vector3" or lookDir.Magnitude < 0.1 then
		return
	end
	local char, _, root = self:_characterAlive(player)
	if not char or not root then
		return
	end
	local state = self._states[player.UserId]
	if not state then
		return
	end
	local cfg = WeaponsConfig.Weapons.Knife
	local ammo = state.Ammo.Knife
	if not ammo then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local minInterval = 1 / math.max(cfg.FireRate, 0.1)
	if now - ammo.LastFire < minInterval * 0.85 then
		return
	end
	ammo.LastFire = now
	state.Equipped = "Knife"
	self:_syncActorState(player)

	local range = cfg.MeleeRange or 8
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }

	local parts = Workspace:GetPartBoundsInRadius(root.Position + lookDir.Unit * (range * 0.4), range * 0.6, params)
	local hitSomeone = false
	for _, p in parts do
		local model = p:FindFirstAncestorOfClass("Model")
		if model then
			local victim = self:_resolveFromModel(model)
			if victim and not self:_sameTeam(player, victim) then
				self:_applyDamage(player, victim, cfg.Damage, "Knife", false)
				hitSomeone = true
				break
			end
		end
	end

	if hitSomeone and player:GetAttribute(Constants.AttributeOperator) == "Jolt" then
		local OperatorsConfig = require(game.ReplicatedStorage.Config.Operators)
		local jolt = OperatorsConfig.Operators.Jolt
		player:SetAttribute(Constants.AttributeMeleeReloadBuffUntil, now + (jolt.MeleeReloadBuffDuration or 3))
		player:SetAttribute(Constants.AttributeMeleeReloadMult, jolt.MeleeReloadMultiplier or 0.65)
	end
end

function WeaponService:_onGrenade(player: Player, origin: any, velocity: any)
	if typeof(origin) ~= "Vector3" or typeof(velocity) ~= "Vector3" then
		return
	end
	local _, _, root = self:_characterAlive(player)
	if not root then
		return
	end
	if (origin - root.Position).Magnitude > 25 then
		origin = root.Position + Vector3.new(0, 3, 0)
	end

	local state = self._states[player.UserId]
	if not state then
		return
	end
	local cfg = WeaponsConfig.Weapons.FragGrenade
	local now = Workspace:GetServerTimeNow()
	if now < state.GrenadeReadyAt then
		return
	end
	local speed = math.min(velocity.Magnitude, (cfg.ProjectileSpeed or 90) * 1.2)
	if speed < 5 then
		return
	end

	state.GrenadeReadyAt = now + (cfg.ThrowCooldown or 8)
	self:_syncActorState(player)

	local grenade = Instance.new("Part")
	grenade.Name = "LatchFrag"
	grenade.Shape = Enum.PartType.Ball
	grenade.Size = Vector3.new(1.2, 1.2, 1.2)
	grenade.Color = Color3.fromRGB(40, 120, 50)
	grenade.Material = Enum.Material.Metal
	grenade.CanCollide = true
	grenade.Position = origin
	grenade.Parent = Workspace

	local att = Instance.new("Attachment")
	att.Parent = grenade
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = 1e6
	lv.VectorVelocity = velocity.Unit * speed
	lv.Parent = grenade
	task.delay(0.15, function()
		if lv.Parent then
			lv:Destroy()
		end
	end)

	local fuse = cfg.FuseTime or 1.6
	local radius = cfg.ExplosionRadius or 18
	local damage = cfg.Damage
	Debris:AddItem(grenade, fuse + 0.5)

	task.delay(fuse, function()
		if not grenade.Parent then
			return
		end
		local pos = grenade.Position
		grenade:Destroy()
		VFX.ExplosionSphere(pos, radius)

		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local hits = Workspace:GetPartBoundsInRadius(pos, radius, params)
		local damaged: { [number]: boolean } = {}
		for _, p in hits do
			local model = p:FindFirstAncestorOfClass("Model")
			if model then
				local victim = self:_resolveFromModel(model)
				if victim then
					local vid = ActorUtil.UserId(victim)
					if not damaged[vid] and not self:_sameTeam(player, victim) then
						damaged[vid] = true
						local rootPart = model:FindFirstChild("HumanoidRootPart") :: BasePart?
						local dist = if rootPart then (rootPart.Position - pos).Magnitude else 0
						local falloff = 1 - math.clamp(dist / radius, 0, 1) * 0.6
						self:_applyDamage(player, victim, damage * falloff, "FragGrenade", false)
					end
				end
			end
		end
	end)
end


return WeaponService
