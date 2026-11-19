--!strict
-- BountyService: what a knockout is worth, and what being knocked out costs.
--  * onEnemyKO: Cash, XP and bounty scaled by enemy, boss, style, passes and
--    the server-wide Big Sale. Updates class mastery and the KO count.
--  * onPlayerKO: loses Config.BOUNTY_LOSS_ON_KO of bounty unless a Bounty
--    Shield is held. bestBounty never drops, so districts stay unlocked.
--  * Global leaderboard: OrderedDataStore of bestBounty, shown on an in-world
--    board on the store street.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local BountyService = {}

local deps: any = {}
local board: SurfaceGui? = nil
local lastWrite: { [Player]: number } = {}
local orderedStore: OrderedDataStore? = nil

local LEADERBOARD_REFRESH = 120
local WRITE_THROTTLE = 60

local function toast(player: Player, payload: any)
	Remotes.event("Toast"):FireClient(player, payload)
end

function BountyService.cashMult(player: Player): number
	local mult = 1
	if deps.Monetization.hasPass(player, "DoubleCash") then
		mult *= 2
	end
	local untilTime = Workspace:GetAttribute("BigSaleUntil")
	local stacks = Workspace:GetAttribute("BigSaleStacks")
	if typeof(untilTime) == "number" and untilTime > os.time() and typeof(stacks) == "number" then
		mult *= 1 + Config.BIG_SALE_MULT_PER_STACK * math.min(stacks, Config.BIG_SALE_MAX_STACKS)
	end
	return mult
end

function BountyService.xpMult(player: Player): number
	return if deps.Monetization.hasPass(player, "DoubleXP") then 2 else 1
end

function BountyService.addBounty(player: Player, amount: number)
	local data = deps.Data.get(player)
	if not data or amount <= 0 then
		return
	end
	local beforeTier = Config.bountyTier(data.bestBounty)
	data.bounty += math.floor(amount)
	if data.bounty > data.bestBounty then
		data.bestBounty = data.bounty
	end
	player:SetAttribute("Bounty", data.bounty)
	local afterTier, tierName = Config.bountyTier(data.bestBounty)
	if afterTier > beforeTier then
		toast(player, { kind = "reward", title = "Bounty rank up", body = tierName })
	end
	for _, def in Config.DISTRICTS do
		if def.bounty > 0 and data.bestBounty >= def.bounty and data.bestBounty - amount < def.bounty then
			toast(player, { kind = "info", title = "District open", body = def.name })
		end
	end
	deps.Data.changed(player)
end

export type KOCtx = { boss: boolean, class: string, thrown: boolean }

function BountyService.onEnemyKO(player: Player, def: Config.EnemyDef, ctx: KOCtx)
	local data = deps.Data.get(player)
	if not data then
		return
	end
	local style = deps.Combat.styleMult(player)
	local bossMult = if ctx.boss then Config.BOSS_REWARD_MULT else 1
	local cash = math.floor(def.cash * bossMult * style * BountyService.cashMult(player))
	local xp = math.floor(def.xp * bossMult * style)
	local bounty = math.floor(def.bounty * bossMult * style)

	data.kos += 1
	if data.mastery[ctx.class] ~= nil then
		data.mastery[ctx.class] += 1
	end
	deps.Progression.addCash(player, cash, "Gameplay", "Knockout")
	deps.Progression.addXp(player, xp * BountyService.xpMult(player), "Knockout")
	BountyService.addBounty(player, bounty)
	deps.Analytics.funnel(player, "FirstKO")

	Remotes.event("Banner"):FireClient(player, {
		kind = "Knockout",
		cash = cash,
		xp = xp,
		bounty = bounty,
		style = style,
		boss = ctx.boss,
	})
end

