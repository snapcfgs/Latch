--!strict
--[[
	CareerController — simple stats panel from ProfileSync.
]]

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CareerController = {}
CareerController.__index = CareerController

function CareerController.new(remotes: { [string]: RemoteEvent })
	local self = setmetatable({
		_remotes = remotes,
		_gui = nil :: ScreenGui?,
		_body = nil :: TextLabel?,
		_profile = nil :: any,
	}, CareerController)
	return self
end

function CareerController:Init()
	self:_build()
	if self._remotes.ProfileSync then
		self._remotes.ProfileSync.OnClientEvent:Connect(function(profile)
			self._profile = profile
			if self._gui and self._gui.Enabled then
				self:_render()
			end
		end)
	end
end

function CareerController:Open()
	if self._gui then
		self._gui.Enabled = true
		self:_render()
	end
end

function CareerController:Close()
	if self._gui then
		self._gui.Enabled = false
	end
end

function CareerController:_render()
	if not self._body then
		return
	end
	local p = self._profile
	if typeof(p) ~= "table" then
		self._body.Text = "Loading profile…"
		return
	end
	local s = p.Stats or {}
	self._body.Text = string.format(
		"Level %d  ·  XP %d\nTokens %d  ·  Scrap %d\n\nMatches %d\nWins %d  ·  Losses %d\nWin streak %d\n\nKills %d  ·  Deaths %d\nDamage %d\nHeadshots %d  ·  Abilities %d",
		tonumber(p.Level) or 1,
		tonumber(p.Xp) or 0,
		tonumber(p.Tokens) or 0,
		tonumber(p.Scrap) or 0,
		tonumber(s.Matches) or 0,
		tonumber(s.Wins) or 0,
		tonumber(s.Losses) or 0,
		tonumber(s.WinStreak) or 0,
		tonumber(s.Kills) or 0,
		tonumber(s.Deaths) or 0,
		tonumber(s.Damage) or 0,
		tonumber(s.Headshots) or 0,
		tonumber(s.AbilityUses) or 0
	)
end

function CareerController:_build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LatchCareer"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 24
	gui.Enabled = false
	gui.Parent = playerGui
	self._gui = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(340, 360)
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
	title.Position = UDim2.fromOffset(0, 8)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = "CAREER"
	title.Parent = panel

	local body = Instance.new("TextLabel")
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, -32, 1, -90)
	body.Position = UDim2.fromOffset(16, 48)
	body.Font = Enum.Font.Gotham
	body.TextSize = 15
	body.TextColor3 = Color3.fromRGB(210, 215, 230)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Text = ""
	body.Parent = panel
	self._body = body

	local close = Instance.new("TextButton")
	close.Size = UDim2.new(1, -32, 0, 32)
	close.Position = UDim2.new(0, 16, 1, -44)
	close.BackgroundColor3 = Color3.fromRGB(60, 70, 90)
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Font = Enum.Font.GothamBold
	close.TextSize = 14
	close.Text = "Close"
	close.Parent = panel
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 8)
	cc.Parent = close
	close.MouseButton1Click:Connect(function()
		self:Close()
	end)
end

return CareerController
