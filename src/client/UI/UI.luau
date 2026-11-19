--!strict
-- UI: the Lanternsteel component kit (plan 27.5).
-- UI.new(class, props, children) plus Plate, Text, Button, Tab, Row, Slot, Bar,
-- Chip and layout helpers. Square corners, 1px hairlines, no shadows.

local GuiService = game:GetService("GuiService")

local Theme = require(script.Parent.Theme)
local Motion = require(script.Parent.Motion)

local C = Theme.Color

local UI = {}

---------------------------------------------------------------------------
-- Core constructor
---------------------------------------------------------------------------
function UI.new(className: string, props: { [string]: any }?, children: { any }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function merge(base: { [string]: any }, extra: { [string]: any }?): { [string]: any }
	if extra then
		for k, v in extra do
			base[k] = v
		end
	end
	return base
end

---------------------------------------------------------------------------
-- Layout helpers
---------------------------------------------------------------------------
function UI.stroke(color: Color3?, transparency: number?): any
	return UI.new("UIStroke", {
		Color = color or C.Rule,
		Thickness = Theme.Stroke,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Miter,
	})
end

function UI.padding(all: number, horizontal: number?): any
	local h = horizontal or all
	return UI.new("UIPadding", {
		PaddingTop = UDim.new(0, all),
		PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, h),
		PaddingRight = UDim.new(0, h),
	})
end

function UI.list(direction: Enum.FillDirection?, gap: number?, align: Enum.HorizontalAlignment?): any
	return UI.new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or Theme.Gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
	})
end

function UI.grid(cell: number, gap: number): any
	return UI.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(cell, cell),
		CellPadding = UDim2.fromOffset(gap, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function UI.clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if not child:IsA("UIBase") then
			child:Destroy()
		end
	end
end

---------------------------------------------------------------------------
-- Text
---------------------------------------------------------------------------
export type TextRole = "body" | "bold" | "display" | "mono" | "monoBold"

local ROLE_FONT: { [string]: Font } = {
	body = Theme.Font.Body,
	bold = Theme.Font.BodyBold,
	display = Theme.Font.Display,
	mono = Theme.Font.Mono,
	monoBold = Theme.Font.MonoBold,
}

function UI.text(text: string, role: TextRole?, size: number?, props: { [string]: any }?): TextLabel
	return UI.new("TextLabel", merge({
		BackgroundTransparency = 1,
		Text = text,
		FontFace = ROLE_FONT[role or "body"],
		TextSize = size or Theme.TextSize.Body,
		TextColor3 = C.Bone,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, 0, 0, (size or Theme.TextSize.Body) + 6),
		TextWrapped = false,
	}, props))
end

-- Display titles: caps with wide tracking (approximated with spaced letters).
function UI.displayText(text: string, size: number?, props: { [string]: any }?): TextLabel
	local spaced = string.upper(text)
	return UI.text(spaced, "display", size or Theme.TextSize.Title, props)
end

-- Small caps label used above sections ("TRACKED", "PROFICIENCY").
function UI.caption(text: string, props: { [string]: any }?): TextLabel
	return UI.text(string.upper(text), "monoBold", Theme.TextSize.Caption, merge({
		TextTransparency = Theme.TextDim,
	}, props))
end

function UI.paragraph(text: string, props: { [string]: any }?): TextLabel
	return UI.text(text, "body", Theme.TextSize.Body, merge({
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		TextYAlignment = Enum.TextYAlignment.Top,
		TextTransparency = 0.15,
	}, props))
end

---------------------------------------------------------------------------
-- Plate: the panel surface
---------------------------------------------------------------------------
function UI.plate(props: { [string]: any }?, children: { any }?): Frame
	local frame = UI.new("Frame", merge({
		BackgroundColor3 = C.Steel,
		BackgroundTransparency = Theme.panelTransparency(),
		BorderSizePixel = 0,
	}, props), children)
	if Theme.PlateImage ~= "" then
		frame.BackgroundTransparency = 1
		UI.new("ImageLabel", {
			Name = "PlateImage",
			BackgroundTransparency = 1,
			Image = Theme.PlateImage,
			ImageColor3 = C.Steel,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Theme.PlateSliceCenter,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 0,
			Parent = frame,
		})
	else
		UI.stroke(C.Rule).Parent = frame
	end
	frame:SetAttribute("Plate", true)
	return frame
end

