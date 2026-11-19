--!strict
-- CharacterService: spawns characters only after the profile has loaded,
-- at the town of the player's current floor, and respawns them after death.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CharacterService = {}

local DataService: any
local FloorService: any
local Analytics: any

local function spawnPlayer(player: Player)
	if not player.Parent then
		return
	end
	FloorService.prepareSpawn(player)
	local ok, err = pcall(function()
		player:LoadCharacterAsync()
	end)
	if not ok then
		warn("[CharacterService] LoadCharacter failed:", err)
	end
end

local function onCharacterAdded(player: Player, character: Model)
	Analytics.funnel(player, "Spawn")
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.Died:Connect(function()
		task.wait(Config.RESPAWN_DELAY)
		if player.Parent and player.Character == character then
			spawnPlayer(player)
		end
	end)
end

function CharacterService.init(dataService: any, floorService: any, analytics: any)
	DataService = dataService
	FloorService = floorService
	Analytics = analytics

	Players.CharacterAutoLoads = false

	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end

	DataService.Loaded:Connect(function(player: Player)
		spawnPlayer(player)
	end)
end

return CharacterService
