--!strict
--[[
	Contracts — daily contract definitions.

	Refresh:
	  • Live (DataStore): 24h from first assign / day key (UTC date).
	  • Studio / in-memory fallback: session-length — refresh when profile
	    Contracts.RefreshAt elapsed (default 30 minutes) OR on new Studio session.
]]

export type ContractStat = "Kills" | "Wins" | "Damage" | "Matches" | "Headshots" | "AbilityUses"

export type ContractDef = {
	Id: string,
	DisplayName: string,
	Description: string,
	Stat: ContractStat,
	Target: number,
	RewardTokens: number,
	RewardXp: number,
	RewardScrap: number?,
}

local Pool: { ContractDef } = {
	{
		Id = "daily_kills_5",
		DisplayName = "Warm Up",
		Description = "Get 5 eliminations",
		Stat = "Kills",
		Target = 5,
		RewardTokens = 30,
		RewardXp = 40,
	},
	{
		Id = "daily_kills_10",
		DisplayName = "Hot Streak",
		Description = "Get 10 eliminations",
		Stat = "Kills",
		Target = 10,
		RewardTokens = 50,
		RewardXp = 60,
	},
	{
		Id = "daily_wins_1",
		DisplayName = "Take the W",
		Description = "Win 1 match",
		Stat = "Wins",
		Target = 1,
		RewardTokens = 40,
		RewardXp = 50,
	},
	{
		Id = "daily_wins_2",
		DisplayName = "Back to Back",
		Description = "Win 2 matches",
		Stat = "Wins",
		Target = 2,
		RewardTokens = 70,
		RewardXp = 80,
	},
	{
		Id = "daily_damage_500",
		DisplayName = "Chip Damage",
		Description = "Deal 500 damage",
		Stat = "Damage",
		Target = 500,
		RewardTokens = 35,
		RewardXp = 45,
	},
	{
		Id = "daily_damage_1000",
		DisplayName = "Heavy Hitter",
		Description = "Deal 1000 damage",
		Stat = "Damage",
		Target = 1000,
		RewardTokens = 55,
		RewardXp = 70,
	},
	{
		Id = "daily_matches_2",
		DisplayName = "Clock In",
		Description = "Play 2 matches",
		Stat = "Matches",
		Target = 2,
		RewardTokens = 25,
		RewardXp = 35,
	},
	{
		Id = "daily_matches_3",
		DisplayName = "Full Shift",
		Description = "Play 3 matches",
		Stat = "Matches",
		Target = 3,
		RewardTokens = 45,
		RewardXp = 55,
	},
	{
		Id = "daily_ability_3",
		DisplayName = "Operator Work",
		Description = "Use abilities 3 times",
		Stat = "AbilityUses",
		Target = 3,
		RewardTokens = 30,
		RewardXp = 40,
		RewardScrap = 10,
	},
}

local DAILY_COUNT = 3
local STUDIO_REFRESH_SECONDS = 30 * 60 -- 30 min session refresh in Studio

local function getById(id: string): ContractDef?
	for _, c in Pool do
		if c.Id == id then
			return c
		end
	end
	return nil
end

--- Deterministic-ish pick of N contracts from pool (seeded by dayKey hash).
local function pickDaily(dayKey: string, count: number?): { ContractDef }
	local n = count or DAILY_COUNT
	local hash = 0
	for i = 1, #dayKey do
		hash = (hash * 31 + string.byte(dayKey, i)) % 2147483647
	end
	local indices = {}
	for i = 1, #Pool do
		table.insert(indices, i)
	end
	-- Fisher-Yates with LCG from hash
	local state = hash
	local function rand(max: number): number
		state = (state * 1103515245 + 12345) % 2147483648
		return (state % max) + 1
	end
	for i = #indices, 2, -1 do
		local j = rand(i)
		indices[i], indices[j] = indices[j], indices[i]
	end
	local out: { ContractDef } = {}
	for i = 1, math.min(n, #indices) do
		table.insert(out, Pool[indices[i]])
	end
	return out
end

local function utcDayKey(now: number?): string
	local t = now or os.time()
	-- YYYY-MM-DD UTC
	return os.date("!%Y-%m-%d", t) :: string
end

return {
	Pool = Pool,
	DailyCount = DAILY_COUNT,
	StudioRefreshSeconds = STUDIO_REFRESH_SECONDS,
	GetById = getById,
	PickDaily = pickDaily,
	UtcDayKey = utcDayKey,
}
