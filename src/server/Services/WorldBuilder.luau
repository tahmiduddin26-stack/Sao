--!strict
-- WorldBuilder: builds every floor from Config.FLOORS at runtime.
-- Rojo never wipes it, and changing a Config number moves the map.
--
-- Art swap hook: if ServerStorage.FloorKits contains a Model named like the floor
-- code ("F01"), it is cloned and pivoted to the floor origin instead of the greybox.
-- A kit may contain a SpawnLocation named "Spawn", and Parts named "TeleportGate",
-- "QuestBoard" and "LabyrinthEntrance"; missing pieces fall back to greybox ones.
-- Greybox parts carry the "Greybox" tag so they are easy to find and replace.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local WorldBuilder = {}

local spawns: { [number]: SpawnLocation } = {}
local origins: { [number]: Vector3 } = {}

local PLAZA_SIZE = 140
local SAFE_HEIGHT = 60

local function part(props: { [string]: any }, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	CollectionService:AddTag(p, "Greybox")
	p.Parent = parent
	return p
end

local function addPrompt(target: BasePart, actionText: string, objectText: string, tab: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OpensTab", tab)
	prompt.Parent = target
	prompt.Triggered:Connect(function(player: Player)
		Remotes.event("OpenLedger"):FireClient(player, tab)
	end)
end

function WorldBuilder.origin(floorId: number): Vector3
	return origins[floorId] or Vector3.new((floorId - 1) * Config.FLOOR_SPACING, 0, 0)
end

local function buildGreybox(def: Config.FloorDef, folder: Folder, origin: Vector3): SpawnLocation
	local size = def.size

	part({
		Name = "Ground",
		Size = Vector3.new(size.X, 4, size.Y),
		Position = origin + Vector3.new(0, -2, 0),
		Color = def.groundColor,
		Material = Enum.Material.Grass,
	}, folder)

	part({
		Name = "Plaza",
		Size = Vector3.new(PLAZA_SIZE, 1, PLAZA_SIZE),
		Position = origin + Vector3.new(0, 0.5, 0),
		Color = def.plazaColor,
		Material = Enum.Material.Slate,
	}, folder)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = origin + Vector3.new(0, 1.5, 0)
	spawn.Color = def.plazaColor
	spawn.Material = Enum.Material.Slate
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Transparency = 0
	CollectionService:AddTag(spawn, "Greybox")
	spawn.Parent = folder
	return spawn
end

local function ensurePiece(folder: Instance, name: string, build: () -> BasePart): BasePart
	local found = folder:FindFirstChild(name, true)
	if found and found:IsA("BasePart") then
		return found
	end
	return build()
end

local function buildFloor(def: Config.FloorDef, root: Folder)
	local code = Config.floorCode(def.id)
	local origin = Vector3.new((def.id - 1) * Config.FLOOR_SPACING, 0, 0)
	origins[def.id] = origin

	local folder = Instance.new("Folder")
	folder.Name = code
	folder:SetAttribute("FloorId", def.id)
	folder.Parent = root

	local spawn: SpawnLocation? = nil
	local kits = ServerStorage:FindFirstChild("FloorKits")
	local kit = kits and kits:FindFirstChild(code)
	if kit and kit:IsA("Model") then
		local clone = kit:Clone()
		clone:PivotTo(CFrame.new(origin))
		clone.Parent = folder
		local s = clone:FindFirstChild("Spawn", true)
		if s and s:IsA("SpawnLocation") then
			spawn = s
		end
	end
	if not spawn then
		spawn = buildGreybox(def, folder, origin)
	end
	assert(spawn)
	spawn.Neutral = true
	spawns[def.id] = spawn

	local half = PLAZA_SIZE / 2

	local gate = ensurePiece(folder, "TeleportGate", function()
		return part({
			Name = "TeleportGate",
			Size = Vector3.new(14, 1, 14),
			Position = origin + Vector3.new(half - 14, 1.5, 0),
			Color = Color3.fromRGB(58, 64, 70),
			Material = Enum.Material.Metal,
		}, folder)
	end)
	addPrompt(gate, "Open map", "Teleport Gate", "Map")

	local board = ensurePiece(folder, "QuestBoard", function()
		return part({
			Name = "QuestBoard",
			Size = Vector3.new(8, 6, 1),
			Position = origin + Vector3.new(-half + 14, 4, -12),
			Color = Color3.fromRGB(92, 74, 56),
			Material = Enum.Material.Wood,
		}, folder)
	end)
	addPrompt(board, "Read", "Quest board", "Quests")

	local labyrinth = ensurePiece(folder, "LabyrinthEntrance", function()
		return part({
			Name = "LabyrinthEntrance",
			Size = Vector3.new(40, 1, 40),
			Position = origin + Vector3.new(0, 0.5, -(def.size.Y / 2) + 40),
			Color = Color3.fromRGB(40, 42, 46),
			Material = Enum.Material.Basalt,
		}, folder)
	end)
	labyrinth:SetAttribute("Labyrinth", true)

	-- Safe zone: towns take no damage and monsters cannot enter (read by combat later).
	local safe = Instance.new("Part")
	safe.Name = "SafeZone"
	safe.Anchored = true
	safe.CanCollide = false
	safe.CanQuery = false
	safe.CanTouch = false
	safe.Transparency = 1
	safe.Size = Vector3.new(PLAZA_SIZE, SAFE_HEIGHT, PLAZA_SIZE)
	safe.Position = origin + Vector3.new(0, SAFE_HEIGHT / 2, 0)
	safe:SetAttribute("SafeZone", true)
	safe:SetAttribute("FloorId", def.id)
	CollectionService:AddTag(safe, "SafeZone")
	safe.Parent = folder
end

function WorldBuilder.build()
	local existing = Workspace:FindFirstChild("World")
	if existing then
		existing:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "World"
	root.Parent = Workspace

	for _, def in Config.FLOORS do
		buildFloor(def, root)
	end

	-- Baseplate from a fresh place would sit under floor 1; remove it.
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
end

function WorldBuilder.getSpawn(floorId: number): SpawnLocation?
	return spawns[floorId]
end

-- True if a world position is inside any town safe zone.
function WorldBuilder.isSafe(position: Vector3): boolean
	for _, zone in CollectionService:GetTagged("SafeZone") do
		if zone:IsA("BasePart") then
			local rel = zone.CFrame:PointToObjectSpace(position)
			local h = zone.Size / 2
			if math.abs(rel.X) <= h.X and math.abs(rel.Y) <= h.Y and math.abs(rel.Z) <= h.Z then
				return true
			end
		end
	end
	return false
end

return WorldBuilder
