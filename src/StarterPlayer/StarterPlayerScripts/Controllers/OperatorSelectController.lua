--!strict
--[[ Operator select UI (lobby). Queue lives in LobbyController (Phase 3). ]]

local Players = game:GetService("Players")

local OperatorsConfig = require(game.ReplicatedStorage.Config.Operators)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local OperatorSelectController = {}
OperatorSelectController.__index = OperatorSelectController

function OperatorSelectController.new(remotes: { [string]: RemoteEvent })
	local self = setmetatable({
		_remotes = remotes,
		_gui = nil :: ScreenGui?,
		_visible = true,
	}, OperatorSelectController)
	return self
end

function OperatorSelectController:Init()
	self:_build()
	self._remotes.MatchSnapshot.OnClientEvent:Connect(function(snap)
		if typeof(snap) ~= "table" then
			return
		end
		local phase = snap.Phase
		-- Visible in Lobby + OperatorLock (pre-countdown pick) + MatchRecap fade
		local show = phase == "Lobby" or phase == "OperatorLock" or phase == "MatchEnd"
		self:_setVisible(show)
	end)
end

function OperatorSelectController:_setVisible(v: boolean)
	self._visible = v
	if self._gui then
		self._gui.Enabled = v
	end
end

function OperatorSelectController:_build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LatchOperatorSelect"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 6
	gui.Parent = playerGui
	self._gui = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Position = UDim2.new(0, 16, 0.5, 0)
	panel.Size = UDim2.fromOffset(280, 280)
	panel.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.Active = true
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 36)
	title.Position = UDim2.fromOffset(0, 8)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = "OPERATOR"
	title.Parent = panel

	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(12, 48)
	list.Size = UDim2.new(1, -24, 1, -60)
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = list

	for _, id in OperatorsConfig.OperatorOrder do
		local cfg = OperatorsConfig.Operators[id]
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 0, 44)
		btn.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.Font = Enum.Font.Gotham
		btn.TextSize = 14
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.Text = string.format("  %s — %s", cfg.DisplayName, cfg.ActiveName)
		btn.Parent = list
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 8)
		bc.Parent = btn
		btn.MouseButton1Click:Connect(function()
			self._remotes.RequestOperator:FireServer(id)
			title.Text = "Selected: " .. cfg.DisplayName
		end)
	end
end

return OperatorSelectController
