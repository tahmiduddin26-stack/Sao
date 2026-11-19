--!strict
-- CombatService: the player's side of every fight, all server-authoritative.
--  * Attack (light / heavy): cooldowns, combo finishers and the hitbox query.
--  * Throw: flies the held prop through PropService.launch and resolves hits.
--  * Dodge (i-frames; a dodge that eats a hit is a perfect dodge).
--  * Parry: blocks melee and, empty-handed, catches thrown props.
--  * Focus and Serious mode, including the body-scale change (Off duty / Serious).
--  * hurtPlayer(): the only way enemies damage a player.
-- Style (variety of prop classes in one fight) is tracked here for rewards.
-- The client sends intent only; clients get cosmetics through CombatFx.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local RateLimit = require(Shared.RateLimit)
local Stats = require(Shared.Stats)

local CombatService = {}

local deps: any = {}

type PlayerState = {
	nextSwing: number,
	lastSwing: number,
	combo: number,
	dodgeUntil: number,
	nextDodge: number,
	parryUntil: number,
	nextParry: number,
	styleClasses: { [string]: boolean },
	styleCatches: number,
	lastCombat: number,
}

local states: { [Player]: PlayerState } = {}

local function state(player: Player): PlayerState
	local s = states[player]
	if not s then
		s = {
			nextSwing = 0,
			lastSwing = 0,
			combo = 0,
			dodgeUntil = 0,
			nextDodge = 0,
			parryUntil = 0,
			nextParry = 0,
			styleClasses = {},
			styleCatches = 0,
			lastCombat = 0,
		}
		states[player] = s
	end
	return s
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function fx(payload: any)
	Remotes.event("CombatFx"):FireAllClients(payload)
end

