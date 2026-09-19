--!strict
--[[
	AudioController — creates placeholder Sound stubs (no toolbox IDs).
	Plays pitch-varied short tones when a SoundId exists; otherwise silent + print.
]]

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local SoundsConfig = require(game.ReplicatedStorage.Config.Sounds)

local player = Players.LocalPlayer

local AudioController = {}
AudioController.__index = AudioController

function AudioController.new(remotes: { [string]: RemoteEvent })
	local self = setmetatable({
		_remotes = remotes,
		_folder = nil :: Folder?,
		_sounds = {} :: { [string]: Sound },
		_enabled = true,
	}, AudioController)
	return self
end

function AudioController:Init()
	local folder = Instance.new("Folder")
	folder.Name = "LatchAudioStubs"
	folder.Parent = SoundService
	self._folder = folder

	for id, stub in SoundsConfig.Sounds do
		local s = Instance.new("Sound")
		s.Name = stub.DisplayName
		s.Volume = stub.Volume
		s.PlaybackSpeed = stub.PlaybackSpeed
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		-- Empty SoundId = silent stub (no marketplace assets)
		if typeof(stub.SoundId) == "string" and stub.SoundId ~= "" then
			s.SoundId = stub.SoundId
		end
		s.Parent = folder
		self._sounds[id] = s
	end

	-- Wire a few combat / UI events
	if self._remotes.WeaponHit then
		self._remotes.WeaponHit.OnClientEvent:Connect(function(payload)
			if typeof(payload) == "table" and payload.Hit then
				self:Play("Hit")
			end
		end)
	end
	if self._remotes.AbilityFx then
		self._remotes.AbilityFx.OnClientEvent:Connect(function(payload)
			if typeof(payload) == "table" and payload.UserId == player.UserId then
				self:Play("Ability")
			end
		end)
	end
	if self._remotes.FireWeapon then
		-- Client fires; WeaponController also fires — listen locally via PlayFire
	end

	print("[Latch] Audio stubs ready (silent placeholders — no toolbox IDs)")
end

function AudioController:Play(id: string)
	if not self._enabled then
		return
	end
	local stub = SoundsConfig.Sounds[id]
	local sound = self._sounds[id]
	if not stub or not sound then
		return
	end
	local base = stub.PlaybackSpeed
	local var = stub.PitchVariance or 0
	sound.PlaybackSpeed = base + (math.random() * 2 - 1) * var
	if sound.SoundId ~= "" and sound.SoundId ~= "rbxassetid://0" then
		sound:Play()
	else
		-- Silent stub fallback
		print(string.format("[Latch:Audio] beep %s (%.2fx)", id, sound.PlaybackSpeed))
	end
end

function AudioController:PlayFire()
	self:Play("Fire")
end

function AudioController:PlayUIClick()
	self:Play("UIClick")
end

function AudioController:PlayQueue()
	self:Play("Queue")
end

return AudioController
