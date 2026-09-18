--!strict
--[[
	MatchSettings — round/match timing and mode rules.
	Balance numbers live here only.
]]

local MatchSettings = {
	RoundsToWin = 5,
	RoundFreezeSeconds = 3,
	BetweenRoundSeconds = 4,
	MatchStartCountdown = 3,
	RespawnInvulnSeconds = 1.5,

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
}

return MatchSettings
