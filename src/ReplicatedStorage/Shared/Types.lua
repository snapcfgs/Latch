--!strict
--[[ Shared types for Latch MVP. ]]

export type TeamId = "A" | "B"

export type MatchPhase = "Lobby" | "Countdown" | "Round" | "RoundEnd" | "MatchEnd"

export type WeaponSlot = "Primary" | "Secondary" | "Melee" | "Utility"

export type OperatorId = "Skid" | "Anchor" | "Splice" | "Jolt"

export type WeaponId = "AssaultRifle" | "Pistol" | "Knife" | "FragGrenade"

export type PlayerMatchState = {
	UserId: number,
	Team: TeamId,
	OperatorId: OperatorId?,
	Alive: boolean,
	Score: number,
}

export type MatchSnapshot = {
	Phase: MatchPhase,
	ModeId: string,
	RoundNumber: number,
	ScoreA: number,
	ScoreB: number,
	RoundsToWin: number,
	PhaseEndsAt: number?, -- workspace:GetServerTimeNow()
}

export type FireRequest = {
	WeaponId: WeaponId,
	Origin: Vector3,
	Direction: Vector3,
	Timestamp: number,
}

export type AbilityRequest = {
	OperatorId: OperatorId,
	LookDirection: Vector3,
	Origin: Vector3,
	TargetUserId: number?,
}

return {}
