--!strict
-- DailyService: the daily streak (plan 12.3). One claim per UTC day; missing a
-- day restarts the streak at 1. Rewards cycle through Config.DAILY_REWARDS.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local RateLimit = require(Shared.RateLimit)

local DailyService = {}

local DataService: any
local ProgressionService: any
local InventoryService: any

local function today(): number
	return math.floor(os.time() / 86400)
end

function DailyService.canClaim(data: any): boolean
	return data.daily.lastDay ~= today()
end

function DailyService.claim(player: Player): boolean
	local data = DataService.get(player)
	if not data or not DailyService.canClaim(data) then
		return false
	end
	local day = today()
	if data.daily.lastDay == day - 1 then
		data.daily.streak += 1
	else
		data.daily.streak = 1
	end
	data.daily.lastDay = day

	local reward = Config.DAILY_REWARDS[((data.daily.streak - 1) % #Config.DAILY_REWARDS) + 1] :: any
	if reward.gold then
		ProgressionService.addGold(player, reward.gold, "Gameplay", "DailyStreak")
	end
	if reward.item then
		InventoryService.give(player, reward.item, reward.count or 1)
	end
	if reward.material then
		ProgressionService.addMaterial(player, reward.material, reward.count2 or reward.count or 1)
	end
	Remotes.event("Toast"):FireClient(player, {
		kind = "reward",
		title = string.format("Day %d streak", data.daily.streak),
		body = string.format("%s %s", Config.CURRENCY_CODE, tostring(reward.gold or 0)),
	})
	DataService.changed(player)
	return true
end

function DailyService.init(dataService: any, progressionService: any, inventoryService: any)
	DataService = dataService
	ProgressionService = progressionService
	InventoryService = inventoryService
	Remotes.event("ClaimDaily").OnServerEvent:Connect(function(player: Player)
		if not RateLimit.check(player, "ClaimDaily") then
			return
		end
		DailyService.claim(player)
	end)
end

return DailyService
