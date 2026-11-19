--!strict
-- Quests: hand-written Jobs. Every Job must pass QuestLint at server boot.
-- A step with `event` advances by itself when that gameplay event happens
-- (QuestService.notify). Events:
--   "ko:any", "ko:<enemyId>", "ko:assassin", "ko:<PropClass>", "throwko",
--   "catch", "serious", "restock", "serve", "boss:<districtCode>", "visit:<districtCode>"
-- Steps without an event advance from code through QuestService.advance.
-- All names are original to Clocked Out.

export type Step = {
	id: string,
	text: string,
	count: number?, -- progress needed; default 1
	event: string?,
}

export type Rewards = {
	xp: number?,
	cash: number?,
	unlocks: { string }?,
	title: string?,
}

export type Quest = {
	id: string,
	district: string,
	kind: "main" | "side",
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
		id = "D01_Main_OpenForBusiness",
		district = "D01",
		kind = "main",
		name = "Open for Business",
		archetype = "Main chain",
		client = { name = "Old Man Sado", role = "Your landlord" },
		problem = "The lease on your store is up unless it turns a profit this week.",
		turn = "The inspector who came to check your books is carrying a knife.",
		verb = "defend",
		teaches = "Restocking, serving and the disguised-assassin tell",
		consequence = "The Cleaning shelf opens, and Sado stops raising the rent",
		estMinutes = 8,
		steps = {
			{ id = "restock", text = "Restock a shelf in your store", event = "restock" },
			{ id = "serve", text = "Ring up customers at the register", count = 3, event = "serve" },
			{ id = "inspector", text = "Deal with the inspector (a customer who draws a weapon)", event = "ko:assassin" },
			{ id = "street", text = "Knock out thugs on Hinode Shopping Street", count = 5, event = "ko:any" },
		},
		rewards = { xp = 300, cash = 200, unlocks = { "shelf:Cleaning" }, title = "Open for Business" },
	},
	{
		id = "D01_Side_MightierPen",
		district = "D01",
		kind = "side",
		name = "Mightier Than the Sword",
		archetype = "Improvisation",
		client = { name = "Kenta Mori", role = "A schoolboy with a stolen pencil case" },
		problem = "Thugs took Kenta's pencil case on his way home.",
		turn = "The case held a note. The thugs are couriers for a hit on his teacher.",
		verb = "improvise",
		teaches = "Pocket props and catching thrown knives",
		consequence = "Kenta's class sends customers to your store",
		estMinutes = 7,
		steps = {
			{ id = "pocket", text = "Knock out thugs using Pocket props", count = 3, event = "ko:Pocket" },
			{ id = "catch", text = "Catch a thrown knife out of the air", event = "catch" },
		},
		rewards = { xp = 220, cash = 90, unlocks = { "prop:ruler" } },
	},
	{
		id = "D01_Side_ButchersGrudge",
		district = "D01",
		kind = "side",
		name = "The Butcher's Grudge",
		archetype = "Boss hunt",
		client = { name = "Fumi Arata", role = "Fishmonger on Hinode Street" },
		problem = "Butcher Gouda is muscling every shop on the street into paying him.",
		turn = "Gouda has a bounty of his own, and whoever drops him collects it.",
		verb = "confront",
		teaches = "Throws, Serious mode and boss phases",
		consequence = "Hinode shops pay you instead, and Downtown hears your name",
		estMinutes = 12,
		requires = { "D01_Main_OpenForBusiness" },
		steps = {
			{ id = "throws", text = "Knock out enemies with thrown props", count = 2, event = "throwko" },
			{ id = "serious", text = "Get Serious (fill Focus, then press R)", event = "serious" },
			{ id = "boss", text = "Knock out Butcher Gouda", event = "boss:D01" },
		},
		rewards = { xp = 600, cash = 400, unlocks = { "cosmetic:CleaverApron" }, title = "Butcher Breaker" },
	},
	{
		id = "D01_Side_LunchRush",
		district = "D01",
		kind = "side",
		name = "Lunch Rush",
		archetype = "Store defence",
		client = { name = "Mr. Tanabe", role = "Office worker with a big order" },
		problem = "Tanabe's whole office wants lunch from your store at noon.",
		turn = "The rush is cover. Two of the customers are there for your bounty.",
		verb = "serve",
		teaches = "Fighting inside your own store with your own stock",
		consequence = "Your register pays more per sale",
		estMinutes = 8,
		requires = { "D01_Main_OpenForBusiness" },
		steps = {
			{ id = "serve", text = "Serve the lunch rush", count = 5, event = "serve" },
			{ id = "assassins", text = "Knock out the assassins in the queue", count = 2, event = "ko:assassin" },
		},
		rewards = { xp = 260, cash = 150, unlocks = { "boost:RegisterTips" } },
	},
	{
		id = "D02_Main_CrossingGuard",
		district = "D02",
		kind = "main",
		name = "Crossing Guard",
		archetype = "Main chain",
		client = { name = "Officer Rin Hoshi", role = "Off-duty traffic cop" },
		problem = "Knife couriers are working the crowds at Downtown Crossing.",
		turn = "They aren't stealing. They're delivering contracts, and one has your face on it.",
		verb = "intercept",
		teaches = "Ranged enemies, catching and Reach props in crowds",
		consequence = "Courier ambushes on your store get rarer",
		estMinutes = 10,
		steps = {
			{ id = "visit", text = "Travel to Downtown Crossing", event = "visit:D02" },
			{ id = "couriers", text = "Knock out Knife Couriers", count = 4, event = "ko:thrower" },
			{ id = "catches", text = "Catch knives and send them back", count = 3, event = "catch" },
			{ id = "reach", text = "Knock out enemies with Reach props", count = 3, event = "ko:Reach" },
		},
		rewards = { xp = 900, cash = 600, unlocks = { "shelf:Kitchen" }, title = "Crossing Guard" },
	},
}

return Quests
