--!strict
-- Theme: Ink Panel. Manga pages: paper panels, heavy ink borders, screentone
-- fills and one red accent. Palette, fonts, sizes and motion tokens.
-- Nothing else in the client hard-codes a colour, font or duration.

local GuiService = game:GetService("GuiService")

local Theme = {}

---------------------------------------------------------------------------
-- Palette: every colour has one job. Red is the only accent.
---------------------------------------------------------------------------
Theme.Color = {
	Shade = Color3.fromHex("0A0A0A"), -- scrims behind menus
	Paper = Color3.fromHex("F3EFE6"), -- panel base
	Tone = Color3.fromHex("DCD6CA"), -- rows, slots, bar tracks, selected tab fill
	Line = Color3.fromHex("141414"), -- 2px panel borders and dividers
	Ink = Color3.fromHex("141414"), -- text, icons, HP fill
	Red = Color3.fromHex("D7261E"), -- Focus, Serious, active/selected, primary button
	Danger = Color3.fromHex("9E1B16"), -- destructive buttons, low HP
}

-- Prop rarity reads through ink weight, not new hues.
Theme.Rarity = {
	Common = Color3.fromHex("8A857B"),
	Fine = Color3.fromHex("141414"),
	Rare = Color3.fromHex("D7261E"),
	Signature = Color3.fromHex("D7261E"),
} :: { [string]: Color3 }

-- Secondary text is Ink at reduced opacity, not a new colour.
Theme.TextDim = 0.45
Theme.TextFaint = 0.65

-- Hover states on paper go one step darker (toward ink).
function Theme.lighter(c: Color3): Color3
	return c:Lerp(Theme.Color.Ink, 0.08)
end

function Theme.darker(c: Color3): Color3
	return c:Lerp(Theme.Color.Shade, 0.18)
end

---------------------------------------------------------------------------
-- Type: built-in Roblox families only, so mockups match what ships.
---------------------------------------------------------------------------
Theme.Font = {
	Display = Font.new("rbxasset://fonts/families/Bangers.json", Enum.FontWeight.Regular),
	Body = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium),
	BodyBold = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
	Mono = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Regular),
	MonoBold = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold),
}

Theme.TextSize = {
	Caption = 14, -- minimum at design scale
	Body = 17,
	Label = 18,
	Heading = 22,
	Title = 28,
	Display = 38,
	Banner = 52,
}

---------------------------------------------------------------------------
-- Shape and surface: square corners, 3px ink borders, hard ink drop shadows,
-- halftone dot corners. No soft shadows, gradients or blur.
---------------------------------------------------------------------------
Theme.Stroke = 3
Theme.InkOffset = 6 -- hard comic drop shadow on panels
Theme.ButtonInkOffset = 4 -- and on chunky buttons (collapses on press)
Theme.Pad = 12
Theme.Gap = 8
Theme.TouchMin = 44
-- Signature notched plate (45 degree cut top-left). Set to an uploaded 9-slice
-- image id to switch every large plate to it; empty keeps flat plates.
Theme.PlateImage = ""
Theme.PlateSliceCenter = Rect.new(12, 12, 52, 52)

-- Panel base transparency, scaled by the player's Preferred Transparency.
local PANEL_BASE_TRANSPARENCY = 0.02
local panelOpacity = 1

function Theme.setPanelOpacity(v: number)
	panelOpacity = v
end

function Theme.panelTransparency(): number
	local t = PANEL_BASE_TRANSPARENCY * GuiService.PreferredTransparency
	return 1 - (1 - t) * panelOpacity
end

---------------------------------------------------------------------------
-- Motion tokens
---------------------------------------------------------------------------
export type MotionToken = { time: number, style: Enum.EasingStyle, dir: Enum.EasingDirection }

Theme.Motion = {
	micro = { time = 0.08, style = Enum.EasingStyle.Quad, dir = Enum.EasingDirection.Out } :: MotionToken,
	quick = { time = 0.14, style = Enum.EasingStyle.Quart, dir = Enum.EasingDirection.Out } :: MotionToken,
	base = { time = 0.22, style = Enum.EasingStyle.Quart, dir = Enum.EasingDirection.Out } :: MotionToken,
	slow = { time = 0.32, style = Enum.EasingStyle.Quart, dir = Enum.EasingDirection.Out } :: MotionToken,
	settle = { time = 0.22, style = Enum.EasingStyle.Back, dir = Enum.EasingDirection.Out } :: MotionToken,
	exitFactor = 0.7,
	exitStyle = Enum.EasingStyle.Quad,
	exitDir = Enum.EasingDirection.In,
	stagger = 0.025,
	staggerMax = 8,
	offsetSmall = 8,
	offsetPanel = 24,
	pressScale = 0.96,
	tooltipDelay = 0.25,
	hpTrailDelay = 0.3,
	hpTrailTime = 0.4,
}

---------------------------------------------------------------------------
-- Toasts and banners
---------------------------------------------------------------------------
Theme.Toast = {
	maxVisible = 3,
	width = 300,
	hold = { reward = 4, levelup = 2.5, quest = 3, info = 3, error = 4.5, purchase = 3 } :: { [string]: number },
	priority = { reward = 3, purchase = 3, levelup = 2, error = 2, quest = 1, info = 1 } :: { [string]: number },
}

Theme.Banner = {
	clearedHold = 2.5,
	bossIntroHold = 1.8,
}

return Theme
