--!strict
--[[ AbilityController — Q / touch Ability → UseAbility remote. ]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local AbilityController = {}
AbilityController.__index = AbilityController

function AbilityController.new(input: any, remotes: { [string]: RemoteEvent })
	local self = setmetatable({
		_input = input,
		_remotes = remotes,
		_cooldownEndsAt = 0,
		_pressed = false,
	}, AbilityController)
	return self
end

function AbilityController:Init()
	self._remotes.PlayerState.OnClientEvent:Connect(function(state)
		if typeof(state) == "table" and typeof(state.AbilityCooldownEndsAt) == "number" then
			self._cooldownEndsAt = state.AbilityCooldownEndsAt
		end
	end)
	self._remotes.AbilityFx.OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" and payload.UserId == player.UserId and typeof(payload.CooldownEndsAt) == "number" then
			self._cooldownEndsAt = payload.CooldownEndsAt
		end
	end)

	self._input:OnAction(function(name, down)
		if name ~= "Ability" then
			return
		end
		if down and not self._pressed then
			self._pressed = true
			self:_tryUse()
		elseif not down then
			self._pressed = false
		end
	end)
end

function AbilityController:GetCooldownEndsAt(): number
	return self._cooldownEndsAt
end

function AbilityController:_tryUse()
	local now = Workspace:GetServerTimeNow()
	if now < self._cooldownEndsAt then
		return
	end
	local cam = Workspace.CurrentCamera
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local origin = if root then root.Position else cam.CFrame.Position
	local look = cam.CFrame.LookVector

	-- Soft target for Jolt: raycast
	local targetUserId: number? = nil
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	if char then
		params.FilterDescendantsInstances = { char }
	end
	local result = Workspace:Raycast(cam.CFrame.Position, look * 120, params)
	if result then
		local model = result.Instance:FindFirstAncestorOfClass("Model")
		if model then
			local plr = Players:GetPlayerFromCharacter(model)
			if plr then
				targetUserId = plr.UserId
			end
		end
	end

	self._remotes.UseAbility:FireServer({
		LookDirection = look,
		Origin = origin,
		TargetUserId = targetUserId,
	})
end

return AbilityController
