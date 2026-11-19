--!strict
-- Settings tab: reduce motion, UI scale, panel opacity, audio volumes.
-- Values are saved on the server; the client applies them on every snapshot.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local UIFolder = script.Parent.Parent.UI
local Theme = require(UIFolder.Theme)
local UI = require(UIFolder.UI)
local Common = require(script.Parent.Common)

local Tab = { title = "Settings" }

local function settingRow(parent: Instance, order: number, label: string, hint: string?): Frame
	local row = UI.block(Theme.Color.Tone, { Size = UDim2.new(1, 0, 0, 56), LayoutOrder = order, Parent = parent }, { UI.padding(8, 14) })
	UI.text(label, "bold", Theme.TextSize.Body, { Size = UDim2.new(1, -220, 0, 22), Parent = row })
	if hint then
		UI.text(hint, "body", Theme.TextSize.Caption, {
			Position = UDim2.fromOffset(0, 22),
			Size = UDim2.new(1, -220, 0, 18),
			TextTransparency = Theme.TextDim,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
	end
	return row
end

local function stepper(row: Frame, value: number, display: string, step: number, min: number, max: number, key: string)
	local holder = UI.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(190, 38),
		Parent = row,
	})
	local minus = UI.button("-", "secondary", function()
		Remotes.event("SetSetting"):FireServer(key, math.clamp(math.floor((value - step) * 100 + 0.5) / 100, min, max))
	end, { Size = UDim2.fromOffset(44, 38), FontFace = Theme.Font.MonoBold, Parent = holder })
	UI.text(display, "mono", Theme.TextSize.Body, {
		Position = UDim2.fromOffset(50, 0),
		Size = UDim2.fromOffset(90, 38),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = holder,
	})
	local plus = UI.button("+", "secondary", function()
		Remotes.event("SetSetting"):FireServer(key, math.clamp(math.floor((value + step) * 100 + 0.5) / 100, min, max))
	end, { Size = UDim2.fromOffset(44, 38), Position = UDim2.fromOffset(146, 0), FontFace = Theme.Font.MonoBold, Parent = holder })
	UI.setDisabled(minus, value <= min + 1e-6)
	UI.setDisabled(plus, value >= max - 1e-6)
end

function Tab.render(content: Frame, data: any, ctx: any)
	local s = data.settings or Config.DEFAULT_SETTINGS
	local wrap = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = content }, { UI.padding(18, 22) })
	local scroll = ctx.scroll("settings", { Parent = wrap })
	UI.list(Enum.FillDirection.Vertical, 8).Parent = scroll

	UI.caption("Display", { LayoutOrder = 0, Parent = scroll })

	local rm = settingRow(scroll, 1, "Reduce motion", if GuiService.ReducedMotionEnabled then "On in your system settings too" else "Slides and scales become fades")
	UI.button(if s.reduceMotion then "On" else "Off", if s.reduceMotion then "primary" else "secondary", function()
		Remotes.event("SetSetting"):FireServer("reduceMotion", not s.reduceMotion)
	end, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(90, 38),
		Parent = rm,
	})

	local sc = settingRow(scroll, 2, "UI scale", "Applies on top of automatic screen scaling")
	stepper(sc, s.uiScale, string.format("%d%%", math.floor(s.uiScale * 100 + 0.5)), 0.05, Config.UI_SCALE_MIN, Config.UI_SCALE_MAX, "uiScale")

	local op = settingRow(scroll, 3, "Panel opacity", "Also follows your system transparency setting")
	stepper(op, s.panelOpacity, string.format("%d%%", math.floor(s.panelOpacity * 100 + 0.5)), 0.1, 0.5, 1, "panelOpacity")

	UI.caption("Audio", { LayoutOrder = 10, Parent = scroll })
	local sfx = settingRow(scroll, 11, "Effects volume")
	stepper(sfx, s.sfxVolume, string.format("%d%%", math.floor(s.sfxVolume * 100 + 0.5)), 0.1, 0, 1, "sfxVolume")
	local music = settingRow(scroll, 12, "Music volume")
	stepper(music, s.musicVolume, string.format("%d%%", math.floor(s.musicVolume * 100 + 0.5)), 0.1, 0, 1, "musicVolume")

	UI.caption("Account", { LayoutOrder = 20, Parent = scroll })
	Common.note(scroll, if data.canSave then "Your progress saves automatically." else "Progress is not saving this session. Rejoin to try again.", 21)
end

return Tab
