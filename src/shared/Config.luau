--!strict
-- Config: the single source of truth for every tunable in Clocked Out.
-- Numbers, props, enemies, districts, the store, products, codes and admin IDs.
-- Colours, fonts and motion timings live in the client Theme module instead.
-- An ID of 0 means "not created on Roblox yet"; Studio simulates those flows.

local Config = {}

---------------------------------------------------------------------------
-- Meta
---------------------------------------------------------------------------
Config.GAME_NAME = "Clocked Out"
Config.VERSION = "0.2.0-brawl"
Config.DATASTORE_NAME = "ClockedOut_v1"
Config.LEADERBOARD_DATASTORE_NAME = "ClockedOut_Bounty_v1"

-- Admins: Studio, the place owner, group rank >= ADMIN_GROUP_RANK, or these user IDs.
Config.ADMIN_IDS = {} :: { number }
Config.GROUP_ID = 0
Config.ADMIN_GROUP_RANK = 254

---------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------
Config.AUTOSAVE_SECONDS = 90
Config.SESSION_LOCK_TTL = 300
Config.SESSION_LOCK_RETRIES = 5
Config.SESSION_LOCK_RETRY_WAIT = 4
Config.DATASTORE_RETRIES = 5
Config.MAX_STORED_RECEIPTS = 60

---------------------------------------------------------------------------
-- Progression
---------------------------------------------------------------------------
Config.STAT_POINTS_PER_LEVEL = 3
Config.STATS = {
	{ key = "POW", name = "Power", blurb = "Hits harder, props last longer, more HP." },
	{ key = "SPD", name = "Speed", blurb = "Moves faster and recovers from swings sooner." },
	{ key = "INS", name = "Instinct", blurb = "Wider catch window and faster Focus gain." },
}

function Config.xpToNext(level: number): number
	return math.floor(80 + 40 * level ^ 1.35)
end

---------------------------------------------------------------------------
-- Body and resources
---------------------------------------------------------------------------
Config.BASE_HP = 120
Config.HP_PER_LEVEL = 10
Config.HP_PER_POW = 4

Config.WALK_OFF_DUTY = 14
Config.WALK_SERIOUS = 24
Config.WALK_PER_SPD = 0.08

-- R15 body scale values. Off duty is the comfortable shopkeeper; Serious is the old pro.
Config.BODY_OFF_DUTY = { width = 1.35, depth = 1.4, height = 0.97 }
Config.BODY_SERIOUS = { width = 0.92, depth = 0.92, height = 1.03 }

Config.FOCUS_MAX = 100
Config.FOCUS_ON_HIT = 6
Config.FOCUS_ON_CATCH = 20
Config.FOCUS_ON_PERFECT_DODGE = 12
Config.FOCUS_ON_HURT = -8
Config.FOCUS_INS_BONUS = 0.01 -- +1% Focus gain per Instinct point

Config.SERIOUS_SECONDS = 12
Config.SERIOUS_DAMAGE_MULT = 1.5

---------------------------------------------------------------------------
-- Combat
---------------------------------------------------------------------------
Config.GRAB_RANGE = 9
Config.DODGE_SECONDS = 0.35 -- invulnerable window
Config.DODGE_COOLDOWN = 0.9
Config.DODGE_IMPULSE = 70
Config.PARRY_COOLDOWN = 0.8
Config.STAGGER_SECONDS = 0.6
Config.HITSTOP_SECONDS = 0.05
Config.COMBO_RESET_SECONDS = 0.9
Config.FISTS_DAMAGE = 8
Config.FINISHER_MULT = 1.3 -- last hit of a light combo

function Config.catchWindow(ins: number): number
	return 0.22 + 0.004 * ins
end

function Config.damageFor(base: number, mult: number, pow: number, serious: boolean): number
	local dmg = base * mult * (1 + 0.02 * pow)
	if serious then
		dmg *= Config.SERIOUS_DAMAGE_MULT
	end
	return math.floor(dmg + 0.5)
end

function Config.swingCooldown(base: number, spd: number, serious: boolean): number
	local cd = base / (1 + 0.01 * spd)
	if serious then
		cd *= 0.75
	end
	return cd
end

-- Style: variety pays. Each new prop class used in a fight adds STYLE_PER_CLASS.
Config.STYLE_PER_CLASS = 0.25
Config.STYLE_MAX = 2
Config.STYLE_CATCH_BONUS = 0.25
Config.STYLE_WINDOW = 20 -- seconds of no combat before the style chain resets

