--!strict
-- Banners: big moments (plan 26). Floor cleared band and boss intro card.
-- Floor cleared: band wipes open from the centre, text fades in 120ms later,
-- holds 2.5s, fades out. Boss intro: ember underline draws left to right,
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

local function floorCleared(p: any)
	local band = UI.block(C.Ink, {
		Name = "FloorCleared",
		BackgroundTransparency = 0.1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(1, 0, 0, 0),
		ClipsDescendants = true,
		Parent = layer,
	})
	UI.block(C.Lantern, { Size = UDim2.new(1, 0, 0, 1), Parent = band })
	UI.block(C.Lantern, { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), Parent = band })

	local content = UI.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, 120),
		Parent = band,
	}, { UI.list(Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Center) })

	local floorId = tonumber(p.floorId) or 1
	local nextFloor = tonumber(p.nextFloor) or (floorId + 1)
	local def = Config.getFloor(floorId)
	UI.text(spacedCaps("Floor " .. Format.index(floorId)), "mono", Theme.TextSize.Caption, {
		TextColor3 = C.Lantern,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 1,
		Parent = content,
	})
	UI.text("CLEARED", "display", Theme.TextSize.Banner, {
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 54),
		LayoutOrder = 2,
		Parent = content,
	})
	local town = def and def.town or "town"
	UI.text(string.format("Gate to Floor %s opens in %s. Cleared by %d adventurers in %s", Format.index(nextFloor), town, tonumber(p.partySize) or 1, Format.clock(tonumber(p.clearSeconds) or 0)), "body", Theme.TextSize.Caption, {
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = Theme.TextDim,
		LayoutOrder = 3,
		Parent = content,
	})

	if soundHook then
		soundHook("floor_clear")
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
	task.delay(Theme.Motion.slow.time + Theme.Banner.floorClearedHold, function()
		finish(band)
	end)
end

local function bossIntro(p: any)
	local card = UI.new("TextButton", {
		Name = "BossIntro",
		AutoButtonColor = false,
		Text = "",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 64, 1, -180),
		Size = UDim2.fromOffset(520, 110),
		Parent = layer,
	})
	UI.text(spacedCaps("Floor boss"), "mono", Theme.TextSize.Caption, { TextColor3 = C.Ember, Parent = card })
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
	local line = UI.block(C.Ember, { Position = UDim2.fromOffset(0, 92), Size = UDim2.fromOffset(0, 1), Parent = card })

	Motion.setFade(card, 1)
	Motion.fadeTo(card, 0, Theme.Motion.base.time, Theme.Motion.base.style, Theme.Motion.base.dir)
	if Motion.reduced() then
		line.Size = UDim2.fromOffset(240, 1)
	else
		Motion.token(line, Theme.Motion.slow, { Size = UDim2.fromOffset(240, 1) })
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
		floorCleared(p)
	end
end

function Banners.show(p: any)
	if typeof(p) ~= "table" then
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
