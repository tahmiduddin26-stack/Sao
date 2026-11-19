--!strict
-- CharacterService: spawns characters only after the profile has loaded, behind
-- the counter of the player's own store, and respawns them there after a KO.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CharacterService = {}

local deps: any = {}

local function spawnPlayer(player: Player)
	if not player.Parent then
		return
	end
	local ok, err = pcall(function()
		player:LoadCharacterAsync()
	end)
	if not ok then
		warn("[CharacterService] LoadCharacter failed:", err)
		return
	end
	local character = player.Character
	if character then
		character:PivotTo(deps.Store.spawnCFrame(player))
		player:SetAttribute("Area", "Store")
	end
end

local function onCharacterAdded(player: Player, character: Model)
	deps.Analytics.funnel(player, "Spawn")
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

function CharacterService.init(dependencies: any)
	deps = dependencies
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

	-- StoreService claims the plot on the same Loaded signal; defer so it runs first.
	deps.Data.Loaded:Connect(function(player: Player)
		task.defer(spawnPlayer, player)
	end)
end

return CharacterService