---------------------------------------------------------------------------
-- Prop classes: the moveset. Every prop belongs to exactly one class.
-- range/width are the hitbox in studs in front of the player.
---------------------------------------------------------------------------
export type MoveDef = { mult: number, range: number, width: number, cooldown: number, knockback: number, stagger: number? }
export type ThrowDef = { mult: number, speed: number, drop: number, stagger: number, pierce: number? }
export type ClassDef = {
	name: string,
	blurb: string,
	light: MoveDef,
	heavy: MoveDef,
	throw: ThrowDef,
	special: string,
	comboHits: number,
}

Config.PROP_CLASSES = {
	Fists = {
		name = "Fists",
		blurb = "Always with you. Quick, short and honest.",
		light = { mult = 1, range = 5, width = 4, cooldown = 0.32, knockback = 8 },
		heavy = { mult = 1.8, range = 5.5, width = 5, cooldown = 0.8, knockback = 30, stagger = 0.5 },
		throw = { mult = 0, speed = 0, drop = 0, stagger = 0 },
		special = "None",
		comboHits = 3,
	},
	Pocket = {
		name = "Pocket",
		blurb = "Pens, keys, chopsticks. Fast jabs; the third hit pins the target.",
		light = { mult = 1, range = 5, width = 3.5, cooldown = 0.24, knockback = 4 },
		heavy = { mult = 1.6, range = 6, width = 3.5, cooldown = 0.6, knockback = 12, stagger = 0.9 },
		throw = { mult = 1.4, speed = 160, drop = 0.1, stagger = 0.5 },
		special = "Pin",
		comboHits = 3,
	},
	Blunt = {
		name = "Blunt",
		blurb = "Cans, pans, kettles. A three-hit combo and a heavy knockdown.",
		light = { mult = 1.2, range = 5.5, width = 5, cooldown = 0.38, knockback = 14 },
		heavy = { mult = 2.4, range = 6, width = 6, cooldown = 0.95, knockback = 55, stagger = 0.8 },
		throw = { mult = 1.8, speed = 110, drop = 0.6, stagger = 0.7 },
		special = "Ricochet",
		comboHits = 3,
	},
	Reach = {
		name = "Reach",
		blurb = "Mops, brooms, umbrellas. Wide sweeps that hit crowds.",
		light = { mult = 1, range = 9, width = 9, cooldown = 0.45, knockback = 18 },
		heavy = { mult = 1.9, range = 10, width = 12, cooldown = 1.05, knockback = 40, stagger = 0.6 },
		throw = { mult = 1.6, speed = 140, drop = 0.3, stagger = 0.6, pierce = 2 },
		special = "Sweep",
		comboHits = 2,
	},
	Big = {
		name = "Big",
		blurb = "Chairs, carts, signs. Slow, wide and guard-breaking.",
		light = { mult = 1.8, range = 7, width = 8, cooldown = 0.7, knockback = 40 },
		heavy = { mult = 3.2, range = 7.5, width = 10, cooldown = 1.4, knockback = 80, stagger = 1.1 },
		throw = { mult = 2.4, speed = 80, drop = 0.9, stagger = 1, pierce = 3 },
		special = "GuardBreak",
		comboHits = 2,
	},
	Soft = {
		name = "Soft",
		blurb = "Bags, towels, aprons. Wrap, spin and sling. Your next throw hits harder.",
		light = { mult = 0.7, range = 6, width = 6, cooldown = 0.35, knockback = 6, stagger = 0.4 },
		heavy = { mult = 1.2, range = 6.5, width = 7, cooldown = 0.8, knockback = 45, stagger = 0.9 },
		throw = { mult = 0.8, speed = 100, drop = 0.4, stagger = 1.4 },
		special = "Sling",
		comboHits = 3,
	},
} :: { [string]: ClassDef }

Config.CLASS_ORDER = { "Pocket", "Blunt", "Reach", "Big", "Soft" }
Config.SLING_THROW_BONUS = 0.5

---------------------------------------------------------------------------
-- Props. Placeholder looks are built from size/shape/color; drop a Model named
-- after the id into ReplicatedStorage.Assets.Props to replace one.
---------------------------------------------------------------------------
export type PropDef = {
	name: string,
	class: string,
	damage: number,
	durability: number,
	size: Vector3,
	shape: string, -- "Block" | "Cylinder" | "Ball"
	color: Color3,
	rarity: string,
	enemyOnly: boolean?,
}

