--!strict
--[[
	HUD — crosshair, health, ammo, utility, ability CD radial, round score,
	team living pips, kill feed (5), scoreboard (Tab), damage numbers.
	Safe-area aware; touch chrome lives in InputController.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local WeaponsConfig = require(game.ReplicatedStorage.Config.Weapons)
local OperatorsConfig = require(game.ReplicatedStorage.Config.Operators)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local HUDController = {}
HUDController.__index = HUDController

function HUDController.new(remotes: { [string]: RemoteEvent }, weaponController: any, abilityController: any, audio: any?)
	local self = setmetatable({
		_remotes = remotes,
		_weapons = weaponController,
		_abilities = abilityController,
		_audio = audio,
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
		_scoreboardOpen = false,
		_killFeedLines = {} :: { TextLabel },
		_pipsA = nil :: Frame?,
		_pipsB = nil :: Frame?,
		_abilityRing = nil :: Frame?,
		_abilityFill = nil :: Frame?,
		_scoreboard = nil :: Frame?,
		_scoreboardList = nil :: Frame?,
		_crossCenter = nil :: Frame?,
		_lastWeaponId = nil :: string?,
	}, HUDController)
	return self
end

function HUDController:Init()
	self:_build()
	self._remotes.MatchSnapshot.OnClientEvent:Connect(function(snap)
		if typeof(snap) == "table" then
			self._snapshot = snap
			self:_refreshPips()
			if self._scoreboardOpen then
				self:_renderScoreboard()
			end
			local phase = snap.Phase
			local combat = phase == "Countdown" or phase == "Round" or phase == "RoundEnd"
			if self._gui then
				-- Keep HUD visible; hide scoreboard auto-close in lobby
				if not combat and self._scoreboardOpen and phase == "Lobby" then
					self:_setScoreboard(false)
				end
			end
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

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Tab then
			local phase = self._snapshot.Phase
			if phase == "Lobby" or phase == "MatchRecap" then
				return
			end
			self:_setScoreboard(not self._scoreboardOpen)
		end
	end)

	RunService.RenderStepped:Connect(function()
		self:_refresh()
	end)
end

function HUDController:ToggleScoreboard()
	local phase = self._snapshot.Phase
	if phase == "Lobby" or phase == "MatchRecap" then
		return
	end
	self:_setScoreboard(not self._scoreboardOpen)
end

function HUDController:_setScoreboard(open: boolean)
	self._scoreboardOpen = open
	if self._scoreboard then
		self._scoreboard.Visible = open
	end
	if open then
		self:_renderScoreboard()
	end
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
	local bottomPad = 24

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

	label("Score", UDim2.new(0.5, -110, 0, topPad + 8), UDim2.fromOffset(220, 28), "0 — 0", 22).TextXAlignment =
		Enum.TextXAlignment.Center
	label("Phase", UDim2.new(0.5, -240, 0, topPad + 36), UDim2.fromOffset(480, 22), "LOBBY", 14).TextXAlignment =
		Enum.TextXAlignment.Center

	-- Living pips under score
	local pipsRow = Instance.new("Frame")
	pipsRow.Name = "LivingPips"
	pipsRow.BackgroundTransparency = 1
	pipsRow.AnchorPoint = Vector2.new(0.5, 0)
	pipsRow.Position = UDim2.new(0.5, 0, 0, topPad + 58)
	pipsRow.Size = UDim2.fromOffset(280, 16)
	pipsRow.Parent = gui
	local pipsA = Instance.new("Frame")
	pipsA.Name = "PipsA"
	pipsA.BackgroundTransparency = 1
	pipsA.Size = UDim2.new(0.45, 0, 1, 0)
	pipsA.Position = UDim2.fromScale(0, 0)
	pipsA.Parent = pipsRow
	local la = Instance.new("UIListLayout")
	la.FillDirection = Enum.FillDirection.Horizontal
	la.HorizontalAlignment = Enum.HorizontalAlignment.Right
	la.Padding = UDim.new(0, 4)
	la.Parent = pipsA
	local pipsB = Instance.new("Frame")
	pipsB.Name = "PipsB"
	pipsB.BackgroundTransparency = 1
	pipsB.Size = UDim2.new(0.45, 0, 1, 0)
	pipsB.Position = UDim2.fromScale(0.55, 0)
	pipsB.Parent = pipsRow
	local lb = Instance.new("UIListLayout")
	lb.FillDirection = Enum.FillDirection.Horizontal
	lb.HorizontalAlignment = Enum.HorizontalAlignment.Left
	lb.Padding = UDim.new(0, 4)
	lb.Parent = pipsB
	self._pipsA = pipsA
	self._pipsB = pipsB

	label("Health", UDim2.new(0, 24, 1, -(70 + bottomPad)), UDim2.fromOffset(160, 28), "HP 100", 20)
	label("Ammo", UDim2.new(1, -200, 1, -(70 + bottomPad)), UDim2.fromOffset(180, 28), "30 / 90", 20).TextXAlignment =
		Enum.TextXAlignment.Right
	label("Weapon", UDim2.new(1, -200, 1, -(98 + bottomPad)), UDim2.fromOffset(180, 22), "Pulse AR", 16).TextXAlignment =
		Enum.TextXAlignment.Right
	label("Utility", UDim2.new(1, -200, 1, -(120 + bottomPad)), UDim2.fromOffset(180, 18), "Util ×1", 13).TextXAlignment =
		Enum.TextXAlignment.Right
	if self._labels.Utility then
		self._labels.Utility.TextColor3 = Color3.fromRGB(180, 210, 255)
	end

	-- Ability radial (center-bottom)
	local abilityWrap = Instance.new("Frame")
	abilityWrap.Name = "AbilityRadial"
	abilityWrap.AnchorPoint = Vector2.new(0.5, 1)
	abilityWrap.Position = UDim2.new(0.5, 0, 1, -(bottomPad + 8))
	abilityWrap.Size = UDim2.fromOffset(72, 72)
	abilityWrap.BackgroundColor3 = Color3.fromRGB(22, 26, 36)
	abilityWrap.BackgroundTransparency = 0.25
	abilityWrap.BorderSizePixel = 0
	abilityWrap.Parent = gui
	local ac = Instance.new("UICorner")
	ac.CornerRadius = UDim.new(1, 0)
	ac.Parent = abilityWrap
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(80, 180, 255)
	stroke.Parent = abilityWrap
	self._abilityRing = abilityWrap
	local fill = Instance.new("Frame")
	fill.Name = "CDFill"
	fill.AnchorPoint = Vector2.new(0.5, 1)
	fill.Position = UDim2.fromScale(0.5, 1)
	fill.Size = UDim2.fromScale(1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(40, 60, 90)
	fill.BackgroundTransparency = 0.35
	fill.BorderSizePixel = 0
	fill.Parent = abilityWrap
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(1, 0)
	fc.Parent = fill
	self._abilityFill = fill
	label("Ability", UDim2.new(0.5, -70, 1, -(bottomPad + 88)), UDim2.fromOffset(140, 18), "Ready", 12).TextXAlignment =
		Enum.TextXAlignment.Center

	label("Announce", UDim2.new(0.5, -200, 0, topPad + 78), UDim2.fromOffset(400, 24), "", 15).TextXAlignment =
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
	self._crossCenter = cross

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

	-- Flash overlay
	local flash = Instance.new("Frame")
	flash.Name = "FlashOverlay"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 50
	flash.Parent = gui
	self._flashOverlay = flash

	-- Kill feed (max 5)
	local feed = Instance.new("Frame")
	feed.Name = "KillFeed"
	feed.BackgroundTransparency = 1
	feed.AnchorPoint = Vector2.new(1, 0)
	feed.Position = UDim2.new(1, -16, 0, topPad + 100)
	feed.Size = UDim2.fromOffset(340, 140)
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

	-- Scoreboard (Tab)
	local sb = Instance.new("Frame")
	sb.Name = "Scoreboard"
	sb.AnchorPoint = Vector2.new(0.5, 0.5)
	sb.Position = UDim2.fromScale(0.5, 0.45)
	sb.Size = UDim2.fromOffset(460, 320)
	sb.BackgroundColor3 = Color3.fromRGB(12, 14, 22)
	sb.BackgroundTransparency = 0.12
	sb.BorderSizePixel = 0
	sb.Visible = false
	sb.ZIndex = 40
	sb.Parent = gui
	local sbc = Instance.new("UICorner")
	sbc.CornerRadius = UDim.new(0, 12)
	sbc.Parent = sb
	local sbt = Instance.new("TextLabel")
	sbt.BackgroundTransparency = 1
	sbt.Size = UDim2.new(1, 0, 0, 32)
	sbt.Position = UDim2.fromOffset(0, 8)
	sbt.Font = Enum.Font.GothamBold
	sbt.TextSize = 18
	sbt.TextColor3 = Color3.new(1, 1, 1)
	sbt.Text = "SCOREBOARD"
	sbt.ZIndex = 41
	sbt.Parent = sb
	local sbHint = Instance.new("TextLabel")
	sbHint.BackgroundTransparency = 1
	sbHint.Size = UDim2.new(1, 0, 0, 16)
	sbHint.Position = UDim2.fromOffset(0, 36)
	sbHint.Font = Enum.Font.Gotham
	sbHint.TextSize = 11
	sbHint.TextColor3 = Color3.fromRGB(140, 150, 170)
	sbHint.Text = "Tab / SCOREBOARD · humans + bots"
	sbHint.ZIndex = 41
	sbHint.Parent = sb
	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(12, 58)
	list.Size = UDim2.new(1, -24, 1, -70)
	list.ZIndex = 41
	list.Parent = sb
	local sll = Instance.new("UIListLayout")
	sll.Padding = UDim.new(0, 4)
	sll.Parent = list
	self._scoreboard = sb
	self._scoreboardList = list
end

function HUDController:_clearPips(frame: Frame?)
	if not frame then
		return
	end
	for _, c in frame:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
end

function HUDController:_addPip(parent: Frame, alive: boolean, isBot: boolean)
	local pip = Instance.new("Frame")
	pip.Size = UDim2.fromOffset(12, 12)
	pip.BackgroundColor3 = if alive then Color3.fromRGB(90, 220, 120) else Color3.fromRGB(60, 60, 70)
	pip.BackgroundTransparency = if alive then 0.05 else 0.35
	pip.BorderSizePixel = 0
	pip.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = pip
	if isBot then
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1
		stroke.Color = Color3.fromRGB(200, 180, 80)
		stroke.Transparency = 0.3
		stroke.Parent = pip
	end
end

function HUDController:_refreshPips()
	self:_clearPips(self._pipsA)
	self:_clearPips(self._pipsB)
	local fighters = self._snapshot.Fighters
	if typeof(fighters) ~= "table" or not self._pipsA or not self._pipsB then
		return
	end
	local phase = self._snapshot.Phase
	if phase == "Lobby" or phase == "MatchRecap" then
		return
	end
	if self._snapshot.IsFFA then
		-- Single row in A for FFA
		for _, f in fighters do
			if typeof(f) == "table" then
				self:_addPip(self._pipsA, f.Alive == true, f.IsBot == true)
			end
		end
		return
	end
	for _, f in fighters do
		if typeof(f) == "table" then
			local team = tostring(f.Team or "A")
			local parent = if team == "B" then self._pipsB else self._pipsA
			self:_addPip(parent :: Frame, f.Alive == true, f.IsBot == true)
		end
	end
end

function HUDController:_renderScoreboard()
	if not self._scoreboardList then
		return
	end
	for _, c in self._scoreboardList:GetChildren() do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	local fighters = self._snapshot.Fighters
	if typeof(fighters) ~= "table" then
		return
	end
	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 20)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.GothamBold
	header.TextSize = 12
	header.TextColor3 = Color3.fromRGB(140, 150, 170)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = "  NAME                    OP       TEAM  HP"
	header.ZIndex = 42
	header.Parent = self._scoreboardList

	local sorted = {}
	for _, f in fighters do
		table.insert(sorted, f)
	end
	table.sort(sorted, function(a, b)
		if typeof(a) ~= "table" or typeof(b) ~= "table" then
			return false
		end
		local ta = tostring(a.Team or "A")
		local tb = tostring(b.Team or "A")
		if ta ~= tb then
			return ta < tb
		end
		return tostring(a.DisplayName or "") < tostring(b.DisplayName or "")
	end)

	for _, f in sorted do
		if typeof(f) == "table" then
			local row = Instance.new("TextLabel")
			row.Size = UDim2.new(1, 0, 0, 24)
			row.BackgroundColor3 = if f.Alive then Color3.fromRGB(28, 34, 48) else Color3.fromRGB(40, 28, 28)
			row.BackgroundTransparency = 0.25
			row.BorderSizePixel = 0
			row.Font = Enum.Font.Gotham
			row.TextSize = 13
			row.TextColor3 = Color3.new(1, 1, 1)
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.ZIndex = 42
			local name = tostring(f.DisplayName or "?")
			if f.IsBot then
				name ..= " *"
			end
			if #name > 18 then
				name = string.sub(name, 1, 17) .. "…"
			end
			row.Text = string.format(
				"  %-18s  %-8s  %-4s  %s",
				name,
				tostring(f.OperatorId or "—"),
				tostring(f.Team or "?"),
				if f.Alive then "ALIVE" else "DOWN"
			)
			row.Parent = self._scoreboardList
			local rc = Instance.new("UICorner")
			rc.CornerRadius = UDim.new(0, 4)
			rc.Parent = row
		end
	end
end

function HUDController:_applyCrosshairStyle(cfg: any)
	if not self._crossArms or not cfg then
		return
	end
	local kind = cfg.Kind
	local color = Color3.new(1, 1, 1)
	local armW, armH = 2, 10
	local thick = 2
	if kind == "Melee" then
		color = Color3.fromRGB(255, 200, 120)
		armW, armH = 3, 8
	elseif kind == "Projectile" or kind == "Utility" then
		color = Color3.fromRGB(140, 200, 255)
		armW, armH = 2, 6
	elseif (cfg.CrosshairGap or 12) <= 8 then
		-- sniper-ish
		color = Color3.fromRGB(180, 255, 200)
		armW, armH = 2, 14
	elseif (cfg.CrosshairGap or 12) >= 18 then
		-- shotgun-ish
		color = Color3.fromRGB(255, 220, 160)
		armW, armH = 3, 8
	end
	if self._crossCenter then
		self._crossCenter.BackgroundColor3 = color
	end
	for i, arm in self._crossArms do
		arm.BackgroundColor3 = color
		if i <= 2 then
			arm.Size = UDim2.fromOffset(thick, armH)
		else
			arm.Size = UDim2.fromOffset(armH, thick)
		end
	end
end

function HUDController:_refresh()
	local snap = self._snapshot
	if self._labels.Score then
		local winType = snap.WinType or "Rounds"
		if winType == "Eliminations" or winType == "GunCycle" or snap.IsFFA then
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

	if equipped ~= self._lastWeaponId and cfg then
		self._lastWeaponId = equipped :: string?
		self:_applyCrosshairStyle(cfg)
	end

	-- Crosshair gap by weapon / ADS
	if self._crossArms and cfg then
		local gap = cfg.CrosshairGap or 12
		if self._weapons.IsAiming and self._weapons:IsAiming() then
			gap = math.max(4, gap * 0.55)
		end
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

	-- Utility count from loadout utility slot ammo
	if self._labels.Utility then
		local utilId = nil
		if self._weapons.GetLoadoutOrder then
			local order = self._weapons:GetLoadoutOrder()
			if typeof(order) == "table" then
				utilId = order[4]
			end
		end
		if typeof(utilId) ~= "string" then
			utilId = WeaponsConfig.DefaultLoadout.Utility
		end
		local ua = ammo and ammo[utilId]
		local count = if ua then (ua.Mag or 0) else 0
		local uCfg = WeaponsConfig.Weapons[utilId :: any]
		local name = if uCfg then uCfg.DisplayName else "Util"
		self._labels.Utility.Text = string.format("%s ×%d", name, count)
	end

	-- Ability radial + label
	local endsAt = self._abilities:GetCooldownEndsAt()
	local now = Workspace:GetServerTimeNow()
	local remain = endsAt - now
	local opId = player:GetAttribute("LatchOperator")
	local op = if typeof(opId) == "string" then OperatorsConfig.Operators[opId :: any] else nil
	local cd = if op then op.Cooldown else 8
	if self._labels.Ability then
		if remain > 0 then
			self._labels.Ability.Text = string.format("%.1fs", remain)
		else
			self._labels.Ability.Text = if op then (op.ActiveName .. " Ready") else "Ability Ready"
		end
	end
	if self._abilityFill and self._abilityRing then
		local frac = 0
		if remain > 0 and cd > 0 then
			frac = math.clamp(remain / cd, 0, 1)
		end
		self._abilityFill.Size = UDim2.fromScale(1, frac)
		local stroke = self._abilityRing:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if remain > 0 then Color3.fromRGB(100, 110, 130) else Color3.fromRGB(80, 200, 255)
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
	local tween = TweenService:Create(l, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = l.Position - UDim2.fromOffset(0, 28),
		TextTransparency = 1,
	})
	tween:Play()
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
	table.insert(self._killFeedLines, row)
	while #self._killFeedLines > 5 do
		local old = table.remove(self._killFeedLines, 1)
		if old then
			old:Destroy()
		end
	end
	task.delay(5, function()
		local idx = table.find(self._killFeedLines, row)
		if idx then
			table.remove(self._killFeedLines, idx)
		end
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
	self:_flashAnnounce(line)
end

return HUDController
