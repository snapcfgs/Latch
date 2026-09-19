--!strict
--[[
	Latch client bootstrap — wires input, slide, weapons, abilities, HUD.
	Seamless PC + mobile via InputController.
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local Controllers = script.Parent:WaitForChild("Controllers")
local InputController = require(Controllers.InputController)
local SlideController = require(Controllers.SlideController)
local WeaponController = require(Controllers.WeaponController)
local AbilityController = require(Controllers.AbilityController)
local HUDController = require(Controllers.HUDController)
local OperatorSelectController = require(Controllers.OperatorSelectController)
local MapVoteController = require(Controllers.MapVoteController)
local LoadoutController = require(Controllers.LoadoutController)
local LobbyController = require(Controllers.LobbyController)
local MatchRecapController = require(Controllers.MatchRecapController)
local ShopController = require(Controllers.ShopController)
local PassController = require(Controllers.PassController)
local ContractController = require(Controllers.ContractController)
local ViewmodelController = require(Controllers.ViewmodelController)

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

local mapVote = MapVoteController.new(remotes)
mapVote:Init()

local loadout = LoadoutController.new(remotes)
loadout:Init()

local lobby = LobbyController.new(remotes)
lobby:Init()

local recap = MatchRecapController.new(remotes)
recap:Init()

local shop = ShopController.new(remotes)
shop:Init()

local pass = PassController.new(remotes)
pass:Init()

local contracts = ContractController.new(remotes)
contracts:Init()

local viewmodel = ViewmodelController.new(remotes)
viewmodel:Init()

-- Expose openers for LobbyController buttons
_G.LatchOpenShop = function()
	shop:Open()
end
_G.LatchOpenPass = function()
	pass:Open()
end
_G.LatchOpenContracts = function()
	contracts:Open()
end

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
		-- Third-person-ish zoom so Studio/PC can click lobby buttons
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
	if phase == "Lobby" or phase == "MatchEnd" or phase == "MatchRecap" or phase == "MapVote" or phase == "OperatorLock" then
		setCombatCamera(false)
	elseif phase == "Countdown" or phase == "Round" or phase == "RoundEnd" then
		setCombatCamera(true)
	else
		setCombatCamera(false)
	end
end)

-- Roblox can re-lock the mouse every frame in first person; keep forcing unlock in lobby.
RunService.RenderStepped:Connect(function()
	if not inCombat then
		if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		if UserInputService.MouseIconEnabled ~= true then
			UserInputService.MouseIconEnabled = true
		end
	end
end)

-- Esc frees the mouse (handy in Studio playtests even mid-match)
UserInputService.InputBegan:Connect(function(inputObj, _processed)
	if inputObj.KeyCode == Enum.KeyCode.Escape then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
end)

print("[Latch] Client bootstrap complete (Phase 5) — touch=", input:IsTouch())
