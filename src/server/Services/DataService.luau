--!strict
-- DataService: owns every player profile.
--  * One profile per player in DataStore Config.DATASTORE_NAME, keyed "u_<UserId>".
--  * Session locking: a server writes its JobId into the record and refuses to
--    load a profile another live server holds (unless the lock is stale).
--  * If a load fails, saving is blocked for that session so a fresh default
--    profile can never overwrite a real save.
--  * Purchase receipts are stored in the profile so nothing is granted twice.
--  * Throttling and transient errors retry with exponential backoff.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)

local DataService = {}

DataService.Loaded = Signal.new() -- (player, data)
DataService.Changed = Signal.new() -- (player, data)

type Session = {
	data: any,
	canSave: boolean,
	loadFailed: boolean,
	dirty: boolean,
	pushQueued: boolean,
	releasing: boolean,
}

local sessions: { [Player]: Session } = {}
local store: DataStore? = nil
local storeError: string? = nil
local JOB_ID = (RunService:IsStudio() and "studio-" or "") .. (game.JobId ~= "" and game.JobId or HttpService:GenerateGUID(false))

---------------------------------------------------------------------------
-- Defaults and reconcile
---------------------------------------------------------------------------
local function newUid(): string
	return HttpService:GenerateGUID(false)
end

function DataService.defaultData(): any
	local stats = {}
	for _, def in Config.STATS do
		stats[def.key] = 0
	end
	local proficiency = {}
	for _, def in Config.PROFICIENCIES do
		proficiency[def.key] = 0
	end

	local items = {}
	local equipped = {}
	for _, itemId in Config.STARTER_ITEMS do
		local uid = newUid()
		local def = (Config.ITEMS :: any)[itemId]
		table.insert(items, { uid = uid, id = itemId, count = 1, durability = def and def.durability or nil })
		for slot, starterId in Config.STARTER_EQUIP do
			if starterId == itemId then
				equipped[slot] = uid
			end
		end
	end

	return {
		version = 1,
		level = 1,
		xp = 0,
		statPoints = 0,
		stats = stats,
		proficiency = proficiency,
		gold = Config.STARTING_GOLD,
		materials = { Crystal = 0 },
		items = items,
		equipped = equipped,
		currentFloor = 1,
		unlockedFloors = { [1] = true },
		clearedFloors = {},
		quests = {}, -- [questId] = { state = "active" | "done", step = number, progress = number, choice = string? }
		tracked = {}, -- { questId }
		unlocks = {}, -- [unlockKey] = true
		titles = {},
		activeTitle = "",
		daily = { lastDay = -1, streak = 0 },
		settings = table.clone(Config.DEFAULT_SETTINGS),
		funnel = {}, -- [stepName] = true
		passes = {}, -- [passKey] = true (granted, including Studio simulations)
		tokens = { Revive = 0, Dye = 0 },
		receipts = {}, -- { purchaseId }
		stats_meta = { createdAt = os.time(), sessions = 0, playSeconds = 0 },
	}
end

-- Fill any missing keys from defaults without touching existing values.
local function reconcile(target: any, template: any)
	for k, v in template do
		if target[k] == nil then
			target[k] = if typeof(v) == "table" then table.clone(v) else v
		elseif typeof(v) == "table" and typeof(target[k]) == "table" and next(v) ~= nil and #v == 0 then
			-- dictionary: recurse; arrays (items, tracked, receipts) are left alone
			reconcile(target[k], v)
		end
	end
end

-- JSON turns sparse integer keys into strings; normalise floor sets back to numbers.
local function normaliseNumberSet(t: any): any
	local out = {}
	if typeof(t) ~= "table" then
		return out
	end
	for k, v in t do
		local n = tonumber(k)
		if n and v then
			out[n] = true
		end
	end
	return out
end

---------------------------------------------------------------------------
-- DataStore helpers
---------------------------------------------------------------------------
local function getStore(): DataStore?
	if store or storeError then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DATASTORE_NAME)
	end)
	if ok then
		store = result
	else
		storeError = tostring(result)
		warn("[DataService] DataStore unavailable:", storeError)
	end
	return store
end

