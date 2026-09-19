--!strict
--[[
	ShopService — featured / weapons / skins / cases / bundles.
	When IS_MONETIZATION_LIVE is false, purchases use Tokens / tickets / debug grants only.
]]

local Cosmetics = require(game.ReplicatedStorage.Config.Cosmetics)
local Monetization = require(game.ReplicatedStorage.Config.Monetization)
local WeaponsConfig = require(game.ReplicatedStorage.Config.Weapons)

local ShopService = {}
ShopService.__index = ShopService

local CASES = {
	SkinCaseAlpha = {
		Id = "SkinCaseAlpha",
		DisplayName = "Skin Case Alpha",
		Pool = {
			"AssaultRifle_Volt",
			"AssaultRifle_Ember",
			"Pistol_Chrome",
			"Pistol_Crimson",
			"Knife_Carbon",
			"FragGrenade_Hazard",
		},
	},
	SkinCaseBeta = {
		Id = "SkinCaseBeta",
		DisplayName = "Skin Case Beta",
		Pool = {
			"CoilSMG_Neon",
			"CoilSMG_Void",
			"Knife_Aurora",
			"FragGrenade_Ice",
			"AssaultRifle_Volt",
			"Pistol_Chrome",
		},
	},
}

function ShopService.new(dataService: any, remotes: { [string]: RemoteEvent })
	local self = setmetatable({
		_data = dataService,
		_remotes = remotes,
	}, ShopService)
	return self
end

function ShopService:Init()
	if self._remotes.ShopBuy then
		self._remotes.ShopBuy.OnServerEvent:Connect(function(player, payload)
			self:_onBuy(player, payload)
		end)
	end
	if self._remotes.OpenCase then
		self._remotes.OpenCase.OnServerEvent:Connect(function(player, payload)
			self:_onOpenCase(player, payload)
		end)
	end
	if self._remotes.EquipCosmetic then
		self._remotes.EquipCosmetic.OnServerEvent:Connect(function(player, payload)
			self:_onEquip(player, payload)
		end)
	end
end

function ShopService:GetCatalog(): { [string]: any }
	local weapons = {}
	for id, price in Monetization.WeaponPrices do
		local cfg = WeaponsConfig.Weapons[id :: any]
		table.insert(weapons, {
			Id = id,
			DisplayName = if cfg then cfg.DisplayName else id,
			Price = price,
			Slot = if cfg then cfg.Slot else "Primary",
		})
	end
	table.sort(weapons, function(a, b)
		return a.Id < b.Id
	end)

	local skins = {}
	for id, price in Monetization.SkinPrices do
		local def = Cosmetics.Skins[id]
		table.insert(skins, {
			Id = id,
			DisplayName = if def then def.DisplayName else id,
			Price = price,
			Rarity = if def then def.Rarity else "Common",
			WeaponId = if def then def.WeaponId else "",
		})
	end
	table.sort(skins, function(a, b)
		return a.Id < b.Id
	end)

	local wraps = {}
	for id, price in Monetization.WrapPrices do
		local def = Cosmetics.Wraps[id]
		table.insert(wraps, {
			Id = id,
			DisplayName = if def then def.DisplayName else id,
			Price = price,
			Rarity = if def then def.Rarity else "Common",
		})
	end

	return {
		Featured = {
			{ Kind = "Bundle", Id = "StarterBundle", DisplayName = "Starter Bundle", Desc = "Coil SMG + Neon Coil + 200 Tokens" },
			{ Kind = "Case", Id = "SkinCaseAlpha", DisplayName = "Skin Case Alpha" },
			{ Kind = "Case", Id = "SkinCaseBeta", DisplayName = "Skin Case Beta" },
		},
		Weapons = weapons,
		Skins = skins,
		Wraps = wraps,
		Cases = {
			{ Id = "SkinCaseAlpha", DisplayName = "Skin Case Alpha", TicketCost = Monetization.CaseTicketCost },
			{ Id = "SkinCaseBeta", DisplayName = "Skin Case Beta", TicketCost = Monetization.CaseTicketCost },
		},
		Bundles = {
			{
				Id = "StarterBundle",
				DisplayName = "Starter Bundle",
				Desc = "Coil SMG + Neon Coil skin + 200 Tokens",
				DebugOnly = not Monetization.IS_MONETIZATION_LIVE,
			},
		},
	}
