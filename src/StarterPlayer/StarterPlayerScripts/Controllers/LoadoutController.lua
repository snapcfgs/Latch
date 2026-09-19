--!strict
--[[
	LoadoutController — loadout picker gated by UnlockedWeapons (Phase 4).
	Starters unlocked; others need Tokens (shop) or Debug Grant.
]]

local Players = game:GetService("Players")

local WeaponsConfig = require(game.ReplicatedStorage.Config.Weapons)
local Monetization = require(game.ReplicatedStorage.Config.Monetization)
local Cosmetics = require(game.ReplicatedStorage.Config.Cosmetics)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local LoadoutController = {}
LoadoutController.__index = LoadoutController

function LoadoutController.new(remotes: { [string]: RemoteEvent })
	local self = setmetatable({
		_remotes = remotes,
		_gui = nil :: ScreenGui?,
		_selection = {
			Primary = WeaponsConfig.DefaultLoadout.Primary,
			Secondary = WeaponsConfig.DefaultLoadout.Secondary,
			Melee = WeaponsConfig.DefaultLoadout.Melee,
			Utility = WeaponsConfig.DefaultLoadout.Utility,
		},
		_visible = true,
		_profile = nil :: any,
		_title = nil :: TextLabel?,
		_note = nil :: TextLabel?,
		_scroll = nil :: ScrollingFrame?,
		_strip = nil :: Frame?,
	}, LoadoutController)
	return self
end

function LoadoutController:Init()
	self:_build()
	self._remotes.MatchSnapshot.OnClientEvent:Connect(function(snap)
		if typeof(snap) ~= "table" then
			return
		end
		local phase = snap.Phase
		local show = phase == "Lobby" or phase == "OperatorLock" or phase == "MatchEnd"
		self:_setVisible(show)
	end)
	if self._remotes.ProfileSync then
		self._remotes.ProfileSync.OnClientEvent:Connect(function(profile)
			self._profile = profile
			if typeof(profile) == "table" and typeof(profile.EquippedLoadout) == "table" then
				local el = profile.EquippedLoadout
				if typeof(el.Primary) == "string" then
					self._selection.Primary = el.Primary
				end
				if typeof(el.Secondary) == "string" then
					self._selection.Secondary = el.Secondary
				end
				if typeof(el.Melee) == "string" then
					self._selection.Melee = el.Melee
				end
				if typeof(el.Utility) == "string" then
					self._selection.Utility = el.Utility
				end
			end
			self:_rebuildButtons()
		end)
	end
end

function LoadoutController:_isUnlocked(weaponId: string): boolean
	if self._profile and typeof(self._profile.UnlockedWeapons) == "table" then
		return self._profile.UnlockedWeapons[weaponId] == true
	end
	for _, id in Monetization.StarterWeapons do
		if id == weaponId then
			return true
		end
	end
	return false
end

function LoadoutController:_setVisible(v: boolean)
	self._visible = v
	if self._gui then
		self._gui.Enabled = v
	end
end

function LoadoutController:_send()
	if self._remotes.SetLoadout then
		self._remotes.SetLoadout:FireServer(self._selection)
	end
end

function LoadoutController:_rebuildButtons()
	local scroll = self._scroll
	if not scroll then
		return
	end
	for _, child in scroll:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = scroll

	local function addSlot(slot: string)
		local header = Instance.new("TextLabel")
		header.BackgroundTransparency = 1
		header.Size = UDim2.new(1, 0, 0, 18)
		header.Font = Enum.Font.GothamBold
		header.TextSize = 13
		header.TextColor3 = Color3.fromRGB(120, 200, 255)
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.Text = slot
		header.Parent = scroll

		for _, id in WeaponsConfig.GetBySlot(slot :: any) do
			local cfg = WeaponsConfig.Weapons[id]
			local unlocked = self:_isUnlocked(id)
			local price = Monetization.WeaponPrices[id]
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(1, 0, 0, 28)
			btn.BackgroundColor3 = if self._selection[slot] == id
				then Color3.fromRGB(50, 90, 70)
				elseif unlocked then Color3.fromRGB(36, 42, 56)
				else Color3.fromRGB(28, 28, 34)
			btn.TextColor3 = if unlocked then Color3.new(1, 1, 1) else Color3.fromRGB(120, 120, 130)
			btn.Font = Enum.Font.Gotham
			btn.TextSize = 13
			btn.TextXAlignment = Enum.TextXAlignment.Left
			if unlocked then
				btn.Text = "  " .. cfg.DisplayName
			else
				btn.Text = string.format("  🔒 %s (%s)", cfg.DisplayName, if price then (tostring(price) .. " Tok") else "locked")
			end
			btn.AutoButtonColor = unlocked
			btn.Parent = scroll
			local bc = Instance.new("UICorner")
			bc.CornerRadius = UDim.new(0, 6)
			bc.Parent = btn

			btn.MouseButton1Click:Connect(function()
				if not self:_isUnlocked(id) then
					if self._note then
						self._note.Text = "Locked — buy in Shop or Debug Grant"
					end
					return
				end
				self._selection[slot] = id
				self:_rebuildButtons()
				self:_send()
			end)
		end
	end

	for _, slot in WeaponsConfig.SlotOrder do
		addSlot(slot)
	end

	if self._title then
		self._title.Text = "Loadout"
	end
	if self._note then
		local tokens = if self._profile then tonumber(self._profile.Tokens) or 0 else 0
		self._note.Text = string.format("Tokens %d · locked guns need Shop / Debug", tokens)
	end
	self:_refreshStrip()
