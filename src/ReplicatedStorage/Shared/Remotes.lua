--!strict
--[[
	Remotes — creates / returns RemoteEvents under ReplicatedStorage.
	Server calls Ensure(); clients WaitForChild after bootstrap.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(script.Parent.Constants)

local RemoteNames = {
	-- Match
	"MatchSnapshot",
	"RequestQueue",
	"RequestOperator",
	"RoundResult",
	"MatchResult",
	-- Combat
	"FireWeapon",
	"WeaponHit", -- server → clients for feedback (damage numbers / hitmarker)
	"ReloadWeapon",
	"SwitchWeapon",
	"ThrowGrenade",
	"MeleeSwing",
	-- Abilities
	"UseAbility",
	"AbilityFx", -- server → clients for VFX
	-- Movement (optional notify)
	"SlideState",
	-- Player state
	"PlayerState",
	"DamageNumber",
	-- Bots / stand-ins
	"Announce",
	"StandInReplaced",
}

export type RemotesMap = { [string]: RemoteEvent }

local function ensureFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(Constants.RemotesFolderName)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = Constants.RemotesFolderName
	folder.Parent = ReplicatedStorage
	return folder
end

local function ensureRemote(folder: Folder, name: string): RemoteEvent
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	return remote
end

local Remotes = {}

function Remotes.Ensure(): RemotesMap
	assert(RunService:IsServer(), "Remotes.Ensure must run on server")
	local folder = ensureFolder()
	local map: RemotesMap = {}
	for _, name in RemoteNames do
		map[name] = ensureRemote(folder, name)
	end
	return map
end

function Remotes.Get(): RemotesMap
	local folder = ReplicatedStorage:WaitForChild(Constants.RemotesFolderName, 30)
	assert(folder and folder:IsA("Folder"), "LatchRemotes folder missing")
	local map: RemotesMap = {}
	for _, name in RemoteNames do
		local remote = folder:WaitForChild(name, 15)
		assert(remote and remote:IsA("RemoteEvent"), "Missing remote: " .. name)
		map[name] = remote :: RemoteEvent
	end
	return map
end

Remotes.Names = RemoteNames

return Remotes
