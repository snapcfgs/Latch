--!strict
--[[
	ProgressionService — match-end Token / XP / Pass XP / Stats / contract progress.
]]


local Monetization = require(game.ReplicatedStorage.Config.Monetization)
local ModesConfig = require(game.ReplicatedStorage.Config.Modes)

local ProgressionService = {}
ProgressionService.__index = ProgressionService

-- Base grants
local WIN_TOKENS = 25
local LOSS_TOKENS = 10
local WIN_XP = 50
local LOSS_XP = 25
local KILL_TOKEN_BONUS = 2 -- per kill, capped
local KILL_TOKEN_CAP = 20
local KILL_XP = 5
local DAMAGE_XP_PER = 50 -- 1 XP per 50 damage

function ProgressionService.new(dataService: any, passService: any?, contractService: any?)
	local self = setmetatable({
		_data = dataService,
		_pass = passService,
		_contracts = contractService,
	}, ProgressionService)
	return self
end

function ProgressionService:SetPassService(passService: any)
	self._pass = passService
end

function ProgressionService:SetContractService(contractService: any)
	self._contracts = contractService
end

export type MatchParticipantGrant = {
	UserId: number,
	Player: Player?,
	Won: boolean,
	Kills: number,
	Deaths: number,
	Damage: number,
	RoundsWon: number?, -- round-mode rounds credited to this player (optional)
	MatchDurationSec: number?,
	AbilityUses: number?,
	Headshots: number?,
}

export type GrantResult = {
	Tokens: number,
	XP: number,
	PassXp: number,
	Level: number,
	TotalTokens: number,
	TotalXp: number,
}


--- Compute Pass XP for one player from match context.
--- Formula: +1 per round win (round modes) OR +1 per kill (continuous),
--- plus +1 per 45s match time (cap +20). 20 Pass XP = 1 tier.
function ProgressionService.ComputePassXp(info: MatchParticipantGrant, modeId: string): number
	local passXp = 0
	local cfg = ModesConfig.Get(modeId)
	local continuous = cfg and (cfg.WinType == "Eliminations" or cfg.WinType == "TeamScore" or cfg.WinType == "GunCycle")
	if continuous then
		passXp += math.max(0, info.Kills)
	else
		passXp += math.max(0, info.RoundsWon or (if info.Won then 1 else 0))
	end
	local dur = info.MatchDurationSec or 0
	local timeXp = math.min(20, math.floor(dur / 45))
	passXp += timeXp
	return passXp
end

function ProgressionService:GrantForMatch(
	modeId: string,
	participants: { MatchParticipantGrant }
): { [number]: GrantResult }
	local results: { [number]: GrantResult } = {}
	for _, info in participants do
		local player = info.Player
		if not player or not player.Parent then
			continue
		end
		local tokens = if info.Won then WIN_TOKENS else LOSS_TOKENS
		local xp = if info.Won then WIN_XP else LOSS_XP
		local killBonus = math.min(KILL_TOKEN_CAP, info.Kills * KILL_TOKEN_BONUS)
		tokens += killBonus
		xp += info.Kills * KILL_XP
		xp += math.floor(info.Damage / DAMAGE_XP_PER)

		local passXp = ProgressionService.ComputePassXp(info, modeId)

		self._data:Mutate(player, function(p)
			p.Tokens += tokens
			p.Xp += xp
			local need = Monetization.LevelXpRequired
			while p.Xp >= need do
				p.Xp -= need
				p.Level += 1
			end
			p.Stats.Matches += 1
			if info.Won then
				p.Stats.Wins += 1
				p.Stats.WinStreak = (p.Stats.WinStreak or 0) + 1
			else
				p.Stats.Losses += 1
				p.Stats.WinStreak = 0
			end
			p.Stats.Kills += info.Kills
			p.Stats.Deaths += info.Deaths
			p.Stats.Damage += info.Damage
			if info.AbilityUses then
				p.Stats.AbilityUses += info.AbilityUses
			end
			if info.Headshots then
				p.Stats.Headshots += info.Headshots
			end
		end)

		if self._pass and passXp > 0 then
			self._pass:AddPassXp(player, passXp)
		end

		if self._contracts then
			self._contracts:OnMatchEnd(player, {
				Won = info.Won,
				Kills = info.Kills,
				Damage = info.Damage,
				AbilityUses = info.AbilityUses or 0,
			})
		end

		local profile = self._data:Get(player)
		results[info.UserId] = {
			Tokens = tokens,
			XP = xp,
			PassXp = passXp,
			Level = if profile then profile.Level else 1,
			TotalTokens = if profile then profile.Tokens else tokens,
			TotalXp = if profile then profile.Xp else xp,
		}
	end
	return results
end

return ProgressionService
