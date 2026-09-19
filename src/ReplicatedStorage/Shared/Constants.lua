--!strict

local Constants = {
	RemotesFolderName = "LatchRemotes",
	CollisionGroupDefault = "Default",
	CollisionGroupPlayers = "LatchPlayers",
	CollisionGroupSpliceFriendly = "LatchSpliceFriendly",
	CollisionGroupSpliceEnemy = "LatchSpliceEnemy",
	CollisionGroupCover = "LatchCover",

	-- VFX budget (see Util/VFX.lua)
	MaxConcurrentAbilityVFX = 12,
	MaxTrailParts = 8,
	AbilityVFXLifetimeCap = 6,

	AttributeOperator = "LatchOperator",
	AttributeTeam = "LatchTeam",
	AttributeAlive = "LatchAlive",
	AttributeReloading = "LatchReloading",
	AttributeSlideDurationBonus = "LatchSlideBonus",
	AttributeQuietCrouch = "LatchQuietCrouch",
	AttributeMeleeReloadBuffUntil = "LatchMeleeReloadUntil",
	AttributeMeleeReloadMult = "LatchMeleeReloadMult",
	AttributeExplosiveKnockReduction = "LatchExplosiveKnockReduction",
	AttributeFragFuseBonus = "LatchFragFuseBonus",
	AttributePlantedArmor = "LatchPlantedArmor",
	AttributePlanted = "LatchPlanted",

	-- Bots
	AttributeIsBot = "LatchIsBot",
	AttributeDifficulty = "LatchDifficulty",
	AttributeDisplayName = "LatchDisplayName",
	AttributeBotId = "LatchBotId",
	AttributeOperatorId = "LatchOperatorId",

	-- Bot UserId range (negative, avoids colliding with real Roblox ids)
	BotIdMin = -900000,
	BotIdMax = -100001,
}

return Constants
