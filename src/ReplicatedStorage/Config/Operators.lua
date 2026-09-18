--!strict
--[[
	Operators — active + passive definitions. Cooldown / duration balance here.
]]

export type OperatorId = "Skid" | "Anchor" | "Splice" | "Jolt"

export type OperatorConfig = {
	Id: OperatorId,
	DisplayName: string,
	Description: string,
	ActiveName: string,
	ActiveDescription: string,
	PassiveName: string,
	PassiveDescription: string,
	Cooldown: number,
	ActiveDuration: number?,
	-- Skid
	DashSpeed: number?,
	DashDuration: number?,
	DashMaxDistance: number?,
	SlideDurationBonus: number?,
	-- Anchor
	CoverSize: Vector3?,
	CoverLifetime: number?,
	ExplosiveKnockReduction: number?,
	-- Splice
	PanelSize: Vector3?,
	PanelLifetime: number?,
	-- Jolt
	MarkDuration: number?,
	MarkRange: number?,
	MeleeReloadBuffDuration: number?,
	MeleeReloadMultiplier: number?,
}

local Operators: { [OperatorId]: OperatorConfig } = {
	Skid = {
		Id = "Skid",
		DisplayName = "Skid",
		Description = "Mobility specialist. Dash in, slide longer.",
		ActiveName = "Friction Dash",
		ActiveDescription = "Short forward dash with a thin trail.",
		PassiveName = "Long Slide",
		PassiveDescription = "Slightly longer slide distance.",
		Cooldown = 8,
		DashSpeed = 80,
		DashDuration = 0.22,
		DashMaxDistance = 28,
		SlideDurationBonus = 0.2,
	},
	Anchor = {
		Id = "Anchor",
		DisplayName = "Anchor",
		Description = "Hold angles with deployable cover.",
		ActiveName = "Cover Plate",
		ActiveDescription = "Deploy a solid plate for a few seconds.",
		PassiveName = "Blast Brace",
		PassiveDescription = "Reduced knock from own explosives (stub).",
		Cooldown = 12,
		CoverSize = Vector3.new(8, 5, 0.6),
		CoverLifetime = 4,
		ExplosiveKnockReduction = 0.5,
	},
	Splice = {
		Id = "Splice",
		DisplayName = "Splice",
		Description = "One-way panel for creative peeks.",
		ActiveName = "One-Way Panel",
		ActiveDescription = "Allies shoot through; enemies blocked.",
		PassiveName = "Quiet Step",
		PassiveDescription = "Quieter footsteps while crouched.",
		Cooldown = 14,
		PanelSize = Vector3.new(6, 5, 0.4),
		PanelLifetime = 5,
	},
	Jolt = {
		Id = "Jolt",
		DisplayName = "Jolt",
		Description = "Reveal and punish with melee tempo.",
		ActiveName = "Mark",
		ActiveDescription = "Brief outline reveal on a target.",
		PassiveName = "Blade Tempo",
		PassiveDescription = "Faster reload briefly after a melee hit.",
		Cooldown = 10,
		MarkDuration = 3,
		MarkRange = 120,
		MeleeReloadBuffDuration = 3,
		MeleeReloadMultiplier = 0.65,
	},
}

local OperatorOrder: { OperatorId } = { "Skid", "Anchor", "Splice", "Jolt" }

return {
	Operators = Operators,
	OperatorOrder = OperatorOrder,
}
