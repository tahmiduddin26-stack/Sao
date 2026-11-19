--!strict
-- Ledger: the one menu shell (plan 25). Slides in from the right, same rail of
-- tabs on the left, same header with currency and close, and a content area.
-- Only one tab is open at a time; opening another swaps the content, not the shell.
-- Each tab module exports { title, render(content, data, ctx), unread?(data) }.

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

local TAB_ORDER = { "Character", "Skills", "Bag", "Quests", "Map", "Party", "Guild", "Shop", "Settings" }
local tabs: { [string]: Tab } = {}
for _, name in TAB_ORDER do
	tabs[name] = require(script:WaitForChild(name)) :: any
end

local scrim: TextButton
local shell: Frame
local railButtons: { [string]: TextButton } = {}
local titleLabel: TextLabel
local goldChip: TextLabel
local crystalChip: TextLabel
local content: Frame
local currentTab = "Character"
local isOpen = false
local scrollMemory: { [string]: Vector2 } = {}
local liveScrolls: { [string]: ScrollingFrame } = {}
local funnelSent = false

local function hex(c: Color3): string
	return "#" .. c:ToHex()
end

local ctx: Ctx

local function render(animate: boolean)
	-- Remember scroll positions before the content is rebuilt.
	for key, sf in liveScrolls do
		if sf.Parent then
			scrollMemory[key] = sf.CanvasPosition
		end
	end
	table.clear(liveScrolls)

	UI.clear(content)
	local tab = tabs[currentTab]
	titleLabel.Text = string.upper(tab and tab.title or currentTab)
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
		UI.setTabSelected(btn, name == currentTab)
		local tab = tabs[name]
		local unread = data ~= nil and tab.unread ~= nil and tab.unread(data)
		local marker = btn:FindFirstChild("Unread")
		if unread and not marker then
			UI.unread({ Parent = btn })
		elseif not unread and marker then
			marker:Destroy()
		end
	end
end

local function updateHeader(data: any)
	goldChip.Text = string.format('<font color="%s">%s</font> %s', hex(C.Lantern), Config.CURRENCY_CODE, Format.commas(data.gold or 0))
	crystalChip.Text = string.format("%s %s", Config.MATERIALS.Crystal.code, Format.commas((data.materials and data.materials.Crystal) or 0))
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
	Motion.enter(shell, "panel", Theme.Motion.base)
	Motion.enter(content, "up", Theme.Motion.base, 0.08)
	UI.focusFirst(shell)

	if not funnelSent then
		funnelSent = true
		Remotes.event("FunnelStep"):FireServer("OpenedLedger")
	end
end

local function close()
	isOpen = false
	-- Exits are faster than entrances and never stagger.
	Motion.exit(shell, "panel", Theme.Motion.base)
	Motion.exit(scrim, "fade", Theme.Motion.quick)
	local GuiService = game:GetService("GuiService")
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(shell) then
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
			Router.open("Ledger", name)
		end,
	}

	scrim = UI.new("TextButton", {
		Name = "LedgerScrim",
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.45,
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

	shell = UI.plate({
		Name = "Ledger",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -40, 0.5, 0),
		Size = UDim2.fromOffset(920, 560),
		Visible = false,
		ZIndex = 11,
		Parent = root,
	})
	shell.SelectionGroup = true

	-- Rail
	local rail = UI.new("Frame", {
		Name = "Rail",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 170, 1, 0),
		Parent = shell,
	})
	UI.block(C.Rule, { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), Parent = rail })
	UI.text("LEDGER", "display", Theme.TextSize.Caption, {
		Position = UDim2.fromOffset(18, 18),
		Size = UDim2.new(1, -18, 0, 20),
		TextTransparency = Theme.TextDim,
		Parent = rail,
	})
	local railList = UI.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, -1, 1, -56),
		Parent = rail,
	}, { UI.list(Enum.FillDirection.Vertical, 2) })
	for i, name in TAB_ORDER do
		local btn = UI.tab(tabs[name].title, function()
			setTab(name)
			Router.noteTab(name)
		end, { LayoutOrder = i, Parent = railList })
		railButtons[name] = btn
	end

	-- Header
	local header = UI.new("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(170, 0),
		Size = UDim2.new(1, -170, 0, 60),
		Parent = shell,
	}, { UI.padding(0, 22) })
	UI.rule({ Position = UDim2.new(0, -22, 1, -1), Size = UDim2.new(1, 44, 0, 1), Parent = header })
	titleLabel = UI.text("CHARACTER", "display", Theme.TextSize.Title, { Size = UDim2.new(0.5, 0, 1, 0), Parent = header })
	local chips = UI.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(360, 30),
		Parent = header,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	goldChip = UI.chip("G 0", nil, { RichText = true, LayoutOrder = 1, Parent = chips })
	crystalChip = UI.chip("CRYS 0", nil, { LayoutOrder = 2, Parent = chips })
	UI.button("ESC", "secondary", function()
		Router.close()
	end, {
		FontFace = Theme.Font.Mono,
		TextSize = Theme.TextSize.Caption,
		Size = UDim2.fromOffset(46, 26),
		LayoutOrder = 3,
		Parent = chips,
	})

	-- Content
	content = UI.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(170, 60),
		Size = UDim2.new(1, -170, 1, -60),
		ClipsDescendants = true,
		Parent = shell,
	})

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
