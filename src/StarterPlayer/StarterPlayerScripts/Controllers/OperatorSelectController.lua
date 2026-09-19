--!strict
--[[ Operator select + lobby queue UI. ]]

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
		local show = phase == "Lobby" or phase == "MatchEnd" -- hidden during MapVote / match
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
	gui.Parent = playerGui
	self._gui = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.45)
	panel.Size = UDim2.fromOffset(420, 360)
	panel.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.Active = true
	panel.Modal = true -- keep mouse free for lobby clicks in Studio
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 36)
	title.Position = UDim2.fromOffset(0, 8)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = "LATCH — Pick Operator"
	title.Parent = panel

	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(16, 50)
	list.Size = UDim2.new(1, -32, 0, 200)
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
		btn.TextSize = 15
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

	local queueRow = Instance.new("Frame")
	queueRow.BackgroundTransparency = 1
	queueRow.Position = UDim2.fromOffset(16, 270)
	queueRow.Size = UDim2.new(1, -32, 0, 70)
	queueRow.Parent = panel
	local qLayout = Instance.new("UIListLayout")
	qLayout.FillDirection = Enum.FillDirection.Horizontal
	qLayout.Padding = UDim.new(0, 12)
	qLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	qLayout.Parent = queueRow

	local function queueBtn(text: string, modeId: string)
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromOffset(160, 48)
		b.BackgroundColor3 = Color3.fromRGB(50, 140, 90)
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Font = Enum.Font.GothamBold
		b.TextSize = 18
		b.Text = text
		b.Parent = queueRow
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = b
		b.MouseButton1Click:Connect(function()
			self._remotes.RequestQueue:FireServer(modeId)
			title.Text = "Queued " .. modeId .. "…"
		end)
	end
	queueBtn("Queue 1v1", "1v1")
	queueBtn("Queue 2v2", "2v2")
end

return OperatorSelectController