local function prop(name: string, class: string, damage: number, durability: number, size: Vector3, shape: string, color: Color3, rarity: string?): PropDef
	return { name = name, class = class, damage = damage, durability = durability, size = size, shape = shape, color = color, rarity = rarity or "Common" }
end

Config.PROPS = {
	-- Pocket
	pen = prop("Ballpoint Pen", "Pocket", 9, 10, Vector3.new(0.15, 0.15, 1.1), "Cylinder", Color3.fromRGB(30, 60, 160)),
	chopsticks = prop("Chopsticks", "Pocket", 8, 12, Vector3.new(0.3, 0.12, 1.4), "Block", Color3.fromRGB(196, 160, 110)),
	keys = prop("Key Ring", "Pocket", 10, 14, Vector3.new(0.5, 0.15, 0.7), "Block", Color3.fromRGB(190, 190, 190)),
	ruler = prop("Steel Ruler", "Pocket", 11, 16, Vector3.new(0.1, 0.4, 1.6), "Block", Color3.fromRGB(200, 205, 210), "Fine"),
	knife = prop("Thrown Knife", "Pocket", 14, 6, Vector3.new(0.1, 0.3, 1.2), "Block", Color3.fromRGB(220, 220, 225), "Fine"),
	-- Blunt
	can_beans = prop("Can of Beans", "Blunt", 12, 8, Vector3.new(0.7, 0.9, 0.7), "Cylinder", Color3.fromRGB(200, 70, 50)),
	canned_coffee = prop("Canned Coffee", "Blunt", 11, 6, Vector3.new(0.5, 0.8, 0.5), "Cylinder", Color3.fromRGB(120, 80, 50)),
	bottle = prop("Water Bottle", "Blunt", 10, 7, Vector3.new(0.5, 1.2, 0.5), "Cylinder", Color3.fromRGB(150, 200, 230)),
	frying_pan = prop("Frying Pan", "Blunt", 17, 18, Vector3.new(1.4, 0.2, 2.4), "Block", Color3.fromRGB(45, 45, 48), "Fine"),
	kettle = prop("Kettle", "Blunt", 15, 12, Vector3.new(1, 1, 1), "Ball", Color3.fromRGB(210, 210, 200)),
	-- Reach
	mop = prop("Mop", "Reach", 13, 14, Vector3.new(0.25, 0.25, 5.5), "Cylinder", Color3.fromRGB(150, 120, 80)),
	broom = prop("Broom", "Reach", 12, 14, Vector3.new(0.25, 0.25, 5), "Cylinder", Color3.fromRGB(170, 140, 90)),
	umbrella = prop("Umbrella", "Reach", 14, 16, Vector3.new(0.3, 0.3, 3.8), "Cylinder", Color3.fromRGB(25, 25, 30), "Fine"),
	coat_rack = prop("Coat Rack", "Reach", 18, 18, Vector3.new(0.4, 0.4, 6), "Cylinder", Color3.fromRGB(100, 70, 45), "Rare"),
	-- Big
	chair = prop("Folding Chair", "Big", 20, 8, Vector3.new(1.8, 2.6, 1.8), "Block", Color3.fromRGB(140, 140, 150)),
	cart = prop("Shopping Cart", "Big", 24, 10, Vector3.new(2.4, 2.4, 3.4), "Block", Color3.fromRGB(180, 180, 185), "Fine"),
	sign_board = prop("Sandwich Board", "Big", 22, 9, Vector3.new(2.4, 3.2, 0.4), "Block", Color3.fromRGB(240, 235, 220)),
	vending_door = prop("Vending Machine Door", "Big", 30, 12, Vector3.new(3, 5, 0.4), "Block", Color3.fromRGB(200, 40, 40), "Rare"),
	-- Soft
	shopping_bag = prop("Shopping Bag", "Soft", 7, 12, Vector3.new(1.2, 1.4, 0.6), "Block", Color3.fromRGB(240, 240, 235)),
	towel = prop("Hand Towel", "Soft", 6, 16, Vector3.new(0.8, 0.2, 1.8), "Block", Color3.fromRGB(230, 120, 120)),
	apron = prop("Shop Apron", "Soft", 8, 20, Vector3.new(1.4, 0.15, 2), "Block", Color3.fromRGB(40, 90, 70), "Fine"),
} :: { [string]: PropDef }

