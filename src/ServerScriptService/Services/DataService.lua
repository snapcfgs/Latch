--!strict
--[[
	DataService — versioned player profile.
	Uses DataStore when available; in-memory fallback for Studio / failures.
	Autosave every 60s + BindToClose when DataStores work.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Cosmetics = require(game.ReplicatedStorage.Config.Cosmetics)
local Monetization = require(game.ReplicatedStorage.Config.Monetization)
local BattlePass = require(game.ReplicatedStorage.Config.BattlePass)
local WeaponsConfig = require(game.ReplicatedStorage.Config.Weapons)

local PROFILE_VERSION = 1
local STORE_NAME = "LatchPlayer_v1"
local AUTOSAVE_SECONDS = 60

export type EquippedCosmetics = {
	Skins: { [string]: string }, -- weaponId -> skinId
	Wrap: string?,
	Charm: string?,
	Finisher: string?,
	Emote: string?,
}

export type PassData = {
	SeasonId: string,
	Xp: number,
	OwnsPrime: boolean,
	ClaimedFree: { [string]: boolean }, -- tier number as string
	ClaimedPrime: { [string]: boolean },
}

export type ContractSlot = {
	Id: string,
	Progress: number,
	Target: number,
	Claimed: boolean,
}

export type ContractsData = {
	DayKey: string,
	RefreshAt: number,
	Active: { ContractSlot },
}

export type StatsData = {
	Matches: number,
	Wins: number,
	Losses: number,
	WinStreak: number,
	Kills: number,
	Deaths: number,
	Damage: number,
	AbilityUses: number,
	Headshots: number,
}

export type Profile = {
	Version: number,
	Tokens: number,
	Scrap: number,
	SkinTickets: number,
	Xp: number,
	Level: number,
	UnlockedWeapons: { [string]: boolean },
	EquippedLoadout: { [string]: string },
	EquippedCosmetics: EquippedCosmetics,
	OwnedCosmetics: {
		Skins: { [string]: boolean },
		Wraps: { [string]: boolean },
		Charms: { [string]: boolean },
		Finishers: { [string]: boolean },
		Emotes: { [string]: boolean },
	},
	Pass: PassData,
	Contracts: ContractsData,
	Stats: StatsData,
	CasePity: { [string]: number },
}

local DataService = {}
DataService.__index = DataService

local function defaultUnlocked(): { [string]: boolean }
	local map: { [string]: boolean } = {}
	for _, id in Monetization.StarterWeapons do
		map[id] = true
	end
	return map
end

local function defaultOwnedCosmetics()
	local skins: { [string]: boolean } = {}
	local skinEquipped: { [string]: string } = {}
	for id, def in Cosmetics.Skins do
		if def.IsDefault then
			skins[id] = true
			skinEquipped[def.WeaponId] = id
		end
	end
	return {
		Skins = skins,
		Wraps = {} :: { [string]: boolean },
		Charms = {} :: { [string]: boolean },
		Finishers = {} :: { [string]: boolean },
		Emotes = { Emote_Wave = true } :: { [string]: boolean },
	}, skinEquipped
end

function DataService.DefaultProfile(): Profile
	local owned, skinEquipped = defaultOwnedCosmetics()
	local loadout = {
		Primary = WeaponsConfig.DefaultLoadout.Primary,
		Secondary = WeaponsConfig.DefaultLoadout.Secondary,
		Melee = WeaponsConfig.DefaultLoadout.Melee,
		Utility = WeaponsConfig.DefaultLoadout.Utility,
	}
	return {
		Version = PROFILE_VERSION,
		Tokens = 100, -- starter pocket change for shop browsing
		Scrap = 0,
		SkinTickets = 1,
		Xp = 0,
		Level = 1,
		UnlockedWeapons = defaultUnlocked(),
		EquippedLoadout = loadout,
		EquippedCosmetics = {
			Skins = skinEquipped,
			Wrap = nil,
			Charm = nil,
			Finisher = nil,
			Emote = "Emote_Wave",
		},
		OwnedCosmetics = owned,
		Pass = {
			SeasonId = BattlePass.SeasonId,
			Xp = 0,
			OwnsPrime = false,
			ClaimedFree = {},
			ClaimedPrime = {},
		},
		Contracts = {
			DayKey = "",
			RefreshAt = 0,
			Active = {},
		},
		Stats = {
			Matches = 0,
			Wins = 0,
			Losses = 0,
			WinStreak = 0,
			Kills = 0,
			Deaths = 0,
			Damage = 0,
			AbilityUses = 0,
			Headshots = 0,
		},
		CasePity = {
			SkinCaseAlpha = 0,
			SkinCaseBeta = 0,
		},
	}
end

local function deepCopy(t: any): any
	if typeof(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in t do
		out[k] = deepCopy(v)
	end
	return out
end

local function migrate(raw: any): Profile
	local base = DataService.DefaultProfile()
	if typeof(raw) ~= "table" then
		return base
	end
	-- Shallow merge known fields
	if typeof(raw.Tokens) == "number" then
		base.Tokens = raw.Tokens
	end
	if typeof(raw.Scrap) == "number" then
		base.Scrap = raw.Scrap
	end
	if typeof(raw.SkinTickets) == "number" then
		base.SkinTickets = raw.SkinTickets
	end
	if typeof(raw.Xp) == "number" then
		base.Xp = raw.Xp
	end
	if typeof(raw.Level) == "number" then
		base.Level = raw.Level
	end
	if typeof(raw.UnlockedWeapons) == "table" then
		for k, v in raw.UnlockedWeapons do
			if v then
				base.UnlockedWeapons[tostring(k)] = true
			end
		end
	end
	if typeof(raw.EquippedLoadout) == "table" then
		for k, v in raw.EquippedLoadout do
			if typeof(v) == "string" then
				base.EquippedLoadout[tostring(k)] = v
			end
		end
	end
	if typeof(raw.EquippedCosmetics) == "table" then
		local ec = raw.EquippedCosmetics
		if typeof(ec.Skins) == "table" then
			for k, v in ec.Skins do
				if typeof(v) == "string" then
					base.EquippedCosmetics.Skins[tostring(k)] = v
				end
			end
		end
		if typeof(ec.Wrap) == "string" then
			base.EquippedCosmetics.Wrap = ec.Wrap
		end
		if typeof(ec.Charm) == "string" then
			base.EquippedCosmetics.Charm = ec.Charm
		end
		if typeof(ec.Finisher) == "string" then
			base.EquippedCosmetics.Finisher = ec.Finisher
		end
		if typeof(ec.Emote) == "string" then
			base.EquippedCosmetics.Emote = ec.Emote
		end
	end
	if typeof(raw.OwnedCosmetics) == "table" then
		for _, kind in { "Skins", "Wraps", "Charms", "Finishers", "Emotes" } do
			local src = raw.OwnedCosmetics[kind]
			if typeof(src) == "table" then
				for k, v in src do
					if v then
						(base.OwnedCosmetics :: any)[kind][tostring(k)] = true
					end
				end
			end
		end
	end
	if typeof(raw.Pass) == "table" then
		local p = raw.Pass
		if typeof(p.SeasonId) == "string" then
			base.Pass.SeasonId = p.SeasonId
		end
		if typeof(p.Xp) == "number" then
			base.Pass.Xp = p.Xp
		end
		if typeof(p.OwnsPrime) == "boolean" then
			base.Pass.OwnsPrime = p.OwnsPrime
		end
		if typeof(p.ClaimedFree) == "table" then
			for k, v in p.ClaimedFree do
				if v then
					base.Pass.ClaimedFree[tostring(k)] = true
				end
			end
		end
		if typeof(p.ClaimedPrime) == "table" then
			for k, v in p.ClaimedPrime do
				if v then
					base.Pass.ClaimedPrime[tostring(k)] = true
				end
			end
		end
		-- Reset pass progress if season changed
		if base.Pass.SeasonId ~= BattlePass.SeasonId then
			base.Pass.SeasonId = BattlePass.SeasonId
			base.Pass.Xp = 0
			base.Pass.ClaimedFree = {}
			base.Pass.ClaimedPrime = {}
		end
	end
	if typeof(raw.Contracts) == "table" then
		base.Contracts = deepCopy(raw.Contracts) :: ContractsData
	end
	if typeof(raw.Stats) == "table" then
		for k, v in raw.Stats do
			if typeof(v) == "number" and (base.Stats :: any)[k] ~= nil then
				(base.Stats :: any)[k] = v
			end
		end
	end
	if typeof(raw.CasePity) == "table" then
		for k, v in raw.CasePity do
			if typeof(v) == "number" then
				base.CasePity[tostring(k)] = v
			end
		end
	end
	base.Version = PROFILE_VERSION
	return base
end

function DataService.new(remotes: { [string]: RemoteEvent })
	local self = setmetatable({
		_remotes = remotes,
		_profiles = {} :: { [number]: Profile },
		_dirty = {} :: { [number]: boolean },
		_store = nil :: DataStore?,
		_dataStoresOk = false,
		_saving = {} :: { [number]: boolean },
	}, DataService)

	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok and store then
		self._store = store
		self._dataStoresOk = true
	end
	-- Studio often has DataStores API off — force memory fallback
	if RunService:IsStudio() then
		local studioOk = false
		if self._store then
			local tOk = pcall(function()
				(self._store :: DataStore):GetAsync("__latch_ping__")
			end)
			studioOk = tOk
		end
		if not studioOk then
			self._dataStoresOk = false
			print("[Latch] DataService: Studio in-memory profiles (DataStore unavailable)")
		end
	end

	return self
end

function DataService:Init()
	Players.PlayerAdded:Connect(function(player)
		self:Load(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:Save(player)
		self._profiles[player.UserId] = nil
		self._dirty[player.UserId] = nil
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(function()
			self:Load(p)
		end)
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			if self._dataStoresOk then
				for _, p in Players:GetPlayers() do
					if self._dirty[p.UserId] then
						self:Save(p)
					end
				end
			end
		end
	end)

	if self._dataStoresOk then
		game:BindToClose(function()
			for _, p in Players:GetPlayers() do
				self:Save(p)
			end
		end)
	end

	if self._remotes.RequestProfile then
		self._remotes.RequestProfile.OnServerEvent:Connect(function(player)
			self:Sync(player)
		end)
	end
end

function DataService:UsesDataStore(): boolean
	return self._dataStoresOk
end

function DataService:Load(player: Player): Profile
	local uid = player.UserId
	if self._profiles[uid] then
		return self._profiles[uid]
	end
	local profile: Profile = DataService.DefaultProfile()
	if self._dataStoresOk and self._store then
		local ok, data = pcall(function()
			return (self._store :: DataStore):GetAsync("u_" .. tostring(uid))
		end)
		if ok and data then
			profile = migrate(data)
		end
	end
	self._profiles[uid] = profile
	self._dirty[uid] = false
	self:Sync(player)
	return profile
end

function DataService:Save(player: Player)
	local uid = player.UserId
	local profile = self._profiles[uid]
	if not profile then
		return
	end
	if not self._dataStoresOk or not self._store then
		self._dirty[uid] = false
		return
	end
	if self._saving[uid] then
		return
	end
	self._saving[uid] = true
	local ok, err = pcall(function()
		(self._store :: DataStore):SetAsync("u_" .. tostring(uid), deepCopy(profile))
	end)
	self._saving[uid] = false
	if ok then
		self._dirty[uid] = false
	else
		warn("[Latch] DataService save failed:", err)
	end
end

function DataService:Get(player: Player): Profile?
	return self._profiles[player.UserId]
end

function DataService:GetOrLoad(player: Player): Profile
	return self._profiles[player.UserId] or self:Load(player)
end

function DataService:MarkDirty(player: Player)
	self._dirty[player.UserId] = true
end

function DataService:Mutate(player: Player, fn: (Profile) -> ())
	local profile = self:GetOrLoad(player)
	fn(profile)
	self:MarkDirty(player)
	self:Sync(player)
end

--- Client-safe snapshot (no metatables)
function DataService:ToClient(profile: Profile): { [string]: any }
	return deepCopy(profile)
end

function DataService:Sync(player: Player)
	local profile = self._profiles[player.UserId]
	if not profile or not self._remotes.ProfileSync then
		return
	end
	self._remotes.ProfileSync:FireClient(player, self:ToClient(profile), {
		DataStore = self._dataStoresOk,
		MonetizationLive = Monetization.IS_MONETIZATION_LIVE,
	})
end

function DataService:IsWeaponUnlocked(player: Player, weaponId: string): boolean
	local profile = self:GetOrLoad(player)
	return profile.UnlockedWeapons[weaponId] == true
end

function DataService:UnlockWeapon(player: Player, weaponId: string)
	self:Mutate(player, function(p)
		p.UnlockedWeapons[weaponId] = true
	end)
end

function DataService:AddTokens(player: Player, amount: number)
	self:Mutate(player, function(p)
		p.Tokens = math.max(0, p.Tokens + amount)
	end)
end

function DataService:AddScrap(player: Player, amount: number)
	self:Mutate(player, function(p)
		p.Scrap = math.max(0, p.Scrap + amount)
	end)
end

function DataService:AddSkinTickets(player: Player, amount: number)
	self:Mutate(player, function(p)
		p.SkinTickets = math.max(0, p.SkinTickets + amount)
	end)
end

function DataService:AddXp(player: Player, amount: number)
	self:Mutate(player, function(p)
		p.Xp += amount
		local need = Monetization.LevelXpRequired
		while p.Xp >= need do
			p.Xp -= need
			p.Level += 1
		end
	end)
end

function DataService:OwnsCosmetic(player: Player, kind: string, id: string): boolean
	local profile = self:GetOrLoad(player)
	local bag = (profile.OwnedCosmetics :: any)[kind]
	return typeof(bag) == "table" and bag[id] == true
end

function DataService:GrantCosmetic(player: Player, kind: string, id: string): boolean
	-- returns true if newly granted, false if duplicate
	local wasNew = false
	self:Mutate(player, function(p)
		local bag = (p.OwnedCosmetics :: any)[kind]
		if typeof(bag) ~= "table" then
			return
		end
		if bag[id] then
			wasNew = false
		else
			bag[id] = true
			wasNew = true
		end
	end)
	return wasNew
end

return DataService
