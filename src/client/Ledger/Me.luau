--!strict
-- ME tab: your level, your bounty rank, three big stat cards with a "+" each,
-- and the controls as key caps. Unread = stat points to spend.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local UIFolder = script.Parent.Parent.UI
local Theme = require(UIFolder.Theme)
local UI = require(UIFolder.UI)

local C = Theme.Color

local Tab = { title = "Me" }

-- Two or three words each. Kids read the name and the number.
local STAT_HINT: { [string]: string } = {
	POW = "Hit harder",
	SPD = "Move faster",
	INS = "Catch better",
}

local CONTROLS = {
	{ "CLICK", "HIT" },
	{ "RIGHT CLICK", "SMASH" },
	{ "E", "GRAB" },
	{ "Q", "THROW" },
	{ "SHIFT", "DODGE" },
	{ "F", "CATCH" },
	{ "R", "GO SERIOUS" },
}

function Tab.unread(data: any): boolean
	return (data.statPoints or 0) > 0
end

function Tab.render(content: Frame, data: any, _ctx: any)
	local points = data.statPoints or 0

	-- Level card
	local level = UI.panel({ Size = UDim2.fromOffset(250, 200), Parent = content }, { tone = "TR" })
	UI.text("LEVEL", "display", Theme.TextSize.Heading, { Position = UDim2.fromOffset(18, 14), Size = UDim2.new(1, -36, 0, 26), Parent = level })
	UI.text(tostring(data.level or 1), "display", 84, {
		Position = UDim2.fromOffset(18, 34),
		Size = UDim2.new(1, -36, 0, 90),
		TextColor3 = C.Red,
		Parent = level,
	})
	local need = Config.xpToNext(data.level or 1)
	local xp = UI.bar(C.Red, 16, false, { Position = UDim2.fromOffset(18, 130), Size = UDim2.new(1, -36, 0, 16), Parent = level })
	UI.stroke(C.Line).Parent = xp.frame
	xp.set((data.xp or 0) / need, true)
	UI.text(string.format("%s XP TO GO", Format.commas(need - (data.xp or 0))), "monoBold", Theme.TextSize.Caption, {
		Position = UDim2.fromOffset(18, 152),
		Size = UDim2.new(1, -36, 0, 20),
		Parent = level,
	})

	-- Bounty card
	local _, rank = Config.bountyTier(data.bestBounty or 0)
	local bounty = UI.panel({ Position = UDim2.fromOffset(0, 222), Size = UDim2.fromOffset(250, 130), Parent = content }, { color = C.Ink, stroke = C.Line })
	UI.text("BOUNTY", "display", Theme.TextSize.Heading, { Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -36, 0, 26), TextColor3 = C.Paper, Parent = bounty })
	UI.text(Format.commas(data.bounty or 0), "display", Theme.TextSize.Display, {
		Position = UDim2.fromOffset(18, 38),
		Size = UDim2.new(1, -36, 0, 44),
		TextColor3 = C.Red,
		Parent = bounty,
	})
	UI.sticker(string.upper(rank), C.Paper, C.Ink, { Position = UDim2.fromOffset(18, 86), Parent = bounty })

	-- Stat cards
	local stats = UI.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(276, 0),
		Size = UDim2.new(1, -276, 0, 252),
		Parent = content,
	})
	if points > 0 then
		UI.sticker(string.format("%d POINTS TO SPEND!", points), C.Red, C.Paper, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 0),
			ZIndex = 3,
			Parent = stats,
		})
	end
	for i, def in Config.STATS do
		local card = UI.panel({
			Position = UDim2.new((i - 1) / 3, 0, 0, 22),
			Size = UDim2.new(1 / 3, -14, 0, 226),
			Parent = stats,
		})
		UI.brushTitle(def.name, Theme.TextSize.Heading, { Position = UDim2.fromOffset(14, 14), Parent = card })
		UI.text(tostring(data.stats[def.key] or 0), "display", 64, {
			Position = UDim2.fromOffset(14, 60),
			Size = UDim2.new(1, -28, 0, 70),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = card,
		})
		UI.text(STAT_HINT[def.key] or "", "bold", Theme.TextSize.Body, {
			Position = UDim2.fromOffset(14, 128),
			Size = UDim2.new(1, -28, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = card,
		})
		local plus = UI.bigButton("+", "primary", function()
			Remotes.event("AllocateStat"):FireServer(def.key, 1)
		end, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -12),
			Size = UDim2.new(1, -28, 0, 50),
			TextSize = Theme.TextSize.Display,
			Parent = card,
		})
		UI.setDisabled(plus, points <= 0)
	end

	-- Controls
	local controls = UI.panel({
		Position = UDim2.fromOffset(276, 272),
		Size = UDim2.new(1, -276, 0, 80),
		Parent = content,
	}, { color = C.Tone })
	UI.text("HOW TO FIGHT", "display", Theme.TextSize.Label, { Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 0, 22), Parent = controls })
	UI.keyHints({ CONTROLS[1], CONTROLS[2], CONTROLS[3], CONTROLS[4] }, { Position = UDim2.fromOffset(14, 30), Parent = controls })
	UI.keyHints({ CONTROLS[5], CONTROLS[6], CONTROLS[7] }, { Position = UDim2.fromOffset(14, 54), Parent = controls })
end

return Tab
