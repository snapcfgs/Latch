--!strict
--[[
	ContractService — 3 daily contracts; progress from match events.
	Studio / memory: refresh after StudioRefreshSeconds (30m) or new session.
	Live DataStore: UTC day key (24h).
]]

local ContractsConfig = require(game.ReplicatedStorage.Config.Contracts)

local ContractService = {}
ContractService.__index = ContractService

function ContractService.new(dataService: any, remotes: { [string]: RemoteEvent })
	local self = setmetatable({
		_data = dataService,
		_remotes = remotes,
	}, ContractService)
	return self
end

function ContractService:Init()
	if self._remotes.ContractClaim then
		self._remotes.ContractClaim.OnServerEvent:Connect(function(player, payload)
			self:_onClaim(player, payload)
		end)
	end
	if self._remotes.ContractRefresh then
		self._remotes.ContractRefresh.OnServerEvent:Connect(function(player)
			self:Ensure(player, true)
		end)
	end
end

function ContractService:_studioMode(): boolean
	return not self._data:UsesDataStore()
end

function ContractService:Ensure(player: Player, force: boolean?)
	local now = os.time()
	local dayKey = ContractsConfig.UtcDayKey(now)
	self._data:Mutate(player, function(p)
		local needs = force == true
		if p.Contracts.DayKey == "" or #p.Contracts.Active == 0 then
			needs = true
		elseif self:_studioMode() then
			if now >= (p.Contracts.RefreshAt or 0) then
				needs = true
			end
		else
			if p.Contracts.DayKey ~= dayKey then
				needs = true
			end
		end
		if not needs then
			return
		end
		local key = if self:_studioMode() then ("studio_" .. tostring(now)) else dayKey
		local picks = ContractsConfig.PickDaily(key, ContractsConfig.DailyCount)
		local active = {}
		for _, def in picks do
			table.insert(active, {
				Id = def.Id,
				Progress = 0,
				Target = def.Target,
				Claimed = false,
			})
		end
		p.Contracts.DayKey = if self:_studioMode() then key else dayKey
		p.Contracts.RefreshAt = now + ContractsConfig.StudioRefreshSeconds
		p.Contracts.Active = active
	end)
end

function ContractService:OnMatchEnd(player: Player, info: {
	Won: boolean,
	Kills: number,
	Damage: number,
	AbilityUses: number,
})
	self:Ensure(player)
	self._data:Mutate(player, function(p)
		for _, slot in p.Contracts.Active do
			if slot.Claimed then
				continue
			end
			local def = ContractsConfig.GetById(slot.Id)
			if not def then
				continue
			end
			local add = 0
			if def.Stat == "Kills" then
				add = info.Kills
			elseif def.Stat == "Wins" then
				add = if info.Won then 1 else 0
			elseif def.Stat == "Damage" then
				add = math.floor(info.Damage)
			elseif def.Stat == "Matches" then
				add = 1
			elseif def.Stat == "AbilityUses" then
				add = info.AbilityUses
			end
			slot.Progress = math.min(slot.Target, slot.Progress + add)
		end
	end)
end

function ContractService:_onClaim(player: Player, payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	local id = payload.Id
	if typeof(id) ~= "string" then
		return
	end
	self:Ensure(player)
	local profile = self._data:GetOrLoad(player)
	local slot = nil
	for _, s in profile.Contracts.Active do
		if s.Id == id then
			slot = s
			break
		end
	end
	if not slot then
		self:_result(player, false, "Unknown contract")
		return
	end
	if slot.Claimed then
		self:_result(player, false, "Already claimed")
		return
	end
	if slot.Progress < slot.Target then
		self:_result(player, false, "Incomplete")
		return
	end
	local def = ContractsConfig.GetById(id)
	if not def then
		self:_result(player, false, "Missing def")
		return
	end
	self._data:Mutate(player, function(p)
		for _, s in p.Contracts.Active do
			if s.Id == id then
				s.Claimed = true
			end
		end
		p.Tokens += def.RewardTokens
		p.Xp += def.RewardXp
		if def.RewardScrap then
			p.Scrap += def.RewardScrap
		end
	end)
	self:_result(player, true, "Claimed " .. def.DisplayName)
end

function ContractService:_result(player: Player, ok: boolean, message: string)
	if self._remotes.ContractResult then
		self._remotes.ContractResult:FireClient(player, { Ok = ok, Message = message })
	end
	self._data:Sync(player)
end

return ContractService
