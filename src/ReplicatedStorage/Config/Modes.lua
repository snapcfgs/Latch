--!strict
--[[
	Modes — Phase 3 match mode registry.
	Balance / win rules live here. MatchService reads these; do not fork per mode.
]]

export type WinType = "Rounds" | "Eliminations" | "TeamScore" | "GunCycle"
export type RespawnRule = "BetweenRounds" | "Timed"

export type ModeConfig = {
	Id: string,
	DisplayName: string,
	Description: string,
	-- Team size per side (ignored when IsFFA)
	TeamSize: number,
	MaxPlayers: number,
	IsFFA: boolean,
	WinType: WinType,
	-- RoundsToWin / ElimTarget / TeamScoreTarget / GunCycle list length
	WinTarget: number,
	RespawnRule: RespawnRule,
	-- FFA / TDM timed respawn (seconds). Chosen rule for FFA: 3s respawn.
	RespawnSeconds: number?,
	FillSeconds: number,
	-- When bot-filling, pad up to this many (defaults to MaxPlayers)
	FillTarget: number?,
	-- Optional bot difficulty override (e.g. Beginner → Recruit)
	BotDifficulty: string?,
	-- Multiplier applied to damage the fighter TAKES (Beginner: 0.85 = -15%)
	DamageTakenMult: number?,
	-- Show on lobby menu / pads
	ShowInMenu: boolean,
	ShowOnPad: boolean,
	PadColor: Color3?,
	-- Casual Mix resolves to one of these Ids at match start
	IsCasualMix: boolean?,
	CasualPool: { string }?,
}

