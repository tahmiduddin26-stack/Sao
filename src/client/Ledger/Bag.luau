--!strict
-- Bag tab: category tabs, rarity-bordered slot grid, item detail pane with
-- mono stats and the equip action. Item art comes from the Blender pipeline;
-- until then slots show the item's initials.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local UIFolder = script.Parent.Parent.UI
local Theme = require(UIFolder.Theme)
local UI = require(UIFolder.UI)
local Common = require(script.Parent.Common)

local C = Theme.Color

local Tab = { title = "Bag" }

local CATEGORIES = { "Weapons", "Armour", "Materials", "Crystals" }
local selectedCategory = "Weapons"
local selectedUid: string? = nil

local SLOT = 56
local GAP = 8
local COLUMNS = 7

local function initials(name: string): string
	local out = ""
	for word in name:gmatch("%a+") do
		out ..= word:sub(1, 1):upper()
		if #out >= 2 then
			break
		end
	end
	return out
end

local function isEquipped(data: any, uid: string): (boolean, string?)
	for slot, equippedUid in data.equipped or {} do
		if equippedUid == uid then
			return true, slot
		end
	end
	return false, nil
end

local function capacity(data: any): number
	return if data.passes and data.passes.BiggerBank then Config.BAG_CAPACITY_BIGGER_BANK else Config.BAG_CAPACITY
end

function Tab.render(content: Frame, data: any, ctx: any)
	local gridWidth = COLUMNS * SLOT + (COLUMNS - 1) * GAP + 44
	local root = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = content })

	-- Left: category tabs + grid
	local left = UI.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, gridWidth, 1, 0),
		Parent = root,
	}, { UI.padding(18, 22) })

	local tabsRow = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), Parent = left }, {
		UI.list(Enum.FillDirection.Horizontal, 4),
	})
	for i, cat in CATEGORIES do
		local t = UI.tab(cat, function()
			selectedCategory = cat
			selectedUid = nil
			ctx.rerender()
		end, { Size = UDim2.fromOffset(96, 32), LayoutOrder = i, TextXAlignment = Enum.TextXAlignment.Center, Parent = tabsRow })
		UI.setTabSelected(t, cat == selectedCategory)
	end
	UI.text(string.format("%d/%d", #(data.items or {}), capacity(data)), "mono", Theme.TextSize.Caption, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(70, 32),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTransparency = Theme.TextDim,
		Parent = left,
	})

	local scroll = ctx.scroll("bag_" .. selectedCategory, {
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -44),
		Parent = left,
	})
	UI.grid(SLOT, GAP).Parent = scroll

	local shown = {}
	for _, item in data.items or {} do
		local def = (Config.ITEMS :: any)[item.id]
		if def and def.category == selectedCategory then
			table.insert(shown, { item = item, def = def })
		end
	end
	table.sort(shown, function(a, b)
		local ra = table.find(Config.RARITIES, a.def.rarity) or 0
		local rb = table.find(Config.RARITIES, b.def.rarity) or 0
		if ra ~= rb then
			return ra > rb
		end
		return a.def.name < b.def.name
	end)
	if not selectedUid and shown[1] then
		selectedUid = shown[1].item.uid
	end

	for i, entry in shown do
		local item, def = entry.item, entry.def
		local slot = UI.slot(def.rarity, function()
			selectedUid = item.uid
			ctx.rerender()
		end, { LayoutOrder = i, Parent = scroll })
		UI.text(initials(def.name), "monoBold", Theme.TextSize.Label, {
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Theme.Rarity[def.rarity] or C.Bone,
			Parent = slot,
		})
		if (item.count or 1) > 1 then
			UI.text("x" .. item.count, "mono", Theme.TextSize.Caption, {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -4, 1, -2),
				Size = UDim2.fromOffset(40, 16),
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = slot,
			})
		end
		if isEquipped(data, item.uid) then
			UI.block(C.Lantern, { Size = UDim2.fromOffset(6, 6), Position = UDim2.fromOffset(4, 4), Parent = slot })
		end
		if item.uid == selectedUid then
			UI.stroke(C.Lantern).Parent = slot
		end
	end
	-- Empty slots to show remaining room on this page.
	for i = #shown + 1, math.max(#shown, 28) do
		UI.slot(nil, nil, { LayoutOrder = i, Parent = scroll, Selectable = false })
	end

	-- Right: detail pane
	UI.block(C.Rule, { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.fromOffset(gridWidth, 0), Parent = root })
	local right = UI.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(gridWidth + 1, 0),
		Size = UDim2.new(1, -gridWidth - 1, 1, 0),
		Parent = root,
	}, { UI.padding(18, 20) })
	local col = Common.stack(right, 8)

	local selected: any = nil
	for _, entry in shown do
		if entry.item.uid == selectedUid then
			selected = entry
		end
	end
	if not selected then
		Common.note(col, "Nothing in this category yet.", 1)
		return
	end
	local item, def = selected.item, selected.def
	local rarityColor = Theme.Rarity[def.rarity] or C.Bone

	local preview = UI.block(C.Ink, { Size = UDim2.new(1, 0, 0, 110), LayoutOrder = 1, Parent = col }, { UI.stroke(rarityColor, 0.4) })
	UI.text(initials(def.name), "display", Theme.TextSize.Display, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = rarityColor,
		TextTransparency = 0.3,
		Parent = preview,
	})

	UI.text(def.name, "bold", Theme.TextSize.Heading, { TextColor3 = rarityColor, LayoutOrder = 2, Parent = col })
	UI.text(def.rarity .. (if def.weaponType then "  " .. Format.splitCamel(def.weaponType) else ""), "body", Theme.TextSize.Caption, {
		TextTransparency = Theme.TextDim,
		LayoutOrder = 3,
		Parent = col,
	})
	UI.paragraph(def.description or "", { LayoutOrder = 4, TextSize = Theme.TextSize.Caption, Parent = col })

	local order = 10
	for key, value in def.stats or {} do
		order += 1
		local text = if typeof(value) == "number" and value > 0 and key ~= "ATTACK" and key ~= "DEFENCE" then "+" .. value else tostring(value)
		Common.kv(col, key, text, order)
	end
	if item.durability and def.durability then
		Common.kv(col, "Durability", string.format("%d/%d", item.durability, def.durability), 40)
	end
	if (item.count or 1) > 1 then
		Common.kv(col, "Count", tostring(item.count), 41)
	end

	local slotName = Config.CATEGORY_TO_SLOT[def.category]
	if slotName then
		local equipped = isEquipped(data, item.uid)
		local actions = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 50, Parent = col }, {
			UI.list(Enum.FillDirection.Horizontal, 8),
		})
		local equipBtn = UI.button(if equipped then "Equipped" else "Equip", "primary", function()
			Remotes.event("EquipItem"):FireServer(item.uid, slotName)
		end, { Size = UDim2.new(0.5, -4, 1, 0), LayoutOrder = 1, Parent = actions })
		UI.setDisabled(equipBtn, equipped)
		if equipped and slotName ~= "Weapon" then
			UI.button("Unequip", "secondary", function()
				Remotes.event("EquipItem"):FireServer(nil, slotName)
			end, { Size = UDim2.new(0.5, -4, 1, 0), LayoutOrder = 2, Parent = actions })
		end
	end
end

return Tab
