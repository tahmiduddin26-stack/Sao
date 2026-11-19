--!strict
-- ProgressionService: XP, levels, stat points, Cash and derived maxima.
-- The only place that changes level, xp, statPoints, stats or cash.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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


-- Push derived values to the character and player attributes.
function ProgressionService.applyDerived(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local derived = Stats.fromData(data)
	player:SetAttribute("Level", data.level)

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
	amount = math.floor(amount)
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
		ProgressionService.applyDerived(player)
	end
	DataService.changed(player)
end

function ProgressionService.addCash(player: Player, amount: number, transactionType: string, sku: string?)
	local data = DataService.get(player)
	if not data or amount <= 0 then
		return
	end
	data.cash += math.floor(amount)
	Analytics.economy(player, "Source", Config.CURRENCY_NAME, amount, data.cash, transactionType, sku)
	DataService.changed(player)
end

-- Returns true if the player could afford it.
function ProgressionService.spendCash(player: Player, amount: number, transactionType: string, sku: string?): boolean
	local data = DataService.get(player)
	if not data or amount <= 0 or data.cash < amount then
		return false
	end
	data.cash -= math.floor(amount)
	Analytics.economy(player, "Sink", Config.CURRENCY_NAME, amount, data.cash, transactionType, sku)
	DataService.changed(player)
	return true
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