end

function ShopService:_result(player: Player, ok: boolean, message: string, extra: any?)
	if self._remotes.ShopResult then
		local payload: { [string]: any } = { Ok = ok, Message = message }
		if typeof(extra) == "table" then
			for k, v in extra do
				payload[k] = v
			end
		end
		self._remotes.ShopResult:FireClient(player, payload)
	end
	self._data:Sync(player)
end

function ShopService:_onBuy(player: Player, payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	local kind = payload.Kind
	local id = payload.Id
	if typeof(kind) ~= "string" or typeof(id) ~= "string" then
		return
	end

	if kind == "Weapon" then
		local price = Monetization.WeaponPrices[id]
		if not price then
			self:_result(player, false, "Unknown weapon")
			return
		end
		if self._data:IsWeaponUnlocked(player, id) then
			self:_result(player, false, "Already unlocked")
			return
		end
		local profile = self._data:GetOrLoad(player)
		if profile.Tokens < price then
			self:_result(player, false, "Not enough Tokens")
			return
		end
		self._data:Mutate(player, function(p)
			p.Tokens -= price
			p.UnlockedWeapons[id] = true
		end)
		self:_result(player, true, "Unlocked " .. id)
		return
	end

	if kind == "Skin" then
		local price = Monetization.SkinPrices[id]
		local def = Cosmetics.Skins[id]
		if not price or not def then
			self:_result(player, false, "Unknown skin")
			return
		end
		if self._data:OwnsCosmetic(player, "Skins", id) then
			self:_result(player, false, "Already owned")
			return
		end
		local profile = self._data:GetOrLoad(player)
		if profile.Tokens < price then
			self:_result(player, false, "Not enough Tokens")
			return
		end
		self._data:Mutate(player, function(p)
			p.Tokens -= price
			p.OwnedCosmetics.Skins[id] = true
		end)
		self:_result(player, true, "Bought " .. def.DisplayName)
		return
	end

	if kind == "Wrap" then
		local price = Monetization.WrapPrices[id]
		local def = Cosmetics.Wraps[id]
		if not price or not def then
			self:_result(player, false, "Unknown wrap")
			return
		end
		if self._data:OwnsCosmetic(player, "Wraps", id) then
			self:_result(player, false, "Already owned")
			return
		end
		local profile = self._data:GetOrLoad(player)
		if profile.Tokens < price then
			self:_result(player, false, "Not enough Tokens")
			return
		end
		self._data:Mutate(player, function(p)
			p.Tokens -= price
			p.OwnedCosmetics.Wraps[id] = true
		end)
		self:_result(player, true, "Bought wrap " .. def.DisplayName)
		return
	end

	if kind == "Bundle" and id == "StarterBundle" then
		-- Real Robux path only when live; otherwise treat as debug/soft grant via MonetizationService
		self:_result(player, false, "Use Debug Grant for Starter Bundle (monetization off)")
		return
	end

	self:_result(player, false, "Unknown shop item")
end

local function pickFromPool(pool: { string }, pity: number): (string, boolean)
	-- pity guarantee: Rare+ after CasePityOpens without Rare+
	local forceRare = pity >= Monetization.CasePityOpens
	local candidates: { string } = {}
	for _, skinId in pool do
		local def = Cosmetics.Skins[skinId]
		if def then
			if forceRare then
				if Cosmetics.RarityAtLeast(def.Rarity, "Rare") then
					table.insert(candidates, skinId)
				end
			else
				table.insert(candidates, skinId)
			end
		end
	end
	if #candidates == 0 then
		candidates = pool
	end
	local pick = candidates[math.random(1, #candidates)]
	local def = Cosmetics.Skins[pick]
	local isRarePlus = def ~= nil and Cosmetics.RarityAtLeast(def.Rarity, "Rare")
	return pick, isRarePlus
end

function ShopService:_onOpenCase(player: Player, payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	local caseId = payload.CaseId
	local debugFree = payload.Debug == true
	if typeof(caseId) ~= "string" or not CASES[caseId] then
		self:_result(player, false, "Unknown case")
		return
	end
	local caseDef = CASES[caseId]
	local profile = self._data:GetOrLoad(player)

	if not debugFree then
		if profile.SkinTickets < Monetization.CaseTicketCost then
			self:_result(player, false, "Need Skin Ticket")
			return
		end
		self._data:Mutate(player, function(p)
			p.SkinTickets -= Monetization.CaseTicketCost
		end)
	end

	profile = self._data:GetOrLoad(player)
	local pity = profile.CasePity[caseId] or 0
	local skinId, isRarePlus = pickFromPool(caseDef.Pool, pity)
	local isNew = self._data:GrantCosmetic(player, "Skins", skinId)
	local scrapGain = 0
	if not isNew then
		scrapGain = Monetization.CaseScrapDuplicate
		self._data:AddScrap(player, scrapGain)
	end

	self._data:Mutate(player, function(p)
		if isRarePlus then
			p.CasePity[caseId] = 0
		else
			p.CasePity[caseId] = pity + 1
		end
	end)

	local def = Cosmetics.Skins[skinId]
	self:_result(player, true, if isNew then "New skin!" else "Duplicate → Scrap", {
		CaseId = caseId,
		SkinId = skinId,
		SkinName = if def then def.DisplayName else skinId,
		Rarity = if def then def.Rarity else "Common",
		Duplicate = not isNew,
		Scrap = scrapGain,
	})
end

function ShopService:_onEquip(player: Player, payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	local kind = payload.Kind
	local id = payload.Id
	if typeof(kind) ~= "string" then
		return
	end

	if kind == "Skin" and typeof(id) == "string" then
		local def = Cosmetics.Skins[id]
		if not def or not self._data:OwnsCosmetic(player, "Skins", id) then
			self:_result(player, false, "Don't own skin")
			return
		end
		self._data:Mutate(player, function(p)
			p.EquippedCosmetics.Skins[def.WeaponId] = id
		end)
		self:_result(player, true, "Equipped skin")
		return
	end

	if kind == "Wrap" then
		if id == nil or id == "" then
			self._data:Mutate(player, function(p)
				p.EquippedCosmetics.Wrap = nil
			end)
			self:_result(player, true, "Cleared wrap")
			return
		end
		if typeof(id) ~= "string" or not self._data:OwnsCosmetic(player, "Wraps", id) then
			self:_result(player, false, "Don't own wrap")
			return
		end
		self._data:Mutate(player, function(p)
			p.EquippedCosmetics.Wrap = id
		end)
		self:_result(player, true, "Equipped wrap")
		return
	end

	if kind == "Charm" and typeof(id) == "string" then
		if not self._data:OwnsCosmetic(player, "Charms", id) then
			self:_result(player, false, "Don't own charm")
			return
		end
		self._data:Mutate(player, function(p)
			p.EquippedCosmetics.Charm = id
		end)
		self:_result(player, true, "Equipped charm")
		return
	end

	if kind == "Emote" and typeof(id) == "string" then
		if not self._data:OwnsCosmetic(player, "Emotes", id) then
			self:_result(player, false, "Don't own emote")
			return
		end
		self._data:Mutate(player, function(p)
			p.EquippedCosmetics.Emote = id
		end)
		self:_result(player, true, "Equipped emote")
		return
	end

	if kind == "Finisher" and typeof(id) == "string" then
		if not self._data:OwnsCosmetic(player, "Finishers", id) then
			self:_result(player, false, "Don't own finisher")
			return
		end
		self._data:Mutate(player, function(p)
			p.EquippedCosmetics.Finisher = id
		end)
		self:_result(player, true, "Equipped finisher")
		return
	end

	self:_result(player, false, "Bad equip")
end

function ShopService:DebugGrantWeapon(player: Player, weaponId: string)
	if not WeaponsConfig.Weapons[weaponId :: any] then
		return false
	end
	self._data:UnlockWeapon(player, weaponId)
	return true
end

function ShopService:DebugGrantAllWeapons(player: Player)
	for id in WeaponsConfig.Weapons do
		self._data:UnlockWeapon(player, id)
	end
end

return ShopService
