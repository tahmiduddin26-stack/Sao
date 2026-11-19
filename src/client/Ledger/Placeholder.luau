--!strict
-- Placeholder: shared body for Ledger tabs whose systems are not built yet.

local UIFolder = script.Parent.Parent.UI
local Theme = require(UIFolder.Theme)
local UI = require(UIFolder.UI)
local Common = require(script.Parent.Common)

return function(title: string, lines: { string }): any
	local Tab = { title = title }
	function Tab.render(content: Frame, _data: any, _ctx: any)
		local wrap = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = content }, { UI.padding(18, 22) })
		local col = Common.stack(wrap, 10)
		UI.caption("Planned", { LayoutOrder = 0, Parent = col })
		for i, line in lines do
			local row = UI.block(Theme.Color.Plate, { Size = UDim2.new(1, 0, 0, 40), LayoutOrder = i, Parent = col }, { UI.padding(0, 14) })
			UI.text(string.format("%02d", i), "mono", Theme.TextSize.Caption, { Size = UDim2.new(0, 30, 1, 0), TextTransparency = Theme.TextDim, Parent = row })
			UI.text(line, "body", Theme.TextSize.Body, { Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -32, 1, 0), Parent = row })
		end
	end
	return Tab
end
