--!strict
--[[
	ViewmodelController — minimal cosmetics stub.
	Recolors equipped Tool / viewmodel Parts from profile skin / wrap colors.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Cosmetics = require(game.ReplicatedStorage.Config.Cosmetics)

local player = Players.LocalPlayer

local ViewmodelController = {}
ViewmodelController.__index = ViewmodelController

function ViewmodelController.new(remotes: { [string]: RemoteEvent })
	local self = setmetatable({
		_remotes = remotes,
		_profile = nil :: any,
		_equippedWeaponId = nil :: string?,
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
				self:Apply()
			end
		end)
	end
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		self:Apply()
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
	-- Wrap overrides tint globally when set
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

function ViewmodelController:Apply()
	local char = player.Character
	if not char then
		return
	end
	local weaponId = self._equippedWeaponId
	local color = if weaponId then self:_colorForWeapon(weaponId) else nil
	-- Also tint any Tool in character / backpack named after weapon
	local function tint(inst: Instance)
		for _, d in inst:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				if color then
					d.Color = color
				end
			end
		end
	end
	for _, child in char:GetChildren() do
		if child:IsA("Tool") then
			tint(child)
		end
	end
	-- Optional client viewmodel folder
	local pg = player:FindFirstChild("PlayerGui")
	local cam = Workspace.CurrentCamera
	local vm = cam and cam:FindFirstChild("LatchViewmodel")
	if vm then
		tint(vm)
	end
	local _ = pg
end

return ViewmodelController