local Modes: { [string]: ModeConfig } = {
	["1v1"] = {
		Id = "1v1",
		DisplayName = "1v1",
		Description = "Duel — first to 5 rounds",
		TeamSize = 1,
		MaxPlayers = 2,
		IsFFA = false,
		WinType = "Rounds",
		WinTarget = 5,
		RespawnRule = "BetweenRounds",
		FillSeconds = 3,
		ShowInMenu = true,
		ShowOnPad = true,
		PadColor = Color3.fromRGB(60, 120, 220),
	},
	["2v2"] = {
		Id = "2v2",
		DisplayName = "2v2",
		Description = "Team duel — first to 5 rounds",
		TeamSize = 2,
		MaxPlayers = 4,
		IsFFA = false,
		WinType = "Rounds",
		WinTarget = 5,
		RespawnRule = "BetweenRounds",
		FillSeconds = 4,
		ShowInMenu = true,
		ShowOnPad = true,
		PadColor = Color3.fromRGB(50, 170, 90),
	},
	["3v3"] = {
		Id = "3v3",
		DisplayName = "3v3",
		Description = "Squad duel — first to 5 rounds",
		TeamSize = 3,
		MaxPlayers = 6,
		IsFFA = false,
		WinType = "Rounds",
		WinTarget = 5,
		RespawnRule = "BetweenRounds",
		FillSeconds = 5,
		ShowInMenu = true,
		ShowOnPad = true,
		PadColor = Color3.fromRGB(40, 190, 190),
	},
	["4v4"] = {
		Id = "4v4",
		DisplayName = "4v4",
		Description = "Full squad — first to 5 rounds",
		TeamSize = 4,
		MaxPlayers = 8,
		IsFFA = false,
		WinType = "Rounds",
		WinTarget = 5,
		RespawnRule = "BetweenRounds",
		FillSeconds = 6,
		ShowInMenu = true,
		ShowOnPad = true,
		PadColor = Color3.fromRGB(140, 80, 210),
	},
	FFA = {
		Id = "FFA",
		DisplayName = "Free For All",
		Description = "First to 7 eliminations. Respawn after 3 seconds.",
		TeamSize = 1,
		MaxPlayers = 8,
		IsFFA = true,
		WinType = "Eliminations",
		WinTarget = 7,
		RespawnRule = "Timed",
		RespawnSeconds = 3, -- stick to 3s for FFA
		FillSeconds = 5,
		FillTarget = 4,
		ShowInMenu = true,
		ShowOnPad = true,
		PadColor = Color3.fromRGB(230, 140, 40),
	},
	TDM = {
		Id = "TDM",
		DisplayName = "Team Deathmatch",
		Description = "Team score to 30. Mid-match respawn (3s).",
		TeamSize = 4,
		MaxPlayers = 8,
		IsFFA = false,
		WinType = "TeamScore",
		WinTarget = 30,
		RespawnRule = "Timed",
		RespawnSeconds = 3,
		FillSeconds = 6,
		FillTarget = 6,
		ShowInMenu = true,
		ShowOnPad = false,
		PadColor = Color3.fromRGB(200, 60, 70),
	},
	GunCycle = {
		Id = "GunCycle",
		DisplayName = "Gun Cycle",
		Description = "Elimination advances weapon along a fixed list. First to finish the list wins. Respawn 3s.",
		TeamSize = 1,
		MaxPlayers = 8,
		IsFFA = true,
		WinType = "GunCycle",
		WinTarget = 0, -- derived from GunCycleOrder length
		RespawnRule = "Timed",
		RespawnSeconds = 3,
		FillSeconds = 5,
		FillTarget = 4,
		ShowInMenu = true,
		ShowOnPad = false,
		PadColor = Color3.fromRGB(220, 200, 60),
	},
	Beginner2v2 = {
		Id = "Beginner2v2",
		DisplayName = "Beginner 2v2",
		Description = "2v2 vs Recruit bots. Damage taken −15%.",
		TeamSize = 2,
		MaxPlayers = 4,
		IsFFA = false,
		WinType = "Rounds",
		WinTarget = 5,
		RespawnRule = "BetweenRounds",
		FillSeconds = 4,
		BotDifficulty = "Recruit",
		DamageTakenMult = 0.85,
		ShowInMenu = true,
		ShowOnPad = false,
		PadColor = Color3.fromRGB(100, 200, 140),
	},
	CasualMix = {
		Id = "CasualMix",
		DisplayName = "Casual Mix",
		Description = "Queue fills, then a casual mode is picked at random (2v2 / FFA / TDM / Gun Cycle).",
		TeamSize = 2,
		MaxPlayers = 6,
		IsFFA = false,
		WinType = "Rounds",
		WinTarget = 5,
		RespawnRule = "BetweenRounds",
		FillSeconds = 5,
		FillTarget = 4,
		ShowInMenu = true,
		ShowOnPad = true,
		PadColor = Color3.fromRGB(240, 210, 80),
		IsCasualMix = true,
		CasualPool = { "2v2", "FFA", "TDM", "GunCycle" },
	},
}

-- Fixed Gun Cycle progression (elimination advances one step; kill with last weapon wins)
local GunCycleOrder: { string } = {
	"AssaultRifle",
	"CoilSMG",
	"Longscope",
	"BreachShotgun",
	"CycleBurst",
	"MachinePistol",
	"StubRevolver",
	"Pistol",
	"Crowbar",
	"Bat",
	"Knife",
}

local MenuOrder: { string } = {
	"1v1",
	"2v2",
	"3v3",
	"4v4",
	"FFA",
	"TDM",
	"GunCycle",
	"Beginner2v2",
	"CasualMix",
}

local PadOrder: { string } = {
	"1v1",
	"2v2",
	"3v3",
	"4v4",
	"FFA",
	"CasualMix",
}

local function get(id: string): ModeConfig?
	return Modes[id]
end

local function resolveCasualMix(id: string): string
	local cfg = Modes[id]
	if not cfg or not cfg.IsCasualMix or not cfg.CasualPool or #cfg.CasualPool == 0 then
		return id
	end
	local pool = cfg.CasualPool
	return pool[math.random(1, #pool)]
end

return {
	Modes = Modes,
	GunCycleOrder = GunCycleOrder,
	MenuOrder = MenuOrder,
	PadOrder = PadOrder,
	Get = get,
	ResolveCasualMix = resolveCasualMix,
	DefaultModeId = "1v1",
}
