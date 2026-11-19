--!strict
-- PropService: every grabbable object. Owns prop instances, the prop in each
-- player's hand, durability, throwing and the shared projectile stepper.
--
-- A prop is one BasePart tagged "Prop" with attributes PropId and Durability.
-- Art swap: a BasePart or MeshPart named after the prop id in
-- ReplicatedStorage.Assets.Props is cloned instead of the coded placeholder.
-- Store props carry StoreOwner (UserId) and Shelf; only the owner can grab them.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local RateLimit = require(Shared.RateLimit)
local Signal = require(Shared.Signal)

local PropService = {}

PropService.Grabbed = Signal.new() -- (player, part, propId)
PropService.Broken = Signal.new() -- (player?, propId)

local WorldBuilder: any
local Analytics: any

local propFolder: Folder
local held: { [Player]: BasePart } = {}
local slingCharged: { [Player]: boolean } = {}
local spawnSlots: { [BasePart]: BasePart? } = {} -- spawn marker -> prop sitting on it
local spawnTimers: { [BasePart]: number } = {}

---------------------------------------------------------------------------
-- Creation
---------------------------------------------------------------------------
local function assetFor(propId: string): BasePart?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local props = assets and assets:FindFirstChild("Props")
	local found = props and props:FindFirstChild(propId)
	if found and found:IsA("BasePart") then
		return found
	end
	return nil
end

export type CreateOpts = { storeOwner: number?, shelf: string?, anchored: boolean?, spawnMarker: BasePart? }

function PropService.create(propId: string, cframe: CFrame, opts: CreateOpts?): BasePart?
	local def = Config.PROPS[propId]
	if not def then
		warn("[PropService] unknown prop", propId)
		return nil
	end
	local p: BasePart
	local asset = assetFor(propId)
	if asset then
		p = asset:Clone()
	else
		local made = Instance.new("Part")
		made.Shape = if def.shape == "Ball" then Enum.PartType.Ball else Enum.PartType.Block
		made.Size = def.size
		made.Color = def.color
		made.Material = Enum.Material.SmoothPlastic
		made.TopSurface = Enum.SurfaceType.Smooth
		made.BottomSurface = Enum.SurfaceType.Smooth
		p = made
	end
	p.Name = propId
	p.CFrame = cframe
	p.Anchored = (opts and opts.anchored) == true
	p.CanCollide = true
	p:SetAttribute("PropId", propId)
	p:SetAttribute("Durability", def.durability)
	p:SetAttribute("Class", def.class)
	if opts and opts.storeOwner then
		p:SetAttribute("StoreOwner", opts.storeOwner)
		p:SetAttribute("Shelf", opts.shelf)
	end
	if opts and opts.spawnMarker then
		spawnSlots[opts.spawnMarker] = p
	end
	CollectionService:AddTag(p, "Prop")
	p.Parent = propFolder
	if not p.Anchored then
		pcall(function()
			p:SetNetworkOwner(nil)
		end)
	end
	return p
end

local function markLoose(p: BasePart)
	p:SetAttribute("LooseAt", os.clock())
	p:SetAttribute("StoreOwner", nil)
	p:SetAttribute("Shelf", nil)
	for marker, occupant in spawnSlots do
		if occupant == p then
			spawnSlots[marker] = nil
			spawnTimers[marker] = os.clock()
		end
	end
end

---------------------------------------------------------------------------
-- Holding
---------------------------------------------------------------------------
local function handOf(character: Model): BasePart?
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	return if hand and hand:IsA("BasePart") then hand else nil
end

function PropService.held(player: Player): (BasePart?, Config.PropDef?)
	local p = held[player]
	if p and p.Parent then
		local id = p:GetAttribute("PropId") :: string
		return p, Config.PROPS[id]
	end
	held[player] = nil
	return nil, nil
end

function PropService.classOf(player: Player): string
	local _, def = PropService.held(player)
	return if def then def.class else "Fists"
end

local function setHeldAttributes(player: Player)
	local p, def = PropService.held(player)
	player:SetAttribute("Holding", if p then p:GetAttribute("PropId") else nil)
	player:SetAttribute("HoldingClass", if def then def.class else "Fists")
	player:SetAttribute("HeldDurability", if p then p:GetAttribute("Durability") else nil)
	player:SetAttribute("HeldMaxDurability", if def then def.durability else nil)
	player:SetAttribute("Sling", slingCharged[player] == true)
end

