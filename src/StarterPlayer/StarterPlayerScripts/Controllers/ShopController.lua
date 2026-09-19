--!strict
--[[
	ShopController — lobby shop UI (weapons / skins / cases / debug grants).
	Opens from Shop kiosk ProximityPrompt or Debug button.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")

local Monetization = require(game.ReplicatedStorage.Config.Monetization)
local WeaponsConfig = require(game.ReplicatedStorage.Config.Weapons)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ShopController = {}
ShopController.__index = ShopController

function ShopController.new(remotes: { [string]: RemoteEvent })
	local self = setmetatable({
		_remotes = remotes,
		_gui = nil :: ScreenGui?,
		_profile = nil :: any,
		_status = nil :: TextLabel?,
		_list = nil :: ScrollingFrame?,
		_tab = "Weapons",
		_currency = nil :: TextLabel?,
	}, ShopController)
	return self
end

function ShopController:Init()
	self:_build()
	if self._remotes.ProfileSync then
		self._remotes.ProfileSync.OnClientEvent:Connect(function(profile, _meta)
			self._profile = profile
			self:_refreshCurrency()
			if self._gui and self._gui.Enabled then
				self:_renderTab()
			end
		end)
	end
	if self._remotes.ShopResult then
		self._remotes.ShopResult.OnClientEvent:Connect(function(result)
			if typeof(result) == "table" and self._status then
				self._status.Text = tostring(result.Message or "")
			end
		end)
	end
	ProximityPromptService.PromptTriggered:Connect(function(prompt, triggerPlayer)
		if triggerPlayer ~= player then
			return
		end
		local part = prompt.Parent
		if part and part:IsA("BasePart") and part:GetAttribute("KioskType") == "Shop" then
			self:Open()
		end
	end)
	task.defer(function()
		if self._remotes.RequestProfile then
			self._remotes.RequestProfile:FireServer()
		end
	end)
end

function ShopController:Open()
	if self._gui then
		self._gui.Enabled = true
		self:_renderTab()
	end
end

function ShopController:Close()
	if self._gui then
		self._gui.Enabled = false
	end
end

function ShopController:_refreshCurrency()
	if not self._currency or not self._profile then
		return
	end
	self._currency.Text = string.format(
		"Tokens %d  ·  Scrap %d  ·  Tickets %d  ·  Lv %d",
		tonumber(self._profile.Tokens) or 0,
		tonumber(self._profile.Scrap) or 0,
		tonumber(self._profile.SkinTickets) or 0,
		tonumber(self._profile.Level) or 1
	)
end

function ShopController:_build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LatchShop"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 25
	gui.Enabled = false
	gui.Parent = playerGui
	self._gui = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(520, 460)
	panel.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -80, 0, 32)
	title.Position = UDim2.fromOffset(14, 10)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "SHOP"
	title.Parent = panel

	local close = Instance.new("TextButton")
	close.Size = UDim2.fromOffset(36, 28)
	close.Position = UDim2.new(1, -48, 0, 10)
	close.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Font = Enum.Font.GothamBold
	close.Text = "X"
	close.Parent = panel
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 6)
	cc.Parent = close
	close.MouseButton1Click:Connect(function()
		self:Close()
	end)

	local currency = Instance.new("TextLabel")
	currency.BackgroundTransparency = 1
	currency.Size = UDim2.new(1, -28, 0, 20)
	currency.Position = UDim2.fromOffset(14, 42)
	currency.Font = Enum.Font.Gotham
	currency.TextSize = 13
	currency.TextColor3 = Color3.fromRGB(180, 200, 160)
	currency.TextXAlignment = Enum.TextXAlignment.Left
	currency.Text = "…"
	currency.Parent = panel
	self._currency = currency

	local tabBar = Instance.new("Frame")
	tabBar.BackgroundTransparency = 1
	tabBar.Position = UDim2.fromOffset(14, 68)
	tabBar.Size = UDim2.new(1, -28, 0, 28)
	tabBar.Parent = panel
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 6)
	tabLayout.Parent = tabBar

	local tabs = { "Weapons", "Skins", "Cases", "Debug" }
	for _, name in tabs do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.fromOffset(90, 28)
		btn.BackgroundColor3 = Color3.fromRGB(40, 48, 64)
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 12
		btn.Text = name
		btn.Parent = tabBar
		local tc = Instance.new("UICorner")
		tc.CornerRadius = UDim.new(0, 6)
		tc.Parent = btn
		btn.MouseButton1Click:Connect(function()
			self._tab = name
			self:_renderTab()
		end)
	end

	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(14, 104)
	list.Size = UDim2.new(1, -28, 1, -150)
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list
	self._list = list

	local status = Instance.new("TextLabel")
	status.BackgroundTransparency = 1
	status.Size = UDim2.new(1, -28, 0, 28)
	status.Position = UDim2.new(0, 14, 1, -36)
	status.Font = Enum.Font.Gotham
	status.TextSize = 12
	status.TextColor3 = Color3.fromRGB(160, 180, 200)
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Text = if Monetization.IS_MONETIZATION_LIVE then "" else "Monetization OFF — use Debug tab for grants"
	status.Parent = panel
	self._status = status
