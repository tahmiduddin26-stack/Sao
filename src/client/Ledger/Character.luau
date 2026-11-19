--!strict
-- Character tab: level, XP, stat point allocation, equipment and derived values.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Stats = require(Shared.Stats)

local UIFolder = script.Parent.Parent.UI
local Theme = require(UIFolder.Theme)
local UI = require(UIFolder.UI)
local Common = require(script.Parent.Common)

local C = Theme.Color

local Tab = { title = "Character" }

function Tab.unread(data: any): boolean
	return (data.statPoints or 0) > 0
end

local function itemFor(data: any, uid: string?): any?
	if not uid then
		return nil
	end
	for _, item in data.items or {} do
		if item.uid == uid then
			return item
		end
	end
	return nil
end

function Tab.render(content: Frame, data: any, _ctx: any)
	local _, left, right = Common.columns(content, 0.56)
	local col = Common.stack(left, 10)

	UI.caption("Adventurer", { LayoutOrder = 1, Parent = col })
	UI.text(Players.LocalPlayer.DisplayName, "bold", Theme.TextSize.Heading, { LayoutOrder = 2, Parent = col })

	local levelRow = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 3, Parent = col })
	UI.text("Level", "body", Theme.TextSize.Body, { Parent = levelRow })
	UI.text(tostring(data.level), "monoBold", Theme.TextSize.Label, { TextXAlignment = Enum.TextXAlignment.Right, Parent = levelRow })

	local need = Config.xpToNext(data.level)
	local xpBar = UI.bar(C.Bone, 4, false, { LayoutOrder = 4, Parent = col })
	xpBar.set(data.xp / need, true)
	UI.text(string.format("%s / %s XP", Format.commas(data.xp), Format.commas(need)), "mono", Theme.TextSize.Caption, {
		TextTransparency = Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		LayoutOrder = 5,
		Parent = col,
	})

	local statsHeader = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 6, Parent = col })
	UI.caption("Stats", { Parent = statsHeader })
	UI.text(string.format("%d points", data.statPoints or 0), "mono", Theme.TextSize.Caption, {
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = if (data.statPoints or 0) > 0 then C.Lantern else C.Bone,
		TextTransparency = if (data.statPoints or 0) > 0 then 0 else Theme.TextDim,
		Parent = statsHeader,
	})

	for i, def in Config.STATS do
		local row = UI.block(C.Plate, { Size = UDim2.new(1, 0, 0, 56), LayoutOrder = 10 + i, Parent = col }, { UI.padding(8, 12) })
		UI.text(def.name, "bold", Theme.TextSize.Body, { Size = UDim2.new(1, -140, 0, 20), Parent = row })
		UI.text(def.blurb, "body", Theme.TextSize.Caption, {
			Position = UDim2.fromOffset(0, 20),
			Size = UDim2.new(1, -140, 0, 18),
			TextTransparency = Theme.TextDim,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
		UI.text(tostring(data.stats[def.key] or 0), "monoBold", Theme.TextSize.Label, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -56, 0.5, 0),
			Size = UDim2.fromOffset(60, 24),
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = row,
		})
		local plus = UI.button("+", "primary", function()
			Remotes.event("AllocateStat"):FireServer(def.key, 1)
		end, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(40, 36),
			FontFace = Theme.Font.MonoBold,
			Parent = row,
		})
		UI.setDisabled(plus, (data.statPoints or 0) <= 0)
	end

	-- Right column: equipment and derived values
	local rcol = Common.stack(right, 8)
	UI.caption("Equipment", { LayoutOrder = 1, Parent = rcol })
	for i, slot in Config.EQUIP_SLOTS do
		local item = itemFor(data, data.equipped and data.equipped[slot])
		local def = item and (Config.ITEMS :: any)[item.id]
		Common.kv(rcol, slot, def and def.name or "Empty", 1 + i, if def then Theme.Rarity[def.rarity] else nil)
	end

	local derived = Stats.fromData(data)
	UI.caption("Derived", { LayoutOrder = 20, Parent = rcol })
	Common.kv(rcol, "Max HP", Format.commas(derived.maxHp), 21)
	Common.kv(rcol, "Max MP", Format.commas(derived.maxMp), 22)
	Common.kv(rcol, "SP charges", tostring(derived.maxSp), 23)
	Common.kv(rcol, "Skill slots", tostring(derived.skillSlots), 24)

	local titleCount = 0
	for _ in data.titles or {} do
		titleCount += 1
	end
	UI.caption("Titles", { LayoutOrder = 30, Parent = rcol })
	Common.kv(rcol, "Earned", tostring(titleCount), 31)
end

return Tab
