--!strict
--[[
	SlideController — crouch while sprinting → slide.
	Client feel + notify server; Skid passive extends duration via attribute.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MatchSettings = require(game.ReplicatedStorage.Config.MatchSettings)
local Constants = require(game.ReplicatedStorage.Shared.Constants)

local player = Players.LocalPlayer

local SlideController = {}
SlideController.__index = SlideController

function SlideController.new(input: any, remotes: { [string]: RemoteEvent })
	local self = setmetatable({
		_input = input,
		_remotes = remotes,
		_sliding = false,
		_slideEndsAt = 0,
		_lastSlide = 0,
		_sprintTime = 0,
		_crouched = false,
		_baseHipHeight = nil :: number?,
	}, SlideController)
	return self
end

function SlideController:Init()
	RunService.RenderStepped:Connect(function(dt)
		self:_update(dt)
	end)
end

function SlideController:IsSliding(): boolean
	return self._sliding
end

function SlideController:_humanoid(): (Humanoid?, BasePart?)
	local char = player.Character
	if not char then
		return nil, nil
	end
	return char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function SlideController:_update(dt: number)
	local actions = self._input:GetActions()
	local hum, root = self:_humanoid()
	if not hum or not root or hum.Health <= 0 then
		return
	end

	local moving = hum.MoveDirection.Magnitude > 0.1
	if actions.Sprint and moving then
		self._sprintTime += dt
	else
		self._sprintTime = 0
	end

	local now = os.clock()
	local bonus = player:GetAttribute(Constants.AttributeSlideDurationBonus)
	if typeof(bonus) ~= "number" then
		bonus = 0
	end
	local duration = MatchSettings.SlideDuration + (bonus :: number)

	-- Start slide: crouch while sprinting (or held sprint long enough)
	if not self._sliding and actions.Crouch and self._sprintTime >= MatchSettings.SlideMinSprintTime then
		if now - self._lastSlide >= MatchSettings.SlideCooldown then
			self._sliding = true
			self._slideEndsAt = now + duration
			self._lastSlide = now
			hum.WalkSpeed = MatchSettings.SlideSpeed
			if self._baseHipHeight == nil then
				self._baseHipHeight = hum.HipHeight
			end
			hum.HipHeight = math.max(0, (self._baseHipHeight :: number) - 1)
			self._remotes.SlideState:FireServer(true)
			-- Impulse along move
			local dir = hum.MoveDirection
			if dir.Magnitude < 0.1 then
				dir = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
			end
			if dir.Magnitude > 0.1 then
				root.AssemblyLinearVelocity = dir.Unit * MatchSettings.SlideSpeed
					+ Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
			end
		end
	end

	if self._sliding then
		if now >= self._slideEndsAt or not actions.Crouch then
			self._sliding = false
			if self._baseHipHeight ~= nil then
				hum.HipHeight = self._baseHipHeight :: number
			end
			self._remotes.SlideState:FireServer(false)
			if actions.Crouch then
				hum.WalkSpeed = MatchSettings.CrouchSpeed
				self._crouched = true
			elseif actions.Sprint then
				hum.WalkSpeed = MatchSettings.SprintSpeed
			else
				hum.WalkSpeed = MatchSettings.WalkSpeed
			end
		else
			hum.WalkSpeed = MatchSettings.SlideSpeed
		end
		return
	end

	-- Normal speeds
	if actions.Crouch then
		hum.WalkSpeed = MatchSettings.CrouchSpeed
		self._crouched = true
	else
		self._crouched = false
		if actions.Sprint and moving then
			hum.WalkSpeed = MatchSettings.SprintSpeed
		else
			hum.WalkSpeed = MatchSettings.WalkSpeed
		end
	end

	if actions.Jump then
		-- Default jump; Humanoid handles Jump request via Bind
		hum.Jump = true
	end
end

return SlideController
