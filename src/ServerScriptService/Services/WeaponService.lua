--!strict
--[[
	WeaponService — server-authoritative hitscan, melee, grenades.
	Validates fire rate, range, and ownership. Damage applied here only.
]]

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local WeaponsConfig = require(game.ReplicatedStorage.Config.Weapons)
local MatchSettings = require(game.ReplicatedStorage.Config.MatchSettings)
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local VFX = require(game.ReplicatedStorage.Util.VFX)
local AbilityService = require(script.Parent.AbilityService)

local WeaponService = {}
WeaponService.__index = WeaponService

type AmmoState = {
	Mag: number,
	Reserve: number,
	LastFire: number,
	Reloading: boolean,
}

type PlayerWeaponState = {
	Equipped: string,
	Ammo: { [string]: AmmoState },
	GrenadeReadyAt: number,
}

function WeaponService.new(remotes: { [string]: RemoteEvent }, deps: { [string]: any })
	local self = setmetatable({
		_remotes = remotes,
		_deps = deps,
		_states = {} :: { [Player]: PlayerWeaponState },
		_onKill = nil :: ((Player, Player) -> ())?,
	}, WeaponService)
	return self
end

function WeaponService:Init()
	self._remotes.FireWeapon.OnServerEvent:Connect(function(player, payload)
		self:_onFire(player, payload)
	end)
	self._remotes.ReloadWeapon.OnServerEvent:Connect(function(player)
		self:_onReload(player)
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
		self._states[player] = nil
	end)
end

function WeaponService:SetOnKill(callback: (Player, Player) -> ())
	self._onKill = callback
end

function WeaponService:SetupPlayer(player: Player)
	local ammo: { [string]: AmmoState } = {}
	for id, cfg in WeaponsConfig.Weapons do
		ammo[id] = {
			Mag = cfg.MagSize,
			Reserve = cfg.ReserveAmmo,
			LastFire = 0,
			Reloading = false,
		}
	end
	self._states[player] = {
		Equipped = "AssaultRifle",
		Ammo = ammo,
		GrenadeReadyAt = 0,
	}
	self:_syncPlayerState(player)
end

function WeaponService:Refill(player: Player)
	local state = self._states[player]
	if not state then
		self:SetupPlayer(player)
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
	self:_syncPlayerState(player)
end

function WeaponService:_syncPlayerState(player: Player)
	local state = self._states[player]
	if not state then
		return
	end
	self._remotes.PlayerState:FireClient(player, {
		Equipped = state.Equipped,
		Ammo = state.Ammo,
		GrenadeReadyAt = state.GrenadeReadyAt,
	})
end

function WeaponService:_characterAlive(player: Player): (Model?, Humanoid?, BasePart?)
	local char = player.Character
	if not char then
		return nil, nil, nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or hum.Health <= 0 or not root then
		return nil, nil, nil
	end
	if player:GetAttribute(Constants.AttributeAlive) == false then
		return nil, nil, nil
	end
	return char, hum, root
end

function WeaponService:_sameTeam(a: Player, b: Player): boolean
	return a:GetAttribute(Constants.AttributeTeam) == b:GetAttribute(Constants.AttributeTeam)
end

function WeaponService:_applyDamage(attacker: Player, victim: Player, amount: number, weaponId: string, headshot: boolean)
	local char = victim.Character
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
		TargetUserId = victim.UserId,
		Amount = math.floor(amount + 0.5),
		Headshot = headshot,
		Position = if char:FindFirstChild("Head") then (char.Head :: BasePart).Position else nil,
	})
	self._remotes.WeaponHit:FireClient(attacker, {
		Hit = true,
		Headshot = headshot,
		Damage = amount,
	})

	if before > 0 and hum.Health <= 0 then
		victim:SetAttribute(Constants.AttributeAlive, false)
		if self._onKill then
			self._onKill(attacker, victim)
		end
	end
end

function WeaponService:_reloadMultiplier(player: Player): number
	local untilT = player:GetAttribute(Constants.AttributeMeleeReloadBuffUntil)
	local mult = player:GetAttribute(Constants.AttributeMeleeReloadMult)
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
	local state = self._states[player]
	if not state then
		return
	end
	state.Equipped = weaponId
	self:_syncPlayerState(player)
end

