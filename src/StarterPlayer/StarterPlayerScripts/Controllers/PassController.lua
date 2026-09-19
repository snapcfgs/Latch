--!strict
--[[
	PassController — Season pass UI (Free / Prime claim).
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local BattlePass = require(game.ReplicatedStorage.Config.BattlePass)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PassController = {}
PassController.__index = PassController

function PassController.new(remotes: { [string]: RemoteEvent })
	local self = setmetatable({
		_remotes = remotes,
		_gui = nil :: ScreenGui?,
		_profile = nil :: any,
		_list = nil :: ScrollingFrame?,
		_header = nil :: TextLabel?,
		_status = nil :: TextLabel?,
	}, PassController)
	return self
end

function PassController:Init()
	self:_build()
	if self._remotes.ProfileSync then
		self._remotes.ProfileSync.OnClientEvent:Connect(function(profile)
			self._profile = profile
			if self._gui and self._gui.Enabled then
				self:_render()
			end
		end)
	end
	if self._remotes.PassResult then
		self._remotes.PassResult.OnClientEvent:Connect(function(result)
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
		if part and part:IsA("BasePart") and part:GetAttribute("KioskType") == "Pass" then
			self:Open()
		end
	end)
end

function PassController:Open()
	if self._gui then
		self._gui.Enabled = true
		self:_render()
	end
end

function PassController:Close()
	if self._gui then
		self._gui.Enabled = false
	end
end

function PassController:_build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LatchPass"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 26
	gui.Enabled = false
	gui.Parent = playerGui
	self._gui = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(540, 480)
	panel.BackgroundColor3 = Color3.fromRGB(22, 16, 32)
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -80, 0, 30)
	title.Position = UDim2.fromOffset(14, 10)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "BATTLE PASS — " .. BattlePass.SeasonName
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
	header.Position = UDim2.fromOffset(14, 44)
	header.Font = Enum.Font.Gotham
	header.TextSize = 13
	header.TextColor3 = Color3.fromRGB(200, 180, 255)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.TextWrapped = true
	header.Text = "20 Pass XP = 1 tier"
	header.Parent = panel
	self._header = header

	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(14, 88)
	list.Size = UDim2.new(1, -28, 1, -140)
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.BorderSizePixel = 0
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.Parent = list
	self._list = list

	local status = Instance.new("TextLabel")
	status.BackgroundTransparency = 1
	status.Size = UDim2.new(1, -28, 0, 28)
	status.Position = UDim2.new(0, 14, 1, -36)
	status.Font = Enum.Font.Gotham
	status.TextSize = 12
	status.TextColor3 = Color3.fromRGB(180, 170, 200)
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Text = ""
	status.Parent = panel
	self._status = status
end

local function rewardLabel(r: any): string
	if typeof(r) ~= "table" then
		return "-"
	end
	if r.Kind == "Tokens" then
		return tostring(r.Amount) .. " Tokens"
	end
	if r.Kind == "Scrap" then
		return tostring(r.Amount) .. " Scrap"
	end
	if r.Kind == "SkinTickets" then
		return tostring(r.Amount) .. " Tickets"
	end
	return tostring(r.Kind) .. (if r.Id then (":" .. r.Id) else "")
end

function PassController:_render()
	if not self._list then
		return
	end
	for _, c in self._list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local pass = self._profile and self._profile.Pass
	local xp = if pass then tonumber(pass.Xp) or 0 else 0
	local tier = BattlePass.TierFromXp(xp)
	local ownsPrime = pass and pass.OwnsPrime == true
	if self._header then
		self._header.Text = string.format(
			"Season %s · Pass XP %d · Tier %d / %d · Prime %s\n(20 XP = 1 tier; matches grant Pass XP)",
			BattlePass.SeasonId,
			xp,
			tier,
			BattlePass.TierCount,
			if ownsPrime then "YES" else "no"
		)
	end
	local claimedFree = (pass and pass.ClaimedFree) or {}
	local claimedPrime = (pass and pass.ClaimedPrime) or {}

	for i = 1, BattlePass.TierCount do
		local def = BattlePass.GetTier(i)
		if not def then
			continue
		end
		local unlocked = i <= tier
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 40)
		row.BackgroundColor3 = if unlocked then Color3.fromRGB(40, 32, 56) else Color3.fromRGB(28, 24, 36)
		row.BorderSizePixel = 0
		row.Parent = self._list
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0, 6)
		rc.Parent = row

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(0.35, 0, 1, 0)
		label.Position = UDim2.fromOffset(8, 0)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 13
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = string.format("T%d", i)
		label.Parent = row

		local freeBtn = Instance.new("TextButton")
		freeBtn.Size = UDim2.new(0.28, 0, 0, 28)
		freeBtn.Position = UDim2.new(0.35, 0, 0.5, -14)
		freeBtn.BackgroundColor3 = Color3.fromRGB(50, 90, 70)
		freeBtn.TextColor3 = Color3.new(1, 1, 1)
		freeBtn.Font = Enum.Font.Gotham
		freeBtn.TextSize = 11
		local freeClaimed = claimedFree[tostring(i)] == true
		freeBtn.Text = if freeClaimed then "Free ✓" else ("Free: " .. rewardLabel(def.Free))
		freeBtn.Parent = row
		local fc = Instance.new("UICorner")
		fc.CornerRadius = UDim.new(0, 4)
		fc.Parent = freeBtn
		freeBtn.MouseButton1Click:Connect(function()
			if unlocked and not freeClaimed then
				self._remotes.PassClaim:FireServer({ Tier = i, Track = "Free" })
			end
		end)

		local primeBtn = Instance.new("TextButton")
		primeBtn.Size = UDim2.new(0.32, -8, 0, 28)
		primeBtn.Position = UDim2.new(0.66, 0, 0.5, -14)
		primeBtn.BackgroundColor3 = Color3.fromRGB(90, 60, 140)
		primeBtn.TextColor3 = Color3.new(1, 1, 1)
		primeBtn.Font = Enum.Font.Gotham
		primeBtn.TextSize = 11
		local primeClaimed = claimedPrime[tostring(i)] == true
		primeBtn.Text = if primeClaimed then "Prime ✓" else ("Prime: " .. rewardLabel(def.Prime))
		primeBtn.Parent = row
		local pc = Instance.new("UICorner")
		pc.CornerRadius = UDim.new(0, 4)
		pc.Parent = primeBtn
		primeBtn.MouseButton1Click:Connect(function()
			if unlocked and ownsPrime and not primeClaimed then
				self._remotes.PassClaim:FireServer({ Tier = i, Track = "Prime" })
			end
		end)
	end
end

return PassController
