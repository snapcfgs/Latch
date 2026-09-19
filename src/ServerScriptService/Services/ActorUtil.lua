--!strict
--[[
	ActorUtil — unify Player and BotRecord for combat / match code.
	Actor = Player | BotRecord (table with IsBot = true).
]]

local Players = game:GetService("Players")

local Constants = require(game.ReplicatedStorage.Shared.Constants)

export type BotRecord = {
	IsBot: boolean,
	Id: number,
	DisplayName: string,
	Character: Model?,
	TeamId: string,
	OperatorId: string,
	Difficulty: string,
	Alive: boolean,
	LobbyOnly: boolean,
}

export type Actor = Player | BotRecord

local ActorUtil = {}

function ActorUtil.IsBot(actor: Actor): boolean
	return typeof(actor) == "table" and (actor :: any).IsBot == true
end

function ActorUtil.IsPlayer(actor: Actor): boolean
	return typeof(actor) == "Instance" and (actor :: Instance):IsA("Player")
end

function ActorUtil.UserId(actor: Actor): number
	if ActorUtil.IsBot(actor) then
		return (actor :: BotRecord).Id
	end
	return (actor :: Player).UserId
end

function ActorUtil.DisplayName(actor: Actor): string
	if ActorUtil.IsBot(actor) then
		return (actor :: BotRecord).DisplayName
	end
	local p = actor :: Player
	return p.DisplayName ~= "" and p.DisplayName or p.Name
end

function ActorUtil.Character(actor: Actor): Model?
	if ActorUtil.IsBot(actor) then
		return (actor :: BotRecord).Character
	end
	return (actor :: Player).Character
end

function ActorUtil.GetAttribute(actor: Actor, name: string): any
	if ActorUtil.IsBot(actor) then
		local bot = actor :: BotRecord
		local char = bot.Character
		if char then
			local v = char:GetAttribute(name)
			if v ~= nil then
				return v
			end
		end
		if name == Constants.AttributeTeam then
			return bot.TeamId
		elseif name == Constants.AttributeOperator then
			return bot.OperatorId
		elseif name == Constants.AttributeAlive then
			return bot.Alive
		elseif name == Constants.AttributeIsBot then
			return true
		elseif name == Constants.AttributeDifficulty then
			return bot.Difficulty
		elseif name == Constants.AttributeDisplayName then
			return bot.DisplayName
		end
		return nil
	end
	return (actor :: Player):GetAttribute(name)
end

function ActorUtil.SetAttribute(actor: Actor, name: string, value: any)
	if ActorUtil.IsBot(actor) then
		local bot = actor :: BotRecord
		if name == Constants.AttributeTeam then
			bot.TeamId = tostring(value)
		elseif name == Constants.AttributeOperator then
			bot.OperatorId = tostring(value)
		elseif name == Constants.AttributeAlive then
			bot.Alive = value ~= false
		elseif name == Constants.AttributeDifficulty then
			bot.Difficulty = tostring(value)
		elseif name == Constants.AttributeDisplayName then
			bot.DisplayName = tostring(value)
		end
		local char = bot.Character
		if char then
			char:SetAttribute(name, value)
		end
		return
	end
	(actor :: Player):SetAttribute(name, value)
end

function ActorUtil.Humanoid(actor: Actor): Humanoid?
	local char = ActorUtil.Character(actor)
	if not char then
		return nil
	end
	return char:FindFirstChildOfClass("Humanoid")
end

function ActorUtil.Root(actor: Actor): BasePart?
	local char = ActorUtil.Character(actor)
	if not char then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function ActorUtil.IsAlive(actor: Actor): boolean
	if ActorUtil.GetAttribute(actor, Constants.AttributeAlive) == false then
		return false
	end
	if ActorUtil.IsBot(actor) then
		local bot = actor :: BotRecord
		if not bot.Alive then
			return false
		end
	elseif ActorUtil.IsPlayer(actor) then
		local p = actor :: Player
		if not p.Parent then
			return false
		end
	end
	local hum = ActorUtil.Humanoid(actor)
	return hum ~= nil and hum.Health > 0
end

--[[ Resolve a character Model to Player or look up via optional botResolver. ]]
function ActorUtil.FromCharacter(model: Model, botFromCharacter: ((Model) -> BotRecord?)?): Actor?
	local plr = Players:GetPlayerFromCharacter(model)
	if plr then
		return plr
	end
	if botFromCharacter then
		return botFromCharacter(model)
	end
	return nil
end

return ActorUtil
