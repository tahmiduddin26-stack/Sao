--!strict
-- Motion: the one motion module. enter, exit, press, stagger, bar.
-- Every call cancels running tweens on the same object first, so animations
-- never stack. Fades tween each element's own transparency from cached base
-- values instead of using CanvasGroup (cheaper on low-end phones).
-- Reduce Motion (system or in-game setting) turns slides and scales into fades.

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Motion = {}

local reduceSetting = false

function Motion.setReduceMotion(v: boolean)
	reduceSetting = v
end

function Motion.reduced(): boolean
	return reduceSetting or GuiService.ReducedMotionEnabled
end

---------------------------------------------------------------------------
-- Tween bookkeeping
---------------------------------------------------------------------------
local active: { [Instance]: { Tween } } = setmetatable({}, { __mode = "k" }) :: any

function Motion.cancel(inst: Instance)
	local list = active[inst]
	if list then
		for _, t in list do
			t:Cancel()
		end
		active[inst] = nil
	end
end

local function track(inst: Instance, tween: Tween)
	local list = active[inst]
	if not list then
		list = {}
		active[inst] = list
	end
	table.insert(list, tween)
	tween.Completed:Once(function()
		local l = active[inst]
		if l then
			local i = table.find(l, tween)
			if i then
				table.remove(l, i)
			end
			if #l == 0 then
				active[inst] = nil
			end
		end
	end)
end

function Motion.tween(inst: Instance, time: number, style: Enum.EasingStyle, dir: Enum.EasingDirection, props: { [string]: any }, delay: number?): Tween
	local tween = TweenService:Create(inst, TweenInfo.new(time, style, dir, 0, false, delay or 0), props)
	track(inst, tween)
	tween:Play()
	return tween
end

function Motion.token(inst: Instance, token: Theme.MotionToken, props: { [string]: any }, delay: number?): Tween
	return Motion.tween(inst, token.time, token.style, token.dir, props, delay)
end

---------------------------------------------------------------------------
-- Transparency caching (fades without CanvasGroup)
---------------------------------------------------------------------------
local FADE_PROPS: { [string]: { string } } = {
	Frame = { "BackgroundTransparency" },
	ScrollingFrame = { "BackgroundTransparency", "ScrollBarImageTransparency" },
	TextLabel = { "BackgroundTransparency", "TextTransparency" },
	TextButton = { "BackgroundTransparency", "TextTransparency" },
	TextBox = { "BackgroundTransparency", "TextTransparency" },
	ImageLabel = { "BackgroundTransparency", "ImageTransparency" },
	ImageButton = { "BackgroundTransparency", "ImageTransparency" },
	UIStroke = { "Transparency" },
}

local bases: { [Instance]: { [string]: number } } = setmetatable({}, { __mode = "k" }) :: any

local function baseOf(inst: Instance): { [string]: number }?
	local props = FADE_PROPS[inst.ClassName]
	if not props then
		return nil
	end
	local b = bases[inst]
	if not b then
		local fresh: { [string]: number } = {}
		for _, p in props do
			fresh[p] = (inst :: any)[p]
		end
		bases[inst] = fresh
		b = fresh
	end
	return b
end

-- Re-read the resting transparency of an element whose look changed on purpose.
function Motion.recapture(inst: Instance)
	bases[inst] = nil
	baseOf(inst)
end

local function eachFadeable(root: Instance, fn: (Instance, { [string]: number }) -> ())
	local b = baseOf(root)
	if b then
		fn(root, b)
	end
	for _, d in root:GetDescendants() do
		local db = baseOf(d)
		if db then
			fn(d, db)
		end
	end
end

-- alpha 0 = resting look, 1 = invisible
-- Fade tweens are tracked apart from movement tweens so a fade never cancels a slide.
local fading: { [Instance]: Tween } = setmetatable({}, { __mode = "k" }) :: any

local function cancelFade(inst: Instance)
	local t = fading[inst]
	if t then
		t:Cancel()
		fading[inst] = nil
	end
end

function Motion.setFade(root: Instance, alpha: number)
	eachFadeable(root, function(inst, b)
		cancelFade(inst)
		for p, v in b do
			(inst :: any)[p] = v + (1 - v) * alpha
		end
	end)
end

function Motion.fadeTo(root: Instance, alpha: number, time: number, style: Enum.EasingStyle, dir: Enum.EasingDirection, delay: number?)
	eachFadeable(root, function(inst, b)
		cancelFade(inst)
		local goal = {}
		for p, v in b do
			goal[p] = v + (1 - v) * alpha
		end
		local tween = TweenService:Create(inst, TweenInfo.new(time, style, dir, 0, false, delay or 0), goal)
		fading[inst] = tween
		tween:Play()
	end)
end