Config.PROPS.knife.enemyOnly = true

Config.RARITIES = { "Common", "Fine", "Rare", "Signature" }

-- Live prop caps per area and respawn time for spawn points.
Config.PROP_RESPAWN_SECONDS = 12
Config.MAX_LOOSE_PROPS_PER_DISTRICT = 60
Config.LOOSE_PROP_DESPAWN_SECONDS = 45 -- dropped/broken props vanish after this

---------------------------------------------------------------------------
-- Enemies. Reward numbers are per KO; the boss multiplier applies on top.
---------------------------------------------------------------------------
export type EnemyDef = {
	name: string,
	hp: number,
	damage: number,
	speed: number,
	attackRange: number,
	windup: number,
	cooldown: number,
	aggro: number,
	ranged: boolean?,
	armour: number?, -- fraction of damage ignored by non-Big hits
	color: Color3,
	scale: number,
	cash: number,
	xp: number,
	bounty: number,
}

Config.ENEMIES = {
	thug = { name = "Street Thug", hp = 60, damage = 8, speed = 13, attackRange = 5, windup = 0.55, cooldown = 1.4, aggro = 60, color = Color3.fromRGB(90, 90, 100), scale = 1, cash = 12, xp = 18, bounty = 400 },
	thrower = { name = "Knife Courier", hp = 50, damage = 10, speed = 12, attackRange = 45, windup = 0.7, cooldown = 2.2, aggro = 70, ranged = true, color = Color3.fromRGB(60, 70, 110), scale = 1, cash = 15, xp = 22, bounty = 600 },
	bruiser = { name = "Bruiser", hp = 170, damage = 16, speed = 10, attackRange = 6, windup = 0.85, cooldown = 1.8, aggro = 55, armour = 0.4, color = Color3.fromRGB(110, 70, 60), scale = 1.3, cash = 30, xp = 45, bounty = 1500 },
	hitman = { name = "Contract Hitman", hp = 120, damage = 14, speed = 17, attackRange = 5.5, windup = 0.4, cooldown = 1.1, aggro = 80, color = Color3.fromRGB(30, 30, 35), scale = 1, cash = 40, xp = 60, bounty = 3000 },
	elite = { name = "Elite Killer", hp = 320, damage = 22, speed = 18, attackRange = 6, windup = 0.35, cooldown = 0.9, aggro = 90, armour = 0.2, color = Color3.fromRGB(140, 20, 25), scale = 1.1, cash = 120, xp = 180, bounty = 12000 },
} :: { [string]: EnemyDef }

Config.BOSS_REWARD_MULT = 12
Config.KO_CLEANUP_SECONDS = 3.5
Config.ENEMY_RESPAWN_SECONDS = 8

---------------------------------------------------------------------------
-- Bounty: the climb. Rises on KOs, drops when you are knocked out.
---------------------------------------------------------------------------
Config.BOUNTY_LOSS_ON_KO = 0.1
Config.BOUNTY_TIERS = {
	{ min = 0, name = "Nobody" },
	{ min = 10000, name = "Rumour" },
	{ min = 50000, name = "Name on the Board" },
	{ min = 250000, name = "Wanted" },
	{ min = 1000000, name = "Most Wanted" },
	{ min = 5000000, name = "Legend" },
	{ min = 20000000, name = "Retired Legend" },
}

function Config.bountyTier(bounty: number): (number, string)
	local idx, name = 1, Config.BOUNTY_TIERS[1].name
	for i, t in Config.BOUNTY_TIERS do
		if bounty >= t.min then
			idx, name = i, t.name
		end
	end
	return idx, name
end

---------------------------------------------------------------------------
-- Districts: the world as data. Built on the X axis by WorldBuilder.
---------------------------------------------------------------------------
export type DistrictDef = {
	code: string,
	name: string,
	blurb: string,
	bounty: number, -- best bounty needed to enter
	enemies: { [string]: number }, -- enemy id -> how many stay alive
	boss: { name: string, title: string, base: string, hpMult: number, scale: number },
	groundColor: Color3,
	plazaColor: Color3,
	size: Vector2,
	props: { [string]: number }, -- prop id -> how many spawn loose here
}

