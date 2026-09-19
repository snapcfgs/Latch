--!strict
--[[
	MatchRecapController — post-match scoreboard (humans+bots), Tokens/XP/pass bar tween, Rematch.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local BattlePass = require(game.ReplicatedStorage.Config.BattlePass)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MatchRecapController = {}
MatchRecapController.__index = MatchRecapController

function MatchRecapController.new(remotes: { [string]: RemoteEvent }, audio: any?)
	local self = setmetatable({
		_remotes = remotes,
		_audio = audio,
		_gui = nil :: ScreenGui?,
		_list = nil :: Frame?,
		_title = nil :: TextLabel?,
		_subtitle = nil :: TextLabel?,
		_rewardLabel = nil :: TextLabel?,
		_tokenBar = nil :: Frame?,
		_xpBar = nil :: Frame?,
		_passBar = nil :: Frame?,
		_lastModeId = "1v1",
		_profile = nil :: any,
		_myEntry = nil :: any,
	}, MatchRecapController)
	return self
end

function MatchRecapController:Init()
	self:_build()
	if self._remotes.MatchRecap then
		self._remotes.MatchRecap.OnClientEvent:Connect(function(payload)
			self:_show(payload)
		end)
	end
	if self._remotes.ProfileSync then
		self._remotes.ProfileSync.OnClientEvent:Connect(function(profile)
			self._profile = profile
		end)
	end
	self._remotes.MatchSnapshot.OnClientEvent:Connect(function(snap)
		if typeof(snap) ~= "table" then
			return
		end
		if snap.Phase == "Lobby" and self._gui then
			self._gui.Enabled = false
		end
	end)
end

function MatchRecapController:_build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LatchMatchRecap"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Enabled = false
	gui.Parent = playerGui
	self._gui = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(500, 480)
	panel.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 36)
	title.Position = UDim2.fromOffset(0, 10)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = "MATCH RECAP"
	title.Parent = panel
	self._title = title

	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Size = UDim2.new(1, -24, 0, 22)
	sub.Position = UDim2.fromOffset(12, 46)
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 14
	sub.TextColor3 = Color3.fromRGB(180, 190, 210)
	sub.Text = ""
	sub.Parent = panel
	self._subtitle = sub

	local header = Instance.new("TextLabel")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, -24, 0, 20)
	header.Position = UDim2.fromOffset(12, 72)
	header.Font = Enum.Font.GothamBold
	header.TextSize = 12
	header.TextColor3 = Color3.fromRGB(140, 150, 170)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = "  PLAYER                  K    D    DMG     TOK  XP"
	header.Parent = panel

	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(12, 94)
	list.Size = UDim2.new(1, -24, 0, 200)
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.Parent = list
	self._list = list

	-- Reward bars
	local reward = Instance.new("TextLabel")
	reward.Name = "Rewards"
	reward.BackgroundTransparency = 1
	reward.Size = UDim2.new(1, -24, 0, 20)
	reward.Position = UDim2.fromOffset(12, 300)
	reward.Font = Enum.Font.GothamBold
	reward.TextSize = 13
	reward.TextColor3 = Color3.fromRGB(255, 220, 140)
	reward.TextXAlignment = Enum.TextXAlignment.Left
	reward.Text = "Rewards"
	reward.Parent = panel
	self._rewardLabel = reward

	local function makeBar(y: number, label: string, color: Color3): Frame
		local wrap = Instance.new("Frame")
		wrap.BackgroundColor3 = Color3.fromRGB(30, 34, 44)
		wrap.Size = UDim2.new(1, -24, 0, 14)
		wrap.Position = UDim2.fromOffset(12, y)
		wrap.BorderSizePixel = 0
		wrap.Parent = panel
		local wc = Instance.new("UICorner")
		wc.CornerRadius = UDim.new(0, 4)
		wc.Parent = wrap
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.BackgroundColor3 = color
		fill.Size = UDim2.fromScale(0, 1)
		fill.BorderSizePixel = 0
		fill.Parent = wrap
		local fc = Instance.new("UICorner")
		fc.CornerRadius = UDim.new(0, 4)
		fc.Parent = fill
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.Gotham
		t.TextSize = 10
		t.TextColor3 = Color3.new(1, 1, 1)
		t.Text = label
		t.ZIndex = 2
		t.Parent = wrap
		return fill
	end
	self._tokenBar = makeBar(324, "Tokens", Color3.fromRGB(255, 200, 80))
	self._xpBar = makeBar(344, "Account XP", Color3.fromRGB(100, 180, 255))
	self._passBar = makeBar(364, "Pass XP", Color3.fromRGB(180, 100, 255))

	local rematch = Instance.new("TextButton")
	rematch.Name = "Rematch"
	rematch.Size = UDim2.new(0.48, -8, 0, 36)
	rematch.Position = UDim2.new(0, 12, 1, -52)
	rematch.BackgroundColor3 = Color3.fromRGB(50, 140, 90)
	rematch.TextColor3 = Color3.new(1, 1, 1)
	rematch.Font = Enum.Font.GothamBold
	rematch.TextSize = 15
	rematch.Text = "REMATCH"
	rematch.Parent = panel
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 8)
	rc.Parent = rematch
	rematch.MouseButton1Click:Connect(function()
		if self._audio and self._audio.PlayUIClick then
			self._audio:PlayUIClick()
		end
		if self._remotes.RequestRematch then
			self._remotes.RequestRematch:FireServer()
		elseif self._remotes.RequestQueue then
			self._remotes.RequestQueue:FireServer(self._lastModeId)
		end
		rematch.Text = "REMATCH QUEUED…"
		if self._subtitle then
			self._subtitle.Text = "Rematch — same mode, bots refill after recap"
		end
	end)

	local note = Instance.new("TextLabel")
	note.BackgroundTransparency = 1
	note.Size = UDim2.new(0.48, -8, 0, 36)
	note.Position = UDim2.new(0.52, 0, 1, -52)
	note.Font = Enum.Font.Gotham
	note.TextSize = 11
	note.TextColor3 = Color3.fromRGB(140, 150, 160)
	note.TextWrapped = true
	note.TextYAlignment = Enum.TextYAlignment.Center
	note.Text = "Rewards applied.\nLobby / rematch shortly…"
	note.Parent = panel
