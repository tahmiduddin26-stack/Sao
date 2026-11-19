--!strict
-- JOBS tab: one panel per Job you can take or are doing. Name, what to do
-- next, a progress bar and one button. Finished Jobs collapse to a count.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Quests = require(Shared.Quests)
local Remotes = require(Shared.Remotes)
local Stats = require(Shared.Stats)

local UIFolder = script.Parent.Parent.UI
local Theme = require(UIFolder.Theme)
local UI = require(UIFolder.UI)

local C = Theme.Color

local Tab = { title = "Jobs" }

local function available(data: any, q: any): boolean
	if data.quests[q.id] or not Stats.districtUnlocked(data, q.district) then
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

local function rewardText(r: any): string
	local parts = {}
	if r.cash then
		table.insert(parts, Config.CURRENCY_CODE .. Format.commas(r.cash))
	end
	if r.xp then
		table.insert(parts, Format.commas(r.xp) .. " XP")
	end
	return table.concat(parts, "  +  ")
end

function Tab.render(content: Frame, data: any, ctx: any)
	local scroll = ctx.scroll("jobs", { Parent = content })
	UI.list(Enum.FillDirection.Vertical, 16).Parent = scroll
	UI.padding(2, 2).Parent = scroll

	local shown, done = 0, 0
	-- Active first, then ones you can start.
	for pass = 1, 2 do
		for i, q in Quests do
			local s = data.quests[q.id]
			local active = s ~= nil and s.state == "active"
			if s and s.state == "done" and pass == 1 then
				done += 1
			end
			if (pass == 1 and active) or (pass == 2 and available(data, q)) then
				shown += 1
				local card = UI.panel({ Size = UDim2.new(1, -12, 0, 118), LayoutOrder = pass * 100 + i, Parent = scroll }, {
					tone = if active then "TR" else nil,
				})
				UI.text(string.upper(q.name), "display", Theme.TextSize.Title, {
					Position = UDim2.fromOffset(18, 10),
					Size = UDim2.new(1, -260, 0, 34),
					TextTruncate = Enum.TextTruncate.AtEnd,
					Parent = card,
				})
				if active then
					local step = q.steps[s.step]
					local needed = step and step.count or 1
					UI.text(step and step.text or "", "bold", Theme.TextSize.Label, {
						Position = UDim2.fromOffset(18, 46),
						Size = UDim2.new(1, -260, 0, 24),
						TextTruncate = Enum.TextTruncate.AtEnd,
						Parent = card,
					})
					local bar = UI.bar(C.Red, 16, false, { Position = UDim2.fromOffset(18, 80), Size = UDim2.new(1, -260, 0, 16), Parent = card })
					UI.stroke(C.Line).Parent = bar.frame
					local overall = ((s.step - 1) + (s.progress or 0) / needed) / #q.steps
					bar.set(overall, true)
					UI.sticker("ON IT!", C.Red, C.Paper, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.5, 0), Parent = card })
				else
					UI.text(q.problem, "body", Theme.TextSize.Body, {
						Position = UDim2.fromOffset(18, 46),
						Size = UDim2.new(1, -260, 0, 44),
						TextWrapped = true,
						TextYAlignment = Enum.TextYAlignment.Top,
						Parent = card,
					})
					UI.bigButton("START", "primary", function()
						Remotes.event("QuestAction"):FireServer("accept", q.id)
					end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.5, 0), Size = UDim2.fromOffset(150, 56), Parent = card })
				end
				UI.text(rewardText(q.rewards), "monoBold", Theme.TextSize.Caption, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -18, 0, 8),
					Size = UDim2.fromOffset(220, 18),
					TextXAlignment = Enum.TextXAlignment.Right,
					Parent = card,
				})
			end
		end
	end

	if shown == 0 then
		local empty = UI.panel({ Size = UDim2.new(1, -12, 0, 100), LayoutOrder = 999, Parent = scroll }, { color = C.Tone })
		UI.text("NO JOBS RIGHT NOW. RAISE YOUR BOUNTY!", "display", Theme.TextSize.Heading, {
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = empty,
		})
	end
	if done > 0 then
		UI.sticker(string.format("%d JOBS DONE", done), C.Ink, C.Paper, { LayoutOrder = 1000, Parent = scroll })
	end
end

return Tab
