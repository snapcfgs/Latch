--!strict
--[[
	Latch client bootstrap — wires input, slide, weapons, abilities, HUD, hub UI.
	Seamless PC + mobile via InputController. Phase 6: audio / emotes / career / scoreboard.
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
local AudioController = require(Controllers.AudioController)
local EmoteController = require(Controllers.EmoteController)
local CareerController = require(Controllers.CareerController)

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local remotes = Remotes.Get()

local audio = AudioController.new(remotes)
audio:Init()

local input = InputController.new()
input:Init()

local slide = SlideController.new(input, remotes)
slide:Init()

local weapons = WeaponController.new(input, remotes)
weapons:Init()

local abilities = AbilityController.new(input, remotes)
abilities:Init()

local hud = HUDController.new(remotes, weapons, abilities, audio)
hud:Init()

input:SetScoreboardCallback(function()
	hud:ToggleScoreboard()
end)

-- Soft audio hooks for fire / reload without touching combat math
input:OnAction(function(name, down)
	if not down then
		return
	end
	if name == "Fire" then
		audio:PlayFire()
	elseif name == "Reload" then
		audio:Play("Reload")
	elseif name == "Ability" then
		-- AbilityFx also plays; this is immediate UI feedback
		audio:Play("Ability")
	end
end)

local opSelect = OperatorSelectController.new(remotes, audio)
opSelect:Init()

local mapVote = MapVoteController.new(remotes)
mapVote:Init()

local loadout = LoadoutController.new(remotes)
loadout:Init()

local lobby = LobbyController.new(remotes, audio)
lobby:Init()

local recap = MatchRecapController.new(remotes, audio)
recap:Init()

local shop = ShopController.new(remotes)
shop:Init()

local pass = PassController.new(remotes)
pass:Init()

local contracts = ContractController.new(remotes)
contracts:Init()

local career = CareerController.new(remotes)
career:Init()

local emotes = EmoteController.new(remotes, audio)
emotes:Init()

local viewmodel = ViewmodelController.new(remotes)
viewmodel:Init()

-- Expose openers for LobbyController hub tabs
_G.LatchOpenShop = function()
	shop:Open()
end
_G.LatchOpenPass = function()
	pass:Open()
end
_G.LatchOpenContracts = function()
	contracts:Open()
end
_G.LatchOpenCareer = function()
	career:Open()
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

UserInputService.InputBegan:Connect(function(inputObj, _processed)
	if inputObj.KeyCode == Enum.KeyCode.Escape then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
end)

print("[Latch] Client bootstrap complete (Phase 6 HUD/juice) — touch=", input:IsTouch())
