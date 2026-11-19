--!strict
-- InventoryService: the bag and equipment slots. Data only for now:
-- combat will read equipped weapon stats, and the Blender pipeline provides
-- the meshes named in Config.ITEMS[*].model.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local RateLimit = require(Shared.RateLimit)

local InventoryService = {}

local DataService: any

local function toast(player: Player, payload: any)
	Remotes.event("Toast"):FireClient(player, payload)
end

function InventoryService.capacity(player: Player): number
	local data = DataService.get(player)
	if data and data.passes.BiggerBank then
		return Config.BAG_CAPACITY_BIGGER_BANK
	end
	return Config.BAG_CAPACITY
end

local function findByUid(data: any, uid: string): (any?, number?)
	for i, item in data.items do
		if item.uid == uid then
			return item, i
		end
	end
	return nil, nil
end

-- Adds an item. Stackable items merge. Returns false if the bag is full.
function InventoryService.give(player: Player, itemId: string, count: number?): boolean
	local data = DataService.get(player)
	local def = (Config.ITEMS :: any)[itemId]
	if not data or not def then
		return false
	end
	local n = math.max(1, math.floor(count or 1))
	if def.stackable then
		for _, item in data.items do
			if item.id == itemId then
				item.count += n
				DataService.changed(player)
				return true
			end
		end
		if #data.items >= InventoryService.capacity(player) then
			toast(player, { kind = "error", title = "Bag full", body = def.name .. " could not be stored." })
			return false
		end
		table.insert(data.items, { uid = HttpService:GenerateGUID(false), id = itemId, count = n })
	else
		for _ = 1, n do
			if #data.items >= InventoryService.capacity(player) then
				toast(player, { kind = "error", title = "Bag full", body = def.name .. " could not be stored." })
				DataService.changed(player)
				return false
			end
			table.insert(data.items, { uid = HttpService:GenerateGUID(false), id = itemId, count = 1, durability = def.durability })
		end
	end
	toast(player, { kind = "reward", title = def.name, body = (n > 1 and ("x" .. n .. "  ") or "") .. def.rarity, rarity = def.rarity })
	DataService.changed(player)
	return true
end

function InventoryService.equip(player: Player, uid: string?, slot: string): boolean
	local data = DataService.get(player)
	if not data or not table.find(Config.EQUIP_SLOTS, slot) then
		return false
	end
	if uid == nil then
		data.equipped[slot] = nil
		DataService.changed(player)
		return true
	end
	local item = findByUid(data, uid)
	if not item then
		return false
	end
	local def = (Config.ITEMS :: any)[item.id]
	if not def or Config.CATEGORY_TO_SLOT[def.category] ~= slot then
		return false
	end
	data.equipped[slot] = uid
	DataService.changed(player)
	return true
end

function InventoryService.equippedDef(player: Player, slot: string): any?
	local data = DataService.get(player)
	local uid = data and data.equipped[slot]
	if not uid then
		return nil
	end
	local item = findByUid(data, uid)
	return item and (Config.ITEMS :: any)[item.id] or nil
end

function InventoryService.init(dataService: any)
	DataService = dataService
	Remotes.event("EquipItem").OnServerEvent:Connect(function(player: Player, uid: any, slot: any)
		if not RateLimit.check(player, "EquipItem") then
			return
		end
		if typeof(slot) ~= "string" then
			return
		end
		if uid ~= nil and typeof(uid) ~= "string" then
			return
		end
		InventoryService.equip(player, uid, slot)
	end)
end

return InventoryService
