--!strict
-- Banners: big moments. District cleared band, boss intro card and KO stamps.
-- District cleared: a paper band wipes open from the centre, text fades in 120ms later,
-- holds, fades out. Boss intro: a red underline draws left to right,
-- name fades in, holds 1.8s (skippable by click).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)
local Motion = require(script.Parent.Motion)

local C = Theme.Color

local Banners = {}

local layer: Frame
local busy = false
local queue: { any } = {}
local soundHook: ((string) -> ())? = nil

function Banners.setSoundHook(fn: (string) -> ())
	soundHook = fn
end

local function spacedCaps(s: string): string
	return (string.upper(s):gsub("(.)", "%1 "):gsub(" $", ""))
end

local playNext: () -> ()

local function finish(gui: GuiObject)
	Motion.exit(gui, "fade", Theme.Motion.base, function()
		gui:Destroy()
		busy = false
		playNext()
	end)
end

local function districtCleared(p: any)
	local band = UI.block(C.Paper, {
		Name = "DistrictCleared",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(1, 0, 0, 0),
		ClipsDescendants = true,
		Parent = layer,
	})
	UI.block(C.Line, { Size = UDim2.new(1, 0, 0, 3), Parent = band })
	UI.block(C.Line, { Size = UDim2.new(1, 0, 0, 3), Position = UDim2.new(0, 0, 1, -3), Parent = band })

	local content = UI.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, 120),
		Parent = band,
	}, { UI.list(Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Center) })

	local def = Config.getDistrict(tostring(p.district or ""))
	UI.text(spacedCaps(def and def.name or "District"), "monoBold", Theme.TextSize.Caption, {
		TextColor3 = C.Red,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 1,
		Parent = content,
	})
	UI.text("CLEARED", "display", Theme.TextSize.Banner + 10, {
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 64),
		LayoutOrder = 2,
		Parent = content,
	})
	UI.text(string.format("%s is out cold.%s", tostring(p.boss or "The boss"), if p.first then " Word gets around." else ""), "body", Theme.TextSize.Body, {
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = Theme.TextDim,
		LayoutOrder = 3,
		Parent = content,
	})

	if soundHook then
		soundHook("ko")
	end
	Motion.setFade(content, 1)
	if Motion.reduced() then
		band.Size = UDim2.new(1, 0, 0, 150)
		Motion.setFade(band, 1)
		Motion.fadeTo(band, 0, Theme.Motion.slow.time, Theme.Motion.slow.style, Theme.Motion.slow.dir)
	else
		Motion.token(band, Theme.Motion.slow, { Size = UDim2.new(1, 0, 0, 150) })
		Motion.fadeTo(content, 0, Theme.Motion.base.time, Theme.Motion.base.style, Theme.Motion.base.dir, 0.12)
	end
	task.delay(Theme.Motion.slow.time + Theme.Banner.clearedHold, function()
		finish(band)
	end)
end

-- Knockout stamp: not queued. A red "K.O." slams in above centre with the
-- reward line under it, then lifts away. Several can overlap.
local stampCount = 0
local function knockoutStamp(p: any)
	stampCount += 1
	local offset = ((stampCount - 1) % 3) * 22
	local splat = UI.splat(layer, UDim2.new(0.5, 0, 0.3, offset - 12), 150, C.Ink, stampCount + 7)
	local stamp = UI.new("Frame", {
		Name = "KO",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.3, offset),
		Size = UDim2.fromOffset(420, 90),
		Parent = layer,
	}, { UI.list(Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Center) })
	local word = UI.text(if p.boss then "BOSS K.O." else "K.O.", "display", Theme.TextSize.Banner, {
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.Red,
		TextStrokeColor3 = C.Paper,
		TextStrokeTransparency = 0,
		Size = UDim2.new(1, 0, 0, 52),
		LayoutOrder = 1,
		Parent = stamp,
	})
	local parts = {
		string.format("+%s%s", Config.CURRENCY_CODE, Format.commas(tonumber(p.cash) or 0)),
		string.format("+%s XP", Format.commas(tonumber(p.xp) or 0)),
		string.format("BOUNTY +%s", Format.commas(tonumber(p.bounty) or 0)),
	}
	local style = tonumber(p.style) or 1
	if style > 1.01 then
		table.insert(parts, string.format("STYLE x%.2f", style))
	end
	UI.text(table.concat(parts, "   "), "monoBold", Theme.TextSize.Body, {
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.Ink,
		TextStrokeColor3 = C.Paper,
		TextStrokeTransparency = 0.2,
		LayoutOrder = 2,
		Parent = stamp,
	})
	if soundHook then
		soundHook("bounty_up")
	end
	if not Motion.reduced() then
		local scale = Instance.new("UIScale")
		scale.Scale = 1.6
		scale.Parent = word
		Motion.token(scale, Theme.Motion.settle, { Scale = 1 })
	end
	task.delay(1.3, function()
		Motion.exit(stamp, "up", Theme.Motion.base, function()
			stamp:Destroy()
			splat:Destroy()
			stampCount = math.max(0, stampCount - 1)
		end)
	end)
end

local function bossIntro(p: any)
	local card = UI.new("TextButton", {
		Name = "BossIntro",
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = C.Paper,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 64, 1, -180),
		Size = UDim2.fromOffset(520, 124),
		Parent = layer,
	}, {
		UI.stroke(C.Line),
		UI.padding(10, 16),
	})
	UI.text(spacedCaps("Boss"), "monoBold", Theme.TextSize.Caption, { TextColor3 = C.Red, Parent = card })
	UI.text(string.upper(tostring(p.name or "Unknown")), "display", Theme.TextSize.Display, {
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 40),
		Parent = card,
	})
	UI.text(tostring(p.title or ""), "body", Theme.TextSize.Body, {
		Position = UDim2.fromOffset(0, 64),
		TextTransparency = Theme.TextDim,
		Parent = card,
	})
	local line = UI.block(C.Red, { Position = UDim2.fromOffset(0, 92), Size = UDim2.fromOffset(0, 3), Parent = card })

	Motion.setFade(card, 1)
	Motion.fadeTo(card, 0, Theme.Motion.base.time, Theme.Motion.base.style, Theme.Motion.base.dir)
	if Motion.reduced() then
		line.Size = UDim2.fromOffset(240, 3)
	else
		Motion.token(line, Theme.Motion.slow, { Size = UDim2.fromOffset(240, 3) })
	end

	local done = false
	local function close()
		if done then
			return
		end
		done = true
		finish(card)
	end
	card.Activated:Connect(close)
	task.delay(Theme.Motion.slow.time + Theme.Banner.bossIntroHold, close)
end

playNext = function()
	if busy or #queue == 0 then
		return
	end
	busy = true
	local p = table.remove(queue, 1)
	if p.kind == "BossIntro" then
		bossIntro(p)
	else
		districtCleared(p)
	end
end

function Banners.show(p: any)
	if typeof(p) ~= "table" then
		return
	end
	if p.kind == "Knockout" then
		knockoutStamp(p)
		return
	end
	table.insert(queue, p)
	playNext()
end

function Banners.init(root: Frame)
	layer = UI.new("Frame", {
		Name = "Banners",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
		Parent = root,
	})
end

return Banners
