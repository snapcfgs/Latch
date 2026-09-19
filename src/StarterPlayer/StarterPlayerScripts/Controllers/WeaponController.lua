--!strict
--[[
	WeaponController — fires remotes from input; camera-forward aim for PC + mobile.
	Phase 2: ADS FOV lerp, Aiming flag for server spread, burst fire, loadout cycle.
	Phase 5: landing spread penalty flag (200ms).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local WeaponsConfig = require(game.ReplicatedStorage.Config.Weapons)
local MatchSettings = require(game.ReplicatedStorage.Config.MatchSettings)

local player = Players.LocalPlayer

local DEFAULT_FOV = 70

local WeaponController = {}
WeaponController.__index = WeaponController

function WeaponController.new(input: any, remotes: { [string]: RemoteEvent })
	local self = setmetatable({
		_input = input,
		_remotes = remotes,
		_equippedIndex = 1,
		_ammo = {} :: any,
		_equipped = "AssaultRifle",
		_loadoutOrder = table.clone(WeaponsConfig.LoadoutOrder) :: { string },
		_lastAuto = 0,
		_aiming = false,
		_fovTarget = DEFAULT_FOV,
		_baseFov = DEFAULT_FOV,
		_burstLeft = 0,
		_burstNextAt = 0,
		_recoilIndex = 1,
		_fireWasDown = false,
		_landedAt = 0,
	}, WeaponController)
	return self
end

function WeaponController:Init()
	local cam = Workspace.CurrentCamera
	if cam then
		self._baseFov = cam.FieldOfView
		self._fovTarget = cam.FieldOfView
	end

	local function hookChar(char: Model)
		local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?
		if not hum then
			return
		end
		hum.StateChanged:Connect(function(_old, newState)
			if newState == Enum.HumanoidStateType.Landed then
				self._landedAt = os.clock()
			end
		end)
	end
	player.CharacterAdded:Connect(hookChar)
	if player.Character then
		task.defer(hookChar, player.Character)
	end

	self._remotes.PlayerState.OnClientEvent:Connect(function(state)
		if typeof(state) ~= "table" then
			return
		end
		if state.Loadout and typeof(state.Loadout) == "table" then
			self._loadoutOrder = WeaponsConfig.LoadoutToOrder(state.Loadout)
		end
		if state.Equipped then
			self._equipped = state.Equipped
			for i, id in self._loadoutOrder do
				if id == state.Equipped then
					self._equippedIndex = i
					break
				end
			end
		end
		if state.Ammo then
			self._ammo = state.Ammo
		end
	end)

	self._input:OnAction(function(name, down)
		if name == "Aim" then
			self._aiming = down
			return
		end
		if not down then
			return
		end
		if name == "Reload" then
			self._remotes.ReloadWeapon:FireServer()
		elseif name == "NextWeapon" then
			self:_cycle(1)
		elseif name == "WeaponSlot" then
			local slot = self._input:GetActions().WeaponSlot
			if slot then
				self:_equipIndex(slot)
			end
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		self:_updateAds(dt)
		self:_updateFire()
	end)
end

function WeaponController:GetEquipped(): string
	return self._equipped
end

function WeaponController:GetAmmo(): any
	return self._ammo
end

function WeaponController:IsAiming(): boolean
	return self._aiming
end

function WeaponController:GetLoadoutOrder(): { string }
	return self._loadoutOrder
end

function WeaponController:_equipIndex(index: number)
	local order = self._loadoutOrder
	local id = order[index]
	if not id then
		return
	end
	self._equippedIndex = index
	self._equipped = id
	self._burstLeft = 0
	self._recoilIndex = 1
	self._remotes.SwitchWeapon:FireServer(id)
end

function WeaponController:_cycle(dir: number)
	local order = self._loadoutOrder
	local n = #order
	if n == 0 then
		return
	end
	self:_equipIndex(((self._equippedIndex - 1 + dir) % n) + 1)
end

function WeaponController:_aim(): (Vector3, Vector3)
	local cam = Workspace.CurrentCamera
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local origin = if root then root.Position + Vector3.new(0, 1.5, 0) else cam.CFrame.Position
	local dir = cam.CFrame.LookVector
	return origin, dir
end

function WeaponController:_updateAds(dt: number)
	local actions = self._input:GetActions()
	self._aiming = actions.Aim == true
	local cfg = WeaponsConfig.Weapons[self._equipped :: any]
	local target = self._baseFov
	local moveMult = 1
	if self._aiming and cfg then
		target = cfg.AdsFov or 60
		moveMult = cfg.MoveSpeedMult or 0.85
	end
	self._fovTarget = target
	local cam = Workspace.CurrentCamera
	if cam then
		cam.FieldOfView = cam.FieldOfView + (self._fovTarget - cam.FieldOfView) * math.clamp(dt * 12, 0, 1)
	end
	-- Soft ADS move slowdown (SlideController owns sprint/slide speeds)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0  then
		local base = if actions.Sprint then MatchSettings.SprintSpeed else MatchSettings.WalkSpeed
		if actions.Crouch then
			base = MatchSettings.CrouchSpeed
		end
		-- Only nudge when aiming; leave SlideController authoritative while sliding
		if self._aiming then
			hum.WalkSpeed = base * moveMult
		end
	end
end

function WeaponController:_applyRecoil(cfg: any)
	local pattern = cfg.RecoilPattern
	if typeof(pattern) ~= "table" or #pattern == 0 then
		return
	end
	local idx = ((self._recoilIndex - 1) % #pattern) + 1
	self._recoilIndex = idx + 1
	local kick = pattern[idx] :: number
	local cam = Workspace.CurrentCamera
	if cam then
		cam.CFrame = cam.CFrame * CFrame.Angles(math.rad(-kick), 0, 0)
	end
end

function WeaponController:_fireHitscan(origin: Vector3, dir: Vector3)
	local landPenalty = (os.clock() - self._landedAt) < (MatchSettings.LandingSpreadSeconds or 0.2)
	self._remotes.FireWeapon:FireServer({
		WeaponId = self._equipped,
		Origin = origin,
		Direction = dir,
		Aiming = self._aiming,
		LandedPenalty = landPenalty,
		Timestamp = Workspace:GetServerTimeNow(),
	})
	local cfg = WeaponsConfig.Weapons[self._equipped :: any]
	if cfg then
		self:_applyRecoil(cfg)
	end
end

function WeaponController:_updateFire()
	local actions = self._input:GetActions()
	local cfg = WeaponsConfig.Weapons[self._equipped :: any]
	if not cfg then
		return
	end

	local origin, dir = self:_aim()
	local now = os.clock()
	local fireDown = actions.Fire == true
	local justPressed = fireDown and not self._fireWasDown
	self._fireWasDown = fireDown

	-- Finish queued burst shots even if button released
	if self._burstLeft > 0 then
		if now >= self._burstNextAt then
			self._burstLeft -= 1
			self._burstNextAt = now + (cfg.BurstInterval or 0.05)
			self:_fireHitscan(origin, dir)
			self._lastAuto = now
		end
		return
	end

	if not fireDown then
		return
	end

	if cfg.Kind == "Melee" then
		local minInterval = 1 / math.max(cfg.FireRate, 0.1)
		if now - self._lastAuto >= minInterval then
			self._lastAuto = now
			self._remotes.MeleeSwing:FireServer(dir)
		end
		return
	end

	if cfg.Kind == "Projectile" then
		local minInterval = 0.4
		if now - self._lastAuto >= minInterval then
			self._lastAuto = now
			local speed = cfg.ProjectileSpeed or 90
			self._remotes.ThrowGrenade:FireServer(origin, dir * speed + Vector3.new(0, 20, 0))
		end
		return
	end

	if cfg.Kind == "Utility" then
		-- Stim Cap
		local minInterval = 0.5
		if now - self._lastAuto >= minInterval then
			self._lastAuto = now
			self:_fireHitscan(origin, dir)
		end
		return
	end

	-- Hitscan (incl. burst)
	local burstCount = cfg.BurstCount or 1
	local minInterval = 1 / math.max(cfg.FireRate, 0.1)

	if burstCount > 1 then
		if justPressed and now - self._lastAuto >= minInterval then
			self._lastAuto = now
			self._burstLeft = burstCount - 1
			self._burstNextAt = now + (cfg.BurstInterval or 0.05)
			self:_fireHitscan(origin, dir)
		end
		return
	end

	if cfg.Auto then
		if now - self._lastAuto >= minInterval then
			self._lastAuto = now
			self:_fireHitscan(origin, dir)
		end
	else
		if justPressed and now - self._lastAuto >= minInterval * 0.5 then
			self._lastAuto = now
			self:_fireHitscan(origin, dir)
		elseif fireDown and now - self._lastAuto >= minInterval then
			-- Hold-to-semi fallback (existing feel)
			self._lastAuto = now
			self:_fireHitscan(origin, dir)
		end
	end
end

return WeaponController
