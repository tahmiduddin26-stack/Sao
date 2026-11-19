--!strict
-- FloorService: which floors a player has unlocked and cleared, travel between
-- them, respawn location, and the server-wide front line (plan 7.4, 12.3).
-- markCleared() is the hook the floor boss will call once combat exists.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local RateLimit = require(Shared.RateLimit)

local FloorService = {}

local DataService: any
local WorldBuilder: any
local Analytics: any

local lastTravel: { [Player]: number } = {}
local worldStore: DataStore? = nil

local FRONT_LINE_KEY = "FrontLine"

local function toast(player: Player, payload: any)
	Remotes.event("Toast"):FireClient(player, payload)
end

local function setFrontLine(value: number)
	local current = Workspace:GetAttribute("FrontLine")
	if typeof(current) ~= "number" or value > current then
		Workspace:SetAttribute("FrontLine", value)
	end
end

local function loadFrontLine()
	setFrontLine(1)
	local ok, ds = pcall(function()
		return DataStoreService:GetDataStore(Config.WORLD_DATASTORE_NAME)
	end)
	if not ok then
		return
	end
	worldStore = ds
	local okGet, value = pcall(function()
		return ds:GetAsync(FRONT_LINE_KEY)
	end)
	if okGet and typeof(value) == "number" then
		setFrontLine(value)
	end
end

local function pushFrontLine(value: number)
	local ds = worldStore
	if not ds then
		return
	end
	task.spawn(function()
		pcall(function()
			ds:UpdateAsync(FRONT_LINE_KEY, function(old: any)
				if typeof(old) == "number" and old >= value then
					return nil
				end
				return value
			end)
		end)
	end)
end

function FloorService.isUnlocked(player: Player, floorId: number): boolean
	local data = DataService.get(player)
	return data ~= nil and data.unlockedFloors[floorId] == true
end

-- Points the player's respawn at the floor town and records it.
local function setCurrent(player: Player, floorId: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	data.currentFloor = floorId
	player:SetAttribute("Floor", floorId)
	local spawn = WorldBuilder.getSpawn(floorId)
	if spawn then
		player.RespawnLocation = spawn
	end
	DataService.changed(player)
end

function FloorService.prepareSpawn(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local floorId = data.currentFloor
	if not Config.getFloor(floorId) or not data.unlockedFloors[floorId] then
		floorId = 1
	end
	setCurrent(player, floorId)
end

function FloorService.travel(player: Player, floorId: number): boolean
	if not Config.getFloor(floorId) or not FloorService.isUnlocked(player, floorId) then
		return false
	end
	local now = os.clock()
	if lastTravel[player] and now - lastTravel[player] < Config.TRAVEL_COOLDOWN then
		return false
	end
	lastTravel[player] = now

	setCurrent(player, floorId)
	local character = player.Character
	local spawn = WorldBuilder.getSpawn(floorId)
	if character and spawn then
		character:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
	end
	local def = Config.getFloor(floorId)
	if def then
		toast(player, { kind = "info", title = Config.floorCode(floorId) .. "  " .. def.town, body = def.name })
	end
	return true
end

function FloorService.unlock(player: Player, floorId: number)
	local data = DataService.get(player)
	if not data or not Config.getFloor(floorId) or data.unlockedFloors[floorId] then
		return
	end
	data.unlockedFloors[floorId] = true
	DataService.changed(player)
end

-- Call when a party defeats a floor boss. `clearSeconds` and `partySize` feed the banner.
function FloorService.markCleared(player: Player, floorId: number, clearSeconds: number?, partySize: number?)
	local data = DataService.get(player)
	if not data or not Config.getFloor(floorId) then
		return
	end
	local firstForPlayer = not data.clearedFloors[floorId]
	data.clearedFloors[floorId] = true
	FloorService.unlock(player, floorId + 1)
	DataService.changed(player)

	if firstForPlayer then
		Analytics.progression(player, floorId, "Complete")
	end

	local frontLine = Workspace:GetAttribute("FrontLine")
	local nextFloor = floorId + 1
	if typeof(frontLine) == "number" and nextFloor > frontLine then
		setFrontLine(nextFloor)
		pushFrontLine(nextFloor)
		for _, p in Players:GetPlayers() do
			toast(p, { kind = "info", title = "The front line moved", body = string.format("%s cleared %s. %s is open.", player.DisplayName, Config.floorCode(floorId), Config.floorCode(nextFloor)) })
		end
	end

	Remotes.event("Banner"):FireClient(player, {
		kind = "FloorCleared",
		floorId = floorId,
		nextFloor = nextFloor,
		clearSeconds = clearSeconds or 0,
		partySize = partySize or 1,
	})
end

function FloorService.init(dataService: any, worldBuilder: any, analytics: any)
	DataService = dataService
	WorldBuilder = worldBuilder
	Analytics = analytics

	task.spawn(loadFrontLine)

	Remotes.event("TravelToFloor").OnServerEvent:Connect(function(player: Player, floorId: any)
		if not RateLimit.check(player, "TravelToFloor") then
			return
		end
		if typeof(floorId) ~= "number" or floorId ~= math.floor(floorId) then
			return
		end
		if not FloorService.travel(player, floorId) then
			toast(player, { kind = "error", title = "Gate closed", body = "That floor is not open to you yet." })
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastTravel[player] = nil
	end)
end

return FloorService