local function attach(player: Player, p: BasePart): boolean
	local character = player.Character
	local hand = character and handOf(character)
	if not hand then
		return false
	end
	markLoose(p)
	p:SetAttribute("LooseAt", nil)
	p.Anchored = false
	p.CanCollide = false
	p.Massless = true
	local weld = Instance.new("Weld")
	weld.Name = "HoldWeld"
	weld.Part0 = hand
	weld.Part1 = p
	local reach = math.max(p.Size.Z * 0.35, 0.3)
	weld.C0 = CFrame.new(0, -hand.Size.Y / 2, -reach)
	weld.Parent = p
	p.Parent = character
	held[player] = p
	setHeldAttributes(player)
	return true
end

local function release(player: Player): BasePart?
	local p = held[player]
	held[player] = nil
	if p and p.Parent then
		local weld = p:FindFirstChild("HoldWeld")
		if weld then
			weld:Destroy()
		end
		p.Massless = false
		p.CanCollide = true
		p.Parent = propFolder
	end
	setHeldAttributes(player)
	return p
end

function PropService.drop(player: Player)
	local p = release(player)
	if p and p.Parent then
		markLoose(p)
		pcall(function()
			p:SetNetworkOwner(nil)
		end)
	end
end

function PropService.canGrab(player: Player, p: BasePart): boolean
	if not p.Parent or not CollectionService:HasTag(p, "Prop") or p.Parent ~= propFolder then
		return false
	end
	if p:GetAttribute("InFlight") then
		return false
	end
	local owner = p:GetAttribute("StoreOwner")
	if typeof(owner) == "number" and owner ~= player.UserId then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	return (root.Position - p.Position).Magnitude <= Config.GRAB_RANGE + p.Size.Magnitude / 2
end

function PropService.grab(player: Player, p: BasePart): boolean
	if not PropService.canGrab(player, p) then
		return false
	end
	local id = p:GetAttribute("PropId") :: string
	local shelf = p:GetAttribute("Shelf")
	PropService.drop(player)
	if not attach(player, p) then
		return false
	end
	slingCharged[player] = false
	setHeldAttributes(player)
	PropService.Grabbed:Fire(player, p, id, shelf)
	Analytics.funnel(player, "FirstGrab")
	return true
end

-- Put a fresh prop straight into the player's hand (catching a thrown knife).
function PropService.giveToHand(player: Player, propId: string): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	PropService.drop(player)
	local p = PropService.create(propId, root.CFrame)
	return p ~= nil and attach(player, p)
end

---------------------------------------------------------------------------
-- Durability
---------------------------------------------------------------------------
local function breakProp(p: BasePart, player: Player?)
	local id = p:GetAttribute("PropId") :: string
	Remotes.event("CombatFx"):FireAllClients({ kind = "break", pos = p.Position, prop = id })
	PropService.Broken:Fire(player, id)
	p:Destroy()
end

-- Wears the held prop. POW gives a chance to skip wear.
function PropService.wearHeld(player: Player, amount: number, pow: number)
	local p = held[player]
	if not p or not p.Parent then
		return
	end
	if math.random() < math.min(pow * 0.01, 0.5) then
		return
	end
	local dur = (p:GetAttribute("Durability") :: number? or 1) - amount
	p:SetAttribute("Durability", dur)
	if dur <= 0 then
		release(player)
		breakProp(p, player)
	end
	setHeldAttributes(player)
end

function PropService.chargeSling(player: Player)
	slingCharged[player] = true
	setHeldAttributes(player)
end

---------------------------------------------------------------------------
-- Projectiles: anchored parts stepped along a ballistic arc with raycasts.
---------------------------------------------------------------------------
export type LaunchOpts = {
	part: BasePart,
	origin: Vector3,
	velocity: Vector3,
	gravityScale: number,
	ignore: { Instance },
	maxTime: number?,
	-- Return "stop" to end the flight at this hit, "pass" to fly on ignoring that model.
	onHit: (result: RaycastResult, model: Model?) -> "stop" | "pass",
	onEnd: ((position: Vector3, stoppedByHit: boolean) -> ())?,
}

