--!strict
-- EnemyService: every hostile NPC (and the rig factory customers share).
--  * Rigs: ReplicatedStorage.Assets.Enemies[<id>] if present, else an R15 rig
--    built from a HumanoidDescription, else a block rig if that fails.
--  * AI: chase, wind up (WindupUntil attribute -> client "!" tell), strike.
--    A stagger during the wind-up cancels the attack. Couriers throw knives
--    that players can dodge, parry or catch empty-handed.
--  * Damage and KO: nobody dies. A KO'd enemy goes limp, gets zip-tied and is
--    cleaned up; rewards and Job events fire from here.
--  * Population: each district with a player in it keeps its roster alive,
--    and stepping into the boss arena calls the boss.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local EnemyService = {}

local deps: any = {}
local enemyFolder: Folder
local lastKO: { [string]: { [string]: number } } = {} -- district -> enemyId -> time
local bossAlive: { [string]: Model } = {}
local bossCooldown: { [string]: number } = {}

local BOSS_RESPAWN_SECONDS = 45
local AI_TICK = 0.15
local MELEE_SLACK = 1.5 -- swing from a little outside range; the hitbox reaches attackRange + 1.5
local WANDER_RADIUS = 70 -- idle district enemies patrol within this many studs of the plaza
local rng = Random.new()
local WALK_ANIM = "rbxassetid://507777826" -- Roblox default R15 walk
local IDLE_ANIM = "rbxassetid://507766388" -- Roblox default R15 idle
local SKIN = Color3.fromRGB(234, 192, 160)

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function fx(payload: any)
	Remotes.event("CombatFx"):FireAllClients(payload)
end

