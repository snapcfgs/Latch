--!strict
--[[
	EmoteController — 6 lobby emote stubs (CFrame bob + BillboardGui).
	Uses Cosmetics.Emotes; unlocked check via ProfileSync when available.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Cosmetics = require(game.ReplicatedStorage.Config.Cosmetics)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local EMOTE_ORDER = {
	"Emote_Wave",
	"Emote_Point",
	"Emote_Flex",
	"Emote_Spin",
	"Emote_Clap",
	"Emote_LiveWire",
}

local EmoteController = {}
EmoteController.__index = EmoteController

function EmoteController.new(remotes: { [string]: RemoteEvent }, audio: any?)
	local self = setmetatable({
		_remotes = remotes,
		_audio = audio,
		_gui = nil :: ScreenGui?,
		_profile = nil :: any,
		_playing = false,
		_phase = "Lobby",
	}, EmoteController)
	return self
end

function EmoteController:Init()
	self:_build()
	if self._remotes.ProfileSync then
		self._remotes.ProfileSync.OnClientEvent:Connect(function(profile)
			self._profile = profile
			self:_refreshLocks()
		end)
	end
	self._remotes.MatchSnapshot.OnClientEvent:Connect(function(snap)
		if typeof(snap) ~= "table" then
			return
		end
		self._phase = tostring(snap.Phase or "Lobby")
		local show = self._phase == "Lobby" or self._phase == "MatchEnd" or self._phase == "MatchRecap"
		if self._gui then
			self._gui.Enabled = show
		end
	end)
end

function EmoteController:_owns(emoteId: string): boolean
	if emoteId == "Emote_Wave" or emoteId == "Emote_Point" then
		return true -- free lobby stubs
	end
	if self._profile and typeof(self._profile.OwnedCosmetics) == "table" then
		local bag = self._profile.OwnedCosmetics.Emotes
		if typeof(bag) == "table" and bag[emoteId] == true then
			return true
		end
	end
	return false
end

function EmoteController:_refreshLocks()
	if not self._gui then
		return
	end
	local row = self._gui:FindFirstChild("EmoteRow", true)
	if not row then
		return
	end
	for _, child in row:GetChildren() do
		if child:IsA("TextButton") then
			local id = child:GetAttribute("EmoteId")
			if typeof(id) == "string" then
				local owned = self:_owns(id)
				child.BackgroundTransparency = if owned then 0.2 else 0.55
				child.TextTransparency = if owned then 0 else 0.4
			end
		end
	end
end

function EmoteController:_play(emoteId: string)
	if self._playing then
		return
	end
	if self._phase ~= "Lobby" and self._phase ~= "MatchEnd" and self._phase ~= "MatchRecap" then
		return
	end
	if not self:_owns(emoteId) then
		return
	end
	local def = Cosmetics.Emotes[emoteId]
	if not def then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = char and char:FindFirstChild("Head") :: BasePart?
	if not root or not head then
		return
	end
	self._playing = true
	if self._audio and self._audio.PlayUIClick then
		self._audio:PlayUIClick()
	end

	-- Billboard label
	local bb = Instance.new("BillboardGui")
	bb.Name = "LatchEmote"
	bb.Size = UDim2.fromOffset(120, 36)
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.Adornee = head
	bb.AlwaysOnTop = true
	bb.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
	label.BackgroundTransparency = 0.25
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Cosmetics.RarityColor[def.Rarity] or Color3.new(1, 1, 1)
	label.Text = def.DisplayName
	label.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label
	Debris:AddItem(bb, 2.2)

	-- CFrame bob (local visual only)
	local start = root.CFrame
	local up = start + Vector3.new(0, 0.6, 0)
	local t1 = TweenService:Create(root, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = up,
	})
	local t2 = TweenService:Create(root, TweenInfo.new(0.35, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
		CFrame = start,
	})
	t1:Play()
	t1.Completed:Connect(function()
		t2:Play()
	end)
	task.delay(2.2, function()
		self._playing = false
	end)

	-- Persist equipped emote preference when owned
	if self._remotes.EquipCosmetic and self:_owns(emoteId) then
		-- Point may be playable as stub without inventory grant
		local ownedInv = false
		if self._profile and typeof(self._profile.OwnedCosmetics) == "table" then
			local bag = self._profile.OwnedCosmetics.Emotes
			ownedInv = typeof(bag) == "table" and bag[emoteId] == true
		end
		if ownedInv or emoteId == "Emote_Wave" then
			self._remotes.EquipCosmetic:FireServer({ Kind = "Emote", Id = emoteId })
		end
	end
end

function EmoteController:_build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LatchEmotes"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 7
	gui.Parent = playerGui
	self._gui = gui

	local row = Instance.new("Frame")
	row.Name = "EmoteRow"
	row.AnchorPoint = Vector2.new(0.5, 1)
	row.Position = UDim2.new(0.5, 0, 1, -18)
	row.Size = UDim2.fromOffset(420, 44)
	row.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
	row.BackgroundTransparency = 0.2
	row.BorderSizePixel = 0
	row.Parent = gui
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 10)
	rc.Parent = row
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.Parent = row
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = row

	for _, id in EMOTE_ORDER do
		local def = Cosmetics.Emotes[id]
		if def then
			local btn = Instance.new("TextButton")
			btn.Name = id
			btn:SetAttribute("EmoteId", id)
			btn.Size = UDim2.fromOffset(62, 32)
			btn.BackgroundColor3 = Color3.fromRGB(40, 48, 68)
			btn.TextColor3 = Color3.new(1, 1, 1)
			btn.Font = Enum.Font.GothamBold
			btn.TextSize = 11
			btn.Text = def.DisplayName
			btn.Parent = row
			local bc = Instance.new("UICorner")
			bc.CornerRadius = UDim.new(0, 6)
			bc.Parent = btn
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 1
			stroke.Color = Cosmetics.RarityColor[def.Rarity] or Color3.fromRGB(120, 120, 140)
			stroke.Transparency = 0.35
			stroke.Parent = btn
			btn.MouseButton1Click:Connect(function()
				self:_play(id)
			end)
		end
	end
	self:_refreshLocks()
end

return EmoteController
