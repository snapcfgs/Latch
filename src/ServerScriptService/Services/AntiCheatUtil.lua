--!strict
--[[
	AntiCheatUtil — light shared validation helpers for Latch Phase 7.

	Model (keep intentionally light):
	  • Fire rate: reject shots faster than 1/FireRate with ~15% slop (latency).
	  • Abilities: server cooldown table is authoritative; dash travel ≤ DashMaxDistance.
	  • Damage: never trust client amounts — server raycast / overlap only.
	  • Bots: same ServerFire / ServerUse entry points as players (ActorUtil).
	  • Movement: do NOT rubber-band slides. SlideState is cosmetic notify only.
	    Only reject exploit-level teleport deltas if movement checks are added later.

]]

local AntiCheatUtil = {}

-- Allow ~15% faster than nominal FireRate (clock skew / latency). Reject below that.
AntiCheatUtil.FIRE_RATE_SLOP = 0.85

-- Origin must be near the actor root (studs); beyond this we rebasing to root.
AntiCheatUtil.ORIGIN_REBASE_STUDS = 20
AntiCheatUtil.GRENADE_ORIGIN_REBASE_STUDS = 25
AntiCheatUtil.ABILITY_ORIGIN_REBASE_STUDS = 25

--[[ True if enough time has passed since lastFire for this fireRate (Hz). ]]
function AntiCheatUtil.PassesFireRate(now: number, lastFire: number, fireRate: number): boolean
	local minInterval = 1 / math.max(fireRate, 0.1)
	return (now - lastFire) >= minInterval * AntiCheatUtil.FIRE_RATE_SLOP
end

--[[ Clamp Skid dash speed so speed * duration never exceeds maxDistance. ]]
function AntiCheatUtil.ClampDashSpeed(speed: number, duration: number, maxDistance: number): number
	local dur = math.max(duration, 0.01)
	local capped = maxDistance / dur
	return math.min(speed, capped)
end

--[[ Effective dash duration given open-space travel (wall may shorten). ]]
function AntiCheatUtil.ClampDashDuration(duration: number, travel: number, speed: number): number
	if speed <= 0.01 then
		return 0
	end
	return math.min(duration, travel / speed)
end

return AntiCheatUtil