function WeaponService:_onReload(player: Player)
	local state = self._states[player]
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
	player:SetAttribute(Constants.AttributeReloading, true)
	self:_syncPlayerState(player)

	local reloadTime = cfg.ReloadTime * self:_reloadMultiplier(player)
	task.delay(reloadTime, function()
		if not self._states[player] then
			return
		end
		local need = cfg.MagSize - ammo.Mag
		local take = math.min(need, ammo.Reserve)
		ammo.Mag += take
		ammo.Reserve -= take
		ammo.Reloading = false
		player:SetAttribute(Constants.AttributeReloading, false)
		self:_syncPlayerState(player)
	end)
end

function WeaponService:_onFire(player: Player, payload: any)
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

	local _, _, root = self:_characterAlive(player)
	if not root then
		return
	end
	-- Sanity: origin near character
	if (origin - root.Position).Magnitude > 20 then
		origin = root.Position + Vector3.new(0, 1.5, 0)
	end

	local state = self._states[player]
	if not state then
		return
	end
	local cfg = WeaponsConfig.Weapons[weaponId :: any]
	if not cfg or cfg.Kind ~= "Hitscan" then
		return
	end
	if state.Equipped ~= weaponId then
		return
	end
	local ammo = state.Ammo[weaponId]
	if not ammo or ammo.Reloading or ammo.Mag <= 0 then
		return
	end

	local now = Workspace:GetServerTimeNow()
	local minInterval = 1 / math.max(cfg.FireRate, 0.1)
	if now - ammo.LastFire < minInterval * 0.85 then
		return -- rate limit with small tolerance
	end
	ammo.LastFire = now
	ammo.Mag -= 1

	local dir = direction.Unit
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	params.IgnoreWater = true

	-- Multi-segment ray to pierce ally Splice one-way panels (see AbilityService comments)
	local remaining = cfg.Range
	local cursor = origin
	local hitPos: Vector3? = nil
	local filterList: { Instance } = { player.Character :: Instance }
	params.FilterDescendantsInstances = filterList
	for _ = 1, 6 do
		local result = Workspace:Raycast(cursor, dir * remaining, params)
		if not result then
			hitPos = cursor + dir * remaining
			break
		end
		if AbilityService.ShouldPierceSplice(player, result.Instance) then
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
			local victimPlayer = Players:GetPlayerFromCharacter(model)
			if victimPlayer then
				local headshot = hitPart.Name == "Head"
				local dmg = cfg.Damage * (if headshot then cfg.HeadMultiplier else 1)
				self:_applyDamage(player, victimPlayer, dmg, weaponId, headshot)
			end
		end
		break
	end
	if hitPos then
		VFX.BeamStreak(origin, hitPos, Color3.fromRGB(255, 230, 120))
	end

	self:_syncPlayerState(player)
	if ammo.Mag <= 0 then
		self:_onReload(player)
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
	local state = self._states[player]
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
	self:_syncPlayerState(player)

	local range = cfg.MeleeRange or 8
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }

	local parts = Workspace:GetPartBoundsInRadius(root.Position + lookDir.Unit * (range * 0.4), range * 0.6, params)
	local hitSomeone = false
	for _, p in parts do
		local model = p:FindFirstAncestorOfClass("Model")
		if model then
			local victim = Players:GetPlayerFromCharacter(model)
			if victim and not self:_sameTeam(player, victim) then
				self:_applyDamage(player, victim, cfg.Damage, "Knife", false)
				hitSomeone = true
				break
			end
		end
	end

	-- Jolt passive: melee hit → faster reload buff
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

	local state = self._states[player]
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
	self:_syncPlayerState(player)

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
		local damaged: { [Player]: boolean } = {}
		for _, p in hits do
			local model = p:FindFirstAncestorOfClass("Model")
			if model then
				local victim = Players:GetPlayerFromCharacter(model)
				if victim and not damaged[victim] and not self:_sameTeam(player, victim) then
					damaged[victim] = true
					local rootPart = model:FindFirstChild("HumanoidRootPart") :: BasePart?
					local dist = if rootPart then (rootPart.Position - pos).Magnitude else 0
					local falloff = 1 - math.clamp(dist / radius, 0, 1) * 0.6
					self:_applyDamage(player, victim, damage * falloff, "FragGrenade", false)
				end
			end
		end
	end)
end

return WeaponService
