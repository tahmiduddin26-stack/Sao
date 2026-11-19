--!strict
-- Hud: always-on screen elements, drawn as comic panels with ink shadows.
--  * Player panel (top left): name, level badge, HP, Focus. While Serious the
--    Focus bar is a red countdown; a red "R" pops up when Focus is full.
--  * Stickers under it: Cash and bounty. Big CLAIM / GIFT buttons when ready.
--  * Area title (top right): a brush-stroke label of where you are, plus MENU.
--  * Job panel (right): your first tracked Job, one line and a bar.
--  * Hands panel (bottom centre): what you are holding, durability pips and
--    key caps for what you can do with it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Quests = require(Shared.Quests)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.UI.Theme)
local UI = require(script.Parent.UI.UI)
local Router = require(script.Parent.UI.Router)
local State = require(script.Parent.State)

local C = Theme.Color
local player = Players.LocalPlayer

local Hud = {}

local questById: { [string]: any } = {}
for _, q in Quests do
	questById[q.id] = q
end

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

---------------------------------------------------------------------------
-- Player panel
---------------------------------------------------------------------------
local nameLabel: TextLabel
local levelBadge: TextLabel
local hpBar: UI.Bar
local hpText: TextLabel
local focusBar: UI.Bar
local focusLabel: TextLabel
local seriousKey: TextLabel

local function buildPlayer(root: Frame)
	local panel = UI.panel({
		Name = "PlayerPanel",
		Position = UDim2.fromOffset(24, 24),
		Size = UDim2.fromOffset(330, 108),
		Parent = root,
	}, { tone = "TR" })

	levelBadge = UI.text("1", "display", Theme.TextSize.Title, {
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.fromOffset(44, 44),
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundColor3 = C.Red,
		BackgroundTransparency = 0,
		TextColor3 = C.Paper,
		Rotation = -4,
		Parent = panel,
	}, nil)
	UI.stroke(C.Line).Parent = levelBadge
	nameLabel = UI.text(string.upper(player.DisplayName), "display", Theme.TextSize.Heading, {
		Position = UDim2.fromOffset(66, 10),
		Size = UDim2.new(1, -78, 0, 26),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = panel,
	})

	hpBar = UI.bar(C.Ink, 16, true, { Position = UDim2.fromOffset(66, 40), Size = UDim2.new(1, -150, 0, 16), Parent = panel })
	UI.stroke(C.Line).Parent = hpBar.frame
	hpText = UI.text("0", "monoBold", Theme.TextSize.Caption, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 38),
		Size = UDim2.fromOffset(72, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = panel,
	})

	focusBar = UI.bar(C.Red, 14, false, { Position = UDim2.fromOffset(66, 70), Size = UDim2.new(1, -150, 0, 14), Parent = panel })
	UI.stroke(C.Line).Parent = focusBar.frame
	focusBar.set(0, true)
	focusLabel = UI.text("FOCUS", "display", Theme.TextSize.Body, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 66),
		Size = UDim2.fromOffset(72, 22),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = panel,
	})
	UI.text("HP", "display", Theme.TextSize.Caption, { Position = UDim2.fromOffset(16, 62), Size = UDim2.fromOffset(40, 18), Parent = panel })

	-- "R" pops out of the panel edge when Serious is ready.
	seriousKey = UI.text("R!", "display", Theme.TextSize.Title, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, 4, 1, 0),
		Size = UDim2.fromOffset(52, 52),
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundColor3 = C.Red,
		BackgroundTransparency = 0,
		TextColor3 = C.Paper,
		Rotation = 8,
		Visible = false,
		ZIndex = 3,
		Parent = panel,
	})
	UI.stroke(C.Line).Parent = seriousKey
end

local humanoidConns: { RBXScriptConnection } = {}

local function updateHp(humanoid: Humanoid, instant: boolean?)
	local max = math.max(1, humanoid.MaxHealth)
	local hp = math.max(0, humanoid.Health)
	local ratio = hp / max
	hpBar.set(ratio, instant)
	hpBar.setColor(if ratio <= 0.3 then C.Danger else C.Ink)
	hpText.Text = Format.commas(math.ceil(hp))
end

local function bindCharacter(character: Model)
	for _, c in humanoidConns do
		c:Disconnect()
	end
	table.clear(humanoidConns)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	local h = humanoid :: Humanoid
	updateHp(h, true)
	table.insert(humanoidConns, h:GetPropertyChangedSignal("Health"):Connect(function()
		updateHp(h)
	end))
	table.insert(humanoidConns, h:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		updateHp(h)
	end))
end

local function updateFocus()
	local untilTime = player:GetAttribute("SeriousUntil")
	local remaining = if typeof(untilTime) == "number" then untilTime - serverNow() else 0
	if remaining > 0 then
		focusBar.set(remaining / Config.SERIOUS_SECONDS, true)
		focusLabel.Text = string.format("%d", math.ceil(remaining))
		focusLabel.TextColor3 = C.Red
		seriousKey.Visible = false
		return
	end
	local focus = (player:GetAttribute("Focus") :: number?) or 0
	focusBar.set(focus / Config.FOCUS_MAX)
	local full = focus >= Config.FOCUS_MAX
	focusLabel.Text = if full then "READY!" else "FOCUS"
	focusLabel.TextColor3 = if full then C.Red else C.Ink
	seriousKey.Visible = full
