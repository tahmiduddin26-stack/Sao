--!strict
-- Hud: always-on screen elements (plan 24).
--  * Player plate (top left): name, level, HP with numbers, SP in 4 segments, thin MP bar.
--  * Minimap (top right): floor code in mono, town name, player dot.
--  * Menu button (top right, also the touch entry to the Ledger).
--  * Quest tracker (right): two tracked quests at most.
--  * Daily streak and server blessing chips under the plate.
-- The skill bar, Connect ring, party frames and boss bar arrive with combat.

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
local Motion = require(script.Parent.UI.Motion)
local Router = require(script.Parent.UI.Router)
local State = require(script.Parent.State)

local C = Theme.Color
local player = Players.LocalPlayer

local Hud = {}

local questById: { [string]: any } = {}
for _, q in Quests do
	questById[q.id] = q
end

---------------------------------------------------------------------------
-- Player plate
---------------------------------------------------------------------------
local plate: Frame
local nameLabel: TextLabel
local levelLabel: TextLabel
local hpBar: UI.Bar
local hpText: TextLabel
local setSp: (number) -> ()
local mpBar: UI.Bar

local function buildPlate(root: Frame)
	plate = UI.plate({
		Name = "PlayerPlate",
		Position = UDim2.fromOffset(24, 24),
		Size = UDim2.fromOffset(300, 86),
		Parent = root,
	}, { UI.padding(10, 12) })

	nameLabel = UI.text(player.DisplayName, "bold", Theme.TextSize.Label, {
		Size = UDim2.new(1, -70, 0, 20),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = plate,
	})
	levelLabel = UI.text("LV 1", "mono", Theme.TextSize.Caption, {
		Size = UDim2.fromOffset(70, 20),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTransparency = 0.2,
		Parent = plate,
	})

	hpBar = UI.bar(C.Vigor, 8, true, { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, -96, 0, 8), Parent = plate })
	hpText = UI.text("0/0", "mono", Theme.TextSize.Caption, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 20),
		Size = UDim2.fromOffset(90, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = plate,
	})

	local _, setter = UI.segments(Config.SP_SEGMENTS, C.Lantern, 4, { Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, -96, 0, 4), Parent = plate })
	setSp = setter
	UI.text("SP", "mono", Theme.TextSize.Caption, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 34),
		Size = UDim2.fromOffset(40, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTransparency = Theme.TextDim,
		Parent = plate,
	})

	mpBar = UI.bar(C.Tide, 3, false, { Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, -96, 0, 3), Parent = plate })
	UI.text("MP", "mono", Theme.TextSize.Caption, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 48),
		Size = UDim2.fromOffset(40, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTransparency = Theme.TextDim,
		Parent = plate,
	})
end

local humanoidConns: { RBXScriptConnection } = {}

local function updateHp(humanoid: Humanoid, instant: boolean?)
	local max = math.max(1, humanoid.MaxHealth)
	local hp = math.max(0, humanoid.Health)
	local ratio = hp / max
	hpBar.set(ratio, instant)
	hpBar.setColor(if ratio <= 0.3 then C.Ember else C.Vigor)
	hpText.Text = string.format("%s/%s", Format.commas(math.ceil(hp)), Format.commas(math.ceil(max)))
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

local function updateResources()
	local sp = player:GetAttribute("SP")
	setSp(if typeof(sp) == "number" then sp else Config.SP_SEGMENTS)
	local mp = player:GetAttribute("MP")
	local maxMp = player:GetAttribute("MaxMP")
	if typeof(mp) == "number" and typeof(maxMp) == "number" and maxMp > 0 then
		mpBar.set(mp / maxMp)
	end
end

---------------------------------------------------------------------------
-- Chips under the plate: daily streak, server blessing
---------------------------------------------------------------------------
local dailyChip: Frame
local dailyText: TextLabel
local blessingChip: TextLabel

local function today(): number
	return math.floor(os.time() / 86400)
end

local function buildChips(root: Frame)
	local column = UI.new("Frame", {
		Name = "Chips",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(24, 118),
		Size = UDim2.fromOffset(300, 120),
		Parent = root,
	}, { UI.list(Enum.FillDirection.Vertical, 6) })

	dailyChip = UI.plate({
		Name = "Daily",
		Size = UDim2.fromOffset(300, 44),
		Visible = false,
		LayoutOrder = 1,
		Parent = column,
	}, { UI.padding(0, 12) })
	dailyText = UI.text("Daily streak ready", "body", Theme.TextSize.Body, { Size = UDim2.new(1, -90, 1, 0), Parent = dailyChip })
	UI.button("Claim", "primary", function()
		Remotes.event("ClaimDaily"):FireServer()
	end, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(80, 30),
		Parent = dailyChip,
	})

	blessingChip = UI.chip("", C.Lantern, { Visible = false, LayoutOrder = 2, Parent = column })
end

local function updateBlessing()
	local untilTime = Workspace:GetAttribute("BlessingUntil")
	local stacks = Workspace:GetAttribute("BlessingStacks")
	local remaining = if typeof(untilTime) == "number" then untilTime - os.time() else 0
	if remaining > 0 and typeof(stacks) == "number" then
		local mult = 1 + Config.BLESSING_XP_MULT_PER_STACK * math.min(stacks, Config.BLESSING_MAX_STACKS)
		blessingChip.Text = string.format("XP x%.2f  %s", mult, Format.clock(remaining))
		blessingChip.Visible = true
	else
		blessingChip.Visible = false
	end
end

---------------------------------------------------------------------------
-- Minimap and menu button
---------------------------------------------------------------------------
local floorCodeLabel: TextLabel
local townLabel: TextLabel
local dot: Frame