local function district(code: string, name: string, blurb: string, bounty: number, enemies: { [string]: number }, boss: any, ground: Color3, plaza: Color3, props: { [string]: number }, size: Vector2?): DistrictDef
	return { code = code, name = name, blurb = blurb, bounty = bounty, enemies = enemies, boss = boss, groundColor = ground, plazaColor = plaza, props = props, size = size or Vector2.new(420, 420) }
end

Config.DISTRICT_SPACING = 1500
Config.TRAVEL_COOLDOWN = 4

Config.DISTRICTS = {
	district("D01", "Hinode Shopping Street", "Where it starts. Small-time thugs chasing a small-time bounty.", 0,
		{ thug = 6, thrower = 2 },
		{ name = "Butcher Gouda", title = "Owner of the Rival Store", base = "bruiser", hpMult = 4, scale = 1.5 },
		Color3.fromRGB(120, 116, 108), Color3.fromRGB(176, 170, 160),
		{ pen = 3, can_beans = 3, mop = 2, chair = 2, shopping_bag = 2, broom = 1, bottle = 2 }),
	district("D02", "Downtown Crossing", "Couriers, crowds and a lot of umbrellas.", 25000,
		{ thug = 5, thrower = 4, hitman = 1 },
		{ name = "The Twin Couriers", title = "Two Bikes, One Contract", base = "hitman", hpMult = 5, scale = 1.1 },
		Color3.fromRGB(80, 82, 88), Color3.fromRGB(150, 150, 155),
		{ umbrella = 3, sign_board = 2, canned_coffee = 3, keys = 2, cart = 1 }),
	district("D03", "Kiramori Funland", "An amusement park after hours. The mascots are armed.", 120000,
		{ thug = 4, bruiser = 3, thrower = 3 },
		{ name = "Ringmaster Pell", title = "The Show Must Go On", base = "bruiser", hpMult = 7, scale = 1.6 },
		Color3.fromRGB(96, 120, 92), Color3.fromRGB(200, 180, 150),
		{ broom = 2, sign_board = 2, bottle = 3, towel = 2, chair = 2 }),
	district("D04", "Blackwater Correctional", "A death-row breakout. Everyone inside wants your bounty.", 400000,
		{ bruiser = 4, hitman = 3, thrower = 2 },
		{ name = "Warden Okubo", title = "The Last Lock", base = "elite", hpMult = 5, scale = 1.4 },
		Color3.fromRGB(70, 72, 76), Color3.fromRGB(120, 120, 124),
		{ chair = 3, frying_pan = 2, kettle = 2, apron = 2, ruler = 2 }),
	district("D05", "Sublevel Lab 9", "Somebody is building better assassins.", 1200000,
		{ hitman = 5, elite = 1, thrower = 3 },
		{ name = "Dr. Silt", title = "Chief of Improvement", base = "elite", hpMult = 7, scale = 1.2 },
		Color3.fromRGB(180, 186, 190), Color3.fromRGB(220, 224, 228),
		{ ruler = 3, cart = 2, kettle = 2, coat_rack = 1, keys = 2 }),
	district("D06", "Academy Entrance Exam", "The assassin academy's entrance exam. Most applicants fail.", 3500000,
		{ hitman = 4, elite = 3 },
		{ name = "Proctor Vane", title = "Pass or Perish", base = "elite", hpMult = 9, scale = 1.3 },
		Color3.fromRGB(100, 92, 80), Color3.fromRGB(170, 160, 140),
		{ ruler = 2, umbrella = 2, chair = 2, coat_rack = 2, frying_pan = 2 }),
	district("D07", "The Eleven", "The association's elite circle. One of them waits each week.", 10000000,
		{ elite = 4, hitman = 2 },
		{ name = "Seat Eleven", title = "Weekly Rotation", base = "elite", hpMult = 14, scale = 1.4 },
		Color3.fromRGB(28, 28, 32), Color3.fromRGB(70, 70, 76),
		{ vending_door = 1, coat_rack = 2, frying_pan = 2, umbrella = 2, cart = 2 }),
} :: { DistrictDef }


function Config.getDistrict(code: string): DistrictDef?
	for _, d in Config.DISTRICTS do
		if d.code == code then
			return d
		end
	end
	return nil
end

function Config.districtIndex(code: string): number
	for i, d in Config.DISTRICTS do
		if d.code == code then
			return i
		end
	end
	return 1
