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
local MatchSettings = require(game.ReplicatedStorage.Config.MatchSettings)
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

type LoadoutMap = {
	Primary: string,
	Secondary: string,
	Melee: string,
	Utility: string,
}

type WeaponState = {
	Equipped: string,
	Ammo: { [string]: AmmoState },
	GrenadeReadyAt: number,
	Loadout: LoadoutMap,
	StimUsedThisRound: boolean,
}

local WeaponService = {}
WeaponService.__index = WeaponService

local function copyDefaultLoadout(): LoadoutMap
	local d = WeaponsConfig.DefaultLoadout
	return {
		Primary = d.Primary,
		Secondary = d.Secondary,
		Melee = d.Melee,
		Utility = d.Utility,
	}
end

local function randomLoadout(): LoadoutMap
	local function pick(slot: string): string
		local list = WeaponsConfig.GetBySlot(slot :: any)
		return list[math.random(1, #list)]
	end
	return {
		Primary = pick("Primary"),
		Secondary = pick("Secondary"),
		Melee = pick("Melee"),
		Utility = pick("Utility"),
	}
end

local function spreadDirection(dir: Vector3, spreadDeg: number): Vector3
	if spreadDeg <= 0 then
		return dir.Unit
	end
	local rad = math.rad(spreadDeg)
	local axis = if math.abs(dir.Unit.Y) < 0.99 then Vector3.yAxis else Vector3.xAxis
	local right = dir.Unit:Cross(axis)
	if right.Magnitude < 1e-4 then
		right = dir.Unit:Cross(Vector3.zAxis)
	end
	right = right.Unit
	local up = right:Cross(dir.Unit).Unit
	local yaw = (math.random() * 2 - 1) * rad
	local pitch = (math.random() * 2 - 1) * rad
	return (dir.Unit + right * math.tan(yaw) + up * math.tan(pitch)).Unit
end


function WeaponService.new(remotes: { [string]: RemoteEvent }, deps: { [string]: any })
	local self = setmetatable({
		_remotes = remotes,
		_deps = deps,
		_states = {} :: { [number]: WeaponState },
		_onKill = nil :: ((Actor, Actor) -> ())?,
		_botFromCharacter = nil :: ((Model) -> BotRecord?)?,
		-- Phase 3
		_damageTakenMult = {} :: { [number]: number },
		_gunCycleLocked = {} :: { [number]: boolean },
		_stats = {} :: { [number]: { Kills: number, Deaths: number, Damage: number } },
		_landingPenaltyUntil = {} :: { [number]: number },
		_lastHit = {} :: { [number]: { KillerName: string, WeaponName: string, Distance: number, Headshot: boolean, KillerUserId: number } },
		_landConn = {} :: { [number]: RBXScriptConnection },
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

	if self._remotes.SetLoadout then
		self._remotes.SetLoadout.OnServerEvent:Connect(function(player, payload)
			self:SetLoadout(player, payload)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		local uid = player.UserId
		self._states[uid] = nil
		self._landingPenaltyUntil[uid] = nil
		self._lastHit[uid] = nil
		local conn = self._landConn[uid]
		if conn then
			conn:Disconnect()
			self._landConn[uid] = nil
		end
	end)
end

--[[ Bind Humanoid.StateChanged → landing spread penalty (Phase 5). ]]
function WeaponService:BindLandingPenalty(actor: Actor)
	local uid = ActorUtil.UserId(actor)
	local prev = self._landConn[uid]
	if prev then
		prev:Disconnect()
		self._landConn[uid] = nil
	end
	local char = ActorUtil.Character(actor)
	if not char then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	self._landConn[uid] = hum.StateChanged:Connect(function(_old, newState)
		if newState == Enum.HumanoidStateType.Landed then
			self._landingPenaltyUntil[uid] = Workspace:GetServerTimeNow() + (MatchSettings.LandingSpreadSeconds or 0.2)
		end
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
	-- Rebind landing penalty on every respawn
	if not player:GetAttribute("LatchLandBind") then
		player:SetAttribute("LatchLandBind", true)
		player.CharacterAdded:Connect(function()
			task.defer(function()
				self:BindLandingPenalty(player)
			end)
		end)
	end
end

function WeaponService:SetupActor(actor: Actor, randomizeLoadout: boolean?)
	local uid = ActorUtil.UserId(actor)
	local existing = self._states[uid]
	local loadout: LoadoutMap = if existing then existing.Loadout else copyDefaultLoadout()
	-- Humans: prefer profile EquippedLoadout when no in-match state yet
	if existing == nil and not ActorUtil.IsBot(actor) then
		local data = self._deps and self._deps.Data
		local player = actor :: Player
		if data and data.GetOrLoad and typeof(player) == "Instance" and player:IsA("Player") then
			local profile = data:GetOrLoad(player)
			local el = profile.EquippedLoadout
			if typeof(el) == "table" and typeof(el.Primary) == "string" then
				loadout = {
					Primary = el.Primary,
					Secondary = el.Secondary,
					Melee = el.Melee,
					Utility = el.Utility,
				}
			end
		end
	end
	if randomizeLoadout == true or (ActorUtil.IsBot(actor) and existing == nil) then
		loadout = randomLoadout()
	end
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
		Equipped = loadout.Primary,
		Ammo = ammo,
		GrenadeReadyAt = 0,
		Loadout = loadout,
		StimUsedThisRound = false,
	}
	self:BindLandingPenalty(actor)
	self:_syncActorState(actor)
end

function WeaponService:ClearActor(actor: Actor)
	local uid = ActorUtil.UserId(actor)
	self._states[uid] = nil
	self._landingPenaltyUntil[uid] = nil
	self._lastHit[uid] = nil
	local conn = self._landConn[uid]
	if conn then
		conn:Disconnect()
		self._landConn[uid] = nil
	end
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
	state.StimUsedThisRound = false
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
			Loadout = state.Loadout,
			StimUsedThisRound = state.StimUsedThisRound,
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

function WeaponService:DealDamage(attacker: Actor, victim: Actor, amount: number, weaponId: string, headshot: boolean)
	self:_applyDamage(attacker, victim, amount, weaponId, headshot)
end

function WeaponService:_applyDamage(attacker: Actor, victim: Actor, amount: number, weaponId: string, headshot: boolean)
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

	local victimId = ActorUtil.UserId(victim)
	local attackerId = ActorUtil.UserId(attacker)
	local takenMult = self._damageTakenMult[victimId]
	if typeof(takenMult) == "number" and takenMult ~= 1 then
		amount = amount * takenMult
	end

	-- Warden planted armor: flat absorb while AttributePlantedArmor > 0
	local armor = ActorUtil.GetAttribute(victim, Constants.AttributePlantedArmor)
	if typeof(armor) == "number" and armor > 0 then
		amount = math.max(0, amount - (armor :: number))
	end
	if amount <= 0 then
		return
	end

	local before = hum.Health
	hum:TakeDamage(amount)
	local dealt = math.max(0, before - hum.Health)
	self:_addStat(attackerId, "Damage", dealt)

	local aRoot = ActorUtil.Root(attacker)
	local vRoot = ActorUtil.Root(victim)
	local dist = 0
	if aRoot and vRoot then
		dist = (aRoot.Position - vRoot.Position).Magnitude
	end
	local cfgEarly = WeaponsConfig.Weapons[weaponId :: any]
	local weaponNameEarly = if cfgEarly then cfgEarly.DisplayName else weaponId
	self._lastHit[victimId] = {
		KillerName = ActorUtil.DisplayName(attacker),
		WeaponName = weaponNameEarly,
		Distance = dist,
		Headshot = headshot,
		KillerUserId = attackerId,
	}

	self._remotes.DamageNumber:FireAllClients({
		TargetUserId = victimId,
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
		self:_addStat(attackerId, "Kills", 1)
		self:_addStat(victimId, "Deaths", 1)
		local cfg = WeaponsConfig.Weapons[weaponId :: any]
		local weaponName = if cfg then cfg.DisplayName else weaponId
		if self._remotes.KillFeed then
			self._remotes.KillFeed:FireAllClients({
				KillerName = ActorUtil.DisplayName(attacker),
				VictimName = ActorUtil.DisplayName(victim),
				KillerUserId = ActorUtil.UserId(attacker),
				VictimUserId = ActorUtil.UserId(victim),
				WeaponId = weaponId,
				WeaponName = weaponName,
				Headshot = headshot,
				Distance = dist,
				KillerIsBot = ActorUtil.IsBot(attacker),
				VictimIsBot = ActorUtil.IsBot(victim),
			})
		end
		-- Death recap line for the victim (Phase 5): "Nox [Coil SMG] 18m head"
		if ActorUtil.IsPlayer(victim) and self._remotes.DeathRecap then
			local hit = self._lastHit[victimId]
			local d = if hit then math.floor((hit.Distance or dist) + 0.5) else math.floor(dist + 0.5)
			local hs = if (hit and hit.Headshot) or headshot then " head" else ""
			local line = string.format(
				"%s [%s] %dm%s",
				ActorUtil.DisplayName(attacker),
				weaponName,
				d,
				hs
			)
			self._remotes.DeathRecap:FireClient(victim :: Player, {
				Line = line,
				KillerName = ActorUtil.DisplayName(attacker),
				WeaponName = weaponName,
				Distance = d,
				Headshot = headshot,
			})
		end
		if self._remotes.Announce then
			local hs = if headshot then " (HS)" else ""
			self._remotes.Announce:FireAllClients({
				Message = string.format(
					"%s [%s]%s %s",
					ActorUtil.DisplayName(attacker),
					weaponName,
					hs,
					ActorUtil.DisplayName(victim)
				),
			})
		end
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

function WeaponService:_inLoadout(state: WeaponState, weaponId: string): boolean
	local L = state.Loadout
	return L.Primary == weaponId or L.Secondary == weaponId or L.Melee == weaponId or L.Utility == weaponId
end

function WeaponService:_isUnlocked(player: Player, weaponId: string): boolean
	local data = self._deps and self._deps.Data
	if data and data.IsWeaponUnlocked then
		return data:IsWeaponUnlocked(player, weaponId)
	end
	-- Fallback: starters only if no DataService
	local Monetization = require(game.ReplicatedStorage.Config.Monetization)
	for _, id in Monetization.StarterWeapons do
		if id == weaponId then
			return true
		end
	end
	return false
end

function WeaponService:SetLoadout(player: Player, payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	local primary, secondary, melee, utility = payload.Primary, payload.Secondary, payload.Melee, payload.Utility
	if typeof(primary) ~= "string" or typeof(secondary) ~= "string" or typeof(melee) ~= "string" or typeof(utility) ~= "string" then
		return
	end
	local wp = WeaponsConfig.Weapons[primary :: any]
	local ws = WeaponsConfig.Weapons[secondary :: any]
	local wm = WeaponsConfig.Weapons[melee :: any]
	local wu = WeaponsConfig.Weapons[utility :: any]
	if not wp or wp.Slot ~= "Primary" then
		return
	end
	if not ws or ws.Slot ~= "Secondary" then
		return
	end
	if not wm or wm.Slot ~= "Melee" then
		return
	end
	if not wu or wu.Slot ~= "Utility" then
		return
	end
	-- Phase 4: gate by UnlockedWeapons (debug grant / shop unlock escape hatch)
	if not self:_isUnlocked(player, primary) then
		return
	end
	if not self:_isUnlocked(player, secondary) then
		return
	end
	if not self:_isUnlocked(player, melee) then
		return
	end
	if not self:_isUnlocked(player, utility) then
		return
	end
	local state = self._states[player.UserId]
	if not state then
		self:SetupPlayer(player)
		state = self._states[player.UserId]
	end
	if not state then
		return
	end
	state.Loadout = {
		Primary = primary,
		Secondary = secondary,
		Melee = melee,
		Utility = utility,
	}
	if not self:_inLoadout(state, state.Equipped) then
		state.Equipped = primary
	end
	-- Persist to profile when DataService present
	local data = self._deps and self._deps.Data
	if data and data.Mutate then
		data:Mutate(player, function(p)
			p.EquippedLoadout = {
				Primary = primary,
				Secondary = secondary,
				Melee = melee,
				Utility = utility,
			}
		end)
	end
	self:_syncActorState(player)
end

function WeaponService:_onSwitch(player: Player, weaponId: any)
	if typeof(weaponId) ~= "string" then
		return
	end
	if self._gunCycleLocked[player.UserId] then
		return -- Gun Cycle locks weapon switches
	end
	if not WeaponsConfig.Weapons[weaponId :: any] then
		return
	end
	local state = self._states[player.UserId]
	if not state then
		return
	end
	if not self:_inLoadout(state, weaponId) then
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
	local aiming = payload.Aiming == true
	if typeof(weaponId) ~= "string" or typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end
	if direction.Magnitude < 0.1 then
		return
	end

	-- Stim Cap activates through fire while equipped as utility
	local cfgEarly = WeaponsConfig.Weapons[weaponId :: any]
	if cfgEarly and cfgEarly.UtilityKind == "Stim" then
		self:_useStim(actor)
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
		if ActorUtil.IsBot(actor) and WeaponsConfig.Weapons[weaponId :: any] then
			state.Equipped = weaponId
			if cfg.Slot == "Primary" then
				state.Loadout.Primary = weaponId
			elseif cfg.Slot == "Secondary" then
				state.Loadout.Secondary = weaponId
			end
		else
			return
		end
	end
	if ActorUtil.IsPlayer(actor) and not self:_inLoadout(state, weaponId) then
		return
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

	local baseDir = direction.Unit
	local spread = if aiming then cfg.AdsSpreadDegrees else cfg.SpreadDegrees
	local landUntil = self._landingPenaltyUntil[uid]
	if typeof(landUntil) == "number" and now < landUntil then
		spread = (spread or 0) + (MatchSettings.LandingSpreadDegrees or 3.5)
	end
	-- Client may also flag LandedPenalty; accept as soft hint (server timer authoritative)
	if payload.LandedPenalty == true and (typeof(landUntil) ~= "number" or now >= (landUntil :: number)) then
		spread = (spread or 0) + (MatchSettings.LandingSpreadDegrees or 3.5) * 0.5
	end
	local pellets = math.max(1, cfg.PelletCount or 1)
	local color = if pellets > 1 then Color3.fromRGB(255, 200, 90) else Color3.fromRGB(255, 230, 120)

	for _ = 1, pellets do
		local dir = if pellets > 1 or spread > 0 then spreadDirection(baseDir, spread) else baseDir
		local hitPos = self:_rayPellet(actor, char, origin, dir, cfg.Range, weaponId, cfg)
		if hitPos then
			VFX.BeamStreak(origin, hitPos, color)
		end
	end

	self:_syncActorState(actor)
	if ammo.Mag <= 0 then
		self:ServerReload(actor)
	end
end

function WeaponService:_rayPellet(
	actor: Actor,
	char: Model,
	origin: Vector3,
	dir: Vector3,
	range: number,
	weaponId: string,
	cfg: any
): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true

	local remaining = range
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
				local mult, headshot = WeaponsConfig.BodyMultiplier(cfg, hitPart.Name)
				self:_applyDamage(actor, victim, cfg.Damage * mult, weaponId, headshot)
			end
		end
		break
	end
	return hitPos
end

function WeaponService:_useStim(actor: Actor)
	local _, hum = self:_characterAlive(actor)
	if not hum then
		return
	end
	local uid = ActorUtil.UserId(actor)
	local state = self._states[uid]
	if not state then
		return
	end
	local utilId = state.Loadout.Utility
	local cfg = WeaponsConfig.Weapons[utilId :: any]
	if not cfg or cfg.UtilityKind ~= "Stim" then
		return
	end
	if state.StimUsedThisRound then
		return
	end
	local ammo = state.Ammo[utilId]
	if ammo and ammo.Mag <= 0 then
		return
	end
	state.StimUsedThisRound = true
	state.Equipped = utilId
	if ammo then
		ammo.Mag = 0
	end
	self:_syncActorState(actor)

	local total = cfg.StimHealTotal or 30
	local duration = cfg.StimHealDuration or 2
	local ticks = 10
	local perTick = total / ticks
	local interval = duration / ticks
	for i = 1, ticks do
		task.delay(interval * i, function()
			local _, hum2 = self:_characterAlive(actor)
			if hum2 and hum2.Health > 0 then
				hum2.Health = math.min(hum2.MaxHealth, hum2.Health + perTick)
			end
		end)
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
	local meleeId = state.Loadout.Melee
	local cfg = WeaponsConfig.Weapons[meleeId :: any]
	local ammo = state.Ammo[meleeId]
	if not cfg or not ammo or cfg.Kind ~= "Melee" then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local minInterval = 1 / math.max(cfg.FireRate, 0.1)
	if now - ammo.LastFire < minInterval * 0.85 then
		return
	end
	ammo.LastFire = now
	state.Equipped = meleeId
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
				self:_applyDamage(player, victim, cfg.Damage, meleeId, false)
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
	local utilId = state.Loadout.Utility
	local cfg = WeaponsConfig.Weapons[utilId :: any]
	if not cfg then
		return
	end

	if cfg.UtilityKind == "Stim" then
		self:_useStim(player)
		return
	end
	if cfg.Kind ~= "Projectile" then
		return
	end

	local now = Workspace:GetServerTimeNow()
	if now < state.GrenadeReadyAt then
		return
	end
	local speed = math.min(velocity.Magnitude, (cfg.ProjectileSpeed or 90) * 1.2)
	if speed < 5 then
		return
	end

	state.GrenadeReadyAt = now + (cfg.ThrowCooldown or 8)
	state.Equipped = utilId
	local ammo = state.Ammo[utilId]
	if ammo then
		ammo.Mag = math.max(0, ammo.Mag - 1)
	end
	self:_syncActorState(player)

	local color = Color3.fromRGB(40, 120, 50)
	local name = "LatchFrag"
	if cfg.UtilityKind == "Flash" then
		color = Color3.fromRGB(240, 240, 200)
		name = "LatchFlash"
	elseif cfg.UtilityKind == "Smoke" then
		color = Color3.fromRGB(90, 100, 110)
		name = "LatchSmokeCan"
	end

	local grenade = Instance.new("Part")
	grenade.Name = name
	grenade.Shape = Enum.PartType.Ball
	grenade.Size = Vector3.new(1.2, 1.2, 1.2)
	grenade.Color = color
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
	-- Fuse operator passive: Frag fuse −0.3s (AttributeFragFuseBonus)
	if (cfg.UtilityKind or "Frag") == "Frag" then
		local fuseBonus = player:GetAttribute(Constants.AttributeFragFuseBonus)
		if typeof(fuseBonus) ~= "number" then
			fuseBonus = 0
		end
		fuse = math.max(0.35, fuse + (fuseBonus :: number))
	end
	local radius = cfg.ExplosionRadius or 18
	local damage = cfg.Damage
	Debris:AddItem(grenade, fuse + 0.5)

	task.delay(fuse, function()
		if not grenade.Parent then
			return
		end
		local pos = grenade.Position
		grenade:Destroy()

		local kind = cfg.UtilityKind or "Frag"
		if kind == "Frag" then
			VFX.ExplosionSphere(pos, radius)
			local params = OverlapParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			local hits = Workspace:GetPartBoundsInRadius(pos, radius, params)
			local damaged: { [number]: boolean } = {}
			local knocked: { [number]: boolean } = {}
			for _, p in hits do
				local model = p:FindFirstAncestorOfClass("Model")
				if model then
					local victim = self:_resolveFromModel(model)
					if victim then
						local vid = ActorUtil.UserId(victim)
						local rootPart = model:FindFirstChild("HumanoidRootPart") :: BasePart?
						local dist = if rootPart then (rootPart.Position - pos).Magnitude else 0
						local falloff = 1 - math.clamp(dist / radius, 0, 1) * 0.6
						-- Damage enemies only
						if not damaged[vid] and not self:_sameTeam(player, victim) then
							damaged[vid] = true
							self:_applyDamage(player, victim, damage * falloff, utilId, false)
						end
						-- Knock thrower + enemies (skip allied teammates); Anchor reduces self knock
						local isSelf = vid == ActorUtil.UserId(player)
						if not knocked[vid] and rootPart and (isSelf or not self:_sameTeam(player, victim)) then
							knocked[vid] = true
							self:_applyFragKnock(player, victim, rootPart, pos, radius)
						end
					end
				end
			end
		elseif kind == "Flash" then
			VFX.ExplosionSphere(pos, radius * 0.45, Color3.fromRGB(255, 255, 230))
			local duration = cfg.FlashDuration or 1.6
			for _, plr in Players:GetPlayers() do
				local pchar = plr.Character
				local proot = pchar and pchar:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not proot or (proot.Position - pos).Magnitude > radius then
					continue
				end
				local isSelf = plr == player
				if self:_sameTeam(player, plr) and not isSelf then
					continue
				end
				local intensity = if isSelf then 0.35 else 1
				if self._remotes.FlashEffect then
					self._remotes.FlashEffect:FireClient(plr, {
						Duration = duration * intensity,
						Intensity = intensity,
					})
				end
			end
		elseif kind == "Smoke" then
			local smokeR = cfg.SmokeRadius or radius
			local smokeDur = cfg.SmokeDuration or 8
			VFX.SmokeSphere(pos, smokeR, smokeDur)
		end
	end)
end


--[[ Explosive knock — Anchor Blast Brace reduces self Frag knock. ]]
function WeaponService:_applyFragKnock(thrower: Actor, victim: Actor, rootPart: BasePart, blastPos: Vector3, radius: number)
	local offset = rootPart.Position - blastPos
	local dist = offset.Magnitude
	if dist < 0.05 then
		offset = Vector3.new(0, 1, 0)
		dist = 1
	end
	local dir = offset.Unit
	-- Bias upward so frags feel like a pop
	dir = (dir + Vector3.new(0, 0.45, 0)).Unit
	local falloff = 1 - math.clamp(dist / math.max(radius, 1), 0, 1)
	local speed = (MatchSettings.FragKnockSpeed or 48) * falloff
	speed = math.min(speed, MatchSettings.FragKnockMax or 72)

	local isSelf = ActorUtil.UserId(thrower) == ActorUtil.UserId(victim)
	if isSelf then
		local reduction = ActorUtil.GetAttribute(victim, Constants.AttributeExplosiveKnockReduction)
		if typeof(reduction) ~= "number" then
			reduction = 0
		end
		speed *= math.clamp(1 - (reduction :: number), 0, 1)
	end
	if speed < 1 then
		return
	end

	local att = rootPart:FindFirstChild("LatchKnockAtt") :: Attachment?
	if not att then
		att = Instance.new("Attachment")
		att.Name = "LatchKnockAtt"
		att.Parent = rootPart
	end
	local lv = Instance.new("LinearVelocity")
	lv.Name = "LatchFragKnock"
	lv.Attachment0 = att
	lv.MaxForce = 1e5
	lv.VectorVelocity = dir * speed
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = rootPart
	Debris:AddItem(lv, 0.18)
	-- Also nudge assembly for immediate feel
	rootPart.AssemblyLinearVelocity = Vector3.new(
		rootPart.AssemblyLinearVelocity.X,
		math.max(rootPart.AssemblyLinearVelocity.Y, 0),
		rootPart.AssemblyLinearVelocity.Z
	) + dir * speed * 0.35
end

function WeaponService:GetEquipped(actor: Actor): string?
	local state = self._states[ActorUtil.UserId(actor)]
	return if state then state.Equipped else nil
end

-- Phase 3 helpers -----------------------------------------------------------

function WeaponService:_ensureStat(uid: number)
	if not self._stats[uid] then
		self._stats[uid] = { Kills = 0, Deaths = 0, Damage = 0 }
	end
end

function WeaponService:_addStat(uid: number, key: string, amount: number)
	self:_ensureStat(uid)
	local s = self._stats[uid]
	if key == "Kills" then
		s.Kills += amount
	elseif key == "Deaths" then
		s.Deaths += amount
	elseif key == "Damage" then
		s.Damage += amount
	end
end

function WeaponService:ResetMatchStats()
	self._stats = {}
end

function WeaponService:GetMatchStats(): { [number]: { Kills: number, Deaths: number, Damage: number } }
	return self._stats
end

function WeaponService:GetActorStats(actor: Actor): { Kills: number, Deaths: number, Damage: number }
	local uid = ActorUtil.UserId(actor)
	self:_ensureStat(uid)
	local s = self._stats[uid]
	return { Kills = s.Kills, Deaths = s.Deaths, Damage = s.Damage }
end

function WeaponService:SetDamageTakenMult(actor: Actor, mult: number)
	self._damageTakenMult[ActorUtil.UserId(actor)] = mult
end

function WeaponService:ClearDamageTakenMults()
	self._damageTakenMult = {}
end

--[[ Force a single weapon for Gun Cycle (locks switches). ]]
function WeaponService:ForceGunCycleWeapon(actor: Actor, weaponId: string)
	local cfg = WeaponsConfig.Weapons[weaponId :: any]
	if not cfg then
		return
	end
	local uid = ActorUtil.UserId(actor)
	local state = self._states[uid]
	if not state then
		self:SetupActor(actor, false)
		state = self._states[uid]
	end
	if not state then
		return
	end
	-- Mirror weapon into every slot so _inLoadout / fire paths stay happy
	local slot = cfg.Slot
	local loadout = {
		Primary = if slot == "Primary" then weaponId else weaponId,
		Secondary = if slot == "Secondary" then weaponId else weaponId,
		Melee = if slot == "Melee" then weaponId else weaponId,
		Utility = state.Loadout.Utility,
	}
	if slot == "Utility" then
		loadout.Utility = weaponId
	end
	-- Keep non-matching slots as the cycle weapon too (single-weapon mode)
	loadout.Primary = weaponId
	loadout.Secondary = weaponId
	loadout.Melee = weaponId
	state.Loadout = loadout
	state.Equipped = weaponId
	local ammo = state.Ammo[weaponId]
	if ammo then
		ammo.Mag = cfg.MagSize
		ammo.Reserve = cfg.ReserveAmmo
		ammo.Reloading = false
	end
	self._gunCycleLocked[uid] = true
	self:_syncActorState(actor)
end

function WeaponService:ClearGunCycleLocks()
	self._gunCycleLocked = {}
end

return WeaponService