function BountyService.onPlayerKO(player: Player)
	local data = deps.Data.get(player)
	if not data then
		return
	end
	if data.tokens.BountyShield > 0 then
		data.tokens.BountyShield -= 1
		toast(player, { kind = "info", title = "Knocked out", body = "Bounty Shield used. Your bounty is safe." })
		deps.Data.changed(player)
		return
	end
	local loss = math.floor(data.bounty * Config.BOUNTY_LOSS_ON_KO)
	data.bounty -= loss
	player:SetAttribute("Bounty", data.bounty)
	toast(player, { kind = "error", title = "Knocked out", body = if loss > 0 then string.format("Bounty -%s. Back to the store.", Format.commas(loss)) else "Back to the store." })
	deps.Data.changed(player)
end

---------------------------------------------------------------------------
-- Leaderboard
---------------------------------------------------------------------------
local function buildBoard()
	local part = Instance.new("Part")
	part.Name = "BountyBoard"
	part.Anchored = true
	part.Size = Vector3.new(16, 20, 1)
	part.Color = Color3.fromRGB(243, 239, 230)
	part.Material = Enum.Material.SmoothPlastic
	part.CFrame = CFrame.new(-50, 10, Config.STORE_ROW_Z) * CFrame.Angles(0, math.rad(90), 0)
	local world = Workspace:FindFirstChild("World")
	part.Parent = world or Workspace

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(400, 500)
	gui.LightInfluence = 0
	gui.Parent = part
	board = gui
end

local function renderBoard(rows: { { name: string, value: number } })
	local gui = board
	if not gui then
		return
	end
	gui:ClearAllChildren()
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.Parent = gui
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 60)
	title.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	title.TextColor3 = Color3.fromRGB(243, 239, 230)
	title.FontFace = Font.new("rbxasset://fonts/families/Bangers.json")
	title.TextSize = 44
	title.Text = "MOST WANTED"
	title.Parent = gui
	for i, row in rows do
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, 40)
		label.BackgroundTransparency = 1
		label.TextColor3 = if i == 1 then Color3.fromRGB(215, 38, 30) else Color3.fromRGB(20, 20, 20)
		label.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
		label.TextSize = 22
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = string.format("  %02d  %-16s %s", i, string.sub(row.name, 1, 16), Format.commas(row.value))
		label.LayoutOrder = i
		label.Parent = gui
	end
end

local function refreshBoard()
	local ds = orderedStore
	if not ds then
		return
	end
	local ok, pages = pcall(function()
		return ds:GetSortedAsync(false, 10)
	end)
	if not ok or not pages then
		return
	end
	local rows = {}
	for _, entry in (pages :: any):GetCurrentPage() do
		local userId = tonumber(string.sub(entry.key, 3)) or 0
		local okName, name = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		table.insert(rows, { name = if okName then name else "Unknown", value = entry.value })
	end
	renderBoard(rows)
end

local function writeScore(player: Player)
	local ds = orderedStore
	local data = deps.Data.get(player)
	if not ds or not data or not deps.Data.canSave(player) then
		return
	end
	local value = math.floor(data.bestBounty)
	task.spawn(function()
		pcall(function()
			ds:SetAsync("u_" .. player.UserId, value)
		end)
	end)
end

function BountyService.init(dependencies: any)
	deps = dependencies
	local ok, ds = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.LEADERBOARD_DATASTORE_NAME)
	end)
	if ok then
		orderedStore = ds
	end
	buildBoard()
	renderBoard({})

	deps.Data.Loaded:Connect(function(player: Player, data: any)
		player:SetAttribute("Bounty", data.bounty)
	end)
	deps.Data.Changed:Connect(function(player: Player)
		local t = os.clock()
		if t - (lastWrite[player] or 0) >= WRITE_THROTTLE then
			lastWrite[player] = t
			writeScore(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		writeScore(player)
		lastWrite[player] = nil
	end)

	task.spawn(function()
		while true do
			refreshBoard()
			task.wait(LEADERBOARD_REFRESH)
		end
	end)
end

return BountyService
