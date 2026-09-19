--!strict
--[[
	HUD — crosshair, health, ammo, ability CD, round score.
	Safe-area aware; touch chrome lives in InputController.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")

local WeaponsConfig = require(game.ReplicatedStorage.Config.Weapons)
local OperatorsConfig = require(game.ReplicatedStorage.Config.Operators)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local HUDController = {}
HUDController.__index = HUDController

function HUDController.new(remotes: { [string]: RemoteEvent }, weaponController: any, abilityController: any)
	local self = setmetatable({
		_remotes = remotes,
		_weapons = weaponController,
		_abilities = abilityController,
		_gui = nil :: ScreenGui?,
		_labels = {} :: { [string]: TextLabel },
		_snapshot = {
			ScoreA = 0,
			ScoreB = 0,
			Phase = "Lobby",
			RoundNumber = 0,
			RoundsToWin = 5,
			WinType = "Rounds",
			WinTarget = 5,
			IsFFA = false,
			ModeId = "1v1",
		},
	}, HUDController)
	return self
end

function HUDController:Init()
	self:_build()
	self._remotes.MatchSnapshot.OnClientEvent:Connect(function(snap)
		if typeof(snap) == "table" then
			self._snapshot = snap
		end
	end)
	self._remotes.DamageNumber.OnClientEvent:Connect(function(payload)
		self:_damagePopup(payload)
	end)
	self._remotes.WeaponHit.OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" and payload.Hit then
			self:_hitmarker(payload.Headshot == true)
		end
	end)

	if self._remotes.FlashEffect then
		self._remotes.FlashEffect.OnClientEvent:Connect(function(payload)
			self:_flashBang(payload)
		end)
	end
	if self._remotes.KillFeed then
		self._remotes.KillFeed.OnClientEvent:Connect(function(payload)
			self:_killFeed(payload)
		end)
	end
	if self._remotes.DeathRecap then
		self._remotes.DeathRecap.OnClientEvent:Connect(function(payload)
			self:_deathRecap(payload)
		end)
	end
	if self._remotes.Announce then
		self._remotes.Announce.OnClientEvent:Connect(function(payload)
			self:_announce(payload)
		end)
	end
	if self._remotes.StandInReplaced then
		self._remotes.StandInReplaced.OnClientEvent:Connect(function(payload)
			if typeof(payload) == "table" then
				local msg = string.format(
					"Stand-in replaced: %s → %s",
					tostring(payload.ReplacedBotName or "?"),
					tostring(payload.PlayerName or "?")
				)
				print("[Latch]", msg)
				self:_flashAnnounce(msg)
			end
		end)
	end
	RunService.RenderStepped:Connect(function()
		self:_refresh()
	end)
end

function HUDController:_build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LatchHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	self._gui = gui

	local inset = GuiService:GetGuiInset()
	local topPad = math.max(inset.Y, 20)

	local function label(name: string, pos: UDim2, size: UDim2, text: string, textSize: number?): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position = pos
		l.Size = size
		l.Font = Enum.Font.GothamBold
		l.TextSize = textSize or 18
		l.TextColor3 = Color3.new(1, 1, 1)
		l.TextStrokeTransparency = 0.5
		l.Text = text
		l.Parent = gui
		self._labels[name] = l
		return l
	end

	label("Score", UDim2.new(0.5, -100, 0, topPad + 8), UDim2.fromOffset(200, 28), "0 — 0", 22).TextXAlignment =
		Enum.TextXAlignment.Center
	label("Phase", UDim2.new(0.5, -220, 0, topPad + 36), UDim2.fromOffset(440, 22), "LOBBY", 14).TextXAlignment =
		Enum.TextXAlignment.Center

	label("Health", UDim2.new(0, 24, 1, -70), UDim2.fromOffset(160, 28), "HP 100", 20)
	label("Ammo", UDim2.new(1, -200, 1, -70), UDim2.fromOffset(180, 28), "30 / 90", 20).TextXAlignment =
		Enum.TextXAlignment.Right
	label("Weapon", UDim2.new(1, -200, 1, -98), UDim2.fromOffset(180, 22), "Pulse AR", 16).TextXAlignment =
		Enum.TextXAlignment.Right
	label("Ability", UDim2.new(0.5, -80, 1, -48), UDim2.fromOffset(160, 22), "Ability Ready", 14).TextXAlignment =
		Enum.TextXAlignment.Center
	label("Announce", UDim2.new(0.5, -200, 0, topPad + 64), UDim2.fromOffset(400, 24), "", 15).TextXAlignment =
		Enum.TextXAlignment.Center
	if self._labels.Announce then
		self._labels.Announce.TextColor3 = Color3.fromRGB(255, 220, 140)
	end
	label("DeathRecap", UDim2.new(0.5, -220, 0.42, 0), UDim2.fromOffset(440, 32), "", 20).TextXAlignment =
		Enum.TextXAlignment.Center
	if self._labels.DeathRecap then
		self._labels.DeathRecap.TextColor3 = Color3.fromRGB(255, 180, 120)
		self._labels.DeathRecap.TextStrokeTransparency = 0.3
	end

	-- Crosshair
	local cross = Instance.new("Frame")
	cross.Name = "Crosshair"
	cross.AnchorPoint = Vector2.new(0.5, 0.5)
	cross.Position = UDim2.fromScale(0.5, 0.5)
	cross.Size = UDim2.fromOffset(4, 4)
	cross.BackgroundColor3 = Color3.new(1, 1, 1)
	cross.BorderSizePixel = 0
	cross.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = cross

	self._crossArms = {} :: { Frame }
	local function arm(dx: number, dy: number, w: number, h: number)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.new(0.5, dx, 0.5, dy)
		f.Size = UDim2.fromOffset(w, h)
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.BorderSizePixel = 0
		f.BackgroundTransparency = 0.15
		f.Parent = gui
		table.insert(self._crossArms, f)
	end
	arm(0, -12, 2, 10)
	arm(0, 12, 2, 10)
	arm(-12, 0, 10, 2)
	arm(12, 0, 10, 2)

	
	-- Flash overlay (Flash Can)
	local flash = Instance.new("Frame")
	flash.Name = "FlashOverlay"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 50
	flash.Parent = gui
	self._flashOverlay = flash

	-- Kill feed
	local feed = Instance.new("Frame")
	feed.Name = "KillFeed"
	feed.BackgroundTransparency = 1
	feed.AnchorPoint = Vector2.new(1, 0)
	feed.Position = UDim2.new(1, -16, 0, topPad + 90)
	feed.Size = UDim2.fromOffset(320, 160)
	feed.Parent = gui
	local feedLayout = Instance.new("UIListLayout")
	feedLayout.SortOrder = Enum.SortOrder.LayoutOrder
	feedLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	feedLayout.Padding = UDim.new(0, 4)
	feedLayout.Parent = feed
	self._killFeed = feed

	self._hitmarker = Instance.new("TextLabel")
	self._hitmarker.Name = "Hitmarker"
	self._hitmarker.AnchorPoint = Vector2.new(0.5, 0.5)
	self._hitmarker.Position = UDim2.fromScale(0.5, 0.5)
	self._hitmarker.Size = UDim2.fromOffset(40, 40)
	self._hitmarker.BackgroundTransparency = 1
	self._hitmarker.Text = "×"
	self._hitmarker.TextSize = 28
	self._hitmarker.Font = Enum.Font.GothamBold
	self._hitmarker.TextColor3 = Color3.fromRGB(255, 255, 255)
	self._hitmarker.Visible = false
	self._hitmarker.Parent = gui
end

function HUDController:_refresh()
	local snap = self._snapshot
	if self._labels.Score then
		local winType = snap.WinType or "Rounds"
		local modeId = tostring(snap.ModeId or "")
		if winType == "Eliminations" or winType == "GunCycle" or snap.IsFFA then
			-- Show local player's elim / gun progress
			local myElims = 0
			local myGun = nil
			local fighters = snap.Fighters
			if typeof(fighters) == "table" then
				for _, f in fighters do
					if typeof(f) == "table" and f.UserId == player.UserId then
						myElims = tonumber(f.Elims) or 0
						myGun = f.GunIndex
						break
					end
				end
			end
			local target = snap.WinTarget or 7
			if winType == "GunCycle" then
				self._labels.Score.Text = string.format("GUN %s/%s", tostring(myGun or 1), tostring(target))
			else
				self._labels.Score.Text = string.format("%d / %d", myElims, target)
			end
		elseif winType == "TeamScore" then
			local target = snap.WinTarget or 30
			self._labels.Score.Text = string.format("%d — %d  (to %d)", snap.ScoreA or 0, snap.ScoreB or 0, target)
		else
			self._labels.Score.Text = string.format("%d — %d", snap.ScoreA or 0, snap.ScoreB or 0)
		end
	end
	if self._labels.Phase then
		local phase = snap.Phase or "Lobby"
		local round = snap.RoundNumber or 0
		local modeBit = if typeof(snap.ModeId) == "string" and snap.ModeId ~= "" then ("  " .. tostring(snap.ModeId)) else ""
		local text = string.upper(tostring(phase)) .. modeBit .. (if round > 0 then ("  R" .. tostring(round)) else "")
		if typeof(snap.CurrentMapId) == "string" and (snap.CurrentMapId :: string) ~= "" then
			text = text .. "  ·  " .. (snap.CurrentMapId :: string)
		end
		if phase == "Lobby" and typeof(snap.FillEndsAt) == "number" then
			local remain = (snap.FillEndsAt :: number) - Workspace:GetServerTimeNow()
			if remain > 0 then
				text = text .. string.format("  BOT FILL %.0fs", remain)
			end
		end
		local fighters = snap.Fighters
		if typeof(fighters) == "table" and #fighters > 0 then
			local bits = {}
			for _, f in fighters do
				if typeof(f) == "table" then
					local n = tostring(f.DisplayName or "?")
					if f.IsBot then
						n ..= "*"
					end
					table.insert(bits, n)
				end
			end
			if #bits > 0 then
				text = text .. "  |  " .. table.concat(bits, " vs ")
			end
		end
		self._labels.Phase.Text = text
	end

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if self._labels.Health and hum then
		self._labels.Health.Text = string.format("HP %d", math.floor(hum.Health + 0.5))
	end

	local equipped = self._weapons:GetEquipped()
	local cfg = WeaponsConfig.Weapons[equipped :: any]
	local ammo = self._weapons:GetAmmo()
	if self._labels.Weapon and cfg then
		self._labels.Weapon.Text = cfg.DisplayName
	end
	-- Crosshair gap by weapon / ADS
	if self._crossArms and cfg then
		local gap = cfg.CrosshairGap or 12
		if self._weapons.IsAiming and self._weapons:IsAiming() then
			gap = math.max(4, gap * 0.55)
		end
		-- arms order: up, down, left, right
		if self._crossArms[1] then
			self._crossArms[1].Position = UDim2.new(0.5, 0, 0.5, -gap)
		end
		if self._crossArms[2] then
			self._crossArms[2].Position = UDim2.new(0.5, 0, 0.5, gap)
		end
		if self._crossArms[3] then
			self._crossArms[3].Position = UDim2.new(0.5, -gap, 0.5, 0)
		end
		if self._crossArms[4] then
			self._crossArms[4].Position = UDim2.new(0.5, gap, 0.5, 0)
		end
	end

	if self._labels.Ammo and cfg then
		if cfg.Kind == "Melee" then
			self._labels.Ammo.Text = "MELEE"
		elseif cfg.Kind == "Projectile" then
			self._labels.Ammo.Text = string.upper(cfg.UtilityKind or "UTIL")
		elseif cfg.Kind == "Utility" then
			self._labels.Ammo.Text = if (ammo and ammo[equipped] and (ammo[equipped].Mag or 0) > 0) then "STIM READY" else "STIM USED"
		else
			local a = ammo and ammo[equipped]
			if a then
				self._labels.Ammo.Text = string.format("%d / %d", a.Mag or 0, a.Reserve or 0)
			end
		end
	end

	if self._labels.Ability then
		local endsAt = self._abilities:GetCooldownEndsAt()
		local now = Workspace:GetServerTimeNow()
		local remain = endsAt - now
		if remain > 0 then
			self._labels.Ability.Text = string.format("Ability %.1fs", remain)
		else
			local opId = player:GetAttribute("LatchOperator")
			local op = if typeof(opId) == "string" then OperatorsConfig.Operators[opId :: any] else nil
			self._labels.Ability.Text = if op then (op.ActiveName .. " Ready") else "Ability Ready"
		end
	end
end

function HUDController:_hitmarker(headshot: boolean)
	if not self._hitmarker then
		return
	end
	self._hitmarker.TextColor3 = if headshot then Color3.fromRGB(255, 80, 80) else Color3.new(1, 1, 1)
	self._hitmarker.Visible = true
	task.delay(0.12, function()
		if self._hitmarker then
			self._hitmarker.Visible = false
		end
	end)
end

function HUDController:_damagePopup(payload: any)
	if typeof(payload) ~= "table" or not self._gui then
		return
	end
	-- Simple screen-space flash near crosshair
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromOffset(60, 24)
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.new(0.5, math.random(-40, 40), 0.5, -40 + math.random(-20, 10))
	l.Font = Enum.Font.GothamBold
	l.TextSize = 18
	l.TextColor3 = if payload.Headshot then Color3.fromRGB(255, 90, 90) else Color3.fromRGB(255, 220, 120)
	l.Text = tostring(payload.Amount or 0)
	l.Parent = self._gui
	task.delay(0.5, function()
		l:Destroy()
	end)
end

function HUDController:_announce(payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	local msg = tostring(payload.Message or "")
	if msg ~= "" then
		print("[Latch]", msg)
		self:_flashAnnounce(msg)
	end
end

function HUDController:_flashAnnounce(msg: string)
	if self._labels.Announce then
		self._labels.Announce.Text = msg
		task.delay(4, function()
			if self._labels.Announce and self._labels.Announce.Text == msg then
				self._labels.Announce.Text = ""
			end
		end)
	end
end


function HUDController:_flashBang(payload: any)
	if typeof(payload) ~= "table" or not self._flashOverlay then
		return
	end
	local intensity = tonumber(payload.Intensity) or 1
	local duration = tonumber(payload.Duration) or 1.6
	self._flashOverlay.BackgroundTransparency = math.clamp(1 - intensity, 0, 0.85)
	task.delay(math.max(0.1, duration), function()
		if self._flashOverlay then
			self._flashOverlay.BackgroundTransparency = 1
		end
	end)
end

function HUDController:_killFeed(payload: any)
	if typeof(payload) ~= "table" or not self._killFeed then
		return
	end
	local killer = tostring(payload.KillerName or "?")
	local victim = tostring(payload.VictimName or "?")
	local weapon = tostring(payload.WeaponName or payload.WeaponId or "")
	local hs = if payload.Headshot then " ●" else ""
	local row = Instance.new("TextLabel")
	row.BackgroundTransparency = 0.35
	row.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	row.Size = UDim2.new(1, 0, 0, 22)
	row.Font = Enum.Font.Gotham
	row.TextSize = 13
	row.TextColor3 = Color3.new(1, 1, 1)
	row.TextXAlignment = Enum.TextXAlignment.Right
	row.Text = string.format("%s [%s]%s  %s", killer, weapon, hs, victim)
	row.Parent = self._killFeed
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = row
	task.delay(5, function()
		row:Destroy()
	end)
end

function HUDController:_deathRecap(payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	local line = tostring(payload.Line or "")
	if line == "" then
		local killer = tostring(payload.KillerName or "?")
		local weapon = tostring(payload.WeaponName or "?")
		local dist = math.floor(tonumber(payload.Distance) or 0)
		local hs = if payload.Headshot then " head" else ""
		line = string.format("%s [%s] %dm%s", killer, weapon, dist, hs)
	end
	if self._labels.DeathRecap then
		self._labels.DeathRecap.Text = line
		task.delay(4.5, function()
			if self._labels.DeathRecap and self._labels.DeathRecap.Text == line then
				self._labels.DeathRecap.Text = ""
			end
		end)
	end
	-- Also echo on announce strip
	self:_flashAnnounce(line)
end

return HUDController