local function withRetry<T>(label: string, fn: () -> T): (boolean, T | string)
	local delay = 1
	local lastErr: any = nil
	for attempt = 1, Config.DATASTORE_RETRIES do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		warn(string.format("[DataService] %s failed (attempt %d): %s", label, attempt, tostring(result)))
		if attempt < Config.DATASTORE_RETRIES then
			task.wait(delay)
			delay = math.min(delay * 2, 16)
		end
	end
	return false, tostring(lastErr)
end

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

local function lockIsLive(lock: any, now: number): boolean
	return typeof(lock) == "table" and lock.jobId ~= JOB_ID and typeof(lock.time) == "number" and (now - lock.time) < Config.SESSION_LOCK_TTL
end

---------------------------------------------------------------------------
-- Snapshot push
---------------------------------------------------------------------------
local function buildSnapshot(player: Player, session: Session): any
	local d = session.data
	local snap = table.clone(d)
	snap.receipts = nil
	snap.funnel = nil
	-- Floor sets go over the wire as arrays so number keys survive.
	local unlocked, cleared = {}, {}
	for id in d.unlockedFloors do
		table.insert(unlocked, id)
	end
	for id in d.clearedFloors do
		table.insert(cleared, id)
	end
	table.sort(unlocked)
	table.sort(cleared)
	snap.unlockedFloors = unlocked
	snap.clearedFloors = cleared
	snap.canSave = session.canSave
	return snap
end

function DataService.snapshot(player: Player): any?
	local session = sessions[player]
	if not session then
		return nil
	end
	return buildSnapshot(player, session)
end

