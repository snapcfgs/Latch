--!strict
--[[
	InputController — abstracts PC (keyboard/mouse) + mobile touch.
	Same action names fire on both platforms; combat rules unchanged.
	Phase 6: safe-area padding; SCOREBOARD + SWAP buttons.
]]

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

export type Actions = {
	Fire: boolean,
	Aim: boolean,
	Jump: boolean,
	Crouch: boolean,
	Sprint: boolean,
	Ability: boolean,
	Reload: boolean,
	NextWeapon: boolean,
	PrevWeapon: boolean,
	WeaponSlot: number?, -- 1-4
	Scoreboard: boolean,
}

local InputController = {}
InputController.__index = InputController

function InputController.new()
	local self = setmetatable({
		_actions = {
			Fire = false,
			Aim = false,
			Jump = false,
			Crouch = false,
			Sprint = false,
			Ability = false,
			Reload = false,
			NextWeapon = false,
			PrevWeapon = false,
			WeaponSlot = nil,
			Scoreboard = false,
		} :: Actions,
		_touchGui = nil :: ScreenGui?,
		_listeners = {} :: { (string, boolean) -> () },
		_lookDelta = Vector2.zero,
		_isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,
		_scoreboardCb = nil :: (() -> ())?,
	}, InputController)
	return self
end

function InputController:Init()
	self._isTouch = UserInputService.TouchEnabled and (GuiService:IsTenFootInterface() == false)
	local showTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		or (UserInputService.TouchEnabled and UserInputService.MouseEnabled == false)
	if UserInputService.TouchEnabled then
		showTouch = true
	end
	if UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled then
		showTouch = false
	end

	self:_bindKeyboard()
	if showTouch then
		self:_buildTouchGui()
	end

	UserInputService.InputChanged:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			self._lookDelta = Vector2.new(input.Delta.X, input.Delta.Y)
		end
	end)
end

function InputController:SetScoreboardCallback(cb: () -> ())
	self._scoreboardCb = cb
end

function InputController:GetActions(): Actions
	return self._actions
end

function InputController:ConsumeLookDelta(): Vector2
	local d = self._lookDelta
	self._lookDelta = Vector2.zero
	return d
end

function InputController:OnAction(cb: (string, boolean) -> ())
	table.insert(self._listeners, cb)
end

function InputController:_emit(name: string, down: boolean)
	(self._actions :: any)[name] = down
	for _, cb in self._listeners do
		cb(name, down)
	end
end

function InputController:_bindKeyboard()
	local map = {
		[Enum.KeyCode.LeftShift] = "Sprint",
		[Enum.KeyCode.C] = "Crouch",
		[Enum.KeyCode.LeftControl] = "Crouch",
		[Enum.KeyCode.Space] = "Jump",
		[Enum.KeyCode.Q] = "Ability",
		[Enum.KeyCode.R] = "Reload",
		[Enum.KeyCode.One] = "Slot1",
		[Enum.KeyCode.Two] = "Slot2",
		[Enum.KeyCode.Three] = "Slot3",
		[Enum.KeyCode.Four] = "Slot4",
		[Enum.KeyCode.E] = "NextWeapon",
	}

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:_emit("Fire", true)
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:_emit("Aim", true)
		elseif input.KeyCode and map[input.KeyCode] then
			local action = map[input.KeyCode]
			if action == "Slot1" then
				self._actions.WeaponSlot = 1
				self:_emit("WeaponSlot", true)
			elseif action == "Slot2" then
				self._actions.WeaponSlot = 2
				self:_emit("WeaponSlot", true)
			elseif action == "Slot3" then
				self._actions.WeaponSlot = 3
				self:_emit("WeaponSlot", true)
			elseif action == "Slot4" then
				self._actions.WeaponSlot = 4
				self:_emit("WeaponSlot", true)
			else
				self:_emit(action, true)
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input, _)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:_emit("Fire", false)
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:_emit("Aim", false)
		elseif input.KeyCode and map[input.KeyCode] then
			local action = map[input.KeyCode]
			if action ~= "Slot1" and action ~= "Slot2" and action ~= "Slot3" and action ~= "Slot4" then
				self:_emit(action, false)
			end
		end
	end)

	ContextActionService:BindAction("LatchJump", function(_, state)
		if state == Enum.UserInputState.Begin then
			self:_emit("Jump", true)
		elseif state == Enum.UserInputState.End then
			self:_emit("Jump", false)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.ButtonA)
end

function InputController:_safeInsets(): (number, number, number, number)
	-- left, top, right, bottom padding for notches / home indicator
	local inset = GuiService:GetGuiInset()
	local left = 16
	local top = math.max(inset.Y, 12)
	local right = 16
	local bottom = 20
	if UserInputService.TouchEnabled then
		bottom = math.max(bottom, 28)
		right = math.max(right, 20)
		left = math.max(left, 20)
	end
	return left, top, right, bottom
end

