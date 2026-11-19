--!strict
-- RateLimit: per-player, per-key sliding window. Server uses it on every remote.

local Config = require(script.Parent.Config)

local RateLimit = {}

local buckets: { [Player]: { [string]: { number } } } = {}

-- Returns true if the call is allowed.
function RateLimit.check(player: Player, key: string): boolean
	local rule = (Config.RATE_LIMITS :: any)[key] or Config.RATE_LIMITS.default
	local now = os.clock()
	local perPlayer = buckets[player]
	if not perPlayer then
		perPlayer = {}
		buckets[player] = perPlayer
	end
	local times = perPlayer[key]
	if not times then
		times = {}
		perPlayer[key] = times
	end
	local cutoff = now - rule.window
	while #times > 0 and times[1] < cutoff do
		table.remove(times, 1)
	end
	if #times >= rule.count then
		return false
	end
	table.insert(times, now)
	return true
end

function RateLimit.clear(player: Player)
	buckets[player] = nil
end

return RateLimit
