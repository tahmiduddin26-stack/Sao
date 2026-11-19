--!strict
-- Server bootstrap for Sword Blox Online. Wires services in dependency order.
-- Combat is not built yet; hooks it will use: FloorService.markCleared,
-- QuestService.advance, ProgressionService.addXp, InventoryService.give,
-- WorldBuilder.isSafe and Analytics.funnel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local RateLimit = require(Shared.RateLimit)
local Config = require(Shared.Config)

local Services = script:WaitForChild("Services")
local DataService = require(Services.DataService)
local Analytics = require(Services.Analytics)
local WorldBuilder = require(Services.WorldBuilder)
local ProgressionService = require(Services.ProgressionService)
local InventoryService = require(Services.InventoryService)
local FloorService = require(Services.FloorService)
local CharacterService = require(Services.CharacterService)
local QuestService = require(Services.QuestService)
local DailyService = require(Services.DailyService)
local SettingsService = require(Services.SettingsService)
local MonetizationService = require(Services.MonetizationService)
local AdminService = require(Services.AdminService)

Remotes.init()
WorldBuilder.build()

Analytics.init(DataService)
ProgressionService.init(DataService, Analytics)
InventoryService.init(DataService)
FloorService.init(DataService, WorldBuilder, Analytics)
CharacterService.init(DataService, FloorService, Analytics)
QuestService.init(DataService, ProgressionService, InventoryService, Analytics)
DailyService.init(DataService, ProgressionService, InventoryService)
SettingsService.init(DataService)
MonetizationService.init(DataService, ProgressionService, Analytics)
AdminService.init({
	Data = DataService,
	Progression = ProgressionService,
	Floor = FloorService,
	Inventory = InventoryService,
	Quest = QuestService,
})

-- Client-observed onboarding steps (only ones the client can see first).
local CLIENT_FUNNEL_STEPS = { FirstMove = true, OpenedLedger = true }
Remotes.event("FunnelStep").OnServerEvent:Connect(function(player: Player, step: any)
	if not RateLimit.check(player, "FunnelStep") then
		return
	end
	if typeof(step) == "string" and CLIENT_FUNNEL_STEPS[step] then
		Analytics.funnel(player, step)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	RateLimit.clear(player)
end)

-- Data loads last so every Loaded listener above is connected first.
DataService.init()

print(string.format("[%s] server %s ready", Config.GAME_NAME, Config.VERSION))
