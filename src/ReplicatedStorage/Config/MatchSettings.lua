--!strict
--[[
	MatchSettings — round/match timing and shared rules.
	Per-mode win/fill/respawn live in Config/Modes.lua (Phase 3).
]]

local MatchSettings = {
	-- Legacy defaults (round modes still read Modes.WinTarget; these are fallbacks)
	RoundsToWin = 5,
	RoundFreezeSeconds = 3,
	BetweenRoundSeconds = 4,
	MatchStartCountdown = 3,
	RespawnInvulnSeconds = 1.5,

	-- After map vote: operator + loadout lock window before countdown
	OperatorLockSeconds = 8,

	-- Match end recap display before returning to lobby
	MatchRecapSeconds = 8,

	-- Legacy fill timers (Modes.FillSeconds preferred)
	FillTimer1v1Seconds = 3,
	FillTimer2v2Seconds = 4,
	FillTimerDefaultSeconds = 5,

	-- Map vote window after queue fills (Phase 1)
	MapVoteSeconds = 8,

	-- Lobby ambient bots (not in match)
	LobbyBotMin = 6,
	LobbyBotMax = 12,

	-- Kept for older callers; prefer Config/Modes.lua
	Modes = {
		Duel1v1 = {
			Id = "1v1",
			DisplayName = "1v1",
			TeamSize = 1,
			MaxPlayers = 2,
		},
		Duel2v2 = {
			Id = "2v2",
			DisplayName = "2v2",
			TeamSize = 2,
			MaxPlayers = 4,
		},
	},

	DefaultModeId = "1v1",

	PlayerHealth = 100,
	WalkSpeed = 16,
	SprintSpeed = 24,
	CrouchSpeed = 8,
	JumpPower = 50,

	-- Slide (base; Skid passive extends duration)
	SlideSpeed = 32,
	SlideDuration = 0.55,
	SlideCooldown = 0.8,
	SlideMinSprintTime = 0.15,

	-- Phase 5 movement polish
	-- Cap horizontal speed retained across chained bunny-hops
	BunnyHopSpeedCap = 26,
	-- Window after landing where consecutive jump speed is capped
	BunnyHopChainWindow = 0.35,
	-- Landing accuracy penalty duration (seconds)
	LandingSpreadSeconds = 0.2,
	-- Extra degrees of spread while landing penalty is active
	LandingSpreadDegrees = 3.5,
	-- Frag explosion knock impulse (studs/s); Anchor passive scales self knock
	FragKnockSpeed = 48,
	FragKnockMax = 72,
}

return MatchSettings
