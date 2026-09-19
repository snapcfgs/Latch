--!strict
--[[
	MapVoteController — minimal 3-button map vote UI + timer (Phase 1).
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MapVoteController = {}
MapVoteController.__index = MapVoteController

function MapVoteController.new(remotes: { [string]: RemoteEvent })
	local self = setmetatable({
		_remotes = remotes,
		_gui = nil :: ScreenGui?,
		_buttons = {} :: { [string]: TextButton },
		_tallyLabels = {} :: { [string]: TextLabel },
		_timerLabel = nil :: TextLabel?,
		_endsAt = nil :: number?,
		_selected = nil :: string?,
		_conn = nil :: RBXScriptConnection?,
	}, MapVoteController)
	return self
end

function MapVoteController:Init()
	self._remotes.MapVoteStart.OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" then
			self:_show(payload)
		end
	end)
	self._remotes.MapVoteUpdate.OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" then
			self:_updateTallies(payload.Tallies)
			if typeof(payload.EndsAt) == "number" then
				self._endsAt = payload.EndsAt
			end
		end
	end)
	self._remotes.MapVoteResult.OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" then
			self:_showResult(payload)
		end
	end)
end

function MapVoteController:_clear()
	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
	if self._gui then
		self._gui:Destroy()
		self._gui = nil
	end
	self._buttons = {}
	self._tallyLabels = {}
	self._timerLabel = nil
	self._endsAt = nil
	self._selected = nil
end

function MapVoteController:_show(payload: any)
	self:_clear()

	local options = payload.Options
	if typeof(options) ~= "table" or #options == 0 then
		return
	end
	self._endsAt = if typeof(payload.EndsAt) == "number" then payload.EndsAt else Workspace:GetServerTimeNow() + 8

	local gui = Instance.new("ScreenGui")
	gui.Name = "LatchMapVote"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Parent = playerGui
	self._gui = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.42)
	panel.Size = UDim2.fromOffset(520, 220)
	panel.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	panel.BackgroundTransparency = 0.12
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 32)
	title.Position = UDim2.fromOffset(0, 8)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = "VOTE FOR MAP"
	title.Parent = panel

	local timer = Instance.new("TextLabel")
	timer.Name = "Timer"
	timer.BackgroundTransparency = 1
	timer.Size = UDim2.new(1, 0, 0, 22)
	timer.Position = UDim2.fromOffset(0, 36)
	timer.Font = Enum.Font.Gotham
	timer.TextSize = 14
	timer.TextColor3 = Color3.fromRGB(200, 210, 230)
	timer.Text = "8s"
	timer.Parent = panel
	self._timerLabel = timer

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(16, 70)
	row.Size = UDim2.new(1, -32, 0, 130)
	row.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 12)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = row

	for _, opt in options do
		if typeof(opt) ~= "table" or typeof(opt.Id) ~= "string" then
			continue
		end
		local id = opt.Id :: string
		local colorTbl = opt.ThumbnailColor
		local thumb = Color3.fromRGB(80, 90, 110)
		if typeof(colorTbl) == "table" and #colorTbl >= 3 then
			thumb = Color3.new(colorTbl[1], colorTbl[2], colorTbl[3])
		end

		local btn = Instance.new("TextButton")
		btn.Name = id
		btn.Size = UDim2.fromOffset(150, 120)
		btn.BackgroundColor3 = thumb
		btn.Text = ""
		btn.AutoButtonColor = true
		btn.Parent = row
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 10)
		bc.Parent = btn

		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Size = UDim2.new(1, -8, 0, 28)
		name.Position = UDim2.fromOffset(4, 8)
		name.Font = Enum.Font.GothamBold
		name.TextSize = 16
		name.TextColor3 = Color3.new(1, 1, 1)
		name.TextStrokeTransparency = 0.4
		name.Text = tostring(opt.DisplayName or id)
		name.Parent = btn

		local size = Instance.new("TextLabel")
		size.BackgroundTransparency = 1
		size.Size = UDim2.new(1, -8, 0, 18)
		size.Position = UDim2.fromOffset(4, 34)
		size.Font = Enum.Font.Gotham
		size.TextSize = 12
		size.TextColor3 = Color3.fromRGB(230, 230, 240)
		size.Text = tostring(opt.SizeClass or "")
		size.Parent = btn

		local tally = Instance.new("TextLabel")
		tally.Name = "Tally"
		tally.BackgroundTransparency = 1
		tally.Size = UDim2.new(1, -8, 0, 22)
		tally.Position = UDim2.fromOffset(4, 88)
		tally.Font = Enum.Font.GothamBold
		tally.TextSize = 18
		tally.TextColor3 = Color3.new(1, 1, 1)
		tally.Text = "0"
		tally.Parent = btn

		self._buttons[id] = btn
		self._tallyLabels[id] = tally

		btn.MouseButton1Click:Connect(function()
			self._selected = id
			self._remotes.MapVoteCast:FireServer(id)
			for otherId, otherBtn in self._buttons do
				otherBtn.BackgroundTransparency = if otherId == id then 0 else 0.35
			end
		end)
	end

	self._conn = RunService.RenderStepped:Connect(function()
		if not self._timerLabel or not self._endsAt then
			return
		end
		local remain = math.max(0, self._endsAt - Workspace:GetServerTimeNow())
		self._timerLabel.Text = string.format("%.0fs remaining", remain)
	end)
end

function MapVoteController:_updateTallies(tallies: any)
	if typeof(tallies) ~= "table" then
		return
	end
	for id, label in self._tallyLabels do
		local n = tallies[id]
		label.Text = tostring(if typeof(n) == "number" then n else 0)
	end
end

function MapVoteController:_showResult(payload: any)
	local mapId = tostring(payload.MapId or "?")
	if self._timerLabel then
		self._timerLabel.Text = "Winner: " .. mapId
	end
	if typeof(payload.Tallies) == "table" then
		self:_updateTallies(payload.Tallies)
	end
	task.delay(1.4, function()
		self:_clear()
	end)
end

return MapVoteController
