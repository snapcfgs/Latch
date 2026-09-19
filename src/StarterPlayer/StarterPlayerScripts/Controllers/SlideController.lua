--!strict
--[[
	SlideController — crouch while sprinting → slide.
	Client feel + notify server; Skid passive extends duration via attribute.
	Phase 5: slide-cancel into jump; bunny-hop horizontal speed cap.
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
		_lastJumpAt = 0,
		_wasJumping = false,
		_airborne = false,
		_jumpChain = 0,
		_landedAt = 0,
	}, SlideController)
	return self
end

function SlideController:Init()
	RunService.RenderStepped:Connect(function(dt)
		self:_update(dt)
	end)
	player.CharacterAdded:Connect(function(char)
		task.defer(function()
			self:_hookHumanoid(char)
		end)
	end)
	if player.Character then
		self:_hookHumanoid(player.Character)
	end
end

function SlideController:_hookHumanoid(char: Model)
	local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?
	if not hum then
		return
	end
	hum.StateChanged:Connect(function(_old, newState)
		if newState == Enum.HumanoidStateType.Landed then
			self._airborne = false
			self._landedAt = os.clock()
			-- Reset chain if grounded long enough next frame; keep chain for bhop window
		elseif newState == Enum.HumanoidStateType.Freefall or newState == Enum.HumanoidStateType.Jumping then
			self._airborne = true
		end
	end)
end

function SlideController:IsSliding(): boolean
	return self._sliding
end

function SlideController:GetLandedAt(): number
	return self._landedAt
end

function SlideController:_humanoid(): (Humanoid?, BasePart?)
	local char = player.Character
	if not char then
		return nil, nil
	end
	return char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function SlideController:_endSlide(hum: Humanoid, actions: any)
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
end

function SlideController:_capBunnyHop(root: BasePart)
	local cap = MatchSettings.BunnyHopSpeedCap or 26
	local vel = root.AssemblyLinearVelocity
	local horiz = Vector3.new(vel.X, 0, vel.Z)
	if horiz.Magnitude > cap then
		local flat = horiz.Unit * cap
		root.AssemblyLinearVelocity = Vector3.new(flat.X, vel.Y, flat.Z)
	end
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

	-- Slide cancel into jump (Phase 5)
	local jumpPressed = actions.Jump == true
	if self._sliding and jumpPressed and not self._wasJumping then
		self:_endSlide(hum, actions)
		-- Keep slide momentum into the jump
		local vel = root.AssemblyLinearVelocity
		local horiz = Vector3.new(vel.X, 0, vel.Z)
		if horiz.Magnitude < MatchSettings.SlideSpeed * 0.6 then
			local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
			if look.Magnitude > 0.1 then
				horiz = look.Unit * MatchSettings.SlideSpeed * 0.85
			end
		end
		root.AssemblyLinearVelocity = Vector3.new(horiz.X, math.max(vel.Y, 0), horiz.Z)
		hum.Jump = true
		self._lastJumpAt = now
		self._jumpChain += 1
		if self._jumpChain > 1 then
			self:_capBunnyHop(root)
		end
		self._wasJumping = true
		return
	end

	if self._sliding then
		if now >= self._slideEndsAt or not actions.Crouch then
			self:_endSlide(hum, actions)
		else
			hum.WalkSpeed = MatchSettings.SlideSpeed
		end
		self._wasJumping = jumpPressed
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

	-- Jump + bunny-hop prevention
	if jumpPressed and not self._wasJumping then
		local chainWindow = MatchSettings.BunnyHopChainWindow or 0.35
		local recentlyLanded = (now - self._landedAt) <= chainWindow
		if recentlyLanded or self._airborne then
			self._jumpChain += 1
		else
			self._jumpChain = 1
		end
		hum.Jump = true
		self._lastJumpAt = now
		if self._jumpChain > 1 then
			-- Cap after first chained hop
			task.defer(function()
				if root.Parent then
					self:_capBunnyHop(root)
				end
			end)
		end
	elseif not jumpPressed then
		-- Reset chain when grounded and not jumping for a bit
		if not self._airborne and (now - self._landedAt) > (MatchSettings.BunnyHopChainWindow or 0.35) then
			self._jumpChain = 0
		end
	end
	self._wasJumping = jumpPressed
end

return SlideController
