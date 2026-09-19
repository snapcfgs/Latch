--!strict
--[[
	MonetizationService — Prompt* behind IS_MONETIZATION_LIVE flag.
	Studio debug panel grants Starter Bundle (SMG + skin + 200 Tokens) when flag is false.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local Monetization = require(game.ReplicatedStorage.Config.Monetization)

local MonetizationService = {}
MonetizationService.__index = MonetizationService

function MonetizationService.new(
	dataService: any,
	shopService: any,
	passService: any,
	remotes: { [string]: RemoteEvent }
)
	local self = setmetatable({
		_data = dataService,
		_shop = shopService,
		_pass = passService,
		_remotes = remotes,
	}, MonetizationService)
	return self
end

function MonetizationService:Init()
	if self._remotes.DebugGrant then
		self._remotes.DebugGrant.OnServerEvent:Connect(function(player, payload)
			self:_onDebugGrant(player, payload)
		end)
	end
	if self._remotes.PromptPurchase then
		self._remotes.PromptPurchase.OnServerEvent:Connect(function(player, payload)
			self:_onPrompt(player, payload)
		end)
	end
end

function MonetizationService:_onPrompt(player: Player, payload: any)
	if not Monetization.IS_MONETIZATION_LIVE then
		if self._remotes.ShopResult then
			self._remotes.ShopResult:FireClient(player, {
				Ok = false,
				Message = "Monetization offline — use Debug Grant in Studio",
			})
		end
		return
	end
	if typeof(payload) ~= "table" then
		return
	end
	local productKey = payload.ProductKey
	if typeof(productKey) ~= "string" then
		return
	end
	local productId = Monetization.ProductIds[productKey]
	local passId = Monetization.GamePassIds[productKey]
	if typeof(productId) == "number" and productId > 0 then
		pcall(function()
			MarketplaceService:PromptProductPurchase(player, productId)
		end)
	elseif typeof(passId) == "number" and passId > 0 then
		pcall(function()
			MarketplaceService:PromptGamePassPurchase(player, passId)
		end)
	end
end

function MonetizationService:_onDebugGrant(player: Player, payload: any)
	-- Allow in Studio always; also when monetization flag is false (dev servers)
	if Monetization.IS_MONETIZATION_LIVE and not RunService:IsStudio() then
		return
	end
	if typeof(payload) ~= "table" then
		return
	end
	local action = payload.Action
	if typeof(action) ~= "string" then
		return
	end

	if action == "StarterBundle" then
		local g = Monetization.StarterBundleGrant
		self._data:UnlockWeapon(player, g.Weapon)
		self._data:GrantCosmetic(player, "Skins", g.Skin)
		self._data:AddTokens(player, g.Tokens)
		self:_msg(player, true, "Starter Bundle granted")
		return
	end

	if action == "Tokens" then
		local n = tonumber(payload.Amount) or 200
		self._data:AddTokens(player, n)
		self:_msg(player, true, "Granted " .. tostring(n) .. " Tokens")
		return
	end

	if action == "SkinTickets" then
		local n = tonumber(payload.Amount) or 5
		self._data:AddSkinTickets(player, n)
		self:_msg(player, true, "Granted Skin Tickets")
		return
	end

	if action == "Scrap" then
		local n = tonumber(payload.Amount) or 50
		self._data:AddScrap(player, n)
		self:_msg(player, true, "Granted Scrap")
		return
	end

	if action == "UnlockAllWeapons" then
		self._shop:DebugGrantAllWeapons(player)
		self:_msg(player, true, "All weapons unlocked")
		return
	end

	if action == "UnlockWeapon" and typeof(payload.Id) == "string" then
		self._shop:DebugGrantWeapon(player, payload.Id)
		self:_msg(player, true, "Unlocked " .. payload.Id)
		return
	end

	if action == "PrimePass" then
		self._pass:DebugGrantPrime(player)
		self:_msg(player, true, "Prime Pass granted")
		return
	end

	if action == "PassXp" then
		local n = tonumber(payload.Amount) or 20
		self._pass:DebugAddXp(player, n)
		self:_msg(player, true, "Pass XP +" .. tostring(n))
		return
	end

	if action == "OpenCaseFree" and typeof(payload.CaseId) == "string" then
		-- Route through shop with Debug flag
		if self._remotes.OpenCase then
			-- call internal
			self._shop:_onOpenCase(player, { CaseId = payload.CaseId, Debug = true })
		end
		return
	end

	self:_msg(player, false, "Unknown debug action")
end

function MonetizationService:_msg(player: Player, ok: boolean, message: string)
	if self._remotes.ShopResult then
		self._remotes.ShopResult:FireClient(player, { Ok = ok, Message = message })
	end
	self._data:Sync(player)
end

return MonetizationService
