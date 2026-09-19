--!strict
--[[
	Cosmetics — skins, wraps, charms, finishers, emotes.
	Launch weapons: AssaultRifle, CoilSMG, Pistol, Knife, FragGrenade (default + 2 skins each).
	Rarities: Common / Rare / Epic / Legendary
]]

export type Rarity = "Common" | "Rare" | "Epic" | "Legendary"
export type CosmeticKind = "Skin" | "Wrap" | "Charm" | "Finisher" | "Emote"

export type SkinDef = {
	Id: string,
	DisplayName: string,
	WeaponId: string,
	Rarity: Rarity,
	Color: Color3,
	IsDefault: boolean?,
}

export type WrapDef = {
	Id: string,
	DisplayName: string,
	Rarity: Rarity,
	Color: Color3,
}

export type CharmDef = {
	Id: string,
	DisplayName: string,
	Rarity: Rarity,
}

export type FinisherDef = {
	Id: string,
	DisplayName: string,
	Rarity: Rarity,
}

export type EmoteDef = {
	Id: string,
	DisplayName: string,
	Rarity: Rarity,
}

local RarityOrder: { [Rarity]: number } = {
	Common = 1,
	Rare = 2,
	Epic = 3,
	Legendary = 4,
}

local RarityColor: { [Rarity]: Color3 } = {
	Common = Color3.fromRGB(180, 180, 190),
	Rare = Color3.fromRGB(80, 140, 255),
	Epic = Color3.fromRGB(180, 90, 255),
	Legendary = Color3.fromRGB(255, 180, 40),
}

-- Launch weapons get Default + 2 unlockable skins
local Skins: { [string]: SkinDef } = {
	-- Pulse AR
	AssaultRifle_Default = {
		Id = "AssaultRifle_Default",
		DisplayName = "Pulse Stock",
		WeaponId = "AssaultRifle",
		Rarity = "Common",
		Color = Color3.fromRGB(70, 78, 90),
		IsDefault = true,
	},
	AssaultRifle_Volt = {
		Id = "AssaultRifle_Volt",
		DisplayName = "Volt Stripe",
		WeaponId = "AssaultRifle",
		Rarity = "Rare",
		Color = Color3.fromRGB(40, 220, 180),
	},
	AssaultRifle_Ember = {
		Id = "AssaultRifle_Ember",
		DisplayName = "Ember Core",
		WeaponId = "AssaultRifle",
		Rarity = "Epic",
		Color = Color3.fromRGB(255, 90, 40),
	},
	-- Coil SMG
	CoilSMG_Default = {
		Id = "CoilSMG_Default",
		DisplayName = "Coil Stock",
		WeaponId = "CoilSMG",
		Rarity = "Common",
		Color = Color3.fromRGB(60, 70, 85),
		IsDefault = true,
	},
	CoilSMG_Neon = {
		Id = "CoilSMG_Neon",
		DisplayName = "Neon Coil",
		WeaponId = "CoilSMG",
		Rarity = "Rare",
		Color = Color3.fromRGB(120, 255, 80),
	},
	CoilSMG_Void = {
		Id = "CoilSMG_Void",
		DisplayName = "Void Coil",
		WeaponId = "CoilSMG",
		Rarity = "Legendary",
		Color = Color3.fromRGB(90, 40, 160),
	},
	-- Sidearm
	Pistol_Default = {
		Id = "Pistol_Default",
		DisplayName = "Sidearm Stock",
		WeaponId = "Pistol",
		Rarity = "Common",
		Color = Color3.fromRGB(55, 60, 70),
		IsDefault = true,
	},
	Pistol_Chrome = {
		Id = "Pistol_Chrome",
		DisplayName = "Chrome Cap",
		WeaponId = "Pistol",
		Rarity = "Rare",
		Color = Color3.fromRGB(200, 210, 220),
	},
	Pistol_Crimson = {
		Id = "Pistol_Crimson",
		DisplayName = "Crimson Cap",
		WeaponId = "Pistol",
		Rarity = "Epic",
		Color = Color3.fromRGB(200, 40, 60),
	},
	-- Blade
	Knife_Default = {
		Id = "Knife_Default",
		DisplayName = "Blade Stock",
		WeaponId = "Knife",
		Rarity = "Common",
		Color = Color3.fromRGB(140, 145, 155),
		IsDefault = true,
	},
	Knife_Carbon = {
		Id = "Knife_Carbon",
		DisplayName = "Carbon Edge",
		WeaponId = "Knife",
		Rarity = "Rare",
		Color = Color3.fromRGB(30, 32, 38),
	},
	Knife_Aurora = {
		Id = "Knife_Aurora",
		DisplayName = "Aurora Edge",
		WeaponId = "Knife",
		Rarity = "Legendary",
		Color = Color3.fromRGB(100, 220, 255),
	},
	-- Frag
	FragGrenade_Default = {
		Id = "FragGrenade_Default",
		DisplayName = "Frag Stock",
		WeaponId = "FragGrenade",
		Rarity = "Common",
		Color = Color3.fromRGB(50, 90, 50),
		IsDefault = true,
	},
	FragGrenade_Hazard = {
		Id = "FragGrenade_Hazard",
		DisplayName = "Hazard Can",
		WeaponId = "FragGrenade",
		Rarity = "Rare",
		Color = Color3.fromRGB(220, 200, 40),
	},
	FragGrenade_Ice = {
		Id = "FragGrenade_Ice",
		DisplayName = "Ice Can",
		WeaponId = "FragGrenade",
		Rarity = "Epic",
		Color = Color3.fromRGB(140, 200, 255),
	},
}