end

function ShopController:_clearList()
	if not self._list then
		return
	end
	for _, c in self._list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

function ShopController:_row(text: string, onClick: (() -> ())?): TextButton
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 36)
	btn.BackgroundColor3 = Color3.fromRGB(36, 42, 56)
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 13
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.Text = "  " .. text
	btn.AutoButtonColor = true
	btn.Parent = self._list
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = btn
	if onClick then
		btn.MouseButton1Click:Connect(onClick)
	end
	return btn
end

function ShopController:_isUnlocked(weaponId: string): boolean
	if not self._profile or typeof(self._profile.UnlockedWeapons) ~= "table" then
		return false
	end
	return self._profile.UnlockedWeapons[weaponId] == true
end

function ShopController:_ownsSkin(id: string): boolean
	local oc = self._profile and self._profile.OwnedCosmetics
	return oc and oc.Skins and oc.Skins[id] == true
end

function ShopController:_renderTab()
	self:_clearList()
	self:_refreshCurrency()
	if self._tab == "Weapons" then
		for id, price in Monetization.WeaponPrices do
			local cfg = WeaponsConfig.Weapons[id :: any]
			local name = if cfg then cfg.DisplayName else id
			local owned = self:_isUnlocked(id)
			local label = if owned then string.format("%s — OWNED", name) else string.format("%s — %d Tokens", name, price)
			self:_row(label, function()
				if not owned and self._remotes.ShopBuy then
					self._remotes.ShopBuy:FireServer({ Kind = "Weapon", Id = id })
				end
			end)
		end
	elseif self._tab == "Skins" then
		for id, price in Monetization.SkinPrices do
			local owned = self:_ownsSkin(id)
			local label = if owned then id .. " — OWNED" else string.format("%s — %d Tokens", id, price)
			self:_row(label, function()
				if owned then
					if self._remotes.EquipCosmetic then
						self._remotes.EquipCosmetic:FireServer({ Kind = "Skin", Id = id })
					end
				elseif self._remotes.ShopBuy then
					self._remotes.ShopBuy:FireServer({ Kind = "Skin", Id = id })
				end
			end)
		end
	elseif self._tab == "Cases" then
		self:_row("Skin Case Alpha (1 Ticket)", function()
			if self._remotes.OpenCase then
				self._remotes.OpenCase:FireServer({ CaseId = "SkinCaseAlpha" })
			end
		end)
		self:_row("Skin Case Beta (1 Ticket)", function()
			if self._remotes.OpenCase then
				self._remotes.OpenCase:FireServer({ CaseId = "SkinCaseBeta" })
			end
		end)
	elseif self._tab == "Debug" then
		if Monetization.IS_MONETIZATION_LIVE and not RunService:IsStudio() then
			self:_row("Debug disabled (monetization live)")
			return
		end
		self:_row("Grant Starter Bundle (SMG + skin + 200)", function()
			self._remotes.DebugGrant:FireServer({ Action = "StarterBundle" })
		end)
		self:_row("Grant +200 Tokens", function()
			self._remotes.DebugGrant:FireServer({ Action = "Tokens", Amount = 200 })
		end)
		self:_row("Grant +5 Skin Tickets", function()
			self._remotes.DebugGrant:FireServer({ Action = "SkinTickets", Amount = 5 })
		end)
		self:_row("Unlock ALL weapons", function()
			self._remotes.DebugGrant:FireServer({ Action = "UnlockAllWeapons" })
		end)
		self:_row("Open Case Alpha (free)", function()
			self._remotes.DebugGrant:FireServer({ Action = "OpenCaseFree", CaseId = "SkinCaseAlpha" })
		end)
		self:_row("Grant Prime Pass", function()
			self._remotes.DebugGrant:FireServer({ Action = "PrimePass" })
		end)
		self:_row("Pass XP +20 (1 tier)", function()
			self._remotes.DebugGrant:FireServer({ Action = "PassXp", Amount = 20 })
		end)
	end
end

return ShopController
