--!strict
-- Theme: Lanternsteel (plan 23, 27). Palette, fonts, sizes and motion tokens.
-- Nothing else in the client hard-codes a colour, font or duration.

local GuiService = game:GetService("GuiService")

local Theme = {}

---------------------------------------------------------------------------
-- Palette: every colour has one job.
---------------------------------------------------------------------------
Theme.Color = {
	Ink = Color3.fromHex("0E0F10"), -- scrims behind menus, tooltips, bar tracks
	Steel = Color3.fromHex("16181A"), -- panel base
	Plate = Color3.fromHex("23272B"), -- rows, slots, selected tab fill
	Rule = Color3.fromHex("3A4046"), -- 1px hairlines and dividers
	Bone = Color3.fromHex("ECE8DF"), -- primary text and icons
	Lantern = Color3.fromHex("E8A93B"), -- skill energy, active/selected, primary button
	Vigor = Color3.fromHex("6DBE7B"), -- HP and positive states
	Tide = Color3.fromHex("6CB4DE"), -- MP
	Ember = Color3.fromHex("D9573F"), -- danger, low HP, boss HP, destructive buttons
}

Theme.Rarity = {
	Common = Color3.fromHex("A8A39A"),
	Fine = Color3.fromHex("7DBE74"),
	Rare = Color3.fromHex("5E9FD6"),
	Heroic = Color3.fromHex("D2774A"),
	Legendary = Color3.fromHex("E8C24A"),
} :: { [string]: Color3 }

-- Secondary text is Bone at reduced opacity, not a new colour.
Theme.TextDim = 0.45
Theme.TextFaint = 0.65

-- "One step lighter" for hover states.
function Theme.lighter(c: Color3): Color3
	return c:Lerp(Theme.Color.Bone, 0.07)
end

function Theme.darker(c: Color3): Color3
	return c:Lerp(Theme.Color.Ink, 0.18)
end

---------------------------------------------------------------------------
-- Type: built-in Roblox families only, so mockups match what ships.
---------------------------------------------------------------------------
Theme.Font = {
	Display = Font.new("rbxasset://fonts/families/Michroma.json", Enum.FontWeight.Regular),
	Body = Font.new("rbxasset://fonts/families/TitilliumWeb.json", Enum.FontWeight.SemiBold),
	BodyBold = Font.new("rbxasset://fonts/families/TitilliumWeb.json", Enum.FontWeight.Bold),
	Mono = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Regular),
	MonoBold = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold),
}

Theme.TextSize = {
	Caption = 13, -- minimum at design scale
	Body = 15,
	Label = 16,
	Heading = 18,
	Title = 22,
	Display = 30,
	Banner = 46,
}

---------------------------------------------------------------------------
-- Shape and surface: square corners, 1px hairlines, no shadows or gradients.
---------------------------------------------------------------------------
Theme.Stroke = 1
Theme.Pad = 12
Theme.Gap = 8
Theme.TouchMin = 44
-- Signature notched plate (45 degree cut top-left). Set to an uploaded 9-slice
-- image id to switch every large plate to it; empty keeps flat plates.
Theme.PlateImage = ""
Theme.PlateSliceCenter = Rect.new(12, 12, 52, 52)

-- Panel base transparency, scaled by the player's Preferred Transparency.
local PANEL_BASE_TRANSPARENCY = 0.1
local panelOpacity = 1

function Theme.setPanelOpacity(v: number)
	panelOpacity = v
end

function Theme.panelTransparency(): number
	local t = PANEL_BASE_TRANSPARENCY * GuiService.PreferredTransparency
	return 1 - (1 - t) * panelOpacity
end

---------------------------------------------------------------------------
-- Motion tokens (plan 27.2)
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
-- Toasts and banners (plan 26)
---------------------------------------------------------------------------
Theme.Toast = {
	maxVisible = 3,
	width = 300,
	hold = { reward = 4, levelup = 2.5, quest = 3, info = 3, error = 4.5, purchase = 3 } :: { [string]: number },
	priority = { reward = 3, purchase = 3, levelup = 2, error = 2, quest = 1, info = 1 } :: { [string]: number },
}

Theme.Banner = {
	floorClearedHold = 2.5,
	bossIntroHold = 1.8,
}

return Theme
