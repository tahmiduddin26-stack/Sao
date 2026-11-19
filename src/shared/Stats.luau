--!strict
-- Stats: values derived from a profile. Client and server both call these
-- so the HUD and the server never disagree about a maximum.

local Config = require(script.Parent.Config)

local Stats = {}

function Stats.maxHp(level: number, pow: number): number
	return Config.BASE_HP + Config.HP_PER_LEVEL * (level - 1) + Config.HP_PER_POW * pow
end

function Stats.walkSpeed(spd: number, serious: boolean): number
	local base = if serious then Config.WALK_SERIOUS else Config.WALK_OFF_DUTY
	return base * (1 + Config.WALK_PER_SPD * spd / 10)
end

function Stats.fromData(data: any): { maxHp: number, pow: number, spd: number, ins: number }
	local s = data.stats or {}
	return {
		maxHp = Stats.maxHp(data.level or 1, s.POW or 0),
		pow = s.POW or 0,
		spd = s.SPD or 0,
		ins = s.INS or 0,
	}
end

-- Points spent so far, used by respec and to validate allocations.
function Stats.spentPoints(data: any): number
	local total = 0
	for _, def in Config.STATS do
		total += (data.stats and data.stats[def.key]) or 0
	end
	return total
end

function Stats.totalPointsForLevel(level: number): number
	return (level - 1) * Config.STAT_POINTS_PER_LEVEL
end

-- The districts a profile may enter, by best bounty ever reached.
function Stats.districtUnlocked(data: any, code: string): boolean
	local def = Config.getDistrict(code)
	return def ~= nil and (data.bestBounty or 0) >= def.bounty
end

function Stats.storeLevel(data: any): any
	local lvl = math.clamp((data.store and data.store.level or 0) + 1, 1, #Config.STORE_LEVELS)
	return Config.STORE_LEVELS[lvl]
end

return Stats