---------------------------------------------------------------------------
-- Rigs
---------------------------------------------------------------------------
local function blockRig(color: Color3, scale: number): Model
	local model = Instance.new("Model")
	local function bodyPart(name: string, size: Vector3, c: Color3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size * scale
		p.Color = c
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local root = bodyPart("HumanoidRootPart", Vector3.new(2, 2, 1), color)
	root.Transparency = 1
	local torso = bodyPart("UpperTorso", Vector3.new(2, 2, 1), color)
	local head = bodyPart("Head", Vector3.new(1.2, 1.2, 1.2), SKIN)
	local legs = bodyPart("Legs", Vector3.new(2, 2, 1), Color3.fromRGB(40, 40, 45))
	local hand = bodyPart("RightHand", Vector3.new(0.6, 0.6, 0.6), SKIN)
	torso.CFrame = root.CFrame
	head.CFrame = root.CFrame * CFrame.new(0, 1.7 * scale, 0)
	legs.CFrame = root.CFrame * CFrame.new(0, -2 * scale, 0)
	hand.CFrame = root.CFrame * CFrame.new(1.3 * scale, -0.6 * scale, -0.4 * scale)
	for _, p in { torso, head, legs, hand } do
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = p
		w.Parent = root
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 3 * scale
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

-- kind: an enemy id, or "customer".
function EnemyService.makeRig(kind: string, color: Color3, scale: number): Model
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Enemies")
	local template = folder and folder:FindFirstChild(kind)
	if template and template:IsA("Model") and template:FindFirstChildOfClass("Humanoid") then
		return template:Clone()
	end
	local ok, rig = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		desc.HeadColor = SKIN
		desc.LeftArmColor = SKIN
		desc.RightArmColor = SKIN
		desc.TorsoColor = color
		desc.LeftLegColor = Color3.fromRGB(35, 35, 40)
		desc.RightLegColor = Color3.fromRGB(35, 35, 40)
		desc.HeightScale = scale
		desc.WidthScale = scale
		desc.DepthScale = scale
		desc.HeadScale = 1
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if ok and rig then
		return rig
	end
	return blockRig(color, scale)
end

local function playLoop(humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local okW, walk = pcall(function()
		local a = Instance.new("Animation")
		a.AnimationId = WALK_ANIM
		return (animator :: Animator):LoadAnimation(a)
	end)
	local okI, idle = pcall(function()
		local a = Instance.new("Animation")
		a.AnimationId = IDLE_ANIM
		return (animator :: Animator):LoadAnimation(a)
	end)
	if not okW or not okI then
		return
	end
	idle.Looped = true
	walk.Looped = true
	idle:Play()
	humanoid.Running:Connect(function(speed)
		if speed > 0.5 then
			if not walk.IsPlaying then
				walk:Play(0.15)
			end
			walk:AdjustSpeed(speed / 14)
		elseif walk.IsPlaying then
			walk:Stop(0.2)
		end
	end)
end
EnemyService.playLoop = playLoop

---------------------------------------------------------------------------
-- State helpers
---------------------------------------------------------------------------
function EnemyService.isAlive(model: Model): boolean
	if not model.Parent or model:GetAttribute("KO") then
		return false
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function defOf(model: Model): Config.EnemyDef?
	local id = model:GetAttribute("EnemyId")
	return if typeof(id) == "string" then Config.ENEMIES[id] else nil
end

local function stunned(model: Model): boolean
	local s = model:GetAttribute("StunUntil")
	return typeof(s) == "number" and s > now()
end

local function setStun(model: Model, seconds: number)
	if seconds <= 0 then
		return
	end
	if model:GetAttribute("Boss") then
		seconds *= 0.4
	end
	local current = (model:GetAttribute("StunUntil") :: number?) or 0
	model:SetAttribute("StunUntil", math.max(current, now() + seconds))
	model:SetAttribute("WindupUntil", nil) -- a stagger cancels the attack
end

---------------------------------------------------------------------------
-- Targeting
---------------------------------------------------------------------------
local function targetFor(model: Model, root: BasePart, def: Config.EnemyDef): (Player?, BasePart?, number)
	local owner = model:GetAttribute("StoreOwner")
	local area = model:GetAttribute("District")
	local best: Player?, bestRoot: BasePart?, bestDist = nil, nil, def.aggro
	for _, player in Players:GetPlayers() do
		if typeof(owner) == "number" and player.UserId ~= owner then
			continue
		end
		if typeof(area) == "string" and player:GetAttribute("Area") ~= area then
			continue
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local pr = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoid and pr and humanoid.Health > 0 then
			local d = (pr.Position - root.Position).Magnitude
			if d < bestDist then
				best, bestRoot, bestDist = player, pr, d
			end
		end
	end
	return best, bestRoot, bestDist
end

---------------------------------------------------------------------------
-- Attacks
---------------------------------------------------------------------------
local function meleeStrike(model: Model, root: BasePart, def: Config.EnemyDef, damage: number)
	local range = def.attackRange + 1.5
	local cf = root.CFrame * CFrame.new(0, 0, -range / 2)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model, enemyFolder }
	local hitPlayers: { [Player]: boolean } = {}
	for _, part in Workspace:GetPartBoundsInBox(cf, Vector3.new(5 * def.scale, 7, range), params) do
		local character = part:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if player and not hitPlayers[player] then
			hitPlayers[player] = true
			local result = deps.Combat.hurtPlayer(player, damage, model, "melee")
			if result == "parried" then
				setStun(model, Config.STAGGER_SECONDS * 1.5)
			end
		end
	end
	fx({ kind = "enemySwing", attacker = model })
end

local function throwKnife(model: Model, root: BasePart, target: BasePart, damage: number)
	local origin = root.Position + Vector3.new(0, 1.5, 0) + root.CFrame.LookVector * 2
	local speed = 110
	local travel = (target.Position - origin).Magnitude / speed
	local aim = target.Position + target.AssemblyLinearVelocity * travel * 0.6
	local knife = deps.Prop.create("knife", CFrame.new(origin), { anchored = true })
	if not knife then
		return
	end
	fx({ kind = "enemyThrow", attacker = model })
	deps.Prop.launch({
		part = knife,
		origin = origin,
		velocity = (aim - origin).Unit * speed,
		gravityScale = 0.03,
		ignore = { model, enemyFolder },
		maxTime = 2,
		onHit = function(_result: RaycastResult, hitModel: Model?)
			local player = hitModel and Players:GetPlayerFromCharacter(hitModel)
			if player then
				local result = deps.Combat.hurtPlayer(player, damage, model, "projectile", "knife")
				if result == "dodged" then
					return "pass"
				end
				knife:Destroy()
				return "stop"
			end
			if hitModel and CollectionService:HasTag(hitModel, "Enemy") then
				return "pass"
			end
			return "stop"
		end,
		onEnd = function(position: Vector3)
			if knife.Parent then
				deps.Prop.settle(knife, position, 0)
			end
		end,
	})
end

local function attack(model: Model, root: BasePart, humanoid: Humanoid, def: Config.EnemyDef, target: BasePart)
	local enraged = model:GetAttribute("Enraged") == true
	local windup = def.windup * (if enraged then 0.75 else 1)
	model:SetAttribute("WindupUntil", now() + windup)
	model:SetAttribute("NextAttack", now() + def.cooldown * (if enraged then 0.7 else 1) + windup)
	humanoid:MoveTo(root.Position)
	root.CFrame = CFrame.lookAt(root.Position, Vector3.new(target.Position.X, root.Position.Y, target.Position.Z))
	task.wait(windup)
	if not EnemyService.isAlive(model) or model:GetAttribute("WindupUntil") == nil then
		return -- staggered out of it
	end
	model:SetAttribute("WindupUntil", nil)
	local bossMult = if model:GetAttribute("Boss") then 1.6 else 1
	local damage = math.floor(def.damage * bossMult)
	if def.ranged then
		throwKnife(model, root, target, damage)
	else
		meleeStrike(model, root, def, damage)
	end
end

local function runAI(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local def = defOf(model)
	if not humanoid or not root or not def then
		return
	end
	local busy = false
	local nextWander = 0
	local district = model:GetAttribute("District")
	local center = if typeof(district) == "string" then Config.districtOrigin(district) else nil
	while EnemyService.isAlive(model) do
		task.wait(AI_TICK)
		if busy or not EnemyService.isAlive(model) then
			continue
		end
		if stunned(model) then
			humanoid:MoveTo(root.Position)
			continue
		end
		local player, target, dist = targetFor(model, root, def)
		if not player or not target then
			-- Patrol: drift toward the plaza so district enemies find players.
			if center and os.clock() >= nextWander then
				nextWander = os.clock() + rng:NextNumber(3, 6)
				local offset = Vector3.new(rng:NextNumber(-WANDER_RADIUS, WANDER_RADIUS), 0, rng:NextNumber(-WANDER_RADIUS, WANDER_RADIUS))
				humanoid:MoveTo(center + offset)
			elseif not center then
				humanoid:MoveTo(root.Position)
			end
			continue
		end
		local ready = now() >= ((model:GetAttribute("NextAttack") :: number?) or 0)
		if def.ranged then
			if dist < 14 then
				humanoid:MoveTo(root.Position + (root.Position - target.Position).Unit * 10)
			elseif dist > def.attackRange then
				humanoid:MoveTo(target.Position)
			elseif ready then
				busy = true
				attack(model, root, humanoid, def, target)
				busy = false
			else
				humanoid:MoveTo(root.Position)
			end
		else
			if dist > def.attackRange + MELEE_SLACK then
				humanoid:MoveTo(target.Position)
			elseif ready then
				busy = true
				attack(model, root, humanoid, def, target)
				busy = false
			end
		end
	end
end

---------------------------------------------------------------------------
-- Spawning
---------------------------------------------------------------------------
export type SpawnCtx = { district: string?, storeOwner: number?, boss: { name: string, title: string, hpMult: number, scale: number }? }

local function setup(model: Model, enemyId: string, def: Config.EnemyDef, ctx: SpawnCtx)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local maxHp = def.hp * (if ctx.boss then ctx.boss.hpMult else 1)
	humanoid.MaxHealth = maxHp
	humanoid.Health = maxHp
	humanoid.WalkSpeed = def.speed
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayName = if ctx.boss then ctx.boss.name else def.name
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	model:SetAttribute("EnemyId", enemyId)
	model:SetAttribute("District", ctx.district)
	model:SetAttribute("StoreOwner", ctx.storeOwner)
	model:SetAttribute("Boss", if ctx.boss then true else nil)
	model:SetAttribute("BossTitle", if ctx.boss then ctx.boss.title else nil)
	model:SetAttribute("NextAttack", now() + 1.2)
	CollectionService:AddTag(model, "Enemy")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
	playLoop(humanoid)
	task.spawn(runAI, model)
end

function EnemyService.spawn(enemyId: string, cframe: CFrame, ctx: SpawnCtx): Model?
	local def = Config.ENEMIES[enemyId]
	if not def then
		return nil
	end
	local scale = def.scale * (if ctx.boss then ctx.boss.scale / def.scale else 1)
	local model = EnemyService.makeRig(enemyId, def.color, scale)
	model.Name = enemyId
	model:PivotTo(cframe)
	model.Parent = enemyFolder
	setup(model, enemyId, def, ctx)
	return model
end

-- Turns an existing rig (a store customer) into an enemy where it stands.
function EnemyService.convert(model: Model, enemyId: string, ctx: SpawnCtx)
	local def = Config.ENEMIES[enemyId]
	if not def or not model.Parent then
		return
	end
	model.Parent = enemyFolder
	setup(model, enemyId, def, ctx)
	fx({ kind = "reveal", attacker = model })
end

---------------------------------------------------------------------------
-- Damage and knockouts
---------------------------------------------------------------------------
export type HitCtx = { class: string, thrown: boolean, knockback: Vector3?, stagger: number? }

local function knockout(model: Model, player: Player, ctx: HitCtx)
	local def = defOf(model)
	if not def then
		return
	end
	model:SetAttribute("KO", true)
	model:SetAttribute("WindupUntil", nil)
	CollectionService:RemoveTag(model, "Enemy")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = true
		humanoid.DisplayName = "KO"
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	fx({ kind = "ko", target = model, boss = model:GetAttribute("Boss") == true })

	local enemyId = model:GetAttribute("EnemyId") :: string
	local district = model:GetAttribute("District")
	local storeOwner = model:GetAttribute("StoreOwner")
	local isBoss = model:GetAttribute("Boss") == true

	deps.Bounty.onEnemyKO(player, def, { boss = isBoss, class = ctx.class, thrown = ctx.thrown })

	local quest = deps.Quest
	quest.notify(player, "ko:any")
	quest.notify(player, "ko:" .. enemyId)
	quest.notify(player, "ko:" .. ctx.class)
	if ctx.thrown then
		quest.notify(player, "throwko")
	end
	if typeof(storeOwner) == "number" then
		quest.notify(player, "ko:assassin")
	end
	if isBoss and typeof(district) == "string" then
		quest.notify(player, "boss:" .. district)
		deps.District.bossBeaten(player, district)
		bossAlive[district] = nil
		bossCooldown[district] = os.clock()
	end
	if typeof(district) == "string" then
		lastKO[district] = lastKO[district] or {}
		lastKO[district][enemyId] = os.clock()
	end

	task.delay(Config.KO_CLEANUP_SECONDS, function()
		if model.Parent then
			fx({ kind = "cleanup", pos = model:GetPivot().Position })
			model:Destroy()
		end
	end)
end

function EnemyService.damage(model: Model, amount: number, player: Player, ctx: HitCtx): boolean
	if not EnemyService.isAlive(model) then
		return false
	end
	local def = defOf(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not def or not humanoid then
		return false
	end
	if def.armour and ctx.class ~= "Big" then
		amount *= 1 - def.armour
	end
	amount = math.max(1, math.floor(amount + 0.5))
	local hp = humanoid.Health - amount
	fx({ kind = "dmg", target = model, amount = amount })
	if model:GetAttribute("Boss") and not model:GetAttribute("Enraged") and hp <= humanoid.MaxHealth * 0.5 then
		model:SetAttribute("Enraged", true)
		humanoid.WalkSpeed = def.speed * 1.2
		fx({ kind = "enrage", attacker = model })
	end
	if hp <= 0 then
		humanoid.Health = 1
		knockout(model, player, ctx)
		return true
	end
	humanoid.Health = hp
	if ctx.stagger then
		setStun(model, ctx.stagger)
	end
	if root and ctx.knockback then
		local k = ctx.knockback * (if model:GetAttribute("Boss") then 0.25 else 1)
		root.AssemblyLinearVelocity += k
	end
	return false
end

---------------------------------------------------------------------------
-- District population and bosses
---------------------------------------------------------------------------
local function aliveIn(district: string): { [string]: number }
	local counts: { [string]: number } = {}
	for _, model in enemyFolder:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("District") == district and not model:GetAttribute("Boss") and EnemyService.isAlive(model) then
			local id = model:GetAttribute("EnemyId") :: string
			counts[id] = (counts[id] or 0) + 1
		end
	end
	return counts
end


local function playersInArea(code: string): { Player }
	local list = {}
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Area") == code then
			table.insert(list, p)
		end
	end
	return list
end

local function tickPopulation()
	for _, def in Config.DISTRICTS do
		local present = playersInArea(def.code)
		local refs = deps.World.district(def.code)
		if #present == 0 or not refs then
			continue
		end
		local counts = aliveIn(def.code)
		local koTimes = lastKO[def.code] or {}
		for enemyId, want in def.enemies do
			local have = counts[enemyId] or 0
			if have < want and os.clock() - (koTimes[enemyId] or 0) >= Config.ENEMY_RESPAWN_SECONDS then
				local marker = refs.enemySpawns[rng:NextInteger(1, #refs.enemySpawns)]
				EnemyService.spawn(enemyId, marker.CFrame, { district = def.code })
				koTimes[enemyId] = os.clock() - Config.ENEMY_RESPAWN_SECONDS + 1.5 -- stagger the next spawn
				lastKO[def.code] = koTimes
			end
		end

		-- Boss: called when someone steps into the arena.
		local boss = bossAlive[def.code]
		if boss and not EnemyService.isAlive(boss) then
			bossAlive[def.code] = nil
			boss = nil
		end
		if not boss and os.clock() - (bossCooldown[def.code] or -1e9) >= BOSS_RESPAWN_SECONDS then
			local spawnPos = refs.bossSpawn.Position
			for _, p in present do
				local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if r and (Vector3.new(r.Position.X, 0, r.Position.Z) - Vector3.new(spawnPos.X, 0, spawnPos.Z)).Magnitude < 32 then
					local b = def.boss
					local model = EnemyService.spawn(b.base, refs.bossSpawn.CFrame, { district = def.code, boss = b })
					if model then
						bossAlive[def.code] = model
						for _, viewer in present do
							Remotes.event("Banner"):FireClient(viewer, { kind = "BossIntro", name = b.name, title = b.title, district = def.code })
						end
					end
					break
				end
			end
		end
	end

	-- Enemies left behind in empty districts are cleared so servers stay light.
	for _, model in enemyFolder:GetChildren() do
		local district = model:GetAttribute("District")
		if typeof(district) == "string" and #playersInArea(district) == 0 then
			if bossAlive[district] == model then
				bossAlive[district] = nil
			end
			model:Destroy()
		end
	end
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------
function EnemyService.init(dependencies: any)
	deps = dependencies
	enemyFolder = Instance.new("Folder")
	enemyFolder.Name = "Enemies"
	enemyFolder.Parent = Workspace

	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(tickPopulation)
			if not ok then
				warn("[EnemyService] population tick failed:", err)
			end
		end
	end)
end

-- Removes every enemy owned by a store (when its owner leaves).
function EnemyService.clearStore(userId: number)
	for _, model in enemyFolder:GetChildren() do
		if model:GetAttribute("StoreOwner") == userId then
			model:Destroy()
		end
	end
end

function EnemyService.folder(): Folder
	return enemyFolder
end

return EnemyService
