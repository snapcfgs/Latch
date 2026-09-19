--!strict
--[[
	BotNames — display name pool + 4-digit tag helper for AI stand-ins.
]]

local NAME_POOL: { string } = {
	"Volt",
	"Nox",
	"Relay",
	"Peck",
	"Glass",
	"Ember",
	"Quill",
	"Rivet",
	"Flux",
	"Cinder",
	"Knob",
	"Spire",
	"Drift",
	"Latch",
	"Bolt",
	"Wick",
	"Prism",
	"Hex",
	"Coil",
	"Ashen",
}

local usedTags: { [string]: boolean } = {}

local BotNames = {}

function BotNames.GetPool(): { string }
	return NAME_POOL
end

function BotNames.RandomBase(): string
	return NAME_POOL[math.random(1, #NAME_POOL)]
end

--[[ Generate DisplayName like "Volt#4821". Retries until tag unused in this server session. ]]
function BotNames.GenerateDisplayName(preferredBase: string?): string
	local base = preferredBase
	if typeof(base) ~= "string" or (base :: string) == "" then
		base = BotNames.RandomBase()
	end
	for _ = 1, 64 do
		local tag = string.format("%04d", math.random(0, 9999))
		local full = (base :: string) .. "#" .. tag
		if not usedTags[full] then
			usedTags[full] = true
			return full
		end
	end
	-- Extremely unlikely collision fallback
	local fallback = (base :: string) .. "#" .. tostring(os.clock() % 10000)
	usedTags[fallback] = true
	return fallback
end

function BotNames.Release(displayName: string)
	usedTags[displayName] = nil
end

return BotNames
