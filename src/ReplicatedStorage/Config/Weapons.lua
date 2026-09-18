--!strict
--[[
	Weapons — loadout definitions. All damage/fire rate balance here.
]]

export type WeaponId = "AssaultRifle" | "Pistol" | "Knife" | "FragGrenade"

export type WeaponConfig = {
	Id: WeaponId,
	DisplayName: string,
	Slot: "Primary" | "Secondary" | "Melee" | "Utility",
	Kind: "Hitscan" | "Melee" | "Projectile",
	Damage: number,
	HeadMultiplier: number,
	FireRate: number, -- shots per second
	MagSize: number,
	ReserveAmmo: number,
	ReloadTime: number,
	Range: number,
	SpreadDegrees: number,
	Auto: boolean,
	-- Melee
	MeleeRange: number?,
	MeleeArcDegrees: number?,
	-- Grenade
	ProjectileSpeed: number?,
	ExplosionRadius: number?,
	FuseTime: number?,
	ThrowCooldown: number?,
}

local Weapons: { [WeaponId]: WeaponConfig } = {
	AssaultRifle = {
		Id = "AssaultRifle",
		DisplayName = "Pulse AR",
		Slot = "Primary",
		Kind = "Hitscan",
		Damage = 18,
		HeadMultiplier = 1.4,
		FireRate = 9,
		MagSize = 30,
		ReserveAmmo = 90,
		ReloadTime = 1.8,
		Range = 400,
		SpreadDegrees = 1.2,
		Auto = true,
	},
	Pistol = {
		Id = "Pistol",
		DisplayName = "Sidearm",
		Slot = "Secondary",
		Kind = "Hitscan",
		Damage = 28,
		HeadMultiplier = 1.6,
		FireRate = 4,
		MagSize = 12,
		ReserveAmmo = 36,
		ReloadTime = 1.4,
		Range = 250,
		SpreadDegrees = 0.8,
		Auto = false,
	},
	Knife = {
		Id = "Knife",
		DisplayName = "Blade",
		Slot = "Melee",
		Kind = "Melee",
		Damage = 45,
		HeadMultiplier = 1.0,
		FireRate = 2.2,
		MagSize = 0,
		ReserveAmmo = 0,
		ReloadTime = 0,
		Range = 0,
		SpreadDegrees = 0,
		Auto = false,
		MeleeRange = 8,
		MeleeArcDegrees = 70,
	},
	FragGrenade = {
		Id = "FragGrenade",
		DisplayName = "Frag",
		Slot = "Utility",
		Kind = "Projectile",
		Damage = 80,
		HeadMultiplier = 1.0,
		FireRate = 0,
		MagSize = 1,
		ReserveAmmo = 1,
		ReloadTime = 0,
		Range = 0,
		SpreadDegrees = 0,
		Auto = false,
		ProjectileSpeed = 90,
		ExplosionRadius = 18,
		FuseTime = 1.6,
		ThrowCooldown = 8,
	},
}

local LoadoutOrder: { WeaponId } = { "AssaultRifle", "Pistol", "Knife", "FragGrenade" }

return {
	Weapons = Weapons,
	LoadoutOrder = LoadoutOrder,
}
