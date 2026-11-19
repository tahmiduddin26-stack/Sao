--!strict
-- Ledger: the one menu, drawn as a comic page. Five chunky tabs on the left
-- (ME, STORE, JOBS, MAP, SHOP), a brush-stroke title, Cash and bounty
-- stickers, and a big close button. Settings sit behind a small button under
-- the tabs. Each tab module exports { title, render(content, data, ctx), unread?(data) }.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local UIFolder = script.Parent.UI
local Theme = require(UIFolder.Theme)
local UI = require(UIFolder.UI)
local Motion = require(UIFolder.Motion)
local Router = require(UIFolder.Router)
local State = require(script.Parent.State)

local C = Theme.Color

local Ledger = {}

export type Ctx = {
	scroll: (key: string, props: { [string]: any }?) -> ScrollingFrame,
	rerender: () -> (),
	openTab: (name: string) -> (),
}

export type Tab = {
	title: string,
	render: (content: Frame, data: any, ctx: Ctx) -> (),
	unread: ((data: any) -> boolean)?,
}

local TAB_ORDER = { "Me", "Store", "Jobs", "Map", "Shop" }
local tabs: { [string]: Tab } = {}
for _, name in TAB_ORDER do
	tabs[name] = require(script:WaitForChild(name)) :: any
end
tabs.Settings = require(script:WaitForChild("Settings")) :: any

local scrim: TextButton
local shellOuter: GuiObject
local railButtons: { [string]: TextButton } = {}
local title: Frame
local cashSticker: TextLabel
local bountySticker: TextLabel
local content: Frame
local currentTab = "Me"
local isOpen = false
local scrollMemory: { [string]: Vector2 } = {}
local liveScrolls: { [string]: ScrollingFrame } = {}
local funnelSent = false

local ctx: Ctx

local function render(animate: boolean)
	for key, sf in liveScrolls do
		if sf.Parent then
			scrollMemory[key] = sf.CanvasPosition
		end
	end
	table.clear(liveScrolls)

	UI.clear(content)
	local tab = tabs[currentTab]
	UI.setBrushText(title, tab and tab.title or currentTab)
	local data = State.data
	if tab and data then
		tab.render(content, data, ctx)
	end
	if animate then
		Motion.enter(content, "small", Theme.Motion.quick, 0.04)
	else
		Motion.setFade(content, 0)
	end
end

