--!strict
--[[ Operator select — polished card row (lobby + OperatorLock). ]]

local Players = game:GetService("Players")

local OperatorsConfig = require(game.ReplicatedStorage.Config.Operators)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ACCENTS: { [string]: Color3 } = {
	Skid = Color3.fromRGB(80, 200, 255),
	Anchor = Color3.fromRGB(120, 140, 160),
	Splice = Color3.fromRGB(160, 100, 255),
	Jolt = Color3.fromRGB(255, 220, 80),
	Fuse = Color3.fromRGB(255, 120, 60),
	Warden = Color3.fromRGB(80, 220, 140),
}

local OperatorSelectController = {}
OperatorSelectController.__index = OperatorSelectController

function OperatorSelectController.new(remotes: { [string]: RemoteEvent }, audio: any?)
	local self = setmetatable({
		_remotes = remotes,
		_audio = audio,
		_gui = nil :: ScreenGui?,
		_visible = true,
		_title = nil :: TextLabel?,
		_selected = nil :: string?,
		_buttons = {} :: { [string]: TextButton },
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

function OperatorSelectController:_select(id: string)
	self._selected = id
	self._remotes.RequestOperator:FireServer(id)
	if self._audio and self._audio.PlayUIClick then
		self._audio:PlayUIClick()
	end
	local cfg = OperatorsConfig.Operators[id :: any]
	if self._title and cfg then
		self._title.Text = "OPERATOR · " .. cfg.DisplayName
	end
	for oid, btn in self._buttons do
		local accent = ACCENTS[oid] or Color3.fromRGB(40, 50, 70)
		if oid == id then
			btn.BackgroundColor3 = accent:Lerp(Color3.fromRGB(30, 40, 55), 0.35)
			local stroke = btn:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Transparency = 0.1
				stroke.Thickness = 2
			end
		else
			btn.BackgroundColor3 = Color3.fromRGB(32, 38, 52)
			local stroke = btn:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Transparency = 0.55
				stroke.Thickness = 1
			end
		end
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
	panel.Position = UDim2.new(0, 16, 0.42, 0)
	panel.Size = UDim2.fromOffset(300, 400)
	panel.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	panel.BackgroundTransparency = 0.12
	panel.BorderSizePixel = 0
	panel.Active = true
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 32)
	title.Position = UDim2.fromOffset(0, 8)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = "OPERATOR"
	title.Parent = panel
	self._title = title

	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(10, 44)
	list.Size = UDim2.new(1, -20, 1, -56)
	list.ScrollBarThickness = 4
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.BorderSizePixel = 0
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = list

	for _, id in OperatorsConfig.OperatorOrder do
		local cfg = OperatorsConfig.Operators[id]
		local accent = ACCENTS[id] or Color3.fromRGB(80, 100, 140)
		local btn = Instance.new("TextButton")
		btn.Name = id
		btn.Size = UDim2.new(1, 0, 0, 56)
		btn.BackgroundColor3 = Color3.fromRGB(32, 38, 52)
		btn.Text = ""
		btn.AutoButtonColor = true
		btn.Parent = list
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 8)
		bc.Parent = btn
		local stroke = Instance.new("UIStroke")
		stroke.Color = accent
		stroke.Thickness = 1
		stroke.Transparency = 0.55
		stroke.Parent = btn

		local stripe = Instance.new("Frame")
		stripe.Size = UDim2.new(0, 5, 1, -8)
		stripe.Position = UDim2.fromOffset(4, 4)
		stripe.BackgroundColor3 = accent
		stripe.BorderSizePixel = 0
		stripe.Parent = btn
		local sc = Instance.new("UICorner")
		sc.CornerRadius = UDim.new(0, 3)
		sc.Parent = stripe

		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(18, 6)
		name.Size = UDim2.new(1, -24, 0, 22)
		name.Font = Enum.Font.GothamBold
		name.TextSize = 15
		name.TextColor3 = Color3.new(1, 1, 1)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = cfg.DisplayName
		name.Parent = btn

		local sub = Instance.new("TextLabel")
		sub.BackgroundTransparency = 1
		sub.Position = UDim2.fromOffset(18, 28)
		sub.Size = UDim2.new(1, -24, 0, 20)
		sub.Font = Enum.Font.Gotham
		sub.TextSize = 12
		sub.TextColor3 = Color3.fromRGB(170, 180, 200)
		sub.TextXAlignment = Enum.TextXAlignment.Left
		sub.Text = cfg.ActiveName .. "  ·  " .. cfg.PassiveName
		sub.Parent = btn

		self._buttons[id] = btn
		btn.MouseButton1Click:Connect(function()
			self:_select(id)
		end)
	end
end

return OperatorSelectController