end

---------------------------------------------------------------------------
-- Stickers and reward buttons
---------------------------------------------------------------------------
local cashSticker: TextLabel
local bountySticker: TextLabel
local dailyButton: TextButton
local giftButton: TextButton
local saleSticker: TextLabel
local nextGiftIndex: number? = nil
local giftReady = false

local function today(): number
	return math.floor(os.time() / 86400)
end

local function buildStickers(root: Frame)
	local column = UI.new("Frame", {
		Name = "Stickers",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(28, 146),
		Size = UDim2.fromOffset(330, 240),
		Parent = root,
	}, { UI.list(Enum.FillDirection.Vertical, 10) })

	local money = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(330, 34), LayoutOrder = 1, Parent = column }, {
		UI.list(Enum.FillDirection.Horizontal, 10),
	})
	cashSticker = UI.sticker("$0", C.Paper, C.Ink, { LayoutOrder = 1, Parent = money })
	bountySticker = UI.sticker("BOUNTY 0", C.Ink, C.Paper, { LayoutOrder = 2, Rotation = 2, Parent = money })

	dailyButton = UI.bigButton("DAILY REWARD!", "primary", function()
		Remotes.event("ClaimDaily"):FireServer()
	end, { Size = UDim2.fromOffset(220, 50), LayoutOrder = 2, Visible = false, Parent = column })

	giftButton = UI.bigButton("GIFT", "secondary", function()
		if nextGiftIndex and giftReady then
			Remotes.event("ClaimGift"):FireServer(nextGiftIndex)
		end
	end, { Size = UDim2.fromOffset(220, 50), LayoutOrder = 3, Visible = false, Parent = column })

	saleSticker = UI.sticker("", C.Red, C.Paper, { LayoutOrder = 4, Visible = false, Parent = column })
end

local function updateMoney(data: any)
	cashSticker.Text = Config.CURRENCY_CODE .. Format.commas(data.cash or 0)
	bountySticker.Text = "BOUNTY " .. Format.commas(data.bounty or 0)
end

local function updateGifts()
	local started = player:GetAttribute("SessionStart")
	local mask = (player:GetAttribute("GiftsClaimed") :: number?) or 0
	if typeof(started) ~= "number" then
		UI.show(giftButton, false)
		return
	end
	nextGiftIndex = nil
	for i in Config.PLAYTIME_GIFTS do
		if math.floor(mask / 2 ^ (i - 1)) % 2 == 0 then
			nextGiftIndex = i
			break
		end
	end
	if not nextGiftIndex then
		UI.show(giftButton, false)
		return
	end
	local gift = Config.PLAYTIME_GIFTS[nextGiftIndex]
	local remaining = gift.minutes * 60 - (serverNow() - started)
	UI.show(giftButton, true)
	giftReady = remaining <= 0
	if giftReady then
		giftButton.Text = "OPEN GIFT!"
		giftButton.BackgroundColor3 = C.Red
		giftButton.TextColor3 = C.Paper
	else
		giftButton.Text = "GIFT IN " .. Format.clock(remaining)
		giftButton.BackgroundColor3 = C.Paper
		giftButton.TextColor3 = C.Ink
	end
end

local function updateSale()
	local untilTime = Workspace:GetAttribute("BigSaleUntil")
	local stacks = Workspace:GetAttribute("BigSaleStacks")
	local remaining = if typeof(untilTime) == "number" then untilTime - os.time() else 0
	if remaining > 0 and typeof(stacks) == "number" then
		local mult = 1 + Config.BIG_SALE_MULT_PER_STACK * math.min(stacks, Config.BIG_SALE_MAX_STACKS)
		saleSticker.Text = string.format("BIG SALE x%d CASH  %s", mult, Format.clock(remaining))
		saleSticker.Visible = true
	else
		saleSticker.Visible = false
	end
end

---------------------------------------------------------------------------
-- Area title and menu button
---------------------------------------------------------------------------
local areaTitle: Frame

local function buildArea(root: Frame)
	UI.bigButton("MENU", "secondary", function()
		Router.toggle("Ledger")
	end, {
		Name = "MenuButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 24),
		Size = UDim2.fromOffset(110, 56),
		TextSize = Theme.TextSize.Title,
		Parent = root,
	})
	areaTitle = UI.brushTitle("Your store", Theme.TextSize.Title, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -150, 0, 30),
		Parent = root,
	})
end

local function updateArea()
	local area = player:GetAttribute("Area")
	if area == "Store" or area == nil then
		UI.setBrushText(areaTitle, "Your store")
		return
	end
	local def = Config.getDistrict(area :: string)
	UI.setBrushText(areaTitle, if def then def.name else tostring(area))
end