end

function Config.districtOrigin(code: string): Vector3
	return Vector3.new(Config.districtIndex(code) * Config.DISTRICT_SPACING, 0, 0)
end

---------------------------------------------------------------------------
-- The store: one plot per player in a row behind the origin.
---------------------------------------------------------------------------
Config.STORE_PLOTS = 20
Config.STORE_SPACING = 70
Config.STORE_ROW_Z = -400
Config.STORE_SIZE = Vector3.new(46, 14, 34)

-- Shelves and what they stock. Stocked shelves hold the props you fight with at home.
Config.SHELVES = {
	{ key = "Stationery", props = { "pen", "ruler", "keys" }, unlockLevel = 0, restockCost = 20 },
	{ key = "Groceries", props = { "can_beans", "canned_coffee", "bottle" }, unlockLevel = 0, restockCost = 25 },
	{ key = "Cleaning", props = { "mop", "broom", "towel" }, unlockLevel = 1, restockCost = 35 },
	{ key = "Kitchen", props = { "frying_pan", "kettle", "apron" }, unlockLevel = 2, restockCost = 60 },
	{ key = "Furniture", props = { "chair", "sign_board", "umbrella" }, unlockLevel = 3, restockCost = 90 },
}
Config.SHELF_CAPACITY = 6

-- Store upgrades: level 0 is the starting store.
Config.STORE_LEVELS = {
	{ cost = 0, customerEvery = 14, saleCash = 6, name = "Corner Kiosk" },
	{ cost = 500, customerEvery = 12, saleCash = 9, name = "Corner Store" },
	{ cost = 2500, customerEvery = 10, saleCash = 14, name = "Neighbourhood Mart" },
	{ cost = 10000, customerEvery = 8, saleCash = 22, name = "Family Mart" },
	{ cost = 40000, customerEvery = 7, saleCash = 34, name = "Local Legend" },
}
Config.MAX_CUSTOMERS = 3
Config.CUSTOMER_PATIENCE = 30
-- Chance a customer is an assassin. Rises with bounty tier (index into BOUNTY_TIERS).
Config.ASSASSIN_CHANCE_BY_TIER = { 0.35, 0.3, 0.32, 0.35, 0.38, 0.4, 0.42 }
Config.ASSASSIN_BY_TIER = { "thug", "thug", "thrower", "bruiser", "hitman", "hitman", "elite" }
Config.FIRST_SPAWN_ASSASSIN = true -- new players meet an assassin right away

---------------------------------------------------------------------------
-- Economy
---------------------------------------------------------------------------
Config.CURRENCY_NAME = "Cash"
Config.CURRENCY_CODE = "$"
Config.STARTING_CASH = 50

---------------------------------------------------------------------------
-- Death
---------------------------------------------------------------------------
Config.RESPAWN_DELAY = 4

---------------------------------------------------------------------------
-- Retention
---------------------------------------------------------------------------
Config.DAILY_REWARDS = {
	{ cash = 100 },
	{ cash = 150 },
	{ cash = 200, focus = true },
	{ cash = 300 },
	{ cash = 400 },
	{ cash = 600 },
	{ cash = 1200, xp = 500 },
}

-- Playtime gifts (minutes in this session). Biggest last.
Config.PLAYTIME_GIFTS = {
	{ minutes = 1, cash = 25 },
	{ minutes = 3, cash = 50 },
	{ minutes = 5, cash = 80 },
	{ minutes = 8, xp = 150 },
	{ minutes = 12, cash = 200 },
	{ minutes = 16, cash = 300 },
	{ minutes = 20, cash = 600, xp = 400 },
}

-- Codes: never invent names for the store page; these are the real ones.
Config.CODES = {
	CLOCKEDIN = { cash = 250 },
	FIRSTSHIFT = { cash = 100, xp = 100 },
} :: { [string]: { cash: number?, xp: number? } }

---------------------------------------------------------------------------
-- Jobs (quests)
---------------------------------------------------------------------------
Config.MAX_TRACKED_QUESTS = 2

