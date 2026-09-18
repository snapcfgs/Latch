--!strict
--[[
	WeaponController — fires remotes from input; camera-forward aim for PC + mobile.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local WeaponsConfig = require(game.ReplicatedStorage.Config.Weapons)

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local WeaponController = {}
WeaponController.__index = WeaponController

function WeaponController.new(input: any, remotes: { [string]: RemoteEvent })
	local self = setmetatable({
		_input = input,
		_remotes = remotes,
		_equippedIndex = 1,
		_ammo = {} :: any,
		_equipped = "AssaultRifle",
		_lastAuto = 0,
	}, WeaponController)
	return self
end

function WeaponController:Init()
	self._remotes.PlayerState.OnClientEvent:Connect(function(state)
		if typeof(state) ~= "table" then
			return
		end
		if state.Equipped then
			self._equipped = state.Equipped
			local order = WeaponsConfig.LoadoutOrder
			for i, id in order do
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

	RunService.RenderStepped:Connect(function()
		self:_updateFire()
	end)
end

function WeaponController:GetEquipped(): string
	return self._equipped
end

function WeaponController:GetAmmo(): any
	return self._ammo
end

function WeaponController:_equipIndex(index: number)
	local order = WeaponsConfig.LoadoutOrder
	local id = order[index]
	if not id then
		return
	end
	self._equippedIndex = index
	self._equipped = id
	self._remotes.SwitchWeapon:FireServer(id)
end

function WeaponController:_cycle(dir: number)
	local order = WeaponsConfig.LoadoutOrder
	local n = #order
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

function WeaponController:_updateFire()
	local actions = self._input:GetActions()
	local cfg = WeaponsConfig.Weapons[self._equipped :: any]
	if not cfg then
		return
	end

	if not actions.Fire then
		return
	end

	local origin, dir = self:_aim()
	local now = os.clock()

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

	-- Hitscan
	local minInterval = 1 / math.max(cfg.FireRate, 0.1)
	if cfg.Auto then
		if now - self._lastAuto >= minInterval then
			self._lastAuto = now
			self._remotes.FireWeapon:FireServer({
				WeaponId = self._equipped,
				Origin = origin,
				Direction = dir,
				Timestamp = Workspace:GetServerTimeNow(),
			})
		end
	else
		-- Semi: fire once per press edge approximated by interval
		if now - self._lastAuto >= minInterval then
			self._lastAuto = now
			self._remotes.FireWeapon:FireServer({
				WeaponId = self._equipped,
				Origin = origin,
				Direction = dir,
				Timestamp = Workspace:GetServerTimeNow(),
			})
		end
	end
end

return WeaponController
