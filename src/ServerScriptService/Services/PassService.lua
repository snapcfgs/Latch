--!strict
--[[
	PassService — Battle Pass claim free/prime tiers; Pass XP from ProgressionService.

	Formula (also in README / BattlePass.lua):
	  20 Pass XP = 1 tier.
	  Match: +1 XP per round win (or per elim in continuous modes) +1 XP / 45s (cap 20).
]]

local BattlePass = require(game.ReplicatedStorage.Config.BattlePass)

local PassService = {}
PassService.__index = PassService

function PassService.new(dataService: any, remotes: { [string]: RemoteEvent })
	local self = setmetatable({
		_data = dataService,
		_remotes = remotes,
	}, PassService)
	return self
end

function PassService:Init()
	if self._remotes.PassClaim then
		self._remotes.PassClaim.OnServerEvent:Connect(function(player, payload)
			self:_onClaim(player, payload)
		end)
	end
end

function PassService:AddPassXp(player: Player, amount: number)
	if amount <= 0 then
		return
	end
	self._data:Mutate(player, function(p)
		if p.Pass.SeasonId ~= BattlePass.SeasonId then
			p.Pass.SeasonId = BattlePass.SeasonId
			p.Pass.Xp = 0
			p.Pass.ClaimedFree = {}
			p.Pass.ClaimedPrime = {}
		end
		p.Pass.Xp += amount
	end)
end

function PassService:_applyReward(player: Player, reward: any)
	if typeof(reward) ~= "table" then
		return
	end
	local kind = reward.Kind
	local amount = reward.Amount or 1
	local id = reward.Id
	if kind == "Tokens" then
		self._data:AddTokens(player, amount)
	elseif kind == "Scrap" then
		self._data:AddScrap(player, amount)
	elseif kind == "SkinTickets" then
		self._data:AddSkinTickets(player, amount)
	elseif kind == "Weapon" and typeof(id) == "string" then
		self._data:UnlockWeapon(player, id)
	elseif kind == "Skin" and typeof(id) == "string" then
		self._data:GrantCosmetic(player, "Skins", id)
	elseif kind == "Wrap" and typeof(id) == "string" then
		self._data:GrantCosmetic(player, "Wraps", id)
	elseif kind == "Charm" and typeof(id) == "string" then
		self._data:GrantCosmetic(player, "Charms", id)
	elseif kind == "Emote" and typeof(id) == "string" then
		self._data:GrantCosmetic(player, "Emotes", id)
	elseif kind == "Finisher" and typeof(id) == "string" then
		self._data:GrantCosmetic(player, "Finishers", id)
	end
end

function PassService:_onClaim(player: Player, payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	local tier = tonumber(payload.Tier)
	local track = payload.Track -- "Free" | "Prime"
	if not tier or (track ~= "Free" and track ~= "Prime") then
		return
	end
	local tierDef = BattlePass.GetTier(tier)
	if not tierDef then
		return
	end

	local profile = self._data:GetOrLoad(player)
	local unlockedTier = BattlePass.TierFromXp(profile.Pass.Xp)
	if tier > unlockedTier then
		self:_result(player, false, "Tier locked")
		return
	end

	local key = tostring(tier)
	if track == "Free" then
		if profile.Pass.ClaimedFree[key] then
			self:_result(player, false, "Already claimed")
			return
		end
		if not tierDef.Free then
			self:_result(player, false, "No free reward")
			return
		end
		self._data:Mutate(player, function(p)
			p.Pass.ClaimedFree[key] = true
		end)
		self:_applyReward(player, tierDef.Free)
		self:_result(player, true, "Claimed free T" .. key)
	else
		if not profile.Pass.OwnsPrime then
			self:_result(player, false, "Prime required")
			return
		end
		if profile.Pass.ClaimedPrime[key] then
			self:_result(player, false, "Already claimed")
			return
		end
		if not tierDef.Prime then
			self:_result(player, false, "No prime reward")
			return
		end
		self._data:Mutate(player, function(p)
			p.Pass.ClaimedPrime[key] = true
		end)
		self:_applyReward(player, tierDef.Prime)
		self:_result(player, true, "Claimed prime T" .. key)
	end
end

function PassService:_result(player: Player, ok: boolean, message: string)
	if self._remotes.PassResult then
		self._remotes.PassResult:FireClient(player, { Ok = ok, Message = message })
	end
	self._data:Sync(player)
end

function PassService:DebugGrantPrime(player: Player)
	self._data:Mutate(player, function(p)
		p.Pass.OwnsPrime = true
	end)
end

function PassService:DebugAddXp(player: Player, amount: number)
	self:AddPassXp(player, amount)
end

return PassService
