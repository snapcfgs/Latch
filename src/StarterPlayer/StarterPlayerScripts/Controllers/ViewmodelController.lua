--!strict
--[[
	ViewmodelController — first-person local weapon Part welded to camera
	so skins/wraps are visible. Recolors from profile EquippedCosmetics.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Cosmetics = require(game.ReplicatedStorage.Config.Cosmetics)
local WeaponsConfig = require(game.ReplicatedStorage.Config.Weapons)

local player = Players.LocalPlayer

local ViewmodelController = {}
ViewmodelController.__index = ViewmodelController

function ViewmodelController.new(remotes: { [string]: RemoteEvent })
	local self = setmetatable({
		_remotes = remotes,
		_profile = nil :: any,
		_equippedWeaponId = nil :: string?,
		_model = nil :: Model?,
		_body = nil :: BasePart?,
		_barrel = nil :: BasePart?,
		_inCombat = false,
		_conn = nil :: RBXScriptConnection?,
	}, ViewmodelController)
	return self
end

function ViewmodelController:Init()
	if self._remotes.ProfileSync then
		self._remotes.ProfileSync.OnClientEvent:Connect(function(profile)
			self._profile = profile
			self:Apply()
		end)
	end
	if self._remotes.PlayerState then
		self._remotes.PlayerState.OnClientEvent:Connect(function(state)
			if typeof(state) == "table" and typeof(state.Equipped) == "string" then
				self._equippedWeaponId = state.Equipped
				self:_rebuildMesh()
				self:Apply()
			end
		end)
	end
	if self._remotes.MatchSnapshot then
		self._remotes.MatchSnapshot.OnClientEvent:Connect(function(snap)
			if typeof(snap) ~= "table" then
				return
			end
			local phase = snap.Phase
			self._inCombat = phase == "Countdown" or phase == "Round" or phase == "RoundEnd"
			self:_setVisible(self._inCombat)
		end)
	end
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		self:_ensureModel()
		self:Apply()
	end)
	self:_ensureModel()
	self._conn = RunService.RenderStepped:Connect(function()
		self:_updateCFrame()
	end)
end

function ViewmodelController:_colorForWeapon(weaponId: string): Color3?
	if not self._profile then
		return nil
	end
	local ec = self._profile.EquippedCosmetics
	if typeof(ec) ~= "table" then
		return nil
	end
	if typeof(ec.Wrap) == "string" then
		local wrap = Cosmetics.Wraps[ec.Wrap]
		if wrap then
			return wrap.Color
		end
	end
	local skins = ec.Skins
	if typeof(skins) == "table" then
		local skinId = skins[weaponId]
		if typeof(skinId) == "string" then
			local skin = Cosmetics.Skins[skinId]
			if skin then
				return skin.Color
			end
		end
	end
	local defId = Cosmetics.DefaultSkinId(weaponId)
	if defId then
		local skin = Cosmetics.Skins[defId]
		if skin then
			return skin.Color
		end
	end
	return nil
end

function ViewmodelController:_ensureModel()
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local existing = cam:FindFirstChild("LatchViewmodel")
	if existing and existing:IsA("Model") then
		self._model = existing
		self._body = existing:FindFirstChild("Body") :: BasePart?
		self._barrel = existing:FindFirstChild("Barrel") :: BasePart?
		return
	end

	local model = Instance.new("Model")
	model.Name = "LatchViewmodel"

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(0.55, 0.45, 1.6)
	body.Material = Enum.Material.Metal
	body.Color = Color3.fromRGB(70, 75, 85)
	body.CastShadow = false
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Anchored = true
	body.Massless = true
	body.Parent = model

	local barrel = Instance.new("Part")
	barrel.Name = "Barrel"
	barrel.Size = Vector3.new(0.18, 0.18, 0.9)
	barrel.Material = Enum.Material.Metal
	barrel.Color = Color3.fromRGB(40, 42, 48)
	barrel.CastShadow = false
	barrel.CanCollide = false
	barrel.CanQuery = false
	barrel.CanTouch = false
	barrel.Anchored = true
	barrel.Massless = true
	barrel.Parent = model

	model.PrimaryPart = body
	model.Parent = cam
	self._model = model
	self._body = body
	self._barrel = barrel
	self:_rebuildMesh()
	self:_setVisible(self._inCombat)
end

function ViewmodelController:_rebuildMesh()
	self:_ensureModel()
	local body = self._body
	local barrel = self._barrel
	if not body or not barrel then
		return
	end
	local weaponId = self._equippedWeaponId or "AssaultRifle"
	local cfg = WeaponsConfig.Weapons[weaponId :: any]
	local kind = if cfg then cfg.Kind else "Hitscan"
	local slot = if cfg then cfg.Slot else "Primary"

	if kind == "Melee" then
		body.Size = Vector3.new(0.2, 0.2, 1.4)
		barrel.Size = Vector3.new(0.35, 0.08, 0.55)
		barrel.Transparency = 0
	elseif kind == "Projectile" or slot == "Utility" then
		body.Size = Vector3.new(0.45, 0.45, 0.45)
		body.Shape = Enum.PartType.Ball
		barrel.Transparency = 1
	else
		body.Shape = Enum.PartType.Block
		if slot == "Secondary" then
			body.Size = Vector3.new(0.4, 0.35, 0.95)
			barrel.Size = Vector3.new(0.14, 0.14, 0.55)
		else
			body.Size = Vector3.new(0.55, 0.45, 1.6)
			barrel.Size = Vector3.new(0.18, 0.18, 0.9)
		end
		barrel.Transparency = 0
	end
end

function ViewmodelController:_setVisible(visible: boolean)
	if self._model then
		for _, d in self._model:GetDescendants() do
			if d:IsA("BasePart") then
				if d.Name == "Barrel" and d.Transparency >= 1 then
					-- keep hidden barrel for grenade shape
				else
					d.LocalTransparencyModifier = if visible then 0 else 1
				end
			end
		end
	end
end

function ViewmodelController:_updateCFrame()
	if not self._inCombat then
		return
	end
	local cam = Workspace.CurrentCamera
	local body = self._body
	local barrel = self._barrel
	if not cam or not body then
		return
	end
	-- Offset into lower-right of first-person view
	local offset = CFrame.new(0.55, -0.55, -1.35)
	body.CFrame = cam.CFrame * offset
	if barrel and barrel.Transparency < 1 then
		barrel.CFrame = body.CFrame * CFrame.new(0, 0.05, -body.Size.Z * 0.45 - barrel.Size.Z * 0.45)
	end
end

function ViewmodelController:Apply()
	local char = player.Character
	local weaponId = self._equippedWeaponId
	local color = if weaponId then self:_colorForWeapon(weaponId) else nil

	local function tint(inst: Instance)
		for _, d in inst:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				if color then
					d.Color = color
				end
			end
		end
	end

	if char then
		for _, child in char:GetChildren() do
			if child:IsA("Tool") then
				tint(child)
			end
		end
	end

	self:_ensureModel()
	if self._model then
		if color then
			if self._body then
				self._body.Color = color
			end
			if self._barrel and self._barrel.Transparency < 1 then
				local h, s, v = color:ToHSV()
				self._barrel.Color = Color3.fromHSV(h, s, math.max(0.15, v * 0.55))
			end
		end
	end
end

return ViewmodelController
