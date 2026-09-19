--!strict
--[[
	LobbyController — hub UI: queue menu, player banner, hub tabs.
	Queues via Remotes.RequestQueue only.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ProximityPromptService = game:GetService("ProximityPromptService")
local GuiService = game:GetService("GuiService")

local ModesConfig = require(game.ReplicatedStorage.Config.Modes)
local Cosmetics = require(game.ReplicatedStorage.Config.Cosmetics)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local LobbyController = {}
LobbyController.__index = LobbyController

function LobbyController.new(remotes: { [string]: RemoteEvent }, audio: any?)
	local self = setmetatable({
		_remotes = remotes,
		_audio = audio,
		_gui = nil :: ScreenGui?,
		_status = nil :: TextLabel?,
		_banner = nil :: TextLabel?,
		_wrapSwatch = nil :: Frame?,
		_menuOpen = true,
		_phase = "Lobby",
		_profile = nil :: any,
		_padConns = {} :: { RBXScriptConnection },
	}, LobbyController)
	return self
end

function LobbyController:Init()
	self:_buildMenu()
	self:_hookPads()
	ProximityPromptService.PromptTriggered:Connect(function(prompt, triggerPlayer)
		if triggerPlayer ~= player then
			return
		end
		local pad = prompt.Parent
		if pad and pad:IsA("BasePart") and pad:GetAttribute("IsQueuePad") then
			local modeId = pad:GetAttribute("QueueModeId")
			if typeof(modeId) == "string" then
				self:_queue(modeId)
			end
		end
	end)

	if self._remotes.ProfileSync then
		self._remotes.ProfileSync.OnClientEvent:Connect(function(profile)
			self._profile = profile
			self:_refreshBanner()
		end)
	end
	task.defer(function()
		if self._remotes.RequestProfile then
			self._remotes.RequestProfile:FireServer()
		end
	end)

	self._remotes.MatchSnapshot.OnClientEvent:Connect(function(snap)
		if typeof(snap) ~= "table" then
			return
		end
		self._phase = tostring(snap.Phase or "Lobby")
		local show = self._phase == "Lobby" or self._phase == "MatchEnd" or self._phase == "MatchRecap"
		if self._gui then
			self._gui.Enabled = show
		end
		if self._status then
			local q = snap.QueueCount or 0
			local mode = snap.QueuedModeId or snap.ModeId or ""
			if self._phase == "Lobby" then
				local fill = ""
				if typeof(snap.FillEndsAt) == "number" then
					fill = " · bot fill…"
				end
				self._status.Text = string.format("Queue: %s (%d)%s\nPads = same as buttons", tostring(mode), q, fill)
			elseif self._phase == "OperatorLock" then
				self._status.Text = "Lock operator & loadout…"
			else
				self._status.Text = string.upper(self._phase)
			end
		end
	end)
end

function LobbyController:_refreshBanner()
	if not self._banner or not self._profile then
		return
	end
	local level = tonumber(self._profile.Level) or 1
	local streak = 0
	if typeof(self._profile.Stats) == "table" then
		streak = tonumber(self._profile.Stats.WinStreak) or 0
	end
	local wrapName = "—"
	local wrapColor = Color3.fromRGB(80, 80, 90)
	local wrapId = nil
	if typeof(self._profile.EquippedCosmetics) == "table" then
		wrapId = self._profile.EquippedCosmetics.Wrap
	end
	if typeof(wrapId) == "string" and Cosmetics.Wraps[wrapId] then
		local w = Cosmetics.Wraps[wrapId]
		wrapName = w.DisplayName
		wrapColor = w.Color
	end
	self._banner.Text = string.format("Lv %d  ·  Wrap %s  ·  Streak %d", level, wrapName, streak)
	if self._wrapSwatch then
		self._wrapSwatch.BackgroundColor3 = wrapColor
	end
end

function LobbyController:_queue(modeId: string)
	if self._phase ~= "Lobby" then
		return
	end
	self._remotes.RequestQueue:FireServer(modeId)
	if self._audio and self._audio.PlayQueue then
		self._audio:PlayQueue()
	end
	if self._status then
		local cfg = ModesConfig.Get(modeId)
		self._status.Text = "Queued " .. ((cfg and cfg.DisplayName) or modeId) .. "…"
	end
end

function LobbyController:_hookPads()
	task.spawn(function()
		local arena = Workspace:WaitForChild("LatchArena", 30)
		if not arena then
			return
		end
		local pads = arena:WaitForChild("QueuePads", 10)
		if not pads then
			return
		end
		for _, pad in pads:GetChildren() do
			if pad:IsA("BasePart") then
				pad.Touched:Connect(function(hit)
					if self._phase ~= "Lobby" then
						return
					end
					local char = player.Character
					if not char or not hit:IsDescendantOf(char) then
						return
					end
					local modeId = pad:GetAttribute("QueueModeId")
					if typeof(modeId) == "string" then
						local last = pad:GetAttribute("_LastTouchQueue")
						local now = os.clock()
						if typeof(last) == "number" and now - last < 2 then
							return
						end
						pad:SetAttribute("_LastTouchQueue", now)
						self:_queue(modeId)
					end
				end)
			end
		end
	end)
end

function LobbyController:_openHub(name: string)
	if self._audio and self._audio.PlayUIClick then
		self._audio:PlayUIClick()
	end
	local map = {
		Shop = "LatchOpenShop",
		Pass = "LatchOpenPass",
		Contracts = "LatchOpenContracts",
		Career = "LatchOpenCareer",
	}
	local globalName = map[name]
	if globalName then
		local fn = (_G :: any)[globalName]
		if typeof(fn) == "function" then
			fn()
		end
	end
end

function LobbyController:_buildMenu()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LatchLobbyMenu"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Parent = playerGui
	self._gui = gui

	local inset = GuiService:GetGuiInset()
	local topPad = math.max(inset.Y, 16)

	-- Player banner (level / wrap / streak)
	local bannerFrame = Instance.new("Frame")
	bannerFrame.Name = "PlayerBanner"
	bannerFrame.AnchorPoint = Vector2.new(0.5, 0)
	bannerFrame.Position = UDim2.new(0.5, 0, 0, topPad + 4)
	bannerFrame.Size = UDim2.fromOffset(360, 36)
	bannerFrame.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
	bannerFrame.BackgroundTransparency = 0.15
	bannerFrame.BorderSizePixel = 0
	bannerFrame.Parent = gui
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 8)
	bc.Parent = bannerFrame
	local swatch = Instance.new("Frame")
	swatch.Name = "WrapSwatch"
	swatch.Size = UDim2.fromOffset(18, 18)
	swatch.Position = UDim2.fromOffset(10, 9)
	swatch.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
	swatch.BorderSizePixel = 0
	swatch.Parent = bannerFrame
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(1, 0)
	sc.Parent = swatch
	self._wrapSwatch = swatch
	local banner = Instance.new("TextLabel")
	banner.BackgroundTransparency = 1
	banner.Size = UDim2.new(1, -40, 1, 0)
	banner.Position = UDim2.fromOffset(36, 0)
	banner.Font = Enum.Font.GothamBold
	banner.TextSize = 13
	banner.TextColor3 = Color3.new(1, 1, 1)
	banner.TextXAlignment = Enum.TextXAlignment.Left
	banner.Text = "Lv 1  ·  Wrap —  ·  Streak 0"
	banner.Parent = bannerFrame
	self._banner = banner

	local panel = Instance.new("Frame")
	panel.Name = "ModeMenu"
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -16, 0.5, 0)
	panel.Size = UDim2.fromOffset(210, 460)
	panel.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	panel.BackgroundTransparency = 0.12
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 28)
	title.Position = UDim2.fromOffset(0, 6)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = "QUEUE"
	title.Parent = panel

	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Size = UDim2.new(1, -12, 0, 28)
	hint.Position = UDim2.fromOffset(6, 30)
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 11
	hint.TextColor3 = Color3.fromRGB(150, 160, 180)
	hint.TextWrapped = true
	hint.Text = "Tap a mode · or step on a colored pad"
	hint.Parent = panel

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Size = UDim2.new(1, -12, 0, 36)
	status.Position = UDim2.fromOffset(6, 56)
	status.Font = Enum.Font.Gotham
	status.TextSize = 12
	status.TextColor3 = Color3.fromRGB(180, 190, 210)
	status.TextWrapped = true
	status.Text = "Ready"
	status.Parent = panel
	self._status = status

	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.Position = UDim2.fromOffset(8, 96)
	scroll.Size = UDim2.new(1, -16, 1, -200)
	scroll.ScrollBarThickness = 4
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = scroll

	for _, modeId in ModesConfig.MenuOrder do
		local cfg = ModesConfig.Modes[modeId]
		if cfg and cfg.ShowInMenu then
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(1, 0, 0, 38)
			btn.BackgroundColor3 = cfg.PadColor or Color3.fromRGB(50, 60, 80)
			btn.TextColor3 = Color3.new(1, 1, 1)
			btn.Font = Enum.Font.GothamBold
			btn.TextSize = 14
			btn.Text = "▶  " .. cfg.DisplayName
			btn.Parent = scroll
			local bc2 = Instance.new("UICorner")
			bc2.CornerRadius = UDim.new(0, 6)
			bc2.Parent = btn
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 1
			stroke.Color = Color3.fromRGB(255, 255, 255)
			stroke.Transparency = 0.75
			stroke.Parent = btn
			btn.MouseButton1Click:Connect(function()
				self:_queue(modeId)
			end)
		end
	end

	-- Hub tabs: Pass, Shop, Contracts, Career
	local eco = Instance.new("Frame")
	eco.BackgroundTransparency = 1
	eco.Size = UDim2.new(1, -16, 0, 56)
	eco.Position = UDim2.new(0, 8, 1, -104)
	eco.Parent = panel
	local ecoLayout = Instance.new("UIGridLayout")
	ecoLayout.CellSize = UDim2.fromOffset(90, 24)
	ecoLayout.CellPadding = UDim2.fromOffset(6, 4)
	ecoLayout.Parent = eco
	for _, info in {
		{ "Shop", "Shop" },
		{ "Pass", "Pass" },
		{ "Contracts", "Contracts" },
		{ "Career", "Career" },
	} do
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromOffset(90, 24)
		b.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Font = Enum.Font.GothamBold
		b.TextSize = 11
		b.Text = info[1]
		b.Parent = eco
		local bc3 = Instance.new("UICorner")
		bc3.CornerRadius = UDim.new(0, 5)
		bc3.Parent = b
		local tabName = info[2]
		b.MouseButton1Click:Connect(function()
			self:_openHub(tabName)
		end)
	end

	local leave = Instance.new("TextButton")
	leave.Size = UDim2.new(1, -16, 0, 32)
	leave.Position = UDim2.new(0, 8, 1, -40)
	leave.BackgroundColor3 = Color3.fromRGB(90, 50, 50)
	leave.TextColor3 = Color3.new(1, 1, 1)
	leave.Font = Enum.Font.Gotham
	leave.TextSize = 13
	leave.Text = "Leave Queue"
	leave.Parent = panel
	local lc = Instance.new("UICorner")
	lc.CornerRadius = UDim.new(0, 6)
	lc.Parent = leave
	leave.MouseButton1Click:Connect(function()
		if self._remotes.RequestLeaveQueue then
			self._remotes.RequestLeaveQueue:FireServer()
		end
		if self._status then
			self._status.Text = "Left queue"
		end
	end)
end

return LobbyController