---------------------------------------------------------------------------
-- Monetisation. Never sells the bounty climb.
---------------------------------------------------------------------------
Config.PASSES = {
	DoubleCash = { id = 0, price = 199, name = "2x Cash", blurb = "Double Cash, forever" },
	DoubleXP = { id = 0, price = 199, name = "2x XP", blurb = "Level up twice as fast" },
	AutoRestock = { id = 0, price = 249, name = "Auto Restock", blurb = "Shelves refill by themselves" },
	VipShelf = { id = 0, price = 149, name = "VIP Shelf", blurb = "Special looks for your props" },
	TailoredSuit = { id = 0, price = 299, name = "Tailored Suit", blurb = "A sharp suit when you go Serious" },
}
Config.PASS_ORDER = { "DoubleCash", "DoubleXP", "AutoRestock", "VipShelf", "TailoredSuit" }

Config.PRODUCTS = {
	CashPack = { id = 0, price = 49, name = "Register Haul", blurb = "A big pile of Cash" },
	LuckyDelivery = { id = 0, price = 49, name = "Lucky Delivery", blurb = "Rare props for 15 minutes" },
	BigSale = { id = 0, price = 99, name = "Big Sale", blurb = "2x Cash for everyone in the server for 30 minutes!" },
	BountyShield = { id = 0, price = 35, name = "Bounty Shield", blurb = "Keep your bounty if you get knocked out" },
}
Config.PRODUCT_ORDER = { "CashPack", "BigSale", "LuckyDelivery", "BountyShield" }

function Config.cashPackAmount(level: number): number
	return math.floor(500 + 150 * level ^ 1.3)
end

Config.BIG_SALE_SECONDS = 30 * 60
Config.BIG_SALE_MULT_PER_STACK = 1 -- each stack adds +100%
Config.BIG_SALE_MAX_STACKS = 3
Config.LUCKY_DELIVERY_SECONDS = 15 * 60

---------------------------------------------------------------------------
-- Settings defaults (saved per profile)
---------------------------------------------------------------------------
Config.DEFAULT_SETTINGS = {
	reduceMotion = false,
	uiScale = 1.0,
	panelOpacity = 1.0,
	sfxVolume = 0.8,
	musicVolume = 0.5,
}
Config.UI_SCALE_MIN = 0.8
Config.UI_SCALE_MAX = 1.25

---------------------------------------------------------------------------
-- Security: per-remote rate limits (calls per window seconds)
---------------------------------------------------------------------------
Config.RATE_LIMITS = {
	default = { count = 10, window = 1 },
	Attack = { count = 12, window = 1 },
	Grab = { count = 6, window = 1 },
	Throw = { count = 4, window = 1 },
	Dodge = { count = 4, window = 1 },
	Parry = { count = 4, window = 1 },
	GoSerious = { count = 2, window = 1 },
	AllocateStat = { count = 20, window = 1 },
	SetSetting = { count = 15, window = 1 },
	TravelToDistrict = { count = 2, window = 2 },
	QuestAction = { count = 8, window = 1 },
	StoreAction = { count = 8, window = 1 },
	ClaimDaily = { count = 2, window = 2 },
	ClaimGift = { count = 4, window = 2 },
	RedeemCode = { count = 3, window = 5 },
	AdminCommand = { count = 10, window = 1 },
	SimulatePurchase = { count = 3, window = 2 },
	FunnelStep = { count = 6, window = 1 },
}

---------------------------------------------------------------------------
-- Analytics funnel. Order matters: step numbers derive from it.
---------------------------------------------------------------------------
Config.ONBOARDING_FUNNEL = {
	"Spawn",
	"FirstMove",
	"FirstGrab",
	"FirstHit",
	"FirstKO",
	"FirstThrow",
	"FirstCatch",
	"FirstSerious",
	"FirstRestock",
	"OpenedLedger",
	"FirstDistrict",
	"FirstQuestDone",
}

---------------------------------------------------------------------------
-- Sounds: named slots. Paste rbxassetid:// strings when ready.
---------------------------------------------------------------------------
Config.SOUNDS = {
	ui_hover = "",
	ui_open = "",
	ui_close = "",
	ui_tab = "",
	ui_confirm = "",
	ui_error = "",
	ui_purchase = "",
	reward_common = "",
	reward_rare = "",
	level_up = "",
	swing_light = "",
	swing_heavy = "",
	hit_light = "",
	hit_heavy = "",
	prop_break = "",
	throw = "",
	catch = "",
	dodge = "",
	ko = "",
	serious_on = "",
	serious_off = "",
	register = "",
	restock = "",
	bounty_up = "",
}

return Config
