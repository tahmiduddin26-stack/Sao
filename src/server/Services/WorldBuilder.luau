--!strict
-- WorldBuilder: builds every district and the row of store plots from Config.
-- Rojo never wipes it, and changing a Config number moves the map.
--
-- Districts sit on the X axis (Config.districtOrigin). Each has a plaza with a
-- travel board, loose-prop spawn points scattered over the ground, enemy spawn
-- points around the edge and a boss arena at the far end.
-- Art swap hook: a Model in ServerStorage.DistrictKits named like the code
-- ("D01") replaces the greybox ground. It may contain Parts named "PropSpawn",
-- "EnemySpawn" or "BossSpawn" (any number) and a SpawnLocation "Spawn".
--
-- Store plots sit in a row at Z = Config.STORE_ROW_Z. StoreService claims one
-- per player and fills it; WorldBuilder only lays the empty lots.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local WorldBuilder = {}

export type DistrictRefs = {
	code: string,
	folder: Folder,
	spawn: BasePart,
	propSpawns: { BasePart },
	enemySpawns: { BasePart },
	bossSpawn: BasePart,
}

local districts: { [string]: DistrictRefs } = {}
local plots: { Model } = {}

local PLAZA_SIZE = 90

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

local function marker(name: string, position: Vector3, parent: Instance): BasePart
	return part({
		Name = name,
		Size = Vector3.new(1, 1, 1),
		Position = position,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, parent)
end

function WorldBuilder.addPrompt(target: BasePart, actionText: string, objectText: string, onTrigger: (Player) -> (), hold: number?): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = Enum.KeyCode.G -- E grabs, F parries
	prompt.GamepadKeyCode = Enum.KeyCode.DPadUp -- X is light attack
	prompt.HoldDuration = hold or 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = target
	prompt.Triggered:Connect(onTrigger)
	return prompt
end

-- Seeded scatter so every server builds the same district.
local function scatter(rng: Random, size: Vector2, avoidRadius: number): Vector3
	for _ = 1, 20 do
		local x = rng:NextNumber(-size.X / 2 + 10, size.X / 2 - 10)
		local z = rng:NextNumber(-size.Y / 2 + 10, size.Y / 2 - 10)
		if math.sqrt(x * x + z * z) > avoidRadius then
			return Vector3.new(x, 0, z)
		end
	end
	return Vector3.new(size.X / 3, 0, size.Y / 3)
end

local function buildCover(def: Config.DistrictDef, folder: Folder, origin: Vector3, rng: Random)
	-- Low crates and walls so fights have corners and things to throw over.
	for i = 1, 26 do
		local pos = scatter(rng, def.size, PLAZA_SIZE / 2 + 12)
		local w, h, d = rng:NextNumber(4, 12), rng:NextNumber(3, 7), rng:NextNumber(4, 12)
		part({
			Name = "Cover" .. i,
			Size = Vector3.new(w, h, d),
			Position = origin + pos + Vector3.new(0, h / 2, 0),
			Color = def.plazaColor:Lerp(Color3.new(0, 0, 0), 0.25),
			Material = Enum.Material.Concrete,
		}, folder)
	end
end

local function buildDistrict(def: Config.DistrictDef, root: Folder)
	local origin = Config.districtOrigin(def.code)
	local folder = Instance.new("Folder")
	folder.Name = def.code
	folder:SetAttribute("District", def.code)
	folder.Parent = root

	local refs: DistrictRefs = {
		code = def.code,
		folder = folder,
		spawn = nil :: any,
		propSpawns = {},
		enemySpawns = {},
		bossSpawn = nil :: any,
	}

	local kits = ServerStorage:FindFirstChild("DistrictKits")
	local kit = kits and kits:FindFirstChild(def.code)
	if kit and kit:IsA("Model") then
		local clone = kit:Clone()
		clone:PivotTo(CFrame.new(origin))
		clone.Parent = folder
		for _, d in clone:GetDescendants() do
			if d:IsA("BasePart") then
				if d.Name == "PropSpawn" then
					table.insert(refs.propSpawns, d)
				elseif d.Name == "EnemySpawn" then
					table.insert(refs.enemySpawns, d)
				elseif d.Name == "BossSpawn" then
					refs.bossSpawn = d
				elseif d.Name == "Spawn" then
					refs.spawn = d
				end
			end
		end
	else
		part({
			Name = "Ground",
			Size = Vector3.new(def.size.X, 4, def.size.Y),
			Position = origin + Vector3.new(0, -2, 0),
			Color = def.groundColor,
			Material = Enum.Material.Asphalt,
		}, folder)
		part({
			Name = "Plaza",
			Size = Vector3.new(PLAZA_SIZE, 1, PLAZA_SIZE),
			Position = origin + Vector3.new(0, 0.5, 0),
			Color = def.plazaColor,
			Material = Enum.Material.Pavement,
		}, folder)
		local rng = Random.new(Config.districtIndex(def.code) * 7919)
		buildCover(def, folder, origin, rng)
	end

	if not refs.spawn then
		refs.spawn = part({
			Name = "Spawn",
			Size = Vector3.new(10, 1, 10),
			Position = origin + Vector3.new(0, 1.1, PLAZA_SIZE / 2 - 10),
			Color = def.plazaColor:Lerp(Color3.new(1, 1, 1), 0.3),
			Material = Enum.Material.Pavement,
		}, folder)
	end

	local rng = Random.new(Config.districtIndex(def.code) * 104729)
	if #refs.propSpawns == 0 then
		local total = 0
		for _, n in def.props do
			total += n
		end
		for i = 1, total * 2 do
			local pos = scatter(rng, def.size, 8)
			table.insert(refs.propSpawns, marker("PropSpawn", origin + pos + Vector3.new(0, 2, 0), folder))
		end
	end
	if #refs.enemySpawns == 0 then
		for i = 1, 10 do
			local angle = (i / 10) * math.pi * 2
			local r = math.min(def.size.X, def.size.Y) * 0.35
			table.insert(refs.enemySpawns, marker("EnemySpawn", origin + Vector3.new(math.cos(angle) * r, 4, math.sin(angle) * r), folder))
		end
	end
	if not refs.bossSpawn then
		local arena = part({
			Name = "BossArena",
			Size = Vector3.new(70, 1, 70),
			Position = origin + Vector3.new(0, 0.5, -def.size.Y / 2 + 45),
			Color = Color3.fromRGB(30, 30, 32),
			Material = Enum.Material.Slate,
		}, folder)
		arena:SetAttribute("BossArena", def.code)
		refs.bossSpawn = marker("BossSpawn", arena.Position + Vector3.new(0, 5, 0), folder)
	end

	-- Travel board: opens the Map tab.
	local board = part({
		Name = "TravelBoard",
		Size = Vector3.new(8, 6, 1),
		Position = origin + Vector3.new(-PLAZA_SIZE / 2 + 10, 4, PLAZA_SIZE / 2 - 10),
		Color = Color3.fromRGB(240, 235, 225),
		Material = Enum.Material.SmoothPlastic,
	}, folder)
	WorldBuilder.addPrompt(board, "Open map", "Travel board", function(player)
		Remotes.event("OpenLedger"):FireClient(player, "Map")
	end)

	districts[def.code] = refs
end

local function buildPlots(root: Folder)
	local folder = Instance.new("Folder")
	folder.Name = "Stores"
	folder.Parent = root

	local width = Config.STORE_PLOTS * Config.STORE_SPACING
	part({
		Name = "StoreStreet",
		Size = Vector3.new(width + 60, 4, Config.STORE_SIZE.Z + 60),
		Position = Vector3.new(width / 2 - Config.STORE_SPACING / 2, -2, Config.STORE_ROW_Z),
		Color = Color3.fromRGB(128, 124, 116),
		Material = Enum.Material.Pavement,
	}, folder)

	for i = 1, Config.STORE_PLOTS do
		local lot = Instance.new("Model")
		lot.Name = "Plot" .. i
		lot:SetAttribute("PlotIndex", i)
		local center = Vector3.new((i - 1) * Config.STORE_SPACING, 0, Config.STORE_ROW_Z)
		local base = part({
			Name = "Lot",
			Size = Vector3.new(Config.STORE_SIZE.X + 8, 0.4, Config.STORE_SIZE.Z + 8),
			Position = center + Vector3.new(0, 0.2, 0),
			Color = Color3.fromRGB(150, 146, 138),
			Material = Enum.Material.Concrete,
		}, lot)
		lot.PrimaryPart = base
		lot.Parent = folder
		table.insert(plots, lot)
	end
end

function WorldBuilder.build()
	local existing = Workspace:FindFirstChild("World")
	if existing then
		existing:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "World"
	root.Parent = Workspace

	for _, def in Config.DISTRICTS do
		buildDistrict(def, root)
	end
	buildPlots(root)

	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
end

function WorldBuilder.district(code: string): DistrictRefs?
	return districts[code]
end

function WorldBuilder.plot(index: number): Model?
	return plots[index]
end

-- Which district (or "Store") a world position is in.
function WorldBuilder.areaAt(position: Vector3): string
	if math.abs(position.Z - Config.STORE_ROW_Z) < 80 and position.X < Config.DISTRICT_SPACING / 2 then
		return "Store"
	end
	local idx = math.floor(position.X / Config.DISTRICT_SPACING + 0.5)
	local def = Config.DISTRICTS[idx]
	return if def then def.code else "Store"
end

return WorldBuilder