end

function LoadoutController:_swatchColor(weaponId: string): Color3
	local wrapId = nil
	if self._profile and typeof(self._profile.EquippedCosmetics) == "table" then
		wrapId = self._profile.EquippedCosmetics.Wrap
		local skins = self._profile.EquippedCosmetics.Skins
		if typeof(skins) == "table" and typeof(skins[weaponId]) == "string" then
			local skin = Cosmetics.Skins[skins[weaponId]]
			if skin then
				return skin.Color
			end
		end
	end
	if typeof(wrapId) == "string" and Cosmetics.Wraps[wrapId] then
		return Cosmetics.Wraps[wrapId].Color
	end
	local def = Cosmetics.DefaultSkinId(weaponId)
	if def and Cosmetics.Skins[def] then
		return Cosmetics.Skins[def].Color
	end
	return Color3.fromRGB(70, 78, 90)
end

function LoadoutController:_refreshStrip()
	if not self._strip then
		return
	end
	for _, child in self._strip:GetChildren() do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = self._strip
	local slots = { "Primary", "Secondary", "Melee", "Utility" }
	for i, slot in slots do
		local wid = self._selection[slot]
		local cfg = if typeof(wid) == "string" then WeaponsConfig.Weapons[wid :: any] else nil
		local cell = Instance.new("Frame")
		cell.Size = UDim2.fromOffset(64, 40)
		cell.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
		cell.BorderSizePixel = 0
		cell.Parent = self._strip
		local cc = Instance.new("UICorner")
		cc.CornerRadius = UDim.new(0, 6)
		cc.Parent = cell
		local sw = Instance.new("Frame")
		sw.Size = UDim2.fromOffset(10, 28)
		sw.Position = UDim2.fromOffset(4, 6)
		sw.BackgroundColor3 = if typeof(wid) == "string" then self:_swatchColor(wid) else Color3.fromRGB(60, 60, 70)
		sw.BorderSizePixel = 0
		sw.Parent = cell
		local sc = Instance.new("UICorner")
		sc.CornerRadius = UDim.new(0, 3)
		sc.Parent = sw
		local lab = Instance.new("TextLabel")
		lab.BackgroundTransparency = 1
		lab.Position = UDim2.fromOffset(16, 2)
		lab.Size = UDim2.fromOffset(46, 36)
		lab.Font = Enum.Font.GothamBold
		lab.TextSize = 10
		lab.TextColor3 = Color3.new(1, 1, 1)
		lab.TextWrapped = true
		lab.Text = string.format("%d\n%s", i, if cfg then cfg.DisplayName else "?")
		lab.Parent = cell
	end
end

function LoadoutController:_build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LatchLoadout"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	self._gui = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Position = UDim2.new(0, 16, 0.55, 80)
	panel.Size = UDim2.fromOffset(300, 380)
	panel.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	panel.BackgroundTransparency = 0.12
	panel.BorderSizePixel = 0
	panel.Active = true
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -12, 0, 28)
	title.Position = UDim2.fromOffset(8, 6)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Loadout"
	title.Parent = panel
	self._title = title

	local note = Instance.new("TextLabel")
	note.BackgroundTransparency = 1
	note.Size = UDim2.new(1, -12, 0, 18)
	note.Position = UDim2.fromOffset(8, 30)
	note.Font = Enum.Font.Gotham
	note.TextSize = 11
	note.TextColor3 = Color3.fromRGB(180, 190, 200)
	note.TextXAlignment = Enum.TextXAlignment.Left
	note.Text = "Unlocks gated by Tokens"
	note.Parent = panel
	self._note = note

	local strip = Instance.new("Frame")
	strip.Name = "LoadoutStrip"
	strip.BackgroundTransparency = 1
	strip.Position = UDim2.fromOffset(8, 50)
	strip.Size = UDim2.new(1, -16, 0, 44)
	strip.Parent = panel
	self._strip = strip

	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.Position = UDim2.fromOffset(8, 98)
	scroll.Size = UDim2.new(1, -16, 1, -142)
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = panel
	self._scroll = scroll

	local apply = Instance.new("TextButton")
	apply.Size = UDim2.new(1, -16, 0, 32)
	apply.Position = UDim2.new(0, 8, 1, -40)
	apply.BackgroundColor3 = Color3.fromRGB(60, 120, 80)
	apply.Font = Enum.Font.GothamBold
	apply.TextSize = 14
	apply.TextColor3 = Color3.new(1, 1, 1)
	apply.Text = "Apply Loadout"
	apply.Parent = panel
	local ac = Instance.new("UICorner")
	ac.CornerRadius = UDim.new(0, 8)
	ac.Parent = apply
	apply.MouseButton1Click:Connect(function()
		self:_send()
		if self._title then
			self._title.Text = string.format(
				"%s / %s / %s / %s",
				WeaponsConfig.Weapons[self._selection.Primary :: any].DisplayName,
				WeaponsConfig.Weapons[self._selection.Secondary :: any].DisplayName,
				WeaponsConfig.Weapons[self._selection.Melee :: any].DisplayName,
				WeaponsConfig.Weapons[self._selection.Utility :: any].DisplayName
			)
		end
	end)

	self:_rebuildButtons()
	task.defer(function()
		self:_send()
	end)
end

return LoadoutController
