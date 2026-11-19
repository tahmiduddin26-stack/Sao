--!strict
-- Quests: hand-written quest data (plan 8). Every quest must pass QuestLint.
-- Steps advance only from the server via QuestService.advance(player, questId, stepId),
-- so systems built later (combat, crafting, NPC dialogue) plug in without changing data.
-- Names are placeholders in our own world.

export type Step = {
	id: string,
	text: string,
	count: number?, -- progress needed; default 1
}

export type Rewards = {
	xp: number?,
	gold: number?,
	items: { { id: string, count: number? } }?,
	unlocks: { string }?, -- e.g. "weapon:CurvedBlade", "recipe:CriticsStew", "shortcut:F01_Farm"
	title: string?,
}

export type Quest = {
	id: string,
	floor: number,
	kind: "main" | "side" | "campaign",
	name: string,
	archetype: string,
	client: { name: string, role: string },
	problem: string,
	turn: string,
	verb: string,
	teaches: string,
	consequence: string,
	estMinutes: number,
	requires: { string }?,
	steps: { Step },
	rewards: Rewards,
}

local Quests: { Quest } = {
	{
		id = "F01_Main_RoadToTheGate",
		floor = 1,
		kind = "main",
		name = "The Road to the Gate",
		archetype = "Main chain",
		client = { name = "Captain Orla Venn", role = "Lowgate watch captain" },
		problem = "The castle sealed itself at launch and nobody can log out. The only way out is up.",
		turn = "The labyrinth gate is already open. Someone went in alone before the announcement.",
		verb = "investigate",
		teaches = "Labyrinth layout and the floor boss gate",
		consequence = "Unlocks the labyrinth fast route for the whole server once anyone finishes it",
		estMinutes = 12,
		steps = {
			{ id = "report", text = "Report to Captain Venn in Lowgate square" },
			{ id = "board", text = "Read the notice on the quest board" },
			{ id = "tracks", text = "Follow the lone tracks to the labyrinth", count = 3 },
			{ id = "gate", text = "Reach the boss gate at the top of the labyrinth" },
		},
		rewards = { xp = 400, gold = 150, unlocks = { "shortcut:F01_Labyrinth" }, title = "First Through the Gate" },
	},
	{
		id = "F01_Side_ScarecrowThatMoves",
		floor = 1,
		kind = "side",
		name = "The Scarecrow That Moves",
		archetype = "Investigation",
		client = { name = "Hale Brennick", role = "Lowlands farmer" },
		problem = "Crops are vanishing overnight and the field has drag marks in it.",
		turn = "The scarecrow only moves when nobody looks. It is guarding the field from something burrowing underneath.",
		verb = "investigate",
		teaches = "Camera awareness and a burrowing enemy pattern",
		consequence = "Opens a shortcut through the Brennick farm",
		estMinutes = 10,
		steps = {
			{ id = "talk", text = "Hear Hale out at the farm gate" },
			{ id = "marks", text = "Follow the drag marks north", count = 3 },
			{ id = "watch", text = "Watch the scarecrow until it moves" },
			{ id = "burrow", text = "Drive out what is under the field" },
		},
		rewards = { xp = 250, gold = 90, unlocks = { "weapon:CurvedBlade", "shortcut:F01_Farm" } },
	},
	{
		id = "F01_Side_TrapBreaker",
		floor = 1,
		kind = "side",
		name = "The Trap-Breaker",
		archetype = "Contract with a twist",
		client = { name = "Wil Sedge", role = "Lowgate trapper" },
		problem = "A named boar keeps wrecking the hunters' traps.",
		turn = "Its den is full of young. It was protecting them, not raiding.",
		verb = "track",
		teaches = "Tracking clues, choice and consequence",
		consequence = "Drive it off for rare hide, or put it down for meat. The trappers remember either way.",
		estMinutes = 9,
		steps = {
			{ id = "traps", text = "Inspect the broken traps", count = 4 },
			{ id = "den", text = "Find the den" },
			{ id = "choose", text = "Decide what happens to the boar" },
		},
		rewards = { xp = 220, gold = 70, items = { { id = "boar_hide", count = 2 } } },
	},
	{
		id = "F01_Side_RetiredChampion",
		floor = 1,
		kind = "side",
		name = "The Retired Champion",
		archetype = "Duel or trial",
		client = { name = "Old Maddoc", role = "Retired swordsman" },
		problem = "An old swordsman will only teach someone who can beat him properly.",
		turn = "He cannot be beaten by damage. Only a parried Sword Skill counts.",
		verb = "duel",
		teaches = "Parry and skill collision",
		consequence = "Maddoc opens his yard for sparring",
		estMinutes = 8,
		requires = { "F01_Main_RoadToTheGate" },
		steps = {
			{ id = "challenge", text = "Challenge Maddoc in his yard" },
			{ id = "parry", text = "Parry his Sword Skill", count = 3 },
		},
		rewards = { xp = 300, gold = 60, unlocks = { "hint:ExtraSkill_Fists" } },
	},
	{
		id = "F01_Side_SmithWhoForgot",
		floor = 1,
		kind = "side",
		name = "The Smith Who Forgot",
		archetype = "Crafting",
		client = { name = "Tomas", role = "Smith of Lowgate" },
		problem = "Tomas lost his best recipe and his hands no longer remember the fold.",
		turn = "His apprentice kept notes, but the apprentice left them at the old mill.",
		verb = "craft",
		teaches = "Upgrade stats and appraisal",
		consequence = "Tomas offers +1 upgrades from now on",
		estMinutes = 12,
		steps = {
			{ id = "notes", text = "Read Tomas's notes at the mill", count = 3 },
			{ id = "materials", text = "Bring the ore the notes call for" },
			{ id = "forge", text = "Forge it with Tomas" },
		},
		rewards = { xp = 260, gold = 80, unlocks = { "service:TomasUpgrades" } },
	},
	{
		id = "F01_Side_Lamplighter",
		floor = 1,
		kind = "side",
		name = "The Lamplighter",
		archetype = "Night or weather",
		client = { name = "The Lamplighter", role = "A ghost on the Lowgate road" },
		problem = "A ghost appears on the road at night and the lamps keep going out.",
		turn = "The lamps must be lit in the order of an old song before dawn.",
		verb = "decode",
		teaches = "Day and night cycle, routing",
		consequence = "The Lowgate road stays lit for everyone at night",
		estMinutes = 10,
		steps = {
			{ id = "meet", text = "Find the ghost on the road after dark" },
			{ id = "song", text = "Learn the verse from the tavern singer" },
			{ id = "lamps", text = "Light the lamps in the right order", count = 5 },
		},
		rewards = { xp = 240, gold = 50, unlocks = { "cosmetic:Lantern" } },
	},
}

return Quests
