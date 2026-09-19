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

local remotes = Remotes.Ensure()

local abilityService = AbilityService.new(remotes)
abilityService:Init()

local weaponService = WeaponService.new(remotes, { Abilities = abilityService })
weaponService:Init()

local mapService = MapService.new()
mapService:Init()
mapService:BindRemotes(remotes)

local matchService = MatchService.new(remotes, weaponService, abilityService, nil)
-- BotService needs weapons/abilities; MatchService gets bots after
local botService = BotService.new(remotes, weaponService, abilityService)
botService:SetMapService(mapService)
botService:Init()

matchService:SetBotService(botService)
matchService:SetMapService(mapService)
matchService:Init()

print("[Latch] Server bootstrap complete (Phase 1 maps)")