---------------------------------------------------------------------------
-- Job panel: the first tracked Job, one line and a bar.
---------------------------------------------------------------------------
local jobPanel: Frame
local jobName: TextLabel
local jobStep: TextLabel
local jobBar: UI.Bar

local function buildJob(root: Frame)
	jobPanel = UI.panel({
		Name = "Job",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 100),
		Size = UDim2.fromOffset(300, 104),
		Visible = false,
		Parent = root,
	})
	UI.text("JOB", "monoBold", Theme.TextSize.Caption, { Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(60, 16), TextColor3 = C.Red, Parent = jobPanel })
	jobName = UI.text("", "display", Theme.TextSize.Heading, {
		Position = UDim2.fromOffset(12, 22),
		Size = UDim2.new(1, -24, 0, 26),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = jobPanel,
	})
	jobStep = UI.text("", "bold", Theme.TextSize.Body, {
		Position = UDim2.fromOffset(12, 48),
		Size = UDim2.new(1, -24, 0, 22),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = jobPanel,
	})
	jobBar = UI.bar(C.Red, 10, false, { Position = UDim2.fromOffset(12, 76), Size = UDim2.new(1, -24, 0, 10), Parent = jobPanel })
	UI.stroke(C.Line).Parent = jobBar.frame
end

local function updateJob(data: any)
	local shown = false
	for _, questId in data.tracked or {} do
		local q = questById[questId]
		local s = data.quests and data.quests[questId]
		if q and s and s.state == "active" then
			local step = q.steps[s.step]
			local needed = step and step.count or 1
			jobName.Text = string.upper(q.name)
			jobStep.Text = if step then (if needed > 1 then string.format("%s  %d/%d", step.text, s.progress or 0, needed) else step.text) else ""
			jobBar.set(((s.step - 1) + (s.progress or 0) / needed) / #q.steps, true)
			shown = true
			break
		end
	end
	UI.show(jobPanel, shown and not Router.isOpen())
end

---------------------------------------------------------------------------
-- Hands panel
---------------------------------------------------------------------------
local handsName: TextLabel
local handsPips: Frame
local handsKeys: Frame
local handsHolder: Frame

local function buildHands(root: Frame)
	local panel = UI.panel({
		Name = "Hands",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.fromOffset(380, 92),
		Parent = root,
	}, { tone = "BL" })
	handsHolder = panel
	handsName = UI.text("FISTS", "display", Theme.TextSize.Title, {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = panel,
	})
	handsPips = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(40, 40), Size = UDim2.new(1, -80, 0, 12), Parent = panel })
	handsKeys = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 60), Size = UDim2.new(1, -28, 0, 22), Parent = panel })
end

local function updateHands()
	local id = player:GetAttribute("Holding")
	local def = if typeof(id) == "string" then Config.PROPS[id] else nil
	UI.clear(handsPips)
	UI.clear(handsKeys)
	if not def then
		handsName.Text = "FISTS"
		local hints = UI.keyHints({ { "CLICK", "PUNCH" }, { "E", "GRAB STUFF" } }, { Parent = handsKeys })
		hints:FindFirstChildOfClass("UIListLayout").HorizontalAlignment = Enum.HorizontalAlignment.Center
		return
	end
	handsName.Text = string.upper(def.name) .. (if player:GetAttribute("Sling") then "  +SLING" else "")
	local dur = (player:GetAttribute("HeldDurability") :: number?) or def.durability
	local pips = math.min(def.durability, 10)
	local filled = math.ceil(dur / math.max(1, def.durability) * pips)
	UI.pips(pips, filled, if filled <= 2 then C.Red else C.Ink, { Size = UDim2.fromScale(1, 1), Parent = handsPips })
	local hints = UI.keyHints({ { "CLICK", "HIT" }, { "Q", "THROW" }, { "E", "DROP" } }, { Parent = handsKeys })
	hints:FindFirstChildOfClass("UIListLayout").HorizontalAlignment = Enum.HorizontalAlignment.Center
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------
function Hud.init(root: Frame)
	local hud = UI.new("Frame", { Name = "Hud", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = root })
	buildPlayer(hud)
	buildStickers(hud)
	buildArea(hud)
	buildJob(hud)
	buildHands(hud)

	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end
	player.CharacterAdded:Connect(bindCharacter)

	for _, attr in { "Holding", "HeldDurability", "Sling" } do
		player:GetAttributeChangedSignal(attr):Connect(updateHands)
	end
	player:GetAttributeChangedSignal("Area"):Connect(updateArea)
	updateHands()
	updateArea()

	State.observe(function(data)
		levelBadge.Text = tostring(data.level or 1)
		nameLabel.Text = string.upper(player.DisplayName)
		UI.show(dailyButton, data.daily ~= nil and data.daily.lastDay ~= today())
		updateMoney(data)
		updateJob(data)
	end)

	Router.Changed:Connect(function(open)
		if open then
			UI.show(jobPanel, false)
		elseif State.data then
			updateJob(State.data)
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		updateFocus()
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		updateGifts()
		updateSale()
	end)
end

return Hud
