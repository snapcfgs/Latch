--!strict
--[[
	Latch client bootstrap — wires input, slide, weapons, abilities, HUD.
	Seamless PC + mobile via InputController.
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local Controllers = script.Parent:WaitForChild("Controllers")
local InputController = require(Controllers.InputController)
local SlideController = require(Controllers.SlideController)
local WeaponController = require(Controllers.WeaponController)
local AbilityController = require(Controllers.AbilityController)
local HUDController = require(Controllers.HUDController)
local OperatorSelectController = require(Controllers.OperatorSelectController)

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local remotes = Remotes.Get()

local input = InputController.new()
input:Init()

local slide = SlideController.new(input, remotes)
slide:Init()

local weapons = WeaponController.new(input, remotes)
weapons:Init()

local abilities = AbilityController.new(input, remotes)
abilities:Init()

local hud = HUDController.new(remotes, weapons, abilities)
hud:Init()

local opSelect = OperatorSelectController.new(remotes)
opSelect:Init()

local player = Players.LocalPlayer
player.CameraMode = Enum.CameraMode.Classic

-- Lobby: free cursor for UI clicks. Match: first-person mouse look.
local inCombat = false

local function setCombatCamera(combat: boolean)
	inCombat = combat
	if combat then
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 0.5
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	else
		player.CameraMinZoomDistance = 8
		player.CameraMaxZoomDistance = 24
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
end

setCombatCamera(false)

player.CharacterAdded:Connect(function()
	task.wait(0.1)
	setCombatCamera(inCombat)
end)

remotes.MatchSnapshot.OnClientEvent:Connect(function(snap)
	if typeof(snap) ~= "table" then
		return
	end
	local phase = snap.Phase
	if phase == "Lobby" or phase == "MatchEnd" then
		setCombatCamera(false)
	elseif phase == "Countdown" or phase == "Round" or phase == "RoundEnd" then
		setCombatCamera(true)
	else
		setCombatCamera(false)
	end
end)

-- Esc frees the mouse (handy in Studio playtests)
UserInputService.InputBegan:Connect(function(inputObj, _processed)
	if inputObj.KeyCode == Enum.KeyCode.Escape then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
end)

print("[Latch] Client bootstrap complete — touch=", input:IsTouch())