local function aliveCharacter(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not humanoid or not root or humanoid.Health <= 0 then
		return nil, nil, nil
	end
	return character, humanoid, root
end

local function derived(player: Player): (number, number, number)
	local data = deps.Data.get(player)
	local d = Stats.fromData(data or {})
	return d.pow, d.spd, d.ins
end

function CombatService.isSerious(player: Player): boolean
	local untilTime = player:GetAttribute("SeriousUntil")
	return typeof(untilTime) == "number" and untilTime > now()
end

---------------------------------------------------------------------------
-- Style
---------------------------------------------------------------------------
local function touchStyle(player: Player, class: string?)
	local s = state(player)
	local t = os.clock()
	if t - s.lastCombat > Config.STYLE_WINDOW then
		table.clear(s.styleClasses)
		s.styleCatches = 0
	end
	s.lastCombat = t
	if class and class ~= "Fists" then
		s.styleClasses[class] = true
	end
end

function CombatService.styleMult(player: Player): number
	local s = state(player)
	local n = 0
	for _ in s.styleClasses do
		n += 1
	end
	local mult = 1 + Config.STYLE_PER_CLASS * math.max(n - 1, 0) + Config.STYLE_CATCH_BONUS * math.min(s.styleCatches, 2)
	return math.min(mult, Config.STYLE_MAX)
end

---------------------------------------------------------------------------
-- Focus and Serious
---------------------------------------------------------------------------
function CombatService.addFocus(player: Player, amount: number)
	if CombatService.isSerious(player) and amount > 0 then
		return -- Focus refills after Serious ends
	end
	local _, _, ins = derived(player)
	if amount > 0 then
		amount *= 1 + Config.FOCUS_INS_BONUS * ins
	end
	local focus = (player:GetAttribute("Focus") :: number?) or 0
	player:SetAttribute("Focus", math.clamp(focus + amount, 0, Config.FOCUS_MAX))
end

local function applyBody(player: Player)
	local _, humanoid = aliveCharacter(player)
	if not humanoid then
		return
	end
	local serious = CombatService.isSerious(player)
	local body = if serious then Config.BODY_SERIOUS else Config.BODY_OFF_DUTY
	for name, value in { BodyWidthScale = body.width, BodyDepthScale = body.depth, BodyHeightScale = body.height } do
		local v = humanoid:FindFirstChild(name)
		if v and v:IsA("NumberValue") then
			v.Value = value
		end
	end
	local _, spd = derived(player)
	humanoid.WalkSpeed = Stats.walkSpeed(spd, serious)
end
CombatService.applyBody = applyBody

local function goSerious(player: Player)
	local character = aliveCharacter(player)
	if not character or CombatService.isSerious(player) then
		return
	end
	local focus = (player:GetAttribute("Focus") :: number?) or 0
	if focus < Config.FOCUS_MAX then
		return
	end
	player:SetAttribute("Focus", 0)
	player:SetAttribute("SeriousUntil", now() + Config.SERIOUS_SECONDS)
	applyBody(player)
	fx({ kind = "serious", attacker = character, on = true })
	deps.Quest.notify(player, "serious")
	deps.Analytics.funnel(player, "FirstSerious")
	task.delay(Config.SERIOUS_SECONDS + 0.05, function()
		if player.Parent and not CombatService.isSerious(player) then
			applyBody(player)
			local c = player.Character
			if c then
				fx({ kind = "serious", attacker = c, on = false })
			end
		end
	end)
end

---------------------------------------------------------------------------
-- Melee
---------------------------------------------------------------------------
local function enemiesInBox(character: Model, root: BasePart, range: number, width: number): { Model }
	local cf = root.CFrame * CFrame.new(0, 0, -range / 2)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local found: { Model } = {}
	local seen: { [Model]: boolean } = {}
	for _, part in Workspace:GetPartBoundsInBox(cf, Vector3.new(width, 7, range), params) do
		local model = part:FindFirstAncestorOfClass("Model")
		while model and not CollectionService:HasTag(model, "Enemy") do
			model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model") or nil
		end
		if model and not seen[model] and deps.Enemy.isAlive(model) then
			seen[model] = true
			table.insert(found, model)
		end
	end
	return found
end

local function onAttack(player: Player, kind: any)
	if not RateLimit.check(player, "Attack") or (kind ~= "light" and kind ~= "heavy") then
		return
	end
	local character, _, root = aliveCharacter(player)
	if not character or not root then
		return
	end
	local s = state(player)
	local t = now()
	if t < s.nextSwing then
		return
	end

	local class = deps.Prop.classOf(player)
	local classDef = Config.PROP_CLASSES[class]
	local move = classDef[kind :: "light" | "heavy"]
	local pow, spd = derived(player)
	local serious = CombatService.isSerious(player)
	s.nextSwing = t + Config.swingCooldown(move.cooldown, spd, serious)

	local finisher = false
	if kind == "light" then
		if t - s.lastSwing > Config.COMBO_RESET_SECONDS + move.cooldown then
			s.combo = 0
		end
		s.combo += 1
		finisher = s.combo % classDef.comboHits == 0
	else
		s.combo = 0
	end
	s.lastSwing = t

	local _, propDef = deps.Prop.held(player)
	local base = if propDef then propDef.damage else Config.FISTS_DAMAGE
	local mult = move.mult * (if finisher then Config.FINISHER_MULT else 1)
	local damage = Config.damageFor(base, mult, pow, serious)
	local stagger = move.stagger or 0
	if finisher and classDef.special == "Pin" then
		stagger = math.max(stagger, 1)
	end

	fx({ kind = "swing", attacker = character, move = kind, class = class, finisher = finisher, serious = serious })

	local targets = enemiesInBox(character, root, move.range, move.width)
	if #targets == 0 then
		return
	end
	touchStyle(player, class)
	local look = root.CFrame.LookVector
	for _, model in targets do
		local knock = look * move.knockback * (if finisher then 1.4 else 1) + Vector3.new(0, move.knockback * 0.25, 0)
		deps.Enemy.damage(model, damage, player, { class = class, thrown = false, knockback = knock, stagger = stagger })
		fx({ kind = "hit", attacker = character, target = model, heavy = kind == "heavy" or finisher, serious = serious })
	end
	CombatService.addFocus(player, Config.FOCUS_ON_HIT)
	deps.Analytics.funnel(player, "FirstHit")
	if propDef then
		deps.Prop.wearHeld(player, 1, pow)
	end
	if kind == "heavy" and classDef.special == "Sling" then
		deps.Prop.chargeSling(player)
	end
end

---------------------------------------------------------------------------
-- Throw
---------------------------------------------------------------------------
local function onThrow(player: Player, aimPoint: any)
	if not RateLimit.check(player, "Throw") or typeof(aimPoint) ~= "Vector3" then
		return
	end
	local character, _, root = aliveCharacter(player)
	if not character or not root then
		return
	end
	if aimPoint.X ~= aimPoint.X or (aimPoint - root.Position).Magnitude > 2000 then
		return
	end
	local p, def, slingBonus = deps.Prop.takeForThrow(player)
	if not p or not def then
		return
	end
	local classDef = Config.PROP_CLASSES[def.class]
	local throw = classDef.throw
	local pow, _, _ = derived(player)
	local serious = CombatService.isSerious(player)
	local origin = root.Position + Vector3.new(0, 1.5, 0) + root.CFrame.LookVector * 2
	local dir = aimPoint - origin
	if dir.Magnitude < 1 then
		dir = root.CFrame.LookVector
	end
	dir = dir.Unit
	local damage = Config.damageFor(def.damage, throw.mult * slingBonus, pow, serious)
	local pierceLeft = throw.pierce or 1

	touchStyle(player, def.class)
	fx({ kind = "throw", attacker = character, class = def.class, prop = def.name })
	deps.Analytics.funnel(player, "FirstThrow")

	deps.Prop.launch({
		part = p,
		origin = origin,
		velocity = dir * throw.speed,
		gravityScale = throw.drop * 0.25,
		ignore = { character },
		maxTime = 2.5,
		onHit = function(result: RaycastResult, model: Model?)
			if model and CollectionService:HasTag(model, "Enemy") then
				if deps.Enemy.isAlive(model) then
					deps.Enemy.damage(model, damage, player, { class = def.class, thrown = true, knockback = dir * 30, stagger = throw.stagger })
					fx({ kind = "hit", attacker = character, target = model, heavy = true, serious = serious })
					CombatService.addFocus(player, Config.FOCUS_ON_HIT)
					pierceLeft -= 1
					if pierceLeft <= 0 then
						return "stop"
					end
				end
				return "pass"
			end
			if model and Players:GetPlayerFromCharacter(model) then
				return "pass" -- no friendly fire
			end
			if result.Instance:GetAttribute("PropId") then
				return "pass"
			end
			return "stop"
		end,
		onEnd = function(position: Vector3)
			deps.Prop.settle(p, position, 2)
		end,
	})
end

---------------------------------------------------------------------------
-- Dodge and parry
---------------------------------------------------------------------------
local function onDodge(player: Player)
	if not RateLimit.check(player, "Dodge") then
		return
	end
	local character = aliveCharacter(player)
	local s = state(player)
	local t = now()
	if not character or t < s.nextDodge then
		return
	end
	s.nextDodge = t + Config.DODGE_COOLDOWN
	s.dodgeUntil = t + Config.DODGE_SECONDS
	fx({ kind = "dodge", attacker = character })
end

local function onParry(player: Player)
	if not RateLimit.check(player, "Parry") then
		return
	end
	local character = aliveCharacter(player)
	local s = state(player)
	local t = now()
	if not character or t < s.nextParry then
		return
	end
	local _, _, ins = derived(player)
	s.nextParry = t + Config.PARRY_COOLDOWN
	s.parryUntil = t + Config.catchWindow(ins)
	fx({ kind = "parry", attacker = character })
end

-- The only way enemies hurt players. Returns what happened so the enemy can react.
export type HurtResult = "none" | "hit" | "dodged" | "parried" | "caught"

function CombatService.hurtPlayer(player: Player, amount: number, attacker: Model?, kind: "melee" | "projectile", propId: string?): HurtResult
	local character, humanoid = aliveCharacter(player)
	if not character or not humanoid then
		return "none"
	end
	local s = state(player)
	local t = now()
	touchStyle(player, nil)
	if t < s.dodgeUntil then
		CombatService.addFocus(player, Config.FOCUS_ON_PERFECT_DODGE)
		fx({ kind = "perfect", attacker = character })
		return "dodged"
	end
	if t < s.parryUntil then
		s.parryUntil = 0
		local holding = deps.Prop.held(player)
		if kind == "projectile" and propId and not holding then
			deps.Prop.giveToHand(player, propId)
			s.styleCatches += 1
			CombatService.addFocus(player, Config.FOCUS_ON_CATCH)
			fx({ kind = "catch", attacker = character, prop = propId })
			deps.Quest.notify(player, "catch")
			deps.Analytics.funnel(player, "FirstCatch")
			return "caught"
		end
		CombatService.addFocus(player, Config.FOCUS_ON_CATCH * 0.5)
		fx({ kind = "parried", attacker = character, target = attacker })
		return "parried"
	end
	humanoid:TakeDamage(amount)
	CombatService.addFocus(player, Config.FOCUS_ON_HURT)
	fx({ kind = "hurt", attacker = attacker, target = character, amount = amount })
	return "hit"
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------
local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.BreakJointsOnDeath = false
	player:SetAttribute("SeriousUntil", nil)
	player:SetAttribute("Focus", 0)
	local s = state(player)
	s.combo = 0
	s.dodgeUntil = 0
	s.parryUntil = 0
	task.defer(applyBody, player)
	humanoid.Died:Connect(function()
		deps.Prop.drop(player)
		deps.Bounty.onPlayerKO(player)
		fx({ kind = "ko", target = character })
	end)
end

function CombatService.init(dependencies: any)
	deps = dependencies

	Remotes.event("Attack").OnServerEvent:Connect(onAttack)
	Remotes.event("Throw").OnServerEvent:Connect(onThrow)
	Remotes.event("Dodge").OnServerEvent:Connect(onDodge)
	Remotes.event("Parry").OnServerEvent:Connect(onParry)
	Remotes.event("GoSerious").OnServerEvent:Connect(function(player: Player)
		if RateLimit.check(player, "GoSerious") then
			goSerious(player)
		end
	end)

	local function hook(player: Player)
		player.CharacterAdded:Connect(function(c)
			onCharacter(player, c)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	-- Stat changes (allocation, level up) refresh speed and HP-related body values.
	deps.Data.Changed:Connect(function(player: Player)
		applyBody(player)
	end)
end

return CombatService
