--!strict
-- Skills tab: weapon and element proficiency (0 to 1,000) and skill slots.
-- Sword Skills themselves arrive with the combat build.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)

local UIFolder = script.Parent.Parent.UI
local Theme = require(UIFolder.Theme)
local UI = require(UIFolder.UI)
local Common = require(script.Parent.Common)

local C = Theme.Color

local Tab = { title = "Skills" }

local function nextSlotLevel(level: number): number?
	for l = level + 1, level + 20 do
		if Config.skillSlotsForLevel(l) > Config.skillSlotsForLevel(level) then
			return l
		end
	end
	return nil
end

function Tab.render(content: Frame, data: any, _ctx: any)
	local _, left, right = Common.columns(content, 0.46)
	local col = Common.stack(left, 8)
	UI.caption("Proficiency", { LayoutOrder = 0, Parent = col })

	for i, def in Config.PROFICIENCIES do
		local value = (data.proficiency and data.proficiency[def.key]) or 0
		local card = UI.block(C.Plate, { Size = UDim2.new(1, 0, 0, 52), LayoutOrder = i, Parent = col }, { UI.padding(8, 12) })
		UI.text(def.name, "bold", Theme.TextSize.Body, { Size = UDim2.new(1, -90, 0, 22), Parent = card })
		UI.text(string.format("%d/%d", value, Config.PROFICIENCY_MAX), "mono", Theme.TextSize.Caption, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(90, 22),
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = card,
		})
		local bar = UI.bar(C.Lantern, 3, false, { Position = UDim2.fromOffset(0, 30), Parent = card })
		bar.set(value / Config.PROFICIENCY_MAX, true)
	end

	local best = 0
	for _, def in Config.PROFICIENCIES do
		best = math.max(best, (data.proficiency and data.proficiency[def.key]) or 0)
	end
	local nextMod = (math.floor(best / Config.PROFICIENCY_MOD_EVERY) + 1) * Config.PROFICIENCY_MOD_EVERY
	UI.paragraph(string.format("Next mod at %s. Slots open at levels 6, 12, 20 and every 10 after.", Format.commas(nextMod)), {
		LayoutOrder = 50,
		TextSize = Theme.TextSize.Caption,
		TextTransparency = Theme.TextDim,
		Parent = col,
	})

	local rcol = Common.stack(right, 10)
	UI.caption("Sword Skills", { LayoutOrder = 0, Parent = rcol })
	local slots = Config.skillSlotsForLevel(data.level or 1)
	Common.kv(rcol, "Skill slots", tostring(slots), 1)
	local nextAt = nextSlotLevel(data.level or 1)
	if nextAt then
		Common.kv(rcol, "Next slot", "LV " .. nextAt, 2)
	end
	Common.note(rcol, "Sword Skills are being built against the team's reference clips. They will list here with hit counts, unlock points and loadout slots.", 3)
end

return Tab
