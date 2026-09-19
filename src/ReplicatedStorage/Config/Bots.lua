--!strict
--[[
	Bots — difficulty tiers for AI stand-ins. Balance numbers live here only.
]]

export type DifficultyId = "Recruit" | "Standard" | "Sweat"

export type DifficultyConfig = {
	Id: DifficultyId,
	DisplayName: string,
	-- Max half-angle (degrees) of aim cone around true target direction
	AccuracyConeDegrees: number,
	-- Seconds before reacting to a newly visible target
	ReactionDelay: number,
	-- WalkSpeed multiplier jitter (±) applied while hunting
	MoveJitter: number,
	-- Chance per decision tick to use operator active when off cooldown
	AbilityUseChance: number,
	-- Chance to peek/strafe instead of holding still while shooting
	PeekChance: number,
	-- How long (seconds) to stay in cover before peeking again
	CoverHoldSeconds: number,
	-- Fire rate scale vs weapon FireRate (1 = full)
	FireRateScale: number,
}

local Difficulties: { [DifficultyId]: DifficultyConfig } = {
	Recruit = {
		Id = "Recruit",
		DisplayName = "Recruit",
		AccuracyConeDegrees = 12,
		ReactionDelay = 0.55,
		MoveJitter = 0.35,
		AbilityUseChance = 0.12,
		PeekChance = 0.25,
		CoverHoldSeconds = 1.4,
		FireRateScale = 0.65,
	},
	Standard = {
		Id = "Standard",
		DisplayName = "Standard",
		AccuracyConeDegrees = 6,
		ReactionDelay = 0.28,
		MoveJitter = 0.2,
		AbilityUseChance = 0.28,
		PeekChance = 0.4,
		CoverHoldSeconds = 0.9,
		FireRateScale = 0.85,
	},
	Sweat = {
		Id = "Sweat",
		DisplayName = "Sweat",
		AccuracyConeDegrees = 2.5,
		ReactionDelay = 0.12,
		MoveJitter = 0.1,
		AbilityUseChance = 0.45,
		PeekChance = 0.55,
		CoverHoldSeconds = 0.5,
		FireRateScale = 1.0,
	},
}

-- Prefer softer bots first when filling; Sweat last
local FillOrder: { DifficultyId } = { "Recruit", "Standard", "Sweat" }

local DifficultyRank: { [DifficultyId]: number } = {
	Recruit = 1,
	Standard = 2,
	Sweat = 3,
}

return {
	Difficulties = Difficulties,
	FillOrder = FillOrder,
	DifficultyRank = DifficultyRank,
	DefaultDifficulty = "Standard" :: DifficultyId,
	LobbyWanderSpeed = 10,
	MatchWalkSpeedScale = 1.0,
	AiTickSeconds = 0.12,
	WaypointSpacing = 14,
}
