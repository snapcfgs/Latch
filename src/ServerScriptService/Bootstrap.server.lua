--!strict
--[[
	Latch server bootstrap — custom lightweight service wiring (no Knit).
]]

local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Services = script.Parent:WaitForChild("Services")
local WeaponService = require(Services.WeaponService)
local AbilityService = require(Services.AbilityService)
local MatchService = require(Services.MatchService)
local BotService = require(Services.BotService)
local MapService = require(Services.MapService)
local DataService = require(Services.DataService)
local ProgressionService = require(Services.ProgressionService)
local ShopService = require(Services.ShopService)
local PassService = require(Services.PassService)
local ContractService = require(Services.ContractService)
local MonetizationService = require(Services.MonetizationService)

local remotes = Remotes.Ensure()

local dataService = DataService.new(remotes)
dataService:Init()

local shopService = ShopService.new(dataService, remotes)
shopService:Init()

local passService = PassService.new(dataService, remotes)
passService:Init()

local contractService = ContractService.new(dataService, remotes)
contractService:Init()

local progressionService = ProgressionService.new(dataService, passService, contractService)

local monetizationService = MonetizationService.new(dataService, shopService, passService, remotes)
monetizationService:Init()

local abilityService = AbilityService.new(remotes)
abilityService:Init()

local weaponService = WeaponService.new(remotes, { Abilities = abilityService, Data = dataService })
weaponService:Init()

local mapService = MapService.new()
mapService:Init()
mapService:BindRemotes(remotes)

local matchService = MatchService.new(remotes, weaponService, abilityService, nil)
local botService = BotService.new(remotes, weaponService, abilityService)
botService:SetMapService(mapService)
botService:Init()

matchService:SetBotService(botService)
matchService:SetMapService(mapService)
matchService:SetProgressionService(progressionService)
matchService:SetDataService(dataService)
matchService:Init()

-- Ensure contracts assigned when players join
game:GetService("Players").PlayerAdded:Connect(function(player)
	task.defer(function()
		contractService:Ensure(player)
	end)
end)
for _, p in game:GetService("Players"):GetPlayers() do
	task.defer(function()
		contractService:Ensure(p)
	end)
end

print("[Latch] Server bootstrap complete (Phase 4 progression + economy)")
