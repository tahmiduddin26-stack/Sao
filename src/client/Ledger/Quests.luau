--!strict
-- Quests tab: numbered rows (active, then available, then done), objective
-- detail, track toggle and accept/abandon. Unread = an available quest.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Quests = require(Shared.Quests)
local Remotes = require(Shared.Remotes)

local UIFolder = script.Parent.Parent.UI
local Theme = require(UIFolder.Theme)
local UI = require(UIFolder.UI)
local Common = require(script.Parent.Common)

local C = Theme.Color

local Tab = { title = "Quests" }

local selectedId: string? = nil

local function available(data: any, q: any): boolean
	if data.quests[q.id] or not data.unlockedFloors[q.floor] then
		return false
	end
	for _, req in q.requires or {} do
		local s = data.quests[req]
		if not s or s.state ~= "done" then
			return false
		end
	end
	return true
end

function Tab.unread(data: any): boolean
	for _, q in Quests do
		if available(data, q) then
			return true
		end
	end
	return false
end

local function rewardLine(r: any): string
	local parts = {}
	if r.xp then
		table.insert(parts, r.xp .. " XP")
	end
	if r.gold then
		table.insert(parts, Config.CURRENCY_CODE .. " " .. r.gold)
	end
	for _, item in r.items or {} do
		local def = (Config.ITEMS :: any)[item.id]
		table.insert(parts, (def and def.name or item.id) .. ((item.count and item.count > 1) and (" x" .. item.count) or ""))
	end
	for _, key in r.unlocks or {} do
		local kind, name = key:match("^(%a+):(.+)$")
		if kind and name then
			table.insert(parts, string.format("%s unlock", kind))
		end
	end
	if r.title then
		table.insert(parts, "Title: " .. r.title)
	end
	return table.concat(parts, "   ")
end

function Tab.render(content: Frame, data: any, ctx: any)
	local _, left, right = Common.columns(content, 0.52)

	-- Build ordered list
	local active, open, done = {}, {}, {}
	for _, q in Quests do
		local s = data.quests[q.id]
		if s and s.state == "active" then
			table.insert(active, q)
		elseif s and s.state == "done" then
			table.insert(done, q)
		elseif available(data, q) then
			table.insert(open, q)
		end
	end
	local ordered = {}
	for _, q in active do
		table.insert(ordered, q)
	end
	for _, q in open do
		table.insert(ordered, q)
	end
	for _, q in done do
		table.insert(ordered, q)
	end

	local stillListed = false
	for _, q in ordered do
		if q.id == selectedId then
			stillListed = true
		end
	end
	if not stillListed then
		selectedId = ordered[1] and ordered[1].id or nil
	end

	local scroll = ctx.scroll("quests", { Parent = left })
	UI.list(Enum.FillDirection.Vertical, 0).Parent = scroll
	if #ordered == 0 then
		Common.note(scroll, "No quests yet. Reach a town and read its quest board.", 1)
	end
	for i, q in ordered do
		local s = data.quests[q.id]
		local status: string
		if s and s.state == "active" then
			status = string.format("%d/%d", math.min(s.step, #q.steps), #q.steps)
		elseif s and s.state == "done" then
			status = "Done"
		else
			status = "New"
		end
		local row = UI.row(i, q.name, status, function()
			selectedId = q.id
			ctx.rerender()
		end, { LayoutOrder = i, Parent = scroll })
		if status == "New" then
			UI.unread({ Parent = row, Position = UDim2.new(1, -60, 0.5, 0) })
		end
		if status == "Done" then
			(row:FindFirstChild("Title") :: TextLabel).TextTransparency = Theme.TextDim
		end
		if table.find(data.tracked or {}, q.id) then
			(row:FindFirstChild("Right") :: TextLabel).TextColor3 = C.Lantern
		end
		UI.setRowSelected(row, q.id == selectedId)
	end

	-- Detail
	local col = Common.stack(right, 8)
	local q: any = nil
	for _, candidate in Quests do
		if candidate.id == selectedId then
			q = candidate
		end
	end
	if not q then
		Common.note(col, "Pick a quest to see its details.", 1)
		return
	end
	local s = data.quests[q.id]

	UI.caption(string.format("%s  %s", Config.floorCode(q.floor), q.archetype), { LayoutOrder = 1, Parent = col })
	UI.text(q.name, "bold", Theme.TextSize.Heading, { LayoutOrder = 2, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Parent = col })
	UI.text(string.format("%s, %s", q.client.name, string.lower(q.client.role)), "body", Theme.TextSize.Caption, {
		TextTransparency = Theme.TextDim,
		LayoutOrder = 3,
		Parent = col,
	})
	UI.paragraph(q.problem, { LayoutOrder = 4, Parent = col })

	if s and s.state == "active" then
		local step = q.steps[s.step]
		if step then
			UI.caption("Objective", { LayoutOrder = 5, Parent = col })
			local needed = step.count or 1
			local line = UI.block(C.Plate, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 6, Parent = col }, { UI.padding(10, 12) })
			UI.paragraph(step.text, { Size = UDim2.new(1, -60, 0, 0), Parent = line })
			if needed > 1 then
				UI.text(string.format("%d/%d", s.progress or 0, needed), "mono", Theme.TextSize.Caption, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(56, 20),
					TextXAlignment = Enum.TextXAlignment.Right,
					TextColor3 = C.Lantern,
					Parent = line,
				})
			end
		end
	elseif s and s.state == "done" then
		UI.caption("Complete", { LayoutOrder = 5, TextColor3 = C.Vigor, TextTransparency = 0, Parent = col })
	end

	UI.caption("Reward", { LayoutOrder = 7, Parent = col })
	UI.paragraph(rewardLine(q.rewards), { LayoutOrder = 8, TextSize = Theme.TextSize.Caption, Parent = col })

	local actions = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 9, Parent = col }, {
		UI.list(Enum.FillDirection.Horizontal, 8),
	})
	if not s then
		UI.button("Accept", "primary", function()
			Remotes.event("QuestAction"):FireServer("accept", q.id)
		end, { Size = UDim2.fromOffset(120, 38), LayoutOrder = 1, Parent = actions })
	elseif s.state == "active" then
		local tracked = table.find(data.tracked or {}, q.id) ~= nil
		UI.button(if tracked then "Untrack" else "Track", "primary", function()
			Remotes.event("QuestAction"):FireServer("track", q.id)
		end, { Size = UDim2.fromOffset(110, 38), LayoutOrder = 1, Parent = actions })
		if q.kind ~= "main" then
			UI.button("Abandon", "danger", function()
				Remotes.event("QuestAction"):FireServer("abandon", q.id)
			end, { Size = UDim2.fromOffset(110, 38), LayoutOrder = 2, Parent = actions })
		end
	end
end

return Tab
