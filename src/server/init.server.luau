--!strict
-- Server bootstrap for Clocked Out. Wires services in dependency order.
-- Services that need each other get one shared `deps` table, so they can call
-- across (Combat <-> Enemy <-> Bounty) without require cycles.

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
local QuestService = require(Services.QuestService)
local SettingsService = require(Services.SettingsService)
local MonetizationService = require(Services.MonetizationService)
local PropService = require(Services.PropService)
local CombatService = require(Services.CombatService)
local EnemyService = require(Services.EnemyService)
local BountyService = require(Services.BountyService)
local StoreService = require(Services.StoreService)
local DistrictService = require(Services.DistrictService)
local CharacterService = require(Services.CharacterService)
local RewardsService = require(Services.RewardsService)
local AdminService = require(Services.AdminService)

Remotes.init()
WorldBuilder.build()

local deps = {
	Data = DataService,
	Analytics = Analytics,
	World = WorldBuilder,
	Progression = ProgressionService,
	Quest = QuestService,
	Monetization = MonetizationService,
	Prop = PropService,
	Combat = CombatService,
	Enemy = EnemyService,
	Bounty = BountyService,
	Store = StoreService,
	District = DistrictService,
}

Analytics.init(DataService)
ProgressionService.init(DataService, Analytics)
QuestService.init(DataService, ProgressionService, Analytics)
SettingsService.init(DataService)
MonetizationService.init(DataService, ProgressionService, Analytics)
PropService.init(WorldBuilder, Analytics)
CombatService.init(deps)
EnemyService.init(deps)
BountyService.init(deps)
StoreService.init(deps)
DistrictService.init(deps)
CharacterService.init(deps)
RewardsService.init(deps)
AdminService.init(deps)

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
