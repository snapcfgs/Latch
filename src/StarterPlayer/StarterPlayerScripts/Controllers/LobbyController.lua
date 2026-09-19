--!strict
--[[
	LobbyController — queue pads (ProximityPrompt + touch) + mode menu for mobile.
	Queues via Remotes.RequestQueue only.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ProximityPromptService = game:GetService("ProximityPromptService")

local ModesConfig = require(game.ReplicatedStorage.Config.Modes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local LobbyController = {}
LobbyController.__index = LobbyController

function LobbyController.new(remotes: { [string]: RemoteEvent })
	local self = setmetatable({
		_remotes = remotes,
		_gui = nil :: ScreenGui?,
		_status = nil :: TextLabel?,
		_menuOpen = true,
		_phase = "Lobby",
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
					fill = " · filling…"
				end
				self._status.Text = string.format("Queue: %s (%d)%s", tostring(mode), q, fill)
			elseif self._phase == "OperatorLock" then
				self._status.Text = "Lock operator & loadout…"
			else
				self._status.Text = string.upper(self._phase)
			end
		end
	end)
end

function LobbyController:_queue(modeId: string)
	if self._phase ~= "Lobby" then
		return
	end
	self._remotes.RequestQueue:FireServer(modeId)
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
		-- Touch fallback (mobile walking onto pad)
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
						-- Debounce via attribute
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

function LobbyController:_buildMenu()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LatchLobbyMenu"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Parent = playerGui
	self._gui = gui

	local panel = Instance.new("Frame")
	panel.Name = "ModeMenu"
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -16, 0.5, 0)
	panel.Size = UDim2.fromOffset(200, 420)
	panel.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	panel.BackgroundTransparency = 0.12
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 32)
	title.Position = UDim2.fromOffset(0, 6)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = "QUEUE"
	title.Parent = panel

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Size = UDim2.new(1, -12, 0, 36)
	status.Position = UDim2.fromOffset(6, 34)
	status.Font = Enum.Font.Gotham
	status.TextSize = 12
	status.TextColor3 = Color3.fromRGB(180, 190, 210)
	status.TextWrapped = true
	status.Text = "Pick a mode (or step on a pad)"
	status.Parent = panel
	self._status = status

	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.Position = UDim2.fromOffset(8, 76)
	scroll.Size = UDim2.new(1, -16, 1, -120)
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
			btn.Size = UDim2.new(1, 0, 0, 36)
			btn.BackgroundColor3 = cfg.PadColor or Color3.fromRGB(50, 60, 80)
			btn.TextColor3 = Color3.new(1, 1, 1)
			btn.Font = Enum.Font.GothamBold
			btn.TextSize = 14
			btn.Text = cfg.DisplayName
			btn.Parent = scroll
			local bc = Instance.new("UICorner")
			bc.CornerRadius = UDim.new(0, 6)
			bc.Parent = btn
			btn.MouseButton1Click:Connect(function()
				self:_queue(modeId)
			end)
		end
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