local Wraps: { [string]: WrapDef } = {
	Wrap_Ash = { Id = "Wrap_Ash", DisplayName = "Ash", Rarity = "Common", Color = Color3.fromRGB(120, 120, 125) },
	Wrap_Moss = { Id = "Wrap_Moss", DisplayName = "Moss", Rarity = "Common", Color = Color3.fromRGB(70, 110, 60) },
	Wrap_Cobalt = { Id = "Wrap_Cobalt", DisplayName = "Cobalt", Rarity = "Rare", Color = Color3.fromRGB(40, 90, 200) },
	Wrap_Rose = { Id = "Wrap_Rose", DisplayName = "Rose", Rarity = "Rare", Color = Color3.fromRGB(200, 80, 120) },
	Wrap_Solar = { Id = "Wrap_Solar", DisplayName = "Solar", Rarity = "Epic", Color = Color3.fromRGB(255, 160, 40) },
	Wrap_Ion = { Id = "Wrap_Ion", DisplayName = "Ion", Rarity = "Epic", Color = Color3.fromRGB(80, 255, 220) },
	Wrap_Obsidian = { Id = "Wrap_Obsidian", DisplayName = "Obsidian", Rarity = "Legendary", Color = Color3.fromRGB(20, 18, 28) },
	Wrap_Prism = { Id = "Wrap_Prism", DisplayName = "Prism", Rarity = "Legendary", Color = Color3.fromRGB(255, 100, 200) },
}

local Charms: { [string]: CharmDef } = {
	Charm_Bolt = { Id = "Charm_Bolt", DisplayName = "Bolt", Rarity = "Common" },
	Charm_Chip = { Id = "Charm_Chip", DisplayName = "Chip", Rarity = "Common" },
	Charm_Coil = { Id = "Charm_Coil", DisplayName = "Mini Coil", Rarity = "Rare" },
	Charm_Key = { Id = "Charm_Key", DisplayName = "Latch Key", Rarity = "Rare" },
	Charm_Spark = { Id = "Charm_Spark", DisplayName = "Spark", Rarity = "Epic" },
	Charm_Shield = { Id = "Charm_Shield", DisplayName = "Plate", Rarity = "Epic" },
	Charm_Crown = { Id = "Charm_Crown", DisplayName = "Wire Crown", Rarity = "Legendary" },
	Charm_Ghost = { Id = "Charm_Ghost", DisplayName = "Ghost Tag", Rarity = "Legendary" },
}

local Finishers: { [string]: FinisherDef } = {
	Finisher_Snap = { Id = "Finisher_Snap", DisplayName = "Snap", Rarity = "Rare" },
	Finisher_Static = { Id = "Finisher_Static", DisplayName = "Static Drop", Rarity = "Epic" },
	Finisher_Overload = { Id = "Finisher_Overload", DisplayName = "Overload", Rarity = "Epic" },
	Finisher_Blackout = { Id = "Finisher_Blackout", DisplayName = "Blackout", Rarity = "Legendary" },
}

local Emotes: { [string]: EmoteDef } = {
	Emote_Wave = { Id = "Emote_Wave", DisplayName = "Wave", Rarity = "Common" },
	Emote_Point = { Id = "Emote_Point", DisplayName = "Point", Rarity = "Common" },
	Emote_Flex = { Id = "Emote_Flex", DisplayName = "Flex", Rarity = "Rare" },
	Emote_Spin = { Id = "Emote_Spin", DisplayName = "Spin", Rarity = "Rare" },
	Emote_Clap = { Id = "Emote_Clap", DisplayName = "Clap", Rarity = "Epic" },
	Emote_LiveWire = { Id = "Emote_LiveWire", DisplayName = "Live Wire", Rarity = "Legendary" },
}

local function skinsForWeapon(weaponId: string): { SkinDef }
	local list: { SkinDef } = {}
	for _, s in Skins do
		if s.WeaponId == weaponId then
			table.insert(list, s)
		end
	end
	table.sort(list, function(a, b)
		return a.Id < b.Id
	end)
	return list
end

local function defaultSkinId(weaponId: string): string?
	for _, s in Skins do
		if s.WeaponId == weaponId and s.IsDefault then
			return s.Id
		end
	end
	return nil
end

local function rarityAtLeast(rarity: Rarity, minRarity: Rarity): boolean
	return (RarityOrder[rarity] or 0) >= (RarityOrder[minRarity] or 0)
end

return {
	Skins = Skins,
	Wraps = Wraps,
	Charms = Charms,
	Finishers = Finishers,
	Emotes = Emotes,
	RarityOrder = RarityOrder,
	RarityColor = RarityColor,
	SkinsForWeapon = skinsForWeapon,
	DefaultSkinId = defaultSkinId,
	RarityAtLeast = rarityAtLeast,
}
