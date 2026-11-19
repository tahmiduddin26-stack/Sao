--!strict
-- Config: the single source of truth for every tunable in Sword Blox Online.
-- Numbers, floors, items, products, rate limits and admin IDs live here.
-- Colours, fonts and motion timings live in the client Theme module instead.
-- An ID of 0 means "not created on Roblox yet"; Studio simulates those flows.

local Config = {}

---------------------------------------------------------------------------
-- Meta
---------------------------------------------------------------------------
Config.GAME_NAME = "Sword Blox Online"
Config.VERSION = "0.1.0-base"
Config.DATASTORE_NAME = "SBO_Profiles_v1"
Config.WORLD_DATASTORE_NAME = "SBO_World_v1"

-- Admins: Studio, the place owner, group rank >= ADMIN_GROUP_RANK, or these user IDs.
Config.ADMIN_IDS = {} :: { number }
Config.GROUP_ID = 0
Config.ADMIN_GROUP_RANK = 254

---------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------
Config.AUTOSAVE_SECONDS = 90
Config.SESSION_LOCK_TTL = 300 -- seconds before a stale lock from a dead server can be taken
Config.SESSION_LOCK_RETRIES = 5
Config.SESSION_LOCK_RETRY_WAIT = 4
Config.DATASTORE_RETRIES = 5
Config.MAX_STORED_RECEIPTS = 60

---------------------------------------------------------------------------
-- Progression (plan 2.5, 7.3)
---------------------------------------------------------------------------
Config.STAT_POINTS_PER_LEVEL = 3
-- Two canon stats plus our magic stat. Keys are what the profile stores.
Config.STATS = {
	{ key = "STR", name = "Strength", blurb = "Raises physical damage and carry weight." },
	{ key = "AGI", name = "Agility", blurb = "Raises speed, dodge and Sword Skill recovery." },
	{ key = "ARC", name = "Arcana", blurb = "Raises MP and spell power." },
}

-- XP needed to go from `level` to `level + 1`. No hard cap, softened curve.
function Config.xpToNext(level: number): number
	return math.floor(80 + 40 * level ^ 1.35)
end

-- Skill slots follow the canon curve: 2 at start, +1 at 6, 12, 20, then every 10.
function Config.skillSlotsForLevel(level: number): number
	local slots = 2
	if level >= 6 then slots += 1 end
	if level >= 12 then slots += 1 end
	if level >= 20 then slots += 1 end
	if level >= 30 then slots += math.floor((level - 20) / 10) end
	return slots
end

Config.PROFICIENCY_MAX = 1000
Config.PROFICIENCY_MOD_EVERY = 50

-- Weapon and element proficiency tracks shown in the Skills tab.
Config.PROFICIENCIES = {
	{ key = "OneHandedSword", name = "One-handed sword", kind = "weapon" },
	{ key = "Rapier", name = "Rapier", kind = "weapon" },
	{ key = "Frost", name = "Frost", kind = "element" },
	{ key = "Ember", name = "Ember", kind = "element" },
}

---------------------------------------------------------------------------
-- Resources. HP / SP / MP maxima derive from these in Stats.luau.
---------------------------------------------------------------------------
Config.BASE_HP = 200
Config.HP_PER_LEVEL = 18
Config.HP_PER_STR = 6
Config.SP_SEGMENTS = 4 -- one per Sword Skill charge
Config.BASE_MP = 40
Config.MP_PER_ARC = 5
Config.BASE_STAMINA = 100

---------------------------------------------------------------------------
-- Economy (plan 10)
---------------------------------------------------------------------------
Config.CURRENCY_NAME = "Gold" -- placeholder; name is an open question
Config.CURRENCY_CODE = "G"
Config.STARTING_GOLD = 50
Config.BAG_CAPACITY = 60
Config.BAG_CAPACITY_BIGGER_BANK = 120

Config.RARITIES = { "Common", "Fine", "Rare", "Heroic", "Legendary" }

Config.MATERIALS = {
	Crystal = { name = "Upgrade crystal", code = "CRYS" },
}