function InputController:_makeButton(parent: Instance, name: string, text: string, pos: UDim2, size: UDim2): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Text = text
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 16
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	btn.BackgroundTransparency = 0.35
	btn.BorderSizePixel = 0
	btn.Size = size
	btn.Position = pos
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	btn.AutoButtonColor = true
	btn.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = btn
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(200, 200, 220)
	stroke.Transparency = 0.5
	stroke.Parent = btn
	return btn
end

function InputController:_bindHold(btn: TextButton, actionName: string)
	btn.MouseButton1Down:Connect(function()
		self:_emit(actionName, true)
	end)
	btn.MouseButton1Up:Connect(function()
		self:_emit(actionName, false)
	end)
	btn.MouseLeave:Connect(function()
		self:_emit(actionName, false)
	end)
	btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			self:_emit(actionName, true)
		end
	end)
	btn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			self:_emit(actionName, false)
		end
	end)
end

function InputController:_buildTouchGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LatchTouchControls"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui
	self._touchGui = gui

	local _l, _t, right, bottom = self:_safeInsets()

	-- FIRE, ADS, JUMP, SLIDE, ABILITY, RELOAD, SWAP, SCOREBOARD, LOOK ZONE
	local fire = self:_makeButton(
		gui,
		"Fire",
		"FIRE",
		UDim2.new(1, -(90 + right), 1, -(100 + bottom)),
		UDim2.fromOffset(110, 110)
	)
	self:_bindHold(fire, "Fire")

	local jump = self:_makeButton(
		gui,
		"Jump",
		"JUMP",
		UDim2.new(1, -(90 + right), 1, -(230 + bottom)),
		UDim2.fromOffset(90, 90)
	)
	self:_bindHold(jump, "Jump")

	local crouch = self:_makeButton(
		gui,
		"Crouch",
		"SLIDE",
		UDim2.new(1, -(200 + right), 1, -(90 + bottom)),
		UDim2.fromOffset(90, 90)
	)
	self:_bindHold(crouch, "Crouch")

	local ability = self:_makeButton(
		gui,
		"Ability",
		"ABILITY",
		UDim2.new(1, -(200 + right), 1, -(210 + bottom)),
		UDim2.fromOffset(90, 90)
	)
	ability.BackgroundColor3 = Color3.fromRGB(40, 80, 120)
	self:_bindHold(ability, "Ability")

	local reload = self:_makeButton(
		gui,
		"Reload",
		"RELOAD",
		UDim2.new(1, -(300 + right), 1, -(90 + bottom)),
		UDim2.fromOffset(74, 70)
	)
	reload.TextSize = 12
	reload.MouseButton1Click:Connect(function()
		self:_emit("Reload", true)
		task.defer(function()
			self:_emit("Reload", false)
		end)
	end)

	local swap = self:_makeButton(
		gui,
		"Swap",
		"SWAP",
		UDim2.new(1, -(300 + right), 1, -(180 + bottom)),
		UDim2.fromOffset(74, 70)
	)
	swap.TextSize = 13
	swap.MouseButton1Click:Connect(function()
		self:_emit("NextWeapon", true)
		task.defer(function()
			self:_emit("NextWeapon", false)
		end)
	end)

	local ads = self:_makeButton(
		gui,
		"ADS",
		"ADS",
		UDim2.new(1, -(200 + right), 1, -(320 + bottom)),
		UDim2.fromOffset(80, 80)
	)
	ads.BackgroundColor3 = Color3.fromRGB(50, 70, 90)
	self:_bindHold(ads, "Aim")

	local scoreboard = self:_makeButton(
		gui,
		"Scoreboard",
		"BOARD",
		UDim2.new(1, -(90 + right), 0, 48 + _t),
		UDim2.fromOffset(72, 44)
	)
	scoreboard.TextSize = 12
	scoreboard.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
	scoreboard.MouseButton1Click:Connect(function()
		if self._scoreboardCb then
			self._scoreboardCb()
		end
	end)

	-- Look zone (right upper — not covering buttons)
	local lookZone = Instance.new("Frame")
	lookZone.Name = "LookZone"
	lookZone.BackgroundTransparency = 1
	lookZone.Size = UDim2.new(0.55, 0, 0.5, 0)
	lookZone.Position = UDim2.new(0.45, 0, 0, _t)
	lookZone.Parent = gui

	local touching: InputObject? = nil
	local lastPos: Vector3? = nil
	lookZone.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			touching = input
			lastPos = input.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if touching and input == touching then
			if lastPos then
				local delta = input.Position - lastPos
				self._lookDelta += Vector2.new(delta.X, delta.Y)
			end
			lastPos = input.Position
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input == touching then
			touching = nil
			lastPos = nil
		end
	end)

	local sprint = self:_makeButton(
		gui,
		"Sprint",
		"RUN",
		UDim2.new(0, 90 + _l, 1, -(90 + bottom)),
		UDim2.fromOffset(80, 80)
	)
	self:_bindHold(sprint, "Sprint")
end

function InputController:IsTouch(): boolean
	return self._touchGui ~= nil
end

return InputController
