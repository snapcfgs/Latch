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

local remotes = Remotes.Ensure()

local abilityService = AbilityService.new(remotes)
abilityService:Init()

local weaponService = WeaponService.new(remotes, { Abilities = abilityService })
weaponService:Init()

local matchService = MatchService.new(remotes, weaponService, abilityService, nil)
-- BotService needs weapons/abilities; MatchService gets bots after
local botService = BotService.new(remotes, weaponService, abilityService)
botService:Init()

matchService:SetBotService(botService)
matchService:Init()

print("[Latch] Server bootstrap complete (Phase 0 bots)")