-- Item definitions. Stats are data only for now; combat reads them later.
-- `model` names the asset the Blender pipeline will provide.
Config.ITEMS = {
	lowgate_shortsword = {
		name = "Lowgate Shortsword",
		category = "Weapons",
		weaponType = "OneHandedSword",
		rarity = "Common",
		description = "Standard issue from the Lowgate armoury. Honest steel.",
		stats = { ATTACK = 24, EDGE = 0, SPEED = 0, WEIGHT = 2 },
		durability = 100,
		model = "W_LowgateShortsword",
	},
	tidecutter = {
		name = "Tidecutter",
		category = "Weapons",
		weaponType = "OneHandedSword",
		rarity = "Rare",
		description = "Rare one-handed sword. Pulled from the Ashgrove millrace.",
		stats = { ATTACK = 148, EDGE = 2, SPEED = 1, WEIGHT = 0 },
		durability = 100,
		model = "W_Tidecutter",
	},
	padded_jerkin = {
		name = "Padded Jerkin",
		category = "Armour",
		rarity = "Common",
		description = "Quilted cloth. Better than a shirt.",
		stats = { DEFENCE = 6, WEIGHT = 1 },
		durability = 80,
		model = "A_PaddedJerkin",
	},
	boar_hide = {
		name = "Boar hide",
		category = "Materials",
		rarity = "Common",
		description = "Tough hide. Smiths and tailors both want it.",
		stackable = true,
	},
	healing_crystal = {
		name = "Healing crystal",
		category = "Crystals",
		rarity = "Fine",
		description = "Single use. Restores health instantly.",
		stackable = true,
	},
}

Config.STARTER_ITEMS = { "lowgate_shortsword", "padded_jerkin" }
Config.STARTER_EQUIP = { Weapon = "lowgate_shortsword", Body = "padded_jerkin" }
Config.EQUIP_SLOTS = { "Weapon", "Offhand", "Head", "Body", "Legs", "Feet", "Accessory" }
Config.CATEGORY_TO_SLOT = { Weapons = "Weapon", Armour = "Body" } :: { [string]: string }

---------------------------------------------------------------------------
-- Floors as data (plan 7.4). Original names; nothing copied from SAO.
-- Only floors listed here exist. Bands ship by appending entries.
---------------------------------------------------------------------------
export type FloorDef = {
	id: number,
	name: string,
	town: string,
	biome: string,
	milestone: boolean,
	boss: { name: string, title: string },
	groundColor: Color3,
	plazaColor: Color3,
	size: Vector2, -- greybox ground size in studs (X, Z)
}

local function floor(id: number, name: string, town: string, biome: string, bossName: string, bossTitle: string, ground: Color3, plaza: Color3, size: Vector2?): FloorDef
	return {
		id = id,
		name = name,
		town = town,
		biome = biome,
		milestone = (id == 1) or (id % 10 == 0) or (id % 25 == 0),
		boss = { name = bossName, title = bossTitle },
		groundColor = ground,
		plazaColor = plaza,
		size = size or Vector2.new(600, 600),
	}
end

Config.TOTAL_FLOORS = 100
Config.FLOOR_SPACING = 3000 -- studs between floor origins on the X axis (one place for now)
Config.TRAVEL_COOLDOWN = 4

Config.FLOORS = {
	floor(1, "The Lowlands", "Lowgate", "farmland", "Grimhorn", "Warden of the Gate", Color3.fromRGB(96, 116, 78), Color3.fromRGB(150, 146, 134), Vector2.new(800, 800)),
	floor(2, "Ashgrove", "Millrace", "forest", "Thornmother", "Root of the Grove", Color3.fromRGB(70, 92, 62), Color3.fromRGB(140, 132, 118)),
	floor(3, "The Saltflats", "Brinehold", "coast", "Kelpjaw", "Tyrant of the Shallows", Color3.fromRGB(176, 168, 140), Color3.fromRGB(160, 154, 140)),
	floor(4, "Canalreach", "Lockbridge", "canals", "The Drowned Bell", "Keeper of the Sluice", Color3.fromRGB(88, 110, 120), Color3.fromRGB(146, 146, 146)),
	floor(5, "Hollowstone", "Quarrytown", "quarry", "Vessel Without Will", "The Empty Giant", Color3.fromRGB(120, 112, 100), Color3.fromRGB(156, 150, 140)),
	floor(6, "Mistmarch", "Fenwick", "marsh", "Bogwarden", "Lantern-Eater", Color3.fromRGB(78, 96, 84), Color3.fromRGB(136, 136, 126)),
	floor(7, "Copperhill", "Kilnmouth", "hills", "Brasshide", "Bull of the Furnace", Color3.fromRGB(128, 100, 72), Color3.fromRGB(150, 140, 128)),
	floor(8, "The Glasswood", "Shardrest", "crystal forest", "Prism Stag", "Light Bender", Color3.fromRGB(100, 120, 130), Color3.fromRGB(156, 158, 160)),
	floor(9, "Thornvale", "Covenant Rise", "briar valley", "The Briar Regent", "Crown of Thorns", Color3.fromRGB(84, 80, 66), Color3.fromRGB(140, 130, 120)),
	floor(10, "Ironkeep", "Garrison", "fortress", "The Thousandfold Blade", "Lord of Ironkeep", Color3.fromRGB(90, 90, 96), Color3.fromRGB(150, 150, 156), Vector2.new(800, 800)),
} :: { FloorDef }

