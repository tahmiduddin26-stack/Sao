--!strict
-- Remotes: every RemoteEvent and RemoteFunction in one list.
-- The server creates them in Remotes.init(); clients wait for them.
-- Direction is noted beside each name. The server validates every C->S call.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local FOLDER_NAME = "Remotes"

local EVENTS = {
	"Snapshot", -- S->C  full profile mirror after any change
	"Toast", -- S->C  { kind, title, body, rarity? }
	"Banner", -- S->C  { kind = "DistrictCleared" | "BossIntro" | "Knockout" | "Serious", ... }
	"OpenLedger", -- S->C  tab name (from a world prompt)
	"CombatFx", -- S->All { kind, attacker, targets, pos, prop?, ... } cosmetic only
	"Attack", -- C->S  (kind: "light" | "heavy")
	"Grab", -- C->S  (prop: BasePart?) nil = drop the held prop
	"Throw", -- C->S  (aimPoint: Vector3)
	"Dodge", -- C->S  ()
	"Parry", -- C->S  ()
	"GoSerious", -- C->S  ()
	"AllocateStat", -- C->S  (statKey, amount)
	"SetSetting", -- C->S  (key, value)
	"QuestAction", -- C->S  (action: "accept" | "abandon" | "track", questId)
	"TravelToDistrict", -- C->S  (code) or "Store"
	"StoreAction", -- C->S  (action: "restock" | "restockAll" | "upgrade", arg)
	"ClaimDaily", -- C->S  ()
	"ClaimGift", -- C->S  (index)
	"RedeemCode", -- C->S  (code)
	"FunnelStep", -- C->S  (stepName) client-observed onboarding steps only
	"AdminCommand", -- C->S  (command, args)
	"SimulatePurchase", -- C->S  (kind: "pass" | "product", key) Studio only, for ID 0 items
}

local FUNCTIONS = {
	"GetSnapshot", -- C->S  returns the current snapshot or nil
}

local folder: Folder? = nil

function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init is server only")
	local f = ReplicatedStorage:FindFirstChild(FOLDER_NAME) :: Folder?
	if not f then
		local created = Instance.new("Folder")
		created.Name = FOLDER_NAME
		created.Parent = ReplicatedStorage
		f = created
	end
	assert(f)
	for _, name in EVENTS do
		if not f:FindFirstChild(name) then
			local ev = Instance.new("RemoteEvent")
			ev.Name = name
			ev.Parent = f
		end
	end
	for _, name in FUNCTIONS do
		if not f:FindFirstChild(name) then
			local fn = Instance.new("RemoteFunction")
			fn.Name = name
			fn.Parent = f
		end
	end
	folder = f
end

local function getFolder(): Folder
	if folder then
		return folder
	end
	local f = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
	folder = f
	return f
end

function Remotes.event(name: string): RemoteEvent
	assert(table.find(EVENTS, name), "Unknown RemoteEvent " .. name)
	return getFolder():WaitForChild(name) :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	assert(table.find(FUNCTIONS, name), "Unknown RemoteFunction " .. name)
	return getFolder():WaitForChild(name) :: RemoteFunction
end

return Remotes
