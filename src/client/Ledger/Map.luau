--!strict
-- Map tab: floor list 01 to 100, state per floor, the server front line and
-- teleport gate travel. Labyrinth maps join this tab once labyrinths exist.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local UIFolder = script.Parent.Parent.UI
local Theme = require(UIFolder.Theme)
local UI = require(UIFolder.UI)
local Router = require(UIFolder.Router)
local Common = require(script.Parent.Common)

local C = Theme.Color

local Tab = { title = "Map" }

local selectedFloor: number? = nil

local function stateOf(data: any, id: number): string
	if data.currentFloor == id then
		return "Here"
	elseif data.clearedFloors[id] then
		return "Cleared"
	elseif data.unlockedFloors[id] then
		return "Open"
	end
	return "Locked"
end

function Tab.render(content: Frame, data: any, ctx: any)
	local _, left, right = Common.columns(content, 0.5)
	selectedFloor = selectedFloor or data.currentFloor or 1

	local frontLine = Workspace:GetAttribute("FrontLine")
	local header = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), Parent = left })
	UI.caption("Floors", { Parent = header })
	UI.chip("FRONT LINE " .. Config.floorCode(if typeof(frontLine) == "number" then frontLine else 1), C.Lantern, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Parent = header,
	})

	local scroll = ctx.scroll("map", { Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 1, -36), Parent = left })
	UI.list(Enum.FillDirection.Vertical, 0).Parent = scroll

	for i, def in Config.FLOORS do
		local state = stateOf(data, def.id)
		local row = UI.row(def.id, def.name, state, function()
			selectedFloor = def.id
			ctx.rerender()
		end, { LayoutOrder = i, Parent = scroll })
		local title = row:FindFirstChild("Title") :: TextLabel
		local rightLabel = row:FindFirstChild("Right") :: TextLabel
		if state == "Locked" then
			title.TextTransparency = Theme.TextFaint
			rightLabel.TextTransparency = Theme.TextFaint
		elseif state == "Here" then
			rightLabel.TextColor3 = C.Lantern
		end
		UI.setRowSelected(row, def.id == selectedFloor)
	end
	local last = Config.FLOORS[#Config.FLOORS]
	if last and last.id < Config.TOTAL_FLOORS then
		local beyond = UI.row(last.id + 1, string.format("Floors %02d to %d", last.id + 1, Config.TOTAL_FLOORS), "Unbuilt", nil, {
			LayoutOrder = 999,
			Parent = scroll,
			Selectable = false,
		})
		local beyondTitle = beyond:FindFirstChild("Title") :: TextLabel
		beyondTitle.TextTransparency = Theme.TextFaint
	end

	-- Detail
	local col = Common.stack(right, 8)
	local def = Config.getFloor(selectedFloor or 1)
	if not def then
		return
	end
	local state = stateOf(data, def.id)
	local known = state ~= "Locked"

	UI.text(Config.floorCode(def.id), "monoBold", Theme.TextSize.Title, { TextColor3 = C.Lantern, LayoutOrder = 1, Parent = col })
	UI.displayText(def.name, Theme.TextSize.Heading, { LayoutOrder = 2, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Parent = col })
	Common.kv(col, "Town", def.town, 3)
	Common.kv(col, "Biome", def.biome, 4)
	Common.kv(col, "Floor boss", if known then def.boss.name else "Unknown", 5, if known then C.Ember else nil)
	Common.kv(col, "Milestone", if def.milestone then "Yes" else "No", 6)
	Common.kv(col, "State", state, 7)

	local actions = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 10, Parent = col })
	local travel = UI.button(if state == "Here" then "You are here" else "Travel to " .. def.town, "primary", function()
		Remotes.event("TravelToFloor"):FireServer(def.id)
		Router.close()
	end, { Size = UDim2.fromScale(1, 1), Parent = actions })
	UI.setDisabled(travel, state == "Here" or state == "Locked")
	if state == "Locked" then
		Common.note(col, "Clear the floor below to open this gate.", 11)
	end
end

return Tab
