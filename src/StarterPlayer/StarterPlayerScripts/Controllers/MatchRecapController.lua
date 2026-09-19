--!strict
--[[
	MatchRecapController — post-match K/D / damage / Tokens+XP placeholders (Phase 4).
]]

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MatchRecapController = {}
MatchRecapController.__index = MatchRecapController

function MatchRecapController.new(remotes: { [string]: RemoteEvent })
	local self = setmetatable({
		_remotes = remotes,
		_gui = nil :: ScreenGui?,
		_list = nil :: Frame?,
		_title = nil :: TextLabel?,
		_subtitle = nil :: TextLabel?,
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
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(480, 420)
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
	header.Position = UDim2.fromOffset(12, 78)
	header.Font = Enum.Font.GothamBold
	header.TextSize = 12
	header.TextColor3 = Color3.fromRGB(140, 150, 170)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = "  PLAYER                  K    D    DMG     TOK  XP"
	header.Parent = panel

	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(12, 100)
	list.Size = UDim2.new(1, -24, 1, -150)
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.Parent = list
	self._list = list

	local note = Instance.new("TextLabel")
	note.BackgroundTransparency = 1
	note.Size = UDim2.new(1, -24, 0, 36)
	note.Position = UDim2.new(0, 12, 1, -48)
	note.Font = Enum.Font.Gotham
	note.TextSize = 12
	note.TextColor3 = Color3.fromRGB(140, 150, 160)
	note.TextWrapped = true
	note.Text = "Tokens / XP placeholders — economy arrives in Phase 4.\nReturning to lobby…"
	note.Parent = panel
end

function MatchRecapController:_show(payload: any)
	if typeof(payload) ~= "table" or not self._gui or not self._list then
		return
	end
	self._gui.Enabled = true
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
		end
	end
end

return MatchRecapController