-- Call after any mutation. Pushes one Snapshot per frame at most.
function DataService.changed(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	session.dirty = true
	if session.pushQueued then
		return
	end
	session.pushQueued = true
	task.defer(function()
		session.pushQueued = false
		if sessions[player] ~= session or not player.Parent then
			return
		end
		Remotes.event("Snapshot"):FireClient(player, buildSnapshot(player, session))
		DataService.Changed:Fire(player, session.data)
	end)
end

---------------------------------------------------------------------------
-- Public accessors
---------------------------------------------------------------------------
function DataService.get(player: Player): any?
	local session = sessions[player]
	return session and session.data or nil
end

function DataService.isReady(player: Player): boolean
	return sessions[player] ~= nil
end

function DataService.canSave(player: Player): boolean
	local session = sessions[player]
	return session ~= nil and session.canSave
end

-- Yields until the player's profile is loaded (or they leave). Returns data or nil.
function DataService.waitFor(player: Player, timeout: number?): any?
	local deadline = os.clock() + (timeout or 60)
	while player.Parent and not sessions[player] and os.clock() < deadline do
		task.wait(0.1)
	end
	return DataService.get(player)
end

---------------------------------------------------------------------------
-- Load / save / release
---------------------------------------------------------------------------
local function toast(player: Player, kind: string, title: string, body: string)
	Remotes.event("Toast"):FireClient(player, { kind = kind, title = title, body = body })
end

local function loadProfile(player: Player): (any?, boolean)
	local ds = getStore()
	if not ds then
		return nil, false
	end
	local key = keyFor(player)

	for attempt = 1, Config.SESSION_LOCK_RETRIES do
		local lockedElsewhere = false
		local ok, result = withRetry("load " .. key, function()
			local loaded: any = nil
			ds:UpdateAsync(key, function(record: any)
				local now = os.time()
				lockedElsewhere = false
				record = record or {}
				if lockIsLive(record.lock, now) then
					lockedElsewhere = true
					loaded = nil
					return nil -- cancel write
				end
				record.lock = { jobId = JOB_ID, time = now }
				loaded = record.data
				return record
			end)
			return loaded
		end)
		if not ok then
			return nil, false
		end
		if not lockedElsewhere then
			local data = result
			if typeof(data) ~= "table" then
				data = DataService.defaultData()
			end
			return data, true
		end
		if attempt < Config.SESSION_LOCK_RETRIES then
			task.wait(Config.SESSION_LOCK_RETRY_WAIT)
		end
		if not player.Parent then
			return nil, false
		end
	end
	return nil, false
end

-- DataStores reject sparse number-keyed tables, so floor sets are written
-- with string keys. normaliseNumberSet turns them back into numbers on load.
local function toStringSet(t: any): any
	local out = {}
	for k, v in t do
		if v then
			out[tostring(k)] = true
		end
	end
	return out
end

local function serialise(data: any): any
	local copy = table.clone(data)
	copy.unlockedFloors = toStringSet(data.unlockedFloors)
	copy.clearedFloors = toStringSet(data.clearedFloors)
	return copy
end

local function trimReceipts(data: any)
	local r = data.receipts
	while #r > Config.MAX_STORED_RECEIPTS do
		table.remove(r, 1)
	end
end

-- Writes the profile. `release` clears the session lock.
local function saveProfile(player: Player, session: Session, release: boolean): boolean
	if not session.canSave then
		return false
	end
	local ds = getStore()
	if not ds then
		return false
	end
	trimReceipts(session.data)
	local payload = serialise(session.data)
	local key = keyFor(player)
	local stolen = false
	local ok = withRetry("save " .. key, function()
		ds:UpdateAsync(key, function(record: any)
			record = record or {}
			local now = os.time()
			stolen = false
			if lockIsLive(record.lock, now) then
				stolen = true
				return nil
			end
			record.data = payload
			record.lock = if release then nil else { jobId = JOB_ID, time = now }
			return record
		end)
		return true
	end)
	if stolen then
		warn("[DataService] Lock for", key, "is held by another server; save skipped")
		session.canSave = false
		return false
	end
	if ok then
		session.dirty = false
	end
	return ok
end

function DataService.saveNow(player: Player): boolean
	local session = sessions[player]
	if not session then
		return false
	end
	return saveProfile(player, session, false)
end

local function onPlayerAdded(player: Player)
	local data, ok = loadProfile(player)
	if not player.Parent then
		return
	end

	local session: Session = {
		data = nil,
		canSave = ok,
		loadFailed = not ok,
		dirty = false,
		pushQueued = false,
		releasing = false,
	}

	if ok and data then
		reconcile(data, DataService.defaultData())
		data.unlockedFloors = normaliseNumberSet(data.unlockedFloors)
		data.clearedFloors = normaliseNumberSet(data.clearedFloors)
		if next(data.unlockedFloors) == nil then
			data.unlockedFloors[1] = true
		end
		data.stats_meta.sessions += 1
		session.data = data
	else
		session.data = DataService.defaultData()
	end

	sessions[player] = session
	player:SetAttribute("DataLoaded", true)
	player:SetAttribute("CanSave", session.canSave)

	if session.loadFailed then
		task.delay(2, function()
			if player.Parent then
				toast(player, "error", "Progress will not save", "We could not load your profile. Play is fine, but nothing this session will be saved. Rejoin to try again.")
			end
		end)
	end

	DataService.Loaded:Fire(player, session.data)
	DataService.changed(player)
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if not session or session.releasing then
		return
	end
	session.releasing = true
	saveProfile(player, session, true)
	sessions[player] = nil
end

function DataService.init()
	getStore()

	Remotes.func("GetSnapshot").OnServerInvoke = function(player: Player)
		return DataService.snapshot(player)
	end

	Players.PlayerAdded:Connect(function(p)
		task.spawn(onPlayerAdded, p)
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerAdded, p)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Autosave loop; also refreshes the session lock time.
	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE_SECONDS)
			for player, session in sessions do
				if session.canSave and not session.releasing then
					task.spawn(saveProfile, player, session, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player, session in sessions do
			if not session.releasing then
				pending += 1
				session.releasing = true
				task.spawn(function()
					saveProfile(player, session, true)
					pending -= 1
				end)
			end
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

---------------------------------------------------------------------------
-- Receipts (used by MonetizationService)
---------------------------------------------------------------------------
function DataService.hasReceipt(player: Player, purchaseId: string): boolean
	local data = DataService.get(player)
	return data ~= nil and table.find(data.receipts, purchaseId) ~= nil
end

function DataService.addReceipt(player: Player, purchaseId: string)
	local data = DataService.get(player)
	if data and not table.find(data.receipts, purchaseId) then
		table.insert(data.receipts, purchaseId)
	end
end

return DataService