---------------------------------------------------------------------------
-- enter / exit
---------------------------------------------------------------------------
export type Preset = "panel" | "small" | "fade" | "up"

local rest: { [GuiObject]: UDim2 } = setmetatable({}, { __mode = "k" }) :: any
local generation: { [GuiObject]: number } = setmetatable({}, { __mode = "k" }) :: any

local function bump(gui: GuiObject): number
	local g = (generation[gui] or 0) + 1
	generation[gui] = g
	return g
end

local function offsetFor(preset: Preset): Vector2
	if preset == "panel" then
		return Vector2.new(Theme.Motion.offsetPanel, 0)
	elseif preset == "small" then
		return Vector2.new(Theme.Motion.offsetSmall, 0)
	elseif preset == "up" then
		return Vector2.new(0, Theme.Motion.offsetSmall)
	end
	return Vector2.zero
end

function Motion.restPosition(gui: GuiObject): UDim2
	local r = rest[gui]
	if not r then
		r = gui.Position
		rest[gui] = r
	end
	return r
end

-- Sets a new resting position (for layouts that move).
function Motion.setRest(gui: GuiObject, pos: UDim2)
	rest[gui] = pos
	gui.Position = pos
end

function Motion.enter(gui: GuiObject, preset: Preset?, token: Theme.MotionToken?, delay: number?)
	local p: Preset = preset or "fade"
	local t = token or Theme.Motion.base
	local home = Motion.restPosition(gui)
	bump(gui)
	Motion.cancel(gui)
	gui.Visible = true
	local off = if Motion.reduced() then Vector2.zero else offsetFor(p)
	gui.Position = home + UDim2.fromOffset(off.X, off.Y)
	Motion.setFade(gui, 1)
	if off ~= Vector2.zero then
		Motion.tween(gui, t.time, t.style, t.dir, { Position = home }, delay)
	end
	Motion.fadeTo(gui, 0, t.time, t.style, t.dir, delay)
end

function Motion.exit(gui: GuiObject, preset: Preset?, token: Theme.MotionToken?, onDone: (() -> ())?)
	local p: Preset = preset or "fade"
	local t = token or Theme.Motion.base
	local home = Motion.restPosition(gui)
	local time = t.time * Theme.Motion.exitFactor
	local style, dir = Theme.Motion.exitStyle, Theme.Motion.exitDir
	local gen = bump(gui)
	Motion.cancel(gui)
	local off = if Motion.reduced() then Vector2.zero else offsetFor(p)
	if off ~= Vector2.zero then
		Motion.tween(gui, time, style, dir, { Position = home + UDim2.fromOffset(off.X, off.Y) })
	end
	Motion.fadeTo(gui, 1, time, style, dir)
	task.delay(time, function()
		-- Only hide if nothing re-entered meanwhile.
		if generation[gui] == gen then
			gui.Visible = false
			gui.Position = home
			if onDone then
				onDone()
			end
		end
	end)
end

-- List rows and grid slots: 25ms per item, max 8 staggered, rest arrive together.
function Motion.stagger(items: { GuiObject }, preset: Preset?, startDelay: number?)
	local step = Theme.Motion.stagger
	for i, item in items do
		local d = (startDelay or 0) + math.min(i - 1, Theme.Motion.staggerMax) * step
		Motion.enter(item, preset or "up", Theme.Motion.base, d)
	end
end

---------------------------------------------------------------------------
-- press: scale to 0.96 and back (uses a UIScale child)
---------------------------------------------------------------------------
local function scaleOf(gui: GuiObject): UIScale
	local s = gui:FindFirstChild("PressScale") :: UIScale?
	if not s then
		local created = Instance.new("UIScale")
		created.Name = "PressScale"
		created.Parent = gui
		s = created
	end
	return s :: UIScale
end

function Motion.pressDown(gui: GuiObject)
	if Motion.reduced() then
		return
	end
	local s = scaleOf(gui)
	Motion.token(s, Theme.Motion.micro, { Scale = Theme.Motion.pressScale })
end

function Motion.pressUp(gui: GuiObject)
	local s = gui:FindFirstChild("PressScale")
	if s then
		Motion.token(s, Theme.Motion.quick, { Scale = 1 })
	end
end

---------------------------------------------------------------------------
-- bar: tween a fill frame's X scale
---------------------------------------------------------------------------
function Motion.bar(fill: GuiObject, value: number, token: Theme.MotionToken?, delay: number?)
	local v = math.clamp(value, 0, 1)
	local goal = UDim2.new(v, 0, fill.Size.Y.Scale, fill.Size.Y.Offset)
	if Motion.reduced() and not token then
		Motion.cancel(fill)
		fill.Size = goal
		return
	end
	local t = token or Theme.Motion.quick
	Motion.token(fill, t, { Size = goal }, delay)
end

return Motion
