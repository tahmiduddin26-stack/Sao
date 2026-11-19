--!strict
-- UI: the Ink Panel component kit.
-- UI.new(class, props, children) plus Plate, Text, Button, Tab, Row, Slot, Bar,
-- Chip and layout helpers, plus the comic kit (panel, bigButton, brushTitle,
-- splat, halftone, sticker, keycap, pips). Square corners, 3px ink borders.

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
		Color = color or C.Line,
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
		TextColor3 = C.Ink,
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
		BackgroundColor3 = C.Paper,
		BackgroundTransparency = Theme.panelTransparency(),
		BorderSizePixel = 0,
	}, props), children)
	if Theme.PlateImage ~= "" then
		frame.BackgroundTransparency = 1
		UI.new("ImageLabel", {
			Name = "PlateImage",
			BackgroundTransparency = 1,
			Image = Theme.PlateImage,
			ImageColor3 = C.Paper,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Theme.PlateSliceCenter,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 0,
			Parent = frame,
		})
	else
		UI.stroke(C.Line).Parent = frame
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
	return UI.block(C.Line, merge({ Size = UDim2.new(1, 0, 0, 1) }, props))
end

---------------------------------------------------------------------------
-- Gamepad focus: a 2px red outline, never a coloured side stripe.
---------------------------------------------------------------------------
local focusTemplate: Frame = UI.new("Frame", {
	Name = "Focus",
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 4, 1, 4),
	Position = UDim2.fromOffset(-2, -2),
}, {
	UI.new("UIStroke", { Color = C.Red, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
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
	primary = { bg = C.Red, bgT = 0, text = C.Paper, stroke = C.Line },
	secondary = { bg = C.Paper, bgT = 0, text = C.Ink, stroke = C.Line },
	danger = { bg = C.Tone, bgT = 1, text = C.Danger, stroke = C.Danger },
	ghost = { bg = C.Tone, bgT = 1, text = C.Ink, stroke = nil },
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
		btn.BackgroundColor3 = C.Tone
		btn.BackgroundTransparency = 0
		btn.TextColor3 = C.Ink
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
		BackgroundColor3 = C.Tone,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = text,
		FontFace = Theme.Font.Body,
		TextSize = Theme.TextSize.Body,
		TextColor3 = C.Ink,
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
		BackgroundColor3 = C.Tone,
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
		local s = UI.stroke(C.Red)
		s.Name = "SelectStroke"
		s.Parent = btn
	elseif not selected and stroke then
		stroke:Destroy()
	end
	Motion.recapture(btn)
end

-- Unread marker: a small red square.
function UI.unread(props: { [string]: any }?): Frame
	return UI.block(C.Red, merge({
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
	local border = (rarity and Theme.Rarity[rarity]) or C.Line
	local btn: TextButton = UI.new("TextButton", merge({
		AutoButtonColor = false,
		BackgroundColor3 = C.Tone,
		BackgroundTransparency = if rarity then 0 else 0.5,
		BorderSizePixel = 0,
		Text = "",
	}, props))
	UI.stroke(border, if rarity then 0 else 0.5).Parent = btn
	UI.focusable(btn)
	if onClick then
		btn.Activated:Connect(onClick)
		btn.MouseEnter:Connect(function()
			Motion.token(btn, Theme.Motion.micro, { BackgroundColor3 = Theme.lighter(C.Tone) })
			if UI.onHover then
				UI.onHover(btn)
			end
		end)
		btn.MouseLeave:Connect(function()
			Motion.token(btn, Theme.Motion.micro, { BackgroundColor3 = C.Tone })
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
	local frame: Frame = UI.block(C.Tone, merge({
		Size = UDim2.new(1, 0, 0, height),
		ClipsDescendants = true,
	}, props))
	local trail: Frame? = nil
	if withTrail then
		trail = UI.block(C.Red, {
			Name = "Trail",
			BackgroundTransparency = 0.3,
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
-- Segmented bar (one fill per segment)
---------------------------------------------------------------------------
function UI.segments(count: number, color: Color3, height: number, props: { [string]: any }?): (Frame, (filled: number) -> ())
	local frame: Frame = UI.new("Frame", merge({
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
	}, props), { UI.list(Enum.FillDirection.Horizontal, 4) })
	local segs = {}
	for i = 1, count do
		local seg = UI.block(C.Tone, {
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
		TextColor3 = accent or C.Ink,
	}, props))
	UI.padding(0, 10).Parent = label
	UI.stroke(C.Line).Parent = label
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
		ScrollBarImageColor3 = C.Line,
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

---------------------------------------------------------------------------
-- Comic kit: the "graphic panel" look. Everything below draws with plain
-- frames (no uploaded images): hard ink drop shadows, halftone dots, ink
-- splats and brush-stroke title slabs.
---------------------------------------------------------------------------

-- Layout props go on the outer holder; everything else goes on the face.
local OUTER_KEYS = {
	Name = true,
	Position = true,
	AnchorPoint = true,
	Size = true,
	LayoutOrder = true,
	Visible = true,
	Parent = true,
	Rotation = true,
	ZIndex = true,
}

local function split(props: { [string]: any }?): ({ [string]: any }, { [string]: any })
	local outer, face = {}, {}
	if props then
		for k, v in props do
			if OUTER_KEYS[k] then
				outer[k] = v
			else
				face[k] = v
			end
		end
	end
	return outer, face
end

-- Halftone: a patch of ink dots that shrink away from one corner (screentone).
-- corner: "TR" | "TL" | "BR" | "BL".
function UI.halftone(parent: Instance, corner: string?, cols: number?, rows: number?, color: Color3?, transparency: number?): Frame
	local c = corner or "TR"
	local nx, ny = cols or 7, rows or 5
	local step = 9
	local right = c == "TR" or c == "BR"
	local bottom = c == "BR" or c == "BL"
	local patch = UI.new("Frame", {
		Name = "Halftone",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(if right then 1 else 0, if bottom then 1 else 0),
		Position = UDim2.fromScale(if right then 1 else 0, if bottom then 1 else 0),
		Size = UDim2.fromOffset(nx * step, ny * step),
		ClipsDescendants = true,
		Parent = parent,
	})
	for ix = 0, nx - 1 do
		for iy = 0, ny - 1 do
			-- Distance from the chosen corner, 0 (corner) to ~1 (far edge).
			local dx = if right then (nx - 1 - ix) / nx else ix / nx
			local dy = if bottom then (ny - 1 - iy) / ny else iy / ny
			local d = math.sqrt(dx * dx + dy * dy)
			local size = math.floor((1 - d) * 7 + 0.5)
			if size >= 2 then
				local offsetRow = if iy % 2 == 1 then step / 2 else 0
				UI.new("Frame", {
					BackgroundColor3 = color or C.Ink,
					BackgroundTransparency = transparency or 0.82,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(ix * step + step / 2 + offsetRow, iy * step + step / 2),
					Size = UDim2.fromOffset(size, size),
					Parent = patch,
				}, { UI.new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
			end
		end
	end
	return patch
end

-- Ink splat: one blob with droplets around it. Seeded so it never flickers.
function UI.splat(parent: Instance, position: UDim2, size: number, color: Color3?, seed: number?, props: { [string]: any }?): Frame
	local rng = Random.new(seed or 1)
	local holder = UI.new("Frame", merge({
		Name = "Splat",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(size, size),
		Parent = parent,
	}, props))
	local function dot(x: number, y: number, d: number)
		UI.new("Frame", {
			BackgroundColor3 = color or C.Ink,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromOffset(d, d),
			Parent = holder,
		}, { UI.new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end
	dot(0.5, 0.5, size * 0.62)
	-- Lumps on the main blob make the edge irregular.
	for i = 1, 6 do
		local a = (i / 6) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local r = 0.2 + rng:NextNumber(0, 0.06)
		dot(0.5 + math.cos(a) * r, 0.5 + math.sin(a) * r, size * rng:NextNumber(0.22, 0.34))
	end
	-- Flung droplets.
	for _ = 1, 7 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0.38, 0.52)
		dot(0.5 + math.cos(a) * r, 0.5 + math.sin(a) * r, size * rng:NextNumber(0.04, 0.1))
	end
	return holder
end

-- Brush title: paper display text on a tilted ink slab with ragged ends.
function UI.brushTitle(text: string, size: number?, props: { [string]: any }?, slabColor: Color3?): Frame
	local textSize = size or Theme.TextSize.Title
	local holder = UI.new("Frame", merge({
		Name = "BrushTitle",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, textSize + 16),
		AutomaticSize = Enum.AutomaticSize.X,
	}, props))
	local slab = UI.new("Frame", {
		Name = "Slab",
		BackgroundColor3 = slabColor or C.Ink,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Rotation = -2,
		Parent = holder,
	}, { UI.padding(0, 16) })
	-- Ragged ends: a few small blocks poking out of each side.
	local rng = Random.new(#text * 31 + textSize)
	for side = 0, 1 do
		for i = 1, 4 do
			UI.new("Frame", {
				BackgroundColor3 = slabColor or C.Ink,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(if side == 0 then 1 else 0, 0.5),
				Position = UDim2.new(side, if side == 0 then 2 else -2, i / 5, 0),
				Size = UDim2.fromOffset(rng:NextInteger(5, 12), rng:NextInteger(3, 6)),
				Rotation = rng:NextNumber(-12, 12),
				Parent = slab,
			})
		end
	end
	UI.text(string.upper(text), "display", textSize, {
		Name = "Label",
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		TextColor3 = C.Paper,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = slab,
	})
	return holder
end

-- Changes a brush title's text after it is built.
function UI.setBrushText(holder: Instance, text: string)
	local slab = holder:FindFirstChild("Slab")
	local label = slab and slab:FindFirstChild("Label") :: TextLabel?
	if label then
		label.Text = string.upper(text)
	end
end

-- Panel: a comic panel. Returns the face (put content in it); the outer
-- holder (face.Parent) carries layout props and the hard ink shadow.
-- opts.tone adds a halftone corner; opts.color overrides the paper.
export type PanelOpts = { tone: string?, color: Color3?, offset: number?, stroke: Color3?, shadow: Color3? }

function UI.panel(props: { [string]: any }?, opts: PanelOpts?, children: { any }?): Frame
	local o = opts or {}
	local off = o.offset or Theme.InkOffset
	local outerProps, faceProps = split(props)
	local parent = outerProps.Parent
	outerProps.Parent = nil
	local outer = UI.new("Frame", merge({ BackgroundTransparency = 1 }, outerProps))
	outer:SetAttribute("InkPanel", true)
	UI.new("Frame", {
		Name = "InkShadow",
		BackgroundColor3 = o.shadow or C.Ink,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(off, off),
		Size = UDim2.new(1, -off, 1, -off),
		Parent = outer,
	})
	local face = UI.new("Frame", merge({
		Name = "Face",
		BackgroundColor3 = o.color or C.Paper,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -off, 1, -off),
	}, faceProps))
	UI.stroke(o.stroke or C.Line).Parent = face
	if o.tone then
		UI.halftone(face, o.tone)
	end
	if children then
		for _, child in children do
			child.Parent = face
		end
	end
	face.Parent = outer
	if parent then
		outer.Parent = parent
	end
	return face
end

-- Shows or hides a panel or chunky button including its shadow.
function UI.show(gui: GuiObject, visible: boolean)
	local outer = gui.Parent
	if outer and outer:IsA("GuiObject") and outer:GetAttribute("InkPanel") then
		outer.Visible = visible
	else
		gui.Visible = visible
	end
end

-- The holder of a panel or chunky button (for Motion or repositioning).
function UI.outer(gui: GuiObject): GuiObject
	local outer = gui.Parent
	if outer and outer:IsA("GuiObject") and outer:GetAttribute("InkPanel") then
		return outer
	end
	return gui
end

-- Chunky button: display font, ink border and a hard shadow that the face
-- presses down into. Big and obvious, for kids and thumbs.
function UI.bigButton(text: string, variant: ButtonVariant?, onClick: (() -> ())?, props: { [string]: any }?): TextButton
	local off = Theme.ButtonInkOffset
	local outerProps, faceProps = split(props)
	local parent = outerProps.Parent
	outerProps.Parent = nil
	local outer = UI.new("Frame", merge({ BackgroundTransparency = 1, Size = UDim2.fromOffset(160, 52) }, outerProps))
	outer:SetAttribute("InkPanel", true)
	UI.new("Frame", {
		Name = "InkShadow",
		BackgroundColor3 = C.Ink,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(off, off),
		Size = UDim2.new(1, -off, 1, -off),
		Parent = outer,
	})
	local btn = UI.button(text, variant or "primary", nil, merge({
		Size = UDim2.new(1, -off, 1, -off),
		FontFace = Theme.Font.Display,
		TextSize = Theme.TextSize.Heading,
	}, faceProps))
	local stroke = btn:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = C.Line
		stroke.Transparency = 0
		stroke.Thickness = Theme.Stroke
	else
		UI.stroke(C.Line).Parent = btn
	end
	btn.Parent = outer
	local rest = btn.Position
	btn.MouseButton1Down:Connect(function()
		if not btn:GetAttribute("Disabled") then
			btn.Position = rest + UDim2.fromOffset(off, off)
		end
	end)
	local function up()
		btn.Position = rest
	end
	btn.MouseButton1Up:Connect(up)
	btn.MouseLeave:Connect(up)
	btn.Activated:Connect(function()
		if btn:GetAttribute("Disabled") then
			return
		end
		if onClick then
			onClick()
		end
	end)
	if parent then
		outer.Parent = parent
	end
	return btn
end

-- Sticker: a small tilted label (cash, bounty, "NEW", "LOCKED").
function UI.sticker(text: string, color: Color3?, textColor: Color3?, props: { [string]: any }?): TextLabel
	local label: TextLabel = UI.text(text, "display", Theme.TextSize.Label, merge({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundColor3 = color or C.Paper,
		BackgroundTransparency = 0,
		TextColor3 = textColor or C.Ink,
		Rotation = -3,
	}, props))
	UI.padding(0, 10).Parent = label
	UI.stroke(C.Line).Parent = label
	return label
end

-- Key cap: "E", "Q", "CLICK" in a little ink box, for control hints.
function UI.keycap(key: string, props: { [string]: any }?): TextLabel
	local label: TextLabel = UI.text(key, "monoBold", Theme.TextSize.Caption, merge({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0,
		TextColor3 = C.Paper,
	}, props))
	UI.padding(0, 6).Parent = label
	return label
end

-- A row of key + word pairs: { {"CLICK", "HIT"}, {"Q", "THROW"} }.
function UI.keyHints(pairs: { { string } }, props: { [string]: any }?): Frame
	local row = UI.new("Frame", merge({
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
	}, props), { UI.list(Enum.FillDirection.Horizontal, 6) })
	for i, pair in pairs do
		UI.keycap(pair[1], { LayoutOrder = i * 2 - 1, Parent = row })
		UI.text(pair[2], "display", Theme.TextSize.Body, {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 22),
			LayoutOrder = i * 2,
			Parent = row,
		})
	end
	return row
end

-- Pip meter: chunky squares (shelf stock, durability). Easy to read at a glance.
function UI.pips(count: number, filled: number, color: Color3?, props: { [string]: any }?): Frame
	local row = UI.new("Frame", merge({
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 14),
	}, props), { UI.list(Enum.FillDirection.Horizontal, 4) })
	for i = 1, count do
		local pip = UI.block(if i <= filled then (color or C.Ink) else C.Paper, {
			Size = UDim2.new(1 / count, -4, 1, 0),
			LayoutOrder = i,
			Parent = row,
		})
		UI.new("UIStroke", { Color = C.Line, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }).Parent = pip
	end
	return row
end

return UI
