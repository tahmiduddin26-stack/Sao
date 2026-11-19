--!strict
-- QuestLint: automatic rejection rules from plan 8.2 and 8.4.
-- Runs on the server at boot for hand-written quests, and later on every
-- generated repeatable before a player ever sees it.

local QuestLint = {}

local BANNED_SOLO_VERBS = { kill = true, collect = true, slay = true, gather = true }

-- Returns a list of problems. Empty means the quest passes.
function QuestLint.check(q: any, recentVerbs: { string }?): { string }
	local problems = {}
	local function fail(msg: string)
		table.insert(problems, (q.id or "?") .. ": " .. msg)
	end

	-- Rule 1: a person, a problem, a turn.
	if not (q.client and q.client.name and q.client.name ~= "") then
		fail("no client (who is asking?)")
	end
	if not q.problem or q.problem == "" then
		fail("no problem (what is wrong?)")
	end
	if not q.turn or q.turn == "" then
		fail("no turn (what changes halfway?)")
	end

	-- Rule 2: a verb that is not "kill N".
	local verb = typeof(q.verb) == "string" and string.lower(q.verb) or ""
	if verb == "" then
		fail("no verb")
	elseif BANNED_SOLO_VERBS[verb] then
		fail("verb '" .. verb .. "' alone is a generic objective")
	end
	if recentVerbs and table.find(recentVerbs, verb) then
		fail("same verb as one of the player's last two repeatables")
	end

	-- Rule 3: rooted in its district.
	if typeof(q.district) ~= "string" or q.district == "" then
		fail("not tied to a district")
	end

	-- Rule 4: teaches or tests a system.
	if not q.teaches or q.teaches == "" then
		fail("does not name the system it teaches")
	end

	-- Rule 5: a reward that matters (not only XP and Cash).
	local r = q.rewards or {}
	local meaningful = (r.unlocks and #r.unlocks > 0) or (r.title ~= nil)
	if not meaningful then
		fail("reward is only XP and Cash")
	end

	-- Rule 6: consequence.
	if not q.consequence or q.consequence == "" then
		fail("no consequence")
	end

	-- Rule 7: 5 to 15 minutes.
	local mins = q.estMinutes
	if typeof(mins) ~= "number" or mins < 5 or mins > 15 then
		fail("estimated time must be 5 to 15 minutes")
	end

	if typeof(q.steps) ~= "table" or #q.steps == 0 then
		fail("has no steps")
	end

	return problems
end

return QuestLint