end

function MatchRecapController:_animateBars(entry: any)
	local tokens = tonumber(entry and entry.Tokens) or 0
	local xp = tonumber(entry and entry.XP) or 0
	local passXp = 0
	-- Approximate pass fill from profile if available
	local passFrac = 0.15
	if self._profile and typeof(self._profile.Pass) == "table" then
		local px = tonumber(self._profile.Pass.Xp) or 0
		local per = BattlePass.XpPerTier or 20
		passFrac = math.clamp((px % per) / per, 0.05, 1)
		passXp = px
	end
	if self._rewardLabel then
		self._rewardLabel.Text = string.format("+%d Tokens   +%d XP   Pass %d", tokens, xp, passXp)
	end
	local function tweenFill(bar: Frame?, target: number)
		if not bar then
			return
		end
		bar.Size = UDim2.fromScale(0, 1)
		TweenService:Create(bar, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(math.clamp(target, 0.05, 1), 1),
		}):Play()
	end
	tweenFill(self._tokenBar, math.clamp(tokens / 60, 0.08, 1))
	tweenFill(self._xpBar, math.clamp(xp / 120, 0.08, 1))
	tweenFill(self._passBar, passFrac)
end

function MatchRecapController:_show(payload: any)
	if typeof(payload) ~= "table" or not self._gui or not self._list then
		return
	end
	self._gui.Enabled = true
	self._lastModeId = tostring(payload.ModeId or self._lastModeId)
	local rematchBtn = self._gui:FindFirstChild("Rematch", true)
	if rematchBtn and rematchBtn:IsA("TextButton") then
		rematchBtn.Text = "REMATCH"
	end
	if self._title then
		self._title.Text = "MATCH RECAP"
	end
	if self._subtitle then
		self._subtitle.Text = string.format(
			"%s  ·  Winner %s  ·  %d–%d",
			tostring(payload.ModeId or ""),
			tostring(payload.Winner or "?"),
			tonumber(payload.ScoreA) or 0,
			tonumber(payload.ScoreB) or 0
		)
	end
	for _, child in self._list:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local entries = payload.Entries
	if typeof(entries) ~= "table" then
		return
	end
	local myEntry = nil
	for _, e in entries do
		if typeof(e) == "table" then
			local row = Instance.new("TextLabel")
			row.Size = UDim2.new(1, 0, 0, 26)
			row.BackgroundColor3 = Color3.fromRGB(30, 34, 48)
			row.BackgroundTransparency = 0.3
			row.BorderSizePixel = 0
			row.Font = Enum.Font.Gotham
			row.TextSize = 13
			row.TextColor3 = Color3.new(1, 1, 1)
			row.TextXAlignment = Enum.TextXAlignment.Left
			local name = tostring(e.DisplayName or "?")
			if e.IsBot then
				name = name .. " (bot)"
			end
			if #name > 18 then
				name = string.sub(name, 1, 17) .. "…"
			end
			row.Text = string.format(
				"  %-18s  %3d  %3d  %5d   %3d  %3d",
				name,
				tonumber(e.Kills) or 0,
				tonumber(e.Deaths) or 0,
				tonumber(e.Damage) or 0,
				tonumber(e.Tokens) or 0,
				tonumber(e.XP) or 0
			)
			row.Parent = self._list
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 4)
			c.Parent = row
			if e.UserId == player.UserId then
				myEntry = e
				row.BackgroundColor3 = Color3.fromRGB(40, 70, 55)
			end
		end
	end
	self._myEntry = myEntry
	self:_animateBars(myEntry or { Tokens = 0, XP = 0 })
end

return MatchRecapController
