--!strict
--[[
	Monetization — ProductId placeholders. No real Robux charges while flag is false.
]]

local Monetization = {
	-- HARD GATE: PromptProductPurchase / PromptGamePassPurchase must check this.
	IS_MONETIZATION_LIVE = false,

	ProductIds = {
		StarterBundle = 0, -- placeholder Developer Product
		PrimePass = 0, -- placeholder GamePass / Product
		TokenPackSmall = 0,
		TokenPackLarge = 0,
		SkinTicketPack = 0,
	},

	GamePassIds = {
		PrimePass = 0,
	},

	-- Soft currency prices (Tokens) for shop weapons / cosmetics
	WeaponPrices = {
		CoilSMG = 150,
		Longscope = 200,
		BreachShotgun = 175,
		CycleBurst = 200,
		MachinePistol = 100,
		StubRevolver = 150,
		Crowbar = 80,
		Bat = 80,
		FlashCan = 100,
		SmokeCan = 100,
		StimCap = 120,
	} :: { [string]: number },

	-- Starters are free / always unlocked
	StarterWeapons = {
		"AssaultRifle",
		"Pistol",
		"Knife",
		"FragGrenade",
	} :: { string },

	SkinPrices = {
		AssaultRifle_Volt = 120,
		AssaultRifle_Ember = 200,
		CoilSMG_Neon = 120,
		CoilSMG_Void = 350,
		Pistol_Chrome = 100,
		Pistol_Crimson = 180,
		Knife_Carbon = 90,
		Knife_Aurora = 300,
		FragGrenade_Hazard = 80,
		FragGrenade_Ice = 160,
	} :: { [string]: number },

	WrapPrices = {
		Wrap_Ash = 40,
		Wrap_Moss = 40,
		Wrap_Cobalt = 80,
		Wrap_Rose = 80,
		Wrap_Solar = 150,
		Wrap_Ion = 150,
		Wrap_Obsidian = 300,
		Wrap_Prism = 300,
	} :: { [string]: number },

	CaseTicketCost = 1,
	CaseScrapDuplicate = 25, -- Scrap granted on duplicate skin
	CasePityOpens = 10, -- guarantee Rare+ after this many opens without Rare+

	StarterBundleGrant = {
		Weapon = "CoilSMG",
		Skin = "CoilSMG_Neon",
		Tokens = 200,
	},

	LevelXpRequired = 100, -- XP per account level
}

return Monetization
