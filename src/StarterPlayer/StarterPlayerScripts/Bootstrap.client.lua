--!strict
--[[
	Latch client bootstrap — wires input, slide, weapons, abilities, HUD.
	Seamless PC + mobile via InputController.
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local Controllers = script.Parent:WaitForChild("Controllers")
local InputController = require(Controllers.InputController)
local SlideController = require(Controllers.SlideController)
local WeaponController = require(Controllers.WeaponController)
local AbilityController = require(Controllers.AbilityController)
local HUDController = require(Controllers.HUDController)
local OperatorSelectController = require(Controllers.OperatorSelectController)

-- Prefer shift-lock free look; hide default backpack
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

-- Default camera
local player = Players.LocalPlayer
player.CameraMode = Enum.CameraMode.Classic
local function lockFirstPerson()
	player.CameraMaxZoomDistance = 0.5
	player.CameraMinZoomDistance = 0.5
end
lockFirstPerson()
player.CharacterAdded:Connect(function()
	task.wait(0.1)
	lockFirstPerson()
end)

print("[Latch] Client bootstrap complete — touch=", input:IsTouch())