function Config.getFloor(id: number): FloorDef?
	for _, f in Config.FLOORS do
		if f.id == id then
			return f
		end
	end
	return nil
end

function Config.floorCode(id: number): string
	return string.format("F%02d", id)
end

---------------------------------------------------------------------------
-- Death (open question in plan 7.4). Soft by default; numbers here.
---------------------------------------------------------------------------
Config.RESPAWN_DELAY = 4
Config.DEATH_XP_LOSS_FRACTION = 0 -- of current-level XP; 0 = no penalty yet

---------------------------------------------------------------------------
-- Retention: daily streak (plan 12.3)
---------------------------------------------------------------------------
Config.DAILY_REWARDS = {
	{ gold = 100 },
	{ gold = 150 },
	{ gold = 150, item = "healing_crystal", count = 2 },
	{ gold = 200 },
	{ gold = 250, material = "Crystal", count = 3 },
	{ gold = 300 },
	{ gold = 500, item = "healing_crystal", count = 5, material = "Crystal", count2 = 5 },
}

---------------------------------------------------------------------------
-- Quests (plan 8)
---------------------------------------------------------------------------
Config.MAX_TRACKED_QUESTS = 2

---------------------------------------------------------------------------
-- Monetisation (plan 11). Never sells power or the climb.
---------------------------------------------------------------------------
Config.PASSES = {
	BiggerBank = { id = 0, price = 149, name = "Bigger Bank", blurb = "Two extra storage tabs" },
	SecondLoadout = { id = 0, price = 199, name = "Second Loadout", blurb = "Swap weapon and skill sets instantly" },
	HardcoreSlot = { id = 0, price = 249, name = "Hardcore Slot", blurb = "Optional permadeath character and memorial" },
	WardrobePack = { id = 0, price = 299, name = "Wardrobe Pack", blurb = "Exclusive outfits, skill-hue colours, sheath styles" },
}
Config.PASS_ORDER = { "BiggerBank", "SecondLoadout", "WardrobePack", "HardcoreSlot" }

Config.PRODUCTS = {
	RespecScroll = { id = 0, price = 75, name = "Respec Scroll", blurb = "Reset your stat points" },
	CardinalsBlessing = { id = 0, price = 99, name = "Server Blessing", blurb = "Server-wide XP and drop boost for 30 min. Stacks." },
	ReviveToken = { id = 0, price = 35, name = "Revive Token", blurb = "Instant self-revive outside raids" },
	DyeSlot = { id = 0, price = 25, name = "Dye Slot", blurb = "One cosmetic recolour slot" },
}
Config.PRODUCT_ORDER = { "RespecScroll", "CardinalsBlessing", "ReviveToken", "DyeSlot" }

Config.BLESSING_SECONDS = 30 * 60
Config.BLESSING_XP_MULT_PER_STACK = 0.25
Config.BLESSING_MAX_STACKS = 4

Config.FLOOR_PASS = {
	season = 1,
	bandLabel = "Floors 01 to 10",
	price = 399,
	tiers = 40,
	blurb = "40 tiers of outfits, skill-hue colours and materials. The free track stays free. Nothing on either track changes combat power.",
}
Config.CHARTER = { price = 49, name = "Adventurer's Charter", blurb = "Monthly cosmetic and daily materials" }

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
	AllocateStat = { count = 20, window = 1 },
	SetSetting = { count = 15, window = 1 },
	TravelToFloor = { count = 2, window = 2 },
	QuestAction = { count = 8, window = 1 },
	EquipItem = { count = 8, window = 1 },
	ClaimDaily = { count = 2, window = 2 },
	AdminCommand = { count = 10, window = 1 },
	SimulatePurchase = { count = 3, window = 2 },
	FunnelStep = { count = 6, window = 1 },
}

---------------------------------------------------------------------------
-- Analytics funnel (plan 14). Order matters: step numbers derive from it.
---------------------------------------------------------------------------
Config.ONBOARDING_FUNNEL = {
	"Spawn",
	"FirstMove",
	"OpenedLedger",
	"FirstKill",
	"FirstSwordSkill",
	"FirstConnect",
	"FirstSwitch",
	"StoryHook",
	"FirstMiniBoss",
	"TownReached",
	"FirstQuestDone",
}

---------------------------------------------------------------------------
-- Sounds: named slots (plan 28). Paste rbxassetid:// strings when ready.
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
	reward_legendary = "",
	connect_window = "",
	switch = "",
	floor_clear = "",
	level_up = "",
}

return Config
