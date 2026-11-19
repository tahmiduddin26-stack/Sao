--!strict
-- QuestService: accept, abandon, track and advance hand-written quests.
-- Quest data lives in Shared.Quests and is linted at boot (plan 8.2).
-- Other systems call QuestService.advance(player, questId, stepId, amount)
-- when the player does the thing a step asks for.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local RateLimit = require(Shared.RateLimit)
local Quests = require(Shared.Quests)
local QuestLint = require(Shared.QuestLint)

local QuestService = {}

local DataService: any
local ProgressionService: any
local InventoryService: any
local Analytics: any

local byId: { [string]: Quests.Quest } = {}

local function toast(player: Player, payload: any)
	Remotes.event("Toast"):FireClient(player, payload)
end

function QuestService.get(questId: string): Quests.Quest?
	return byId[questId]
end

local function prerequisitesMet(data: any, q: Quests.Quest): boolean
	if not data.unlockedFloors[q.floor] then
		return false
	end
	for _, req in (q.requires or {}) :: { string } do
		local s = data.quests[req]
		if not s or s.state ~= "done" then
			return false
		end
	end
	return true
end

function QuestService.accept(player: Player, questId: string): boolean
	local data = DataService.get(player)
	local q = byId[questId]
	if not data or not q then
		return false
	end
	if data.quests[questId] then
		return false
	end
	if not prerequisitesMet(data, q) then
		toast(player, { kind = "error", title = "Not yet", body = "Something else needs doing first." })
		return false
	end
	data.quests[questId] = { state = "active", step = 1, progress = 0 }
	if #data.tracked < Config.MAX_TRACKED_QUESTS then
		table.insert(data.tracked, questId)
	end
	toast(player, { kind = "quest", title = "Quest accepted", body = q.name })
	Analytics.custom(player, "QuestAccepted", 1, { Archetype = q.archetype })
	DataService.changed(player)
	return true
end

function QuestService.abandon(player: Player, questId: string): boolean
	local data = DataService.get(player)
	local q = byId[questId]
	if not data or not q or q.kind == "main" then
		return false
	end
	local s = data.quests[questId]
	if not s or s.state ~= "active" then
		return false
	end
	data.quests[questId] = nil
	local i = table.find(data.tracked, questId)
	if i then
		table.remove(data.tracked, i)
	end
	Analytics.custom(player, "QuestAbandoned", 1, { Archetype = q.archetype })
	DataService.changed(player)
	return true
end

function QuestService.toggleTrack(player: Player, questId: string): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	local s = data.quests[questId]
	if not s or s.state ~= "active" then
		return false
	end
	local i = table.find(data.tracked, questId)
	if i then
		table.remove(data.tracked, i)
	else
		if #data.tracked >= Config.MAX_TRACKED_QUESTS then
			table.remove(data.tracked, 1)
		end
		table.insert(data.tracked, questId)
	end
	DataService.changed(player)
	return true
end

local function grantRewards(player: Player, q: Quests.Quest)
	local data = DataService.get(player)
	local r = q.rewards
	if r.gold then
		ProgressionService.addGold(player, r.gold, "Gameplay", q.id)
	end
	for _, item in (r.items or {}) :: { any } do
		InventoryService.give(player, item.id, item.count or 1)
	end
	for _, key in (r.unlocks or {}) :: { string } do
		data.unlocks[key] = true
	end
	if r.title then
		data.titles[r.title] = true
	end
	if r.xp then
		ProgressionService.addXp(player, r.xp, "Quest")
	end
end

local function complete(player: Player, q: Quests.Quest)
	local data = DataService.get(player)
	local s = data.quests[q.id]
	s.state = "done"
	s.progress = 0
	local i = table.find(data.tracked, q.id)
	if i then
		table.remove(data.tracked, i)
	end
	grantRewards(player, q)
	toast(player, { kind = "quest", title = "Quest complete", body = q.name })
	Analytics.funnel(player, "FirstQuestDone")
	Analytics.custom(player, "QuestCompleted", 1, { Archetype = q.archetype })
	DataService.changed(player)
end

-- Advance a quest step. If stepId is given it must be the current step.
function QuestService.advance(player: Player, questId: string, stepId: string?, amount: number?): boolean
	local data = DataService.get(player)
	local q = byId[questId]
	if not data or not q then
		return false
	end
	local s = data.quests[questId]
	if not s or s.state ~= "active" then
		return false
	end
	local step = q.steps[s.step]
	if not step or (stepId and step.id ~= stepId) then
		return false
	end
	s.progress += amount or 1
	local needed = step.count or 1
	if s.progress >= needed then
		s.step += 1
		s.progress = 0
		if s.step > #q.steps then
			complete(player, q)
			return true
		end
		toast(player, { kind = "quest", title = "Quest updated", body = q.steps[s.step].text })
	else
		toast(player, { kind = "quest", title = "Quest updated", body = string.format("%s %d/%d", step.text, s.progress, needed) })
	end
	DataService.changed(player)
	return true
end

-- Record a branch choice (e.g. The Trap-Breaker) for later consequences.
function QuestService.setChoice(player: Player, questId: string, choice: string)
	local data = DataService.get(player)
	local s = data and data.quests[questId]
	if s then
		s.choice = choice
		DataService.changed(player)
	end
end

function QuestService.init(dataService: any, progressionService: any, inventoryService: any, analytics: any)
	DataService = dataService
	ProgressionService = progressionService
	InventoryService = inventoryService
	Analytics = analytics

	for _, q in Quests do
		local problems = QuestLint.check(q)
		if #problems > 0 then
			for _, p in problems do
				warn("[QuestLint] " .. p)
			end
		else
			byId[q.id] = q
		end
	end

	Remotes.event("QuestAction").OnServerEvent:Connect(function(player: Player, action: any, questId: any)
		if not RateLimit.check(player, "QuestAction") then
			return
		end
		if typeof(action) ~= "string" or typeof(questId) ~= "string" then
			return
		end
		if action == "accept" then
			QuestService.accept(player, questId)
		elseif action == "abandon" then
			QuestService.abandon(player, questId)
		elseif action == "track" then
			QuestService.toggleTrack(player, questId)
		end
	end)
end

return QuestService
