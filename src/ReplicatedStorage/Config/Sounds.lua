--!strict
--[[
	Sounds — placeholder audio stubs (no toolbox / copyrighted IDs).
	AudioController creates short Sound objects in code; playback may be silent
	with print fallbacks when no usable SoundId is set.
]]

export type SoundStub = {
	Id: string,
	DisplayName: string,
	-- Prefer empty / omitted — never ship marketplace asset IDs here
	SoundId: string?,
	Volume: number,
	PlaybackSpeed: number,
	PitchVariance: number, -- ± random added to PlaybackSpeed
}

local Sounds: { [string]: SoundStub } = {
	UIClick = {
		Id = "UIClick",
		DisplayName = "UI Click",
		SoundId = "",
		Volume = 0.35,
		PlaybackSpeed = 1.2,
		PitchVariance = 0.08,
	},
	Fire = {
		Id = "Fire",
		DisplayName = "Weapon Fire",
		SoundId = "",
		Volume = 0.4,
		PlaybackSpeed = 1.0,
		PitchVariance = 0.12,
	},
	Hit = {
		Id = "Hit",
		DisplayName = "Hit Confirm",
		SoundId = "",
		Volume = 0.45,
		PlaybackSpeed = 1.35,
		PitchVariance = 0.1,
	},
	Ability = {
		Id = "Ability",
		DisplayName = "Ability Activate",
		SoundId = "",
		Volume = 0.5,
		PlaybackSpeed = 0.9,
		PitchVariance = 0.05,
	},
	Reload = {
		Id = "Reload",
		DisplayName = "Reload",
		SoundId = "",
		Volume = 0.3,
		PlaybackSpeed = 1.0,
		PitchVariance = 0.05,
	},
	Queue = {
		Id = "Queue",
		DisplayName = "Queue Confirm",
		SoundId = "",
		Volume = 0.4,
		PlaybackSpeed = 1.1,
		PitchVariance = 0.05,
	},
}

return {
	Sounds = Sounds,
}
