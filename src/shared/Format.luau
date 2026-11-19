--!strict
-- Format: numbers, times and codes, shared by client and server.

local Format = {}

-- 10240 -> "10,240"
function Format.commas(n: number): string
	local negative = n < 0
	local s = tostring(math.floor(math.abs(n)))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return (negative and "-" or "") .. out
end

-- 125 -> "2:05"
function Format.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	if m >= 60 then
		return string.format("%d:%02d:%02d", math.floor(m / 60), m % 60, s)
	end
	return string.format("%d:%02d", m, s)
end

-- 5 -> "05"
function Format.index(i: number): string
	return string.format("%02d", i)
end

-- "Guard break" style sentence case for keys like "GuardBreak"
function Format.splitCamel(s: string): string
	local spaced = s:gsub("(%l)(%u)", "%1 %2")
	return spaced:sub(1, 1):upper() .. spaced:sub(2):lower()
end

return Format