local function buildMinimap(root: Frame)
	local map = UI.plate({
		Name = "Minimap",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 24),
		Size = UDim2.fromOffset(200, 150),
		Parent = root,
	}, { UI.padding(8) })
	local field = UI.block(C.Ink, { Name = "Field", Size = UDim2.new(1, 0, 1, -24), BackgroundTransparency = 0.2, ClipsDescendants = true, Parent = map })
	-- Town plaza marker and labyrinth gate (lantern) for orientation.
	UI.block(C.Rule, { Name = "Plaza", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(16, 16), Parent = field })
	UI.new("Frame", {
		Name = "Labyrinth",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.12),
		Size = UDim2.fromOffset(10, 10),
		Parent = field,
	}, { UI.stroke(C.Lantern) })
	dot = UI.block(C.Bone, { Name = "Player", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(5, 5), Position = UDim2.fromScale(0.5, 0.5), Parent = field })

	floorCodeLabel = UI.text("F01", "monoBold", Theme.TextSize.Caption, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(0.4, 0, 0, 18),
		TextColor3 = C.Lantern,
		Parent = map,
	})
	townLabel = UI.text("", "body", Theme.TextSize.Caption, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.new(0.6, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = map,
	})

	-- Menu button: 44px touch target. Three hairlines as the icon.
	local menu = UI.button("", "ghost", function()
		Router.toggle("Ledger")
	end, {
		Name = "MenuButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -232, 0, 24),
		Size = UDim2.fromOffset(Theme.TouchMin, Theme.TouchMin),
		BackgroundColor3 = C.Steel,
		BackgroundTransparency = Theme.panelTransparency(),
		Parent = root,
	})
	UI.stroke(C.Rule).Parent = menu
	for i = 0, 2 do
		UI.block(C.Bone, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, (i - 1) * 6),
			Size = UDim2.fromOffset(16, 2),
			Parent = menu,
		})
	end
end

local function updateMinimap(data: any)
	local floorId = data.currentFloor or 1
	local def = Config.getFloor(floorId)
	floorCodeLabel.Text = Config.floorCode(floorId)
	townLabel.Text = def and def.town or ""
end

local function updateDot()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local data = State.data
	if not root or not data then
		return
	end
	local def = Config.getFloor(data.currentFloor or 1)
	if not def then
		return
	end
	local origin = Vector3.new((def.id - 1) * Config.FLOOR_SPACING, 0, 0)
	local rel = root.Position - origin
	local x = math.clamp(0.5 + rel.X / def.size.X, 0, 1)
	local y = math.clamp(0.5 + rel.Z / def.size.Y, 0, 1)
	dot.Position = UDim2.fromScale(x, y)
end

---------------------------------------------------------------------------
-- Quest tracker
---------------------------------------------------------------------------
local tracker: Frame
local trackerList: Frame

local function buildTracker(root: Frame)
	tracker = UI.plate({
		Name = "Tracker",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 186),
		Size = UDim2.fromOffset(280, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = root,
	}, { UI.padding(10, 12), UI.list(Enum.FillDirection.Vertical, 6) })
	UI.caption("Tracked", { LayoutOrder = 0, Parent = tracker })
	trackerList = UI.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = tracker,
	}, { UI.list(Enum.FillDirection.Vertical, 8) })
end

local function updateTracker(data: any)
	UI.clear(trackerList)
	local shown = 0
	for i, questId in data.tracked or {} do
		local q = questById[questId]
		local s = data.quests and data.quests[questId]
		if q and s and s.state == "active" then
			shown += 1
			local step = q.steps[s.step]
			local entry = UI.new("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = i,
				Parent = trackerList,
			}, { UI.list(Enum.FillDirection.Vertical, 0) })
			UI.text(q.name, "bold", Theme.TextSize.Body, { LayoutOrder = 1, TextTruncate = Enum.TextTruncate.AtEnd, Parent = entry })
			if step then
				local needed = step.count or 1
				local progress = if needed > 1 then string.format("  %d/%d", s.progress or 0, needed) else ""
				UI.paragraph(step.text .. progress, {
					LayoutOrder = 2,
					TextSize = Theme.TextSize.Caption,
					TextTransparency = Theme.TextDim,
					Parent = entry,
				})
			end
		end
	end
	tracker.Visible = shown > 0 and not Router.isOpen()
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------
function Hud.init(root: Frame)
	local hud = UI.new("Frame", { Name = "Hud", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = root })
	buildPlate(hud)
	buildChips(hud)
	buildMinimap(hud)
	buildTracker(hud)

	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end
	player.CharacterAdded:Connect(bindCharacter)

	for _, attr in { "SP", "MP", "MaxMP" } do
		player:GetAttributeChangedSignal(attr):Connect(updateResources)
	end
	updateResources()

	State.observe(function(data)
		levelLabel.Text = "LV " .. tostring(data.level or 1)
		nameLabel.Text = if data.activeTitle and data.activeTitle ~= "" then player.DisplayName .. "  " .. data.activeTitle else player.DisplayName
		local claimable = data.daily and data.daily.lastDay ~= today()
		dailyChip.Visible = claimable == true
		if claimable then
			dailyText.Text = string.format("Day %d streak ready", ((data.daily.lastDay == today() - 1) and data.daily.streak or 0) + 1)
		end
		updateMinimap(data)
		updateTracker(data)
	end)

	-- Hide the tracker while a menu is open so the Ledger reads cleanly.
	Router.Changed:Connect(function(open)
		if open then
			tracker.Visible = false
		elseif State.data then
			updateTracker(State.data)
			if tracker.Visible then
				Motion.enter(tracker, "small", Theme.Motion.quick)
			end
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		updateDot()
		updateBlessing()
	end)
end

return Hud