function PropService.launch(opts: LaunchOpts)
	local p = opts.part
	p.Anchored = true
	p.CanCollide = false
	p:SetAttribute("InFlight", true)
	p.CFrame = CFrame.lookAt(opts.origin, opts.origin + opts.velocity)
	local position = opts.origin
	local velocity = opts.velocity
	local gravity = Vector3.new(0, -Workspace.Gravity * opts.gravityScale, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = table.clone(opts.ignore)
	table.insert(ignore, p)
	params.FilterDescendantsInstances = ignore
	local started = os.clock()
	local maxTime = opts.maxTime or 3

	local conn: RBXScriptConnection
	local function finish(stopped: boolean)
		conn:Disconnect()
		if p.Parent then
			p:SetAttribute("InFlight", nil)
		end
		if opts.onEnd then
			opts.onEnd(position, stopped)
		end
	end
	conn = RunService.Heartbeat:Connect(function(dt)
		if not p.Parent then
			conn:Disconnect()
			return
		end
		local nextVelocity = velocity + gravity * dt
		local step = (velocity + nextVelocity) * 0.5 * dt
		local result = Workspace:Raycast(position, step, params)
		while result do
			local model = result.Instance:FindFirstAncestorOfClass("Model")
			local verdict = opts.onHit(result, model)
			if verdict == "stop" then
				position = result.Position
				p.CFrame = CFrame.new(position)
				finish(true)
				return
			end
			table.insert(ignore, model or result.Instance)
			params.FilterDescendantsInstances = ignore
			result = Workspace:Raycast(position, step, params)
		end
		position += step
		velocity = nextVelocity
		p.CFrame = CFrame.lookAt(position, position + velocity)
		if os.clock() - started > maxTime then
			finish(false)
		end
	end)
end

-- Unanchors a landed prop and lets it settle; it becomes loose.
function PropService.settle(p: BasePart, position: Vector3, wear: number)
	if not p.Parent then
		return
	end
	local dur = (p:GetAttribute("Durability") :: number? or 1) - wear
	p:SetAttribute("Durability", dur)
	if dur <= 0 then
		breakProp(p, nil)
		return
	end
	p.CFrame = CFrame.new(position + Vector3.new(0, 1, 0))
	p.Anchored = false
	p.CanCollide = true
	markLoose(p)
	pcall(function()
		p:SetNetworkOwner(nil)
	end)
end

-- Releases the held prop and returns it with its def and the sling bonus, for CombatService to fly.
function PropService.takeForThrow(player: Player): (BasePart?, Config.PropDef?, number)
	local p, def = PropService.held(player)
	if not p or not def then
		return nil, nil, 1
	end
	local bonus = if slingCharged[player] then 1 + Config.SLING_THROW_BONUS else 1
	slingCharged[player] = false
	release(player)
	p.Parent = propFolder
	return p, def, bonus
end

---------------------------------------------------------------------------
-- District loose-prop spawning and cleanup
---------------------------------------------------------------------------
local function playersIn(code: string): boolean
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Area") == code then
			return true
		end
	end
	return false
end

local function weightedPick(pool: { [string]: number }, rng: Random): string?
	local total = 0
	for _, n in pool do
		total += n
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber(0, total)
	for id, n in pool do
		roll -= n
		if roll <= 0 then
			return id
		end
	end
	return next(pool)
end

local rng = Random.new()

local function tickDistricts()
	local now = os.clock()
	for _, def in Config.DISTRICTS do
		if playersIn(def.code) then
			local refs = WorldBuilder.district(def.code)
			if refs then
				for _, marker in refs.propSpawns do
					local occupant = spawnSlots[marker]
					if (not occupant or not occupant.Parent) and now - (spawnTimers[marker] or 0) >= Config.PROP_RESPAWN_SECONDS then
						local id = weightedPick(def.props, rng)
						if id then
							PropService.create(id, marker.CFrame * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), { spawnMarker = marker })
							spawnTimers[marker] = now
						end
					end
				end
			end
		end
	end
	-- Loose props (dropped, thrown, knocked off shelves) time out.
	for _, p in propFolder:GetChildren() do
		if p:IsA("BasePart") then
			local looseAt = p:GetAttribute("LooseAt")
			if typeof(looseAt) == "number" and now - looseAt > Config.LOOSE_PROP_DESPAWN_SECONDS then
				p:Destroy()
			elseif p.Position.Y < -50 then
				p:Destroy()
			end
		end
	end
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------
function PropService.init(worldBuilder: any, analytics: any)
	WorldBuilder = worldBuilder
	Analytics = analytics

	propFolder = Instance.new("Folder")
	propFolder.Name = "Props"
	propFolder.Parent = Workspace

	Remotes.event("Grab").OnServerEvent:Connect(function(player: Player, target: any)
		if not RateLimit.check(player, "Grab") then
			return
		end
		if target == nil then
			PropService.drop(player)
			return
		end
		if typeof(target) == "Instance" and target:IsA("BasePart") then
			PropService.grab(player, target)
		end
	end)

	local function hook(player: Player)
		player.CharacterRemoving:Connect(function()
			local p = held[player]
			held[player] = nil
			slingCharged[player] = false
			if p and p.Parent then
				p:Destroy()
			end
			setHeldAttributes(player)
		end)
		setHeldAttributes(player)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		held[player] = nil
		slingCharged[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(tickDistricts)
			if not ok then
				warn("[PropService] tick failed:", err)
			end
		end
	end)
end

function PropService.folder(): Folder
	return propFolder
end

return PropService
