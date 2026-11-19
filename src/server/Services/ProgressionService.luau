--!strict
-- ProgressionService: XP, levels, stat points, gold and derived maxima.
-- The only place that changes level, xp, statPoints, stats or gold.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Stats = require(Shared.Stats)
local RateLimit = require(Shared.RateLimit)

local ProgressionService = {}

local DataService: any
local Analytics: any

local function toast(player: Player, payload: any)
	Remotes.event("Toast"):FireClient(player, payload)
end

-- Server-wide blessing multiplier (bought by any player; stacks).
function ProgressionService.xpMultiplier(): number
	local untilTime = Workspace:GetAttribute("BlessingUntil")
	local stacks = Workspace:GetAttribute("BlessingStacks")
	if typeof(untilTime) == "number" and untilTime > os.time() and typeof(stacks) == "number" then
		return 1 + Config.BLESSING_XP_MULT_PER_STACK * math.min(stacks, Config.BLESSING_MAX_STACKS)
	end
	return 1
end

-- Push derived values to the character and player attributes.
function ProgressionService.applyDerived(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local derived = Stats.fromData(data)
	player:SetAttribute("Level", data.level)
	player:SetAttribute("MaxSP", derived.maxSp)
	player:SetAttribute("MaxMP", derived.maxMp)
	if player:GetAttribute("SP") == nil then
		player:SetAttribute("SP", derived.maxSp)
	end
	local mp = player:GetAttribute("MP")
	if typeof(mp) ~= "number" or mp > derived.maxMp then
		player:SetAttribute("MP", derived.maxMp)
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local wasFull = humanoid.Health >= humanoid.MaxHealth - 0.01
		humanoid.MaxHealth = derived.maxHp
		if wasFull or humanoid.Health > derived.maxHp then
			humanoid.Health = derived.maxHp
		end
	end
end

function ProgressionService.addXp(player: Player, amount: number, source: string?)
	local data = DataService.get(player)
	if not data or amount <= 0 then
		return
	end
	amount = math.floor(amount * ProgressionService.xpMultiplier())
	data.xp += amount
	local startLevel = data.level
	while data.xp >= Config.xpToNext(data.level) do
		data.xp -= Config.xpToNext(data.level)
		data.level += 1
		data.statPoints += Config.STAT_POINTS_PER_LEVEL
	end
	if data.level > startLevel then
		toast(player, { kind = "levelup", title = "Level up", from = startLevel, to = data.level })
		Analytics.custom(player, "LevelUp", data.level, { Source = source or "unknown" })
		local oldSlots = Config.skillSlotsForLevel(startLevel)
		local newSlots = Config.skillSlotsForLevel(data.level)
		if newSlots > oldSlots then
			toast(player, { kind = "info", title = "Skill slot unlocked", body = string.format("You can now equip %d Sword Skills.", newSlots) })
		end
		ProgressionService.applyDerived(player)
	end
	DataService.changed(player)
end

function ProgressionService.addGold(player: Player, amount: number, transactionType: string, sku: string?)
	local data = DataService.get(player)
	if not data or amount <= 0 then
		return
	end
	data.gold += math.floor(amount)
	Analytics.economy(player, "Source", Config.CURRENCY_NAME, amount, data.gold, transactionType, sku)
	DataService.changed(player)
end

-- Returns true if the player could afford it.
function ProgressionService.spendGold(player: Player, amount: number, transactionType: string, sku: string?): boolean
	local data = DataService.get(player)
	if not data or amount <= 0 or data.gold < amount then
		return false
	end
	data.gold -= math.floor(amount)
	Analytics.economy(player, "Sink", Config.CURRENCY_NAME, amount, data.gold, transactionType, sku)
	DataService.changed(player)
	return true
end

function ProgressionService.addMaterial(player: Player, key: string, amount: number)
	local data = DataService.get(player)
	if not data or amount <= 0 or not (Config.MATERIALS :: any)[key] then
		return
	end
	data.materials[key] = (data.materials[key] or 0) + math.floor(amount)
	DataService.changed(player)
end

function ProgressionService.setLevel(player: Player, level: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	level = math.clamp(math.floor(level), 1, 10000)
	data.level = level
	data.xp = 0
	data.statPoints = Stats.totalPointsForLevel(level) - Stats.spentPoints(data)
	if data.statPoints < 0 then
		ProgressionService.respec(player)
	end
	ProgressionService.applyDerived(player)
	DataService.changed(player)
end

function ProgressionService.respec(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	for _, def in Config.STATS do
		data.stats[def.key] = 0
	end
	data.statPoints = Stats.totalPointsForLevel(data.level)
	ProgressionService.applyDerived(player)
	DataService.changed(player)
end

local function onAllocate(player: Player, statKey: any, amount: any)
	if not RateLimit.check(player, "AllocateStat") then
		return
	end
	if typeof(statKey) ~= "string" or typeof(amount) ~= "number" then
		return
	end
	amount = math.floor(amount)
	if amount < 1 or amount > 100 or amount ~= amount then
		return
	end
	local valid = false
	for _, def in Config.STATS do
		if def.key == statKey then
			valid = true
		end
	end
	if not valid then
		return
	end
	local data = DataService.get(player)
	if not data or data.statPoints < amount then
		return
	end
	data.statPoints -= amount
	data.stats[statKey] = (data.stats[statKey] or 0) + amount
	ProgressionService.applyDerived(player)
	DataService.changed(player)
end

function ProgressionService.init(dataService: any, analytics: any)
	DataService = dataService
	Analytics = analytics
	Remotes.event("AllocateStat").OnServerEvent:Connect(onAllocate)
	DataService.Loaded:Connect(function(player: Player)
		ProgressionService.applyDerived(player)
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.defer(ProgressionService.applyDerived, player)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function()
			task.defer(ProgressionService.applyDerived, player)
		end)
	end
end

return ProgressionService