-- A plain fill block (rows, slots, tracks).
function UI.block(color: Color3, props: { [string]: any }?, children: { any }?): Frame
	return UI.new("Frame", merge({
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, props), children)
end

function UI.rule(props: { [string]: any }?): Frame
	return UI.block(C.Rule, merge({ Size = UDim2.new(1, 0, 0, 1) }, props))
end

---------------------------------------------------------------------------
-- Gamepad focus: a 1px lantern outline, never a coloured side stripe.
---------------------------------------------------------------------------
local focusTemplate: Frame = UI.new("Frame", {
	Name = "Focus",
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 4, 1, 4),
	Position = UDim2.fromOffset(-2, -2),
}, {
	UI.new("UIStroke", { Color = C.Lantern, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
})

function UI.focusable(gui: GuiObject)
	gui.Selectable = true
	gui.SelectionImageObject = focusTemplate
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------
export type ButtonVariant = "primary" | "secondary" | "danger" | "ghost"

local VARIANT = {
	primary = { bg = C.Lantern, bgT = 0, text = C.Ink, stroke = nil },
	secondary = { bg = C.Plate, bgT = 1, text = C.Bone, stroke = C.Bone },
	danger = { bg = C.Plate, bgT = 1, text = C.Ember, stroke = C.Ember },
	ghost = { bg = C.Plate, bgT = 1, text = C.Bone, stroke = nil },
}

-- Sound hook set by the Sound module, so the kit stays dependency-free.
UI.onHover = nil :: ((GuiObject) -> ())?
UI.onClick = nil :: ((GuiObject) -> ())?

function UI.button(text: string, variant: ButtonVariant?, onClick: (() -> ())?, props: { [string]: any }?): TextButton
	local v = VARIANT[variant or "secondary"]
	local btn: TextButton = UI.new("TextButton", merge({
		AutoButtonColor = false,
		BackgroundColor3 = v.bg,
		BackgroundTransparency = v.bgT,
		BorderSizePixel = 0,
		Text = text,
		FontFace = Theme.Font.BodyBold,
		TextSize = Theme.TextSize.Body,
		TextColor3 = v.text,
		Size = UDim2.fromOffset(120, Theme.TouchMin - 6),
	}, props))
	if v.stroke then
		UI.stroke(v.stroke, 0.35).Parent = btn
	end
	UI.focusable(btn)
	btn:SetAttribute("Variant", variant or "secondary")

	-- Rest look comes from the built button, so props can override the variant.
	local restBg, restBgT = btn.BackgroundColor3, btn.BackgroundTransparency
	local function restColor(): (Color3, number)
		return restBg, restBgT
	end
	btn.MouseEnter:Connect(function()
		if btn:GetAttribute("Disabled") then
			return
		end
		local bg, bgT = restColor()
		local hoverT = if bgT >= 1 then 0.4 else bgT
		Motion.token(btn, Theme.Motion.micro, { BackgroundColor3 = Theme.lighter(bg), BackgroundTransparency = hoverT })
		if UI.onHover then
			UI.onHover(btn)
		end
	end)
	btn.MouseLeave:Connect(function()
		local bg, bgT = restColor()
		Motion.token(btn, Theme.Motion.micro, { BackgroundColor3 = bg, BackgroundTransparency = bgT })
		Motion.pressUp(btn)
	end)
	btn.MouseButton1Down:Connect(function()
		if not btn:GetAttribute("Disabled") then
			Motion.pressDown(btn)
		end
	end)
	btn.MouseButton1Up:Connect(function()
		Motion.pressUp(btn)
	end)
	btn.Activated:Connect(function()
		if btn:GetAttribute("Disabled") then
			return
		end
		if UI.onClick then
			UI.onClick(btn)
		end
		if onClick then
			onClick()
		end
	end)
	return btn
end

-- Disabled look: plate fill, faint text. Recaptures fade bases.
function UI.setDisabled(btn: TextButton, disabled: boolean)
	btn:SetAttribute("Disabled", disabled)
	local v = VARIANT[(btn:GetAttribute("Variant") :: string?) or "secondary"] or VARIANT.secondary
	if disabled then
		btn.BackgroundColor3 = C.Plate
		btn.BackgroundTransparency = 0
		btn.TextColor3 = C.Bone
		btn.TextTransparency = Theme.TextFaint
	else
		btn.BackgroundColor3 = v.bg
		btn.BackgroundTransparency = v.bgT
		btn.TextColor3 = v.text
		btn.TextTransparency = 0
	end
	Motion.recapture(btn)
end

---------------------------------------------------------------------------
-- Tab (rail item or top tab). Selected = plate fill.
---------------------------------------------------------------------------
function UI.tab(text: string, onClick: () -> (), props: { [string]: any }?): TextButton
	local btn: TextButton = UI.new("TextButton", merge({
		AutoButtonColor = false,
		BackgroundColor3 = C.Plate,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = text,
		FontFace = Theme.Font.Body,
		TextSize = Theme.TextSize.Body,
		TextColor3 = C.Bone,
		TextTransparency = Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 36),
	}, props), { UI.padding(0, 14) })
	UI.focusable(btn)
	btn.MouseEnter:Connect(function()
		if not btn:GetAttribute("Selected") then
			Motion.token(btn, Theme.Motion.micro, { TextTransparency = 0.15 })
		end
		if UI.onHover then
			UI.onHover(btn)
		end
	end)
	btn.MouseLeave:Connect(function()
		if not btn:GetAttribute("Selected") then
			Motion.token(btn, Theme.Motion.micro, { TextTransparency = Theme.TextDim })
		end
	end)
	btn.Activated:Connect(onClick)
	return btn
end

function UI.setTabSelected(btn: TextButton, selected: boolean)
	btn:SetAttribute("Selected", selected)
	Motion.cancel(btn)
	btn.BackgroundTransparency = if selected then 0 else 1
	btn.TextTransparency = if selected then 0 else Theme.TextDim
	btn.FontFace = if selected then Theme.Font.BodyBold else Theme.Font.Body
	Motion.recapture(btn)
end

---------------------------------------------------------------------------
-- Row: numbered list row (01, 02 ...) with title, right-side mono value.
---------------------------------------------------------------------------
function UI.row(index: number, title: string, right: string?, onClick: (() -> ())?, props: { [string]: any }?): TextButton
	local btn: TextButton = UI.new("TextButton", merge({
		AutoButtonColor = false,
		BackgroundColor3 = C.Plate,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		Size = UDim2.new(1, 0, 0, 40),
	}, props), {
		UI.text(string.format("%02d", index), "mono", Theme.TextSize.Caption, {
			Name = "Index",
			Size = UDim2.new(0, 28, 1, 0),
			Position = UDim2.fromOffset(12, 0),
			TextTransparency = Theme.TextDim,
		}),
		UI.text(title, "bold", Theme.TextSize.Body, {
			Name = "Title",
			Size = UDim2.new(1, -150, 1, 0),
			Position = UDim2.fromOffset(44, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
		UI.text(right or "", "mono", Theme.TextSize.Caption, {
			Name = "Right",
			Size = UDim2.new(0, 100, 1, 0),
			Position = UDim2.new(1, -112, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
		UI.rule({ Name = "Divider", Position = UDim2.new(0, 0, 1, -1) }),
	})
	UI.focusable(btn)
	btn.MouseEnter:Connect(function()
		if not btn:GetAttribute("Selected") then
			Motion.token(btn, Theme.Motion.micro, { BackgroundTransparency = 0.5 })
		end
		if UI.onHover then
			UI.onHover(btn)
		end
	end)
	btn.MouseLeave:Connect(function()
		if not btn:GetAttribute("Selected") then
			Motion.token(btn, Theme.Motion.micro, { BackgroundTransparency = 1 })
		end
	end)
	if onClick then
		btn.Activated:Connect(onClick)
	end
	return btn
end

function UI.setRowSelected(btn: TextButton, selected: boolean)
	btn:SetAttribute("Selected", selected)
	Motion.cancel(btn)
	btn.BackgroundTransparency = if selected then 0 else 1
	local stroke = btn:FindFirstChild("SelectStroke") :: UIStroke?
	if selected and not stroke then
		local s = UI.stroke(C.Lantern)
		s.Name = "SelectStroke"
		s.Parent = btn
	elseif not selected and stroke then
		stroke:Destroy()
	end
	Motion.recapture(btn)
end

-- Unread marker: a small lantern square, never a red badge.
function UI.unread(props: { [string]: any }?): Frame
	return UI.block(C.Lantern, merge({
		Name = "Unread",
		Size = UDim2.fromOffset(6, 6),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
	}, props))
end

---------------------------------------------------------------------------
-- Slot: rarity-bordered item cell.
---------------------------------------------------------------------------
function UI.slot(rarity: string?, onClick: (() -> ())?, props: { [string]: any }?): TextButton
	local border = (rarity and Theme.Rarity[rarity]) or C.Rule
	local btn: TextButton = UI.new("TextButton", merge({
		AutoButtonColor = false,
		BackgroundColor3 = C.Plate,
		BackgroundTransparency = if rarity then 0 else 0.5,
		BorderSizePixel = 0,
		Text = "",
	}, props))
	UI.stroke(border, if rarity then 0 else 0.5).Parent = btn
	UI.focusable(btn)
	if onClick then
		btn.Activated:Connect(onClick)
		btn.MouseEnter:Connect(function()
			Motion.token(btn, Theme.Motion.micro, { BackgroundColor3 = Theme.lighter(C.Plate) })
			if UI.onHover then
				UI.onHover(btn)
			end
		end)
		btn.MouseLeave:Connect(function()
			Motion.token(btn, Theme.Motion.micro, { BackgroundColor3 = C.Plate })
		end)
	end
	return btn
end

---------------------------------------------------------------------------
-- Bar: track + fill (+ optional pale trailing bar for HP loss)
---------------------------------------------------------------------------
export type Bar = {
	frame: Frame,
	fill: Frame,
	trail: Frame?,
	set: (value: number, instant: boolean?) -> (),
	setColor: (color: Color3) -> (),
}

function UI.bar(color: Color3, height: number, withTrail: boolean?, props: { [string]: any }?): Bar
	local frame: Frame = UI.block(C.Ink, merge({
		Size = UDim2.new(1, 0, 0, height),
		ClipsDescendants = true,
	}, props))
	local trail: Frame? = nil
	if withTrail then
		trail = UI.block(C.Bone, {
			Name = "Trail",
			BackgroundTransparency = 0.55,
			Size = UDim2.fromScale(1, 1),
			Parent = frame,
		})
	end
	local fill: Frame = UI.block(color, { Name = "Fill", Size = UDim2.fromScale(1, 1), Parent = frame })
	local current = 1

	local bar: Bar = {
		frame = frame,
		fill = fill,
		trail = trail,
		set = function(value: number, instant: boolean?)
			local v = math.clamp(value, 0, 1)
			if v == current and not instant then
				return
			end
			local dropped = v < current
			current = v
			if instant then
				Motion.cancel(fill)
				fill.Size = UDim2.fromScale(v, 1)
				if trail then
					Motion.cancel(trail)
					trail.Size = UDim2.fromScale(v, 1)
				end
				return
			end
			if dropped and trail then
				-- Main bar drops instantly; the pale trail shrinks after a delay.
				Motion.cancel(fill)
				fill.Size = UDim2.fromScale(v, 1)
				Motion.cancel(trail)
				Motion.tween(trail, Theme.Motion.hpTrailTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Size = UDim2.fromScale(v, 1) }, Theme.Motion.hpTrailDelay)
			else
				Motion.bar(fill, v)
				if trail then
					Motion.cancel(trail)
					trail.Size = UDim2.fromScale(v, 1)
				end
			end
		end,
		setColor = function(c: Color3)
			fill.BackgroundColor3 = c
		end,
	}
	return bar
end

---------------------------------------------------------------------------
-- Segmented bar (SP: one segment per Sword Skill charge)
---------------------------------------------------------------------------
function UI.segments(count: number, color: Color3, height: number, props: { [string]: any }?): (Frame, (filled: number) -> ())
	local frame: Frame = UI.new("Frame", merge({
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
	}, props), { UI.list(Enum.FillDirection.Horizontal, 4) })
	local segs = {}
	for i = 1, count do
		local seg = UI.block(C.Ink, {
			Size = UDim2.new(1 / count, -4 * (count - 1) / count, 1, 0),
			LayoutOrder = i,
			Parent = frame,
		})
		local fill = UI.block(color, { Name = "Fill", Size = UDim2.fromScale(1, 1), Parent = seg })
		table.insert(segs, fill)
	end
	local function set(filled: number)
		for i, fill in segs do
			local amount = math.clamp(filled - (i - 1), 0, 1)
			fill.Size = UDim2.fromScale(amount, 1)
		end
	end
	return frame, set
end

---------------------------------------------------------------------------
-- Chip: small mono value box ("G 10,240", "CRYS 36", "ESC")
---------------------------------------------------------------------------
function UI.chip(text: string, accent: Color3?, props: { [string]: any }?): TextLabel
	local label: TextLabel = UI.text(text, "mono", Theme.TextSize.Caption, merge({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 26),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = accent or C.Bone,
	}, props))
	UI.padding(0, 10).Parent = label
	UI.stroke(C.Rule).Parent = label
	return label
end

---------------------------------------------------------------------------
-- Scroll area
---------------------------------------------------------------------------
function UI.scroll(props: { [string]: any }?, children: { any }?): ScrollingFrame
	return UI.new("ScrollingFrame", merge({
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.Rule,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.fromScale(1, 1),
		SelectionGroup = true,
	}, props), children)
end

-- Gamepad focus helper: land on the first useful control.
function UI.focusFirst(root: Instance)
	if not GuiService:IsTenFootInterface() and not (game:GetService("UserInputService").GamepadEnabled) then
		return
	end
	for _, d in root:GetDescendants() do
		if d:IsA("GuiButton") and d.Visible and d.Selectable then
			GuiService.SelectedObject = d
			return
		end
	end
end

return UI
