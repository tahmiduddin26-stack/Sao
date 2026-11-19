--!strict
-- Toasts: stacked notifications (plan 26). At most 3 on screen, the rest queue.
-- Rewards outrank quest updates. Slides 8px from the right and fades in; reward
-- toasts settle with a small overshoot. Never covers the skill bar or the player.

local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)
local Motion = require(script.Parent.Motion)

local C = Theme.Color

local Toasts = {}

type Payload = {
	kind: string?,
	title: string?,
	body: string?,
	rarity: string?,
	from: number?,
	to: number?,
}

local container: Frame
local queue: { Payload } = {}
local visible = 0
local soundHook: ((string) -> ())? = nil
local order = 0

function Toasts.setSoundHook(fn: (string) -> ())
	soundHook = fn
end

local function build(p: Payload): Frame
	local kind = p.kind or "info"
	local plate = UI.plate({
		Name = "Toast",
		Size = UDim2.fromOffset(Theme.Toast.width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, { UI.padding(10, 14), UI.list(Enum.FillDirection.Vertical, 2) })

	if kind == "levelup" then
		local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Parent = plate })
		UI.text("Level up", "bold", Theme.TextSize.Label, { Parent = row })
		UI.text(string.format("%d > %d", p.from or 0, p.to or 0), "monoBold", Theme.TextSize.Label, {
			TextColor3 = C.Lantern,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = row,
		})
		return plate
	end

	local header = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 1, Parent = plate })
	local titleX = 0
	if kind == "quest" then
		UI.block(C.Lantern, { Size = UDim2.fromOffset(6, 6), Position = UDim2.new(0, 0, 0.5, -3), Parent = header })
		titleX = 14
	end
	local titleColor = C.Bone
	if kind == "reward" and p.rarity and Theme.Rarity[p.rarity] then
		titleColor = Theme.Rarity[p.rarity]
	elseif kind == "error" then
		titleColor = C.Ember
	end
	if kind == "reward" then
		UI.caption("Reward", { Parent = plate, LayoutOrder = 0, TextColor3 = C.Lantern, TextTransparency = 0 })
	end
	UI.text(p.title or "", "bold", Theme.TextSize.Body, {
		Position = UDim2.fromOffset(titleX, 0),
		Size = UDim2.new(1, -titleX, 1, 0),
		TextColor3 = titleColor,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = header,
	})
	if p.body and p.body ~= "" then
		UI.paragraph(p.body, { LayoutOrder = 2, TextSize = Theme.TextSize.Caption, TextTransparency = Theme.TextDim, Parent = plate })
	end
	return plate
end

local pump: () -> ()

local function show(p: Payload)
	visible += 1
	local kind = p.kind or "info"
	local plate = build(p)
	order -= 1 -- newest on top
	plate.LayoutOrder = order
	plate.Parent = container
	local token = if kind == "reward" or kind == "purchase" then Theme.Motion.settle else Theme.Motion.base
	Motion.enter(plate, "small", token)

	if soundHook then
		if kind == "reward" then
			local r = p.rarity
			soundHook(if r == "Legendary" then "reward_legendary" elseif r == "Rare" or r == "Heroic" then "reward_rare" else "reward_common")
		elseif kind == "levelup" then
			soundHook("level_up")
		elseif kind == "error" then
			soundHook("ui_error")
		elseif kind == "purchase" then
			soundHook("ui_purchase")
		end
	end

	local hold = Theme.Toast.hold[kind] or 3
	task.delay(hold, function()
		Motion.exit(plate, "fade", Theme.Motion.quick, function()
			plate:Destroy()
		end)
		task.delay(Theme.Motion.quick.time * Theme.Motion.exitFactor, function()
			visible -= 1
			pump()
		end)
	end)
end

pump = function()
	while visible < Theme.Toast.maxVisible and #queue > 0 do
		-- Highest priority first; ties keep arrival order.
		local bestIndex, bestPriority = 1, -1
		for i, p in queue do
			local pr = Theme.Toast.priority[p.kind or "info"] or 1
			if pr > bestPriority then
				bestIndex, bestPriority = i, pr
			end
		end
		show(table.remove(queue, bestIndex) :: Payload)
	end
end

function Toasts.push(p: Payload)
	if typeof(p) ~= "table" then
		return
	end
	table.insert(queue, p)
	pump()
end

function Toasts.init(root: Frame)
	container = UI.new("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 330),
		Size = UDim2.fromOffset(Theme.Toast.width, 300),
		Parent = root,
	}, { UI.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right) })
end

return Toasts
