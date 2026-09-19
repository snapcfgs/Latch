--!strict
--[[
	BattlePass — Season 01 "Live Wire", 40 tiers, Free + Prime tracks.

	Pass XP formula (see README):
	  • 20 Pass XP = 1 tier
	  • Match grants: +1 Pass XP per round won (round modes),
	    or +1 Pass XP per elimination (FFA / TDM / Gun Cycle),
	    plus +1 Pass XP per full 45s of match time (cap 20/match).
	  Roughly: 20 round wins ≈ 1 tier, or ~15 minutes of continuous play ≈ 1 tier.
]]

export type RewardKind = "Tokens" | "Scrap" | "SkinTickets" | "Skin" | "Wrap" | "Charm" | "Emote" | "Weapon" | "Finisher" | "PrimeTrial"

export type PassReward = {
	Kind: RewardKind,
	Id: string?, -- cosmetic / weapon id when relevant
	Amount: number?,
}

export type PassTier = {
	Tier: number,
	XpRequired: number, -- cumulative Pass XP to unlock this tier
	Free: PassReward?,
	Prime: PassReward?,
}

local SEASON_ID = "S01"
local SEASON_NAME = "Live Wire"
local TIER_COUNT = 40
local XP_PER_TIER = 20

local function tokens(n: number): PassReward
	return { Kind = "Tokens", Amount = n }
end
local function scrap(n: number): PassReward
	return { Kind = "Scrap", Amount = n }
end
local function tickets(n: number): PassReward
	return { Kind = "SkinTickets", Amount = n }
end
local function skin(id: string): PassReward
	return { Kind = "Skin", Id = id, Amount = 1 }
end
local function wrap(id: string): PassReward
	return { Kind = "Wrap", Id = id, Amount = 1 }
end
local function charm(id: string): PassReward
	return { Kind = "Charm", Id = id, Amount = 1 }
end
local function emote(id: string): PassReward
	return { Kind = "Emote", Id = id, Amount = 1 }
end
local function weapon(id: string): PassReward
	return { Kind = "Weapon", Id = id, Amount = 1 }
end
local function finisher(id: string): PassReward
	return { Kind = "Finisher", Id = id, Amount = 1 }
end

-- Build 40 tiers with a mix of free + prime rewards
local Tiers: { PassTier } = {}
for i = 1, TIER_COUNT do
	local cumXp = i * XP_PER_TIER
	local free: PassReward? = nil
	local prime: PassReward? = nil

	-- Free track: every tier gets something small; bigger every 5
	if i % 5 == 0 then
		free = tokens(40 + i)
	elseif i % 3 == 0 then
		free = scrap(15 + i)
	else
		free = tokens(10 + math.floor(i / 2))
	end

	-- Prime track: richer
	if i == 1 then
		prime = wrap("Wrap_Cobalt")
	elseif i == 5 then
		prime = charm("Charm_Coil")
	elseif i == 10 then
		prime = skin("AssaultRifle_Volt")
	elseif i == 15 then
		prime = emote("Emote_Flex")
	elseif i == 20 then
		prime = weapon("CoilSMG")
	elseif i == 25 then
		prime = skin("Pistol_Chrome")
	elseif i == 30 then
		prime = wrap("Wrap_Ion")
	elseif i == 35 then
		prime = finisher("Finisher_Static")
	elseif i == 40 then
		prime = emote("Emote_LiveWire")
	elseif i % 4 == 0 then
		prime = tickets(1)
	elseif i % 2 == 0 then
		prime = tokens(50 + i * 2)
	else
		prime = scrap(25 + i)
	end

	Tiers[i] = {
		Tier = i,
		XpRequired = cumXp,
		Free = free,
		Prime = prime,
	}
end

local function tierFromXp(passXp: number): number
	local t = math.floor(passXp / XP_PER_TIER)
	if t < 0 then
		return 0
	end
	if t > TIER_COUNT then
		return TIER_COUNT
	end
	return t
end

local function getTier(n: number): PassTier?
	return Tiers[n]
end

return {
	SeasonId = SEASON_ID,
	SeasonName = SEASON_NAME,
	TierCount = TIER_COUNT,
	XpPerTier = XP_PER_TIER,
	Tiers = Tiers,
	TierFromXp = tierFromXp,
	GetTier = getTier,
}
