--!strict
-- Stats: values derived from a profile. Client and server both call these
-- so the HUD and the server never disagree about a maximum.

local Config = require(script.Parent.Config)

local Stats = {}

function Stats.maxHp(level: number, str: number): number
	return Config.BASE_HP + Config.HP_PER_LEVEL * (level - 1) + Config.HP_PER_STR * str
end

function Stats.maxMp(arc: number): number
	return Config.BASE_MP + Config.MP_PER_ARC * arc
end

function Stats.maxSp(): number
	return Config.SP_SEGMENTS
end

function Stats.fromData(data: any): { maxHp: number, maxMp: number, maxSp: number, skillSlots: number }
	local s = data.stats or {}
	return {
		maxHp = Stats.maxHp(data.level or 1, s.STR or 0),
		maxMp = Stats.maxMp(s.ARC or 0),
		maxSp = Stats.maxSp(),
		skillSlots = Config.skillSlotsForLevel(data.level or 1),
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

return Stats