local function updateRail(data: any?)
	for name, btn in railButtons do
		local selected = name == currentTab
		btn.BackgroundColor3 = if selected then C.Red else C.Paper
		btn.TextColor3 = if selected then C.Paper else C.Ink
		UI.outer(btn).Rotation = if selected then -2 else 0
		local tab = tabs[name]
		local unread = data ~= nil and tab.unread ~= nil and tab.unread(data)
		local marker = btn:FindFirstChild("Splat")
		if unread and not marker then
			UI.splat(btn, UDim2.new(1, -16, 0.5, 0), 22, C.Red, #name, { ZIndex = 2 })
		elseif not unread and marker then
			marker:Destroy()
		end
	end
end

local function updateHeader(data: any)
	cashSticker.Text = Config.CURRENCY_CODE .. Format.commas(data.cash or 0)
	bountySticker.Text = "BOUNTY " .. Format.commas(data.bounty or 0)
end

local function setTab(name: string, animate: boolean?)
	if not tabs[name] then
		return
	end
	local changed = name ~= currentTab
	currentTab = name
	updateRail(State.data)
	render(animate ~= false and changed)
end

local function open(tab: string?)
	if tab and tabs[tab] then
		currentTab = tab
	elseif tab and tab ~= "" then
		-- Old tab names from world prompts map onto the new five.
		local aliases: { [string]: string } = { Character = "Me", Quests = "Jobs" }
		if aliases[tab] then
			currentTab = aliases[tab]
		end
	end
	isOpen = true
	updateRail(State.data)
	if State.data then
		updateHeader(State.data)
	end
	render(false)

	Motion.setFade(scrim, 1)
	scrim.Visible = true
	Motion.fadeTo(scrim, 0, Theme.Motion.quick.time, Theme.Motion.quick.style, Theme.Motion.quick.dir)
	shellOuter.Visible = true
	Motion.enter(shellOuter, "panel", Theme.Motion.base)
	UI.focusFirst(shellOuter)

	if not funnelSent then
		funnelSent = true
		Remotes.event("FunnelStep"):FireServer("OpenedLedger")
	end
end

local function close()
	isOpen = false
	Motion.exit(shellOuter, "panel", Theme.Motion.base)
	Motion.exit(scrim, "fade", Theme.Motion.quick)
	local GuiService = game:GetService("GuiService")
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(shellOuter) then
		GuiService.SelectedObject = nil
	end
end

function Ledger.init(root: Frame)
	ctx = {
		scroll = function(key: string, props: { [string]: any }?): ScrollingFrame
			local sf = UI.scroll(props)
			liveScrolls[key] = sf
			local remembered = scrollMemory[key]
			if remembered then
				task.defer(function()
					if sf.Parent then
						sf.CanvasPosition = remembered
					end
				end)
			end
			return sf
		end,
		rerender = function()
			if isOpen then
				render(false)
			end
		end,
		openTab = function(name: string)
			setTab(name)
		end,
	}

	scrim = UI.new("TextButton", {
		Name = "LedgerScrim",
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = C.Shade,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 10,
		Selectable = false,
		Parent = root,
	})
	scrim.Activated:Connect(function()
		Router.close()
	end)

	local shell = UI.panel({
		Name = "Ledger",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(980, 590),
		Visible = false,
		ZIndex = 11,
		Parent = root,
	}, { tone = "BR", offset = 12, shadow = C.Red })
	shellOuter = UI.outer(shell)
	shell.SelectionGroup = true

	-- Rail: five chunky tabs and a small settings button.
	local rail = UI.new("Frame", {
		Name = "Rail",
		BackgroundColor3 = C.Tone,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 200, 1, 0),
		Parent = shell,
	})
	UI.block(C.Line, { Size = UDim2.new(0, 3, 1, 0), Position = UDim2.new(1, -3, 0, 0), Parent = rail })
	UI.halftone(rail, "TL", 10, 8)
	local railList = UI.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 24),
		Size = UDim2.new(1, -36, 1, -90),
		Parent = rail,
	}, { UI.list(Enum.FillDirection.Vertical, 12) })
	for i, name in TAB_ORDER do
		local btn = UI.bigButton(tabs[name].title, "secondary", function()
			setTab(name)
			Router.noteTab(name)
		end, {
			Size = UDim2.new(1, 0, 0, 60),
			TextSize = Theme.TextSize.Title,
			LayoutOrder = i,
			Parent = railList,
		})
		railButtons[name] = btn
	end
	UI.button("SETTINGS", "ghost", function()
		setTab("Settings")
	end, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 18, 1, -18),
		Size = UDim2.new(1, -36, 0, 36),
		FontFace = Theme.Font.Display,
		TextSize = Theme.TextSize.Label,
		Parent = rail,
	})

	-- Header: brush title, stickers, close.
	local header = UI.new("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(200, 0),
		Size = UDim2.new(1, -200, 0, 84),
		Parent = shell,
	}, { UI.padding(0, 26) })
	UI.splat(header, UDim2.fromOffset(150, 58), 120, C.Red, 3, { ZIndex = 1 })
	title = UI.brushTitle("ME", Theme.TextSize.Display, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 4),
		ZIndex = 2,
		Parent = header,
	})
	local right = UI.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 4),
		Size = UDim2.fromOffset(420, 56),
		Parent = header,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	cashSticker = UI.sticker("$0", C.Paper, C.Ink, { LayoutOrder = 1, Parent = right })
	bountySticker = UI.sticker("BOUNTY 0", C.Ink, C.Paper, { LayoutOrder = 2, Rotation = 2, Parent = right })
	UI.bigButton("X", "primary", function()
		Router.close()
	end, { Size = UDim2.fromOffset(56, 56), TextSize = Theme.TextSize.Title, LayoutOrder = 3, Parent = right })

	content = UI.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(200, 84),
		Size = UDim2.new(1, -200, 1, -84),
		ClipsDescendants = true,
		Parent = shell,
	}, { UI.padding(10, 26) })

	Router.register("Ledger", {
		open = open,
		close = close,
		setTab = function(tab: string)
			setTab(tab)
		end,
	})

	State.Changed:Connect(function(data)
		if isOpen then
			updateHeader(data)
			updateRail(data)
			render(false)
		end
	end)
end

return Ledger
