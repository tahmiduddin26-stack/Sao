--!strict
-- Common: layout helpers shared by Ledger tabs.

local UIFolder = script.Parent.Parent.UI
local Theme = require(UIFolder.Theme)
local UI = require(UIFolder.UI)

local Common = {}

-- Two columns with a hairline between. leftScale is the left column's share.
function Common.columns(content: Frame, leftScale: number): (Frame, Frame, Frame)
	local root = UI.new("Frame", {
		Name = "Columns",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = content,
	})
	local left = UI.new("Frame", {
		Name = "Left",
		BackgroundTransparency = 1,
		Size = UDim2.new(leftScale, 0, 1, 0),
		Parent = root,
	}, { UI.padding(18, 22) })
	UI.block(Theme.Color.Line, { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(leftScale, 0, 0, 0), Parent = root })
	local right = UI.new("Frame", {
		Name = "Right",
		BackgroundTransparency = 1,
		Position = UDim2.new(leftScale, 1, 0, 0),
		Size = UDim2.new(1 - leftScale, -1, 1, 0),
		Parent = root,
	}, { UI.padding(18, 22) })
	return root, left, right
end

-- A vertical stack that grows with its content.
function Common.stack(parent: Instance, gap: number?, order: number?): Frame
	return UI.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order or 0,
		Parent = parent,
	}, { UI.list(Enum.FillDirection.Vertical, gap or Theme.Gap) })
end

-- "KEY ........ value" with a mono value (tabular figures).
function Common.kv(parent: Instance, key: string, value: string, order: number?, valueColor: Color3?): Frame
	local row = UI.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = order or 0,
		Parent = parent,
	})
	UI.text(string.upper(key), "mono", Theme.TextSize.Caption, { TextTransparency = Theme.TextDim, Size = UDim2.new(0.6, 0, 1, 0), Parent = row })
	UI.text(value, "mono", Theme.TextSize.Caption, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.4, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = valueColor or Theme.Color.Ink,
		Parent = row,
	})
	return row
end

-- Empty-state note in a quiet plate.
function Common.note(parent: Instance, text: string, order: number?): Frame
	local f = UI.block(Theme.Color.Tone, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order or 0,
		Parent = parent,
	}, { UI.padding(12, 14) })
	UI.paragraph(text, { TextTransparency = Theme.TextDim, TextSize = Theme.TextSize.Caption, Parent = f })
	return f
end

return Common
