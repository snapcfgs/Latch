--!strict
--[[
	ContractController — daily contracts board (lobby kiosk).
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local ContractsConfig = require(game.ReplicatedStorage.Config.Contracts)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ContractController = {}
ContractController.__index = ContractController

function ContractController.new(remotes: { [string]: RemoteEvent })
	local self = setmetatable({
		_remotes = remotes,
		_gui = nil :: ScreenGui?,
		_profile = nil :: any,
		_list = nil :: Frame?,
		_status = nil :: TextLabel?,
		_header = nil :: TextLabel?,
	}, ContractController)
	return self
end

function ContractController:Init()
	self:_build()
	if self._remotes.ProfileSync then
		self._remotes.ProfileSync.OnClientEvent:Connect(function(profile)
			self._profile = profile
			if self._gui and self._gui.Enabled then
				self:_render()
			end
		end)
	end
	if self._remotes.ContractResult then
		self._remotes.ContractResult.OnClientEvent:Connect(function(result)
			if typeof(result) == "table" and self._status then
				self._status.Text = tostring(result.Message or "")
			end
		end)
	end
	ProximityPromptService.PromptTriggered:Connect(function(prompt, triggerPlayer)
		if triggerPlayer ~= player then
			return
		end
		local part = prompt.Parent
		if part and part:IsA("BasePart") and part:GetAttribute("KioskType") == "Contracts" then
			self:Open()
		end
	end)
end

function ContractController:Open()
	if self._gui then
		self._gui.Enabled = true
		self:_render()
	end
end

function ContractController:Close()
	if self._gui then
		self._gui.Enabled = false
	end
end

function ContractController:_build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LatchContracts"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 27
	gui.Enabled = false
	gui.Parent = playerGui
	self._gui = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(440, 320)
	panel.BackgroundColor3 = Color3.fromRGB(28, 22, 16)
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -80, 0, 28)
	title.Position = UDim2.fromOffset(14, 10)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "DAILY CONTRACTS"
	title.Parent = panel

	local close = Instance.new("TextButton")
	close.Size = UDim2.fromOffset(36, 28)
	close.Position = UDim2.new(1, -48, 0, 10)
	close.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
	close.Text = "X"
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Font = Enum.Font.GothamBold
	close.Parent = panel
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 6)
	cc.Parent = close
	close.MouseButton1Click:Connect(function()
		self:Close()
	end)

	local header = Instance.new("TextLabel")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, -28, 0, 36)
	header.Position = UDim2.fromOffset(14, 42)
	header.Font = Enum.Font.Gotham
	header.TextSize = 12
	header.TextColor3 = Color3.fromRGB(220, 190, 140)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.TextWrapped = true
	header.Text = "3 dailies — Studio refreshes ~30m / session; live uses UTC day"
	header.Parent = panel
	self._header = header

	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(14, 88)
	list.Size = UDim2.new(1, -28, 1, -130)
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = list
	self._list = list

	local status = Instance.new("TextLabel")
	status.BackgroundTransparency = 1
	status.Size = UDim2.new(1, -28, 0, 24)
	status.Position = UDim2.new(0, 14, 1, -32)
	status.Font = Enum.Font.Gotham
	status.TextSize = 12
	status.TextColor3 = Color3.fromRGB(200, 180, 140)
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Text = ""
	status.Parent = panel
	self._status = status
end

function ContractController:_render()
	if not self._list then
		return
	end
	for _, c in self._list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local contracts = self._profile and self._profile.Contracts
	local active = contracts and contracts.Active
	if typeof(active) ~= "table" or #active == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 40)
		empty.BackgroundTransparency = 1
		empty.Font = Enum.Font.Gotham
		empty.TextSize = 14
		empty.TextColor3 = Color3.fromRGB(180, 160, 140)
		empty.Text = "No contracts — wait for profile sync"
		empty.Parent = self._list
		return
	end
	if self._header and contracts then
		self._header.Text = string.format(
			"Key %s · refresh at %s\nStudio: %ds session refresh · Live: UTC day",
			tostring(contracts.DayKey),
			tostring(contracts.RefreshAt),
			ContractsConfig.StudioRefreshSeconds
		)
	end
	for _, slot in active do
		if typeof(slot) ~= "table" then
			continue
		end
		local def = ContractsConfig.GetById(tostring(slot.Id))
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 56)
		row.BackgroundColor3 = Color3.fromRGB(48, 36, 24)
		row.BorderSizePixel = 0
		row.Parent = self._list
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0, 8)
		rc.Parent = row

		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Size = UDim2.new(1, -110, 0, 22)
		name.Position = UDim2.fromOffset(10, 6)
		name.Font = Enum.Font.GothamBold
		name.TextSize = 14
		name.TextColor3 = Color3.new(1, 1, 1)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = if def then def.DisplayName else tostring(slot.Id)
		name.Parent = row

		local prog = Instance.new("TextLabel")
		prog.BackgroundTransparency = 1
		prog.Size = UDim2.new(1, -110, 0, 20)
		prog.Position = UDim2.fromOffset(10, 28)
		prog.Font = Enum.Font.Gotham
		prog.TextSize = 12
		prog.TextColor3 = Color3.fromRGB(200, 180, 150)
		prog.TextXAlignment = Enum.TextXAlignment.Left
		local reward = if def
			then string.format("%d Tok / %d XP", def.RewardTokens, def.RewardXp)
			else ""
		prog.Text = string.format(
			"%s  ·  %d / %d  ·  %s",
			if def then def.Description else "",
			tonumber(slot.Progress) or 0,
			tonumber(slot.Target) or 0,
			reward
		)
		prog.Parent = row

		local claim = Instance.new("TextButton")
		claim.Size = UDim2.fromOffset(90, 32)
		claim.Position = UDim2.new(1, -100, 0.5, -16)
		claim.BackgroundColor3 = Color3.fromRGB(120, 90, 40)
		claim.TextColor3 = Color3.new(1, 1, 1)
		claim.Font = Enum.Font.GothamBold
		claim.TextSize = 12
		local done = (tonumber(slot.Progress) or 0) >= (tonumber(slot.Target) or 1)
		local claimed = slot.Claimed == true
		claim.Text = if claimed then "Done" elseif done then "Claim" else "…"
		claim.Parent = row
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 6)
		bc.Parent = claim
		claim.MouseButton1Click:Connect(function()
			if done and not claimed then
				self._remotes.ContractClaim:FireServer({ Id = slot.Id })
			end
		end)
	end
end

return ContractController
