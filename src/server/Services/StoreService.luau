--!strict
-- StoreService: every player's corner store (home base and idle loop).
--  * Claims a plot from WorldBuilder and builds the store in code.
--  * Shelves show their stock as real props the owner can grab and fight with;
--    grabbing one uses up stock. Restock at the shelf (G) for Cash.
--  * Customers walk in, take something off a stocked shelf and queue at the
--    counter; ring them up for Cash. Some customers are assassins. The tell:
--    assassins carry no basket and walk straight to the counter.
--  * A pen always sits on the counter, so a new player's first fight has a weapon.
--  * Upgrades raise the store level: faster customers, bigger sales, more shelves.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local RateLimit = require(Shared.RateLimit)
local Stats = require(Shared.Stats)

local StoreService = {}

local deps: any = {}

type ShelfState = { def: any, frame: CFrame, part: BasePart, tag: BasePart, props: { BasePart } }
type Store = {
	player: Player,
	plotIndex: number,
	model: Model,
	origin: CFrame,
	shelves: { [string]: ShelfState },
	customers: { Model },
	counterPen: BasePart?,
	penTakenAt: number?,
	nextCustomer: number,
	firstAssassinDone: boolean,
}

local stores: { [Player]: Store } = {}
local plotTaken: { [number]: Player } = {}

local LUCKY_POOL = { "frying_pan", "coat_rack", "umbrella", "ruler", "cart", "vending_door" }
local SHELF_X = { -18, -9, 0, 9, 18 }
local SLOT_X = { -2, 0, 2 }
local BOARD_Y = { 1.6, 3.6 }

local function toast(player: Player, payload: any)
	Remotes.event("Toast"):FireClient(player, payload)
end

local function local3(store: Store, x: number, y: number, z: number): CFrame
	return store.origin * CFrame.new(x, y, z)
end

local function part(props: { [string]: any }, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function shelfUnlocked(data: any, shelfDef: any): boolean
	return (data.store.level or 0) >= shelfDef.unlockLevel or data.unlocks["shelf:" .. shelfDef.key] == true
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
local function buildShell(store: Store)
	local size = Config.STORE_SIZE
	local m = store.model
	local wall = Color3.fromRGB(236, 230, 218)
	part({ Name = "Floor", Size = Vector3.new(size.X, 1, size.Z), CFrame = local3(store, 0, 0.5, 0), Color = Color3.fromRGB(205, 200, 190), Material = Enum.Material.Marble }, m)
	part({ Name = "BackWall", Size = Vector3.new(size.X, size.Y, 1), CFrame = local3(store, 0, size.Y / 2, -size.Z / 2), Color = wall }, m)
	part({ Name = "LeftWall", Size = Vector3.new(1, size.Y, size.Z), CFrame = local3(store, -size.X / 2, size.Y / 2, 0), Color = wall }, m)
	part({ Name = "RightWall", Size = Vector3.new(1, size.Y, size.Z), CFrame = local3(store, size.X / 2, size.Y / 2, 0), Color = wall }, m)
	local door = 12
	local side = (size.X - door) / 2
	part({ Name = "FrontLeft", Size = Vector3.new(side, size.Y, 1), CFrame = local3(store, -(door / 2 + side / 2), size.Y / 2, size.Z / 2), Color = wall }, m)
	part({ Name = "FrontRight", Size = Vector3.new(side, size.Y, 1), CFrame = local3(store, door / 2 + side / 2, size.Y / 2, size.Z / 2), Color = wall }, m)
	part({ Name = "Lintel", Size = Vector3.new(door, 3, 1), CFrame = local3(store, 0, size.Y - 1.5, size.Z / 2), Color = wall }, m)
	part({ Name = "Roof", Size = Vector3.new(size.X + 2, 1, size.Z + 2), CFrame = local3(store, 0, size.Y + 0.5, 0), Color = Color3.fromRGB(40, 40, 44), Transparency = 0.6, CanQuery = false }, m)

	-- Counter with register, and the spot the pen lives.
	part({ Name = "Counter", Size = Vector3.new(14, 4, 3), CFrame = local3(store, 0, 2.5, -11), Color = Color3.fromRGB(120, 90, 60), Material = Enum.Material.Wood }, m)
	local register = part({ Name = "Register", Size = Vector3.new(2, 1.4, 1.6), CFrame = local3(store, -3, 5.2, -11), Color = Color3.fromRGB(30, 30, 30) }, m)
	register:SetAttribute("Register", true)

	-- Sign over the door: store name and owner.
	local sign = part({ Name = "Sign", Size = Vector3.new(16, 3, 0.5), CFrame = local3(store, 0, size.Y + 2.5, size.Z / 2 + 0.5), Color = Color3.fromRGB(20, 20, 20) }, m)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(512, 96)
	gui.LightInfluence = 0
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Name = "Name"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(243, 239, 230)
	label.FontFace = Font.new("rbxasset://fonts/families/Bangers.json")
	label.TextScaled = true
	label.Parent = gui
end

local function updateSign(store: Store)
	local data = deps.Data.get(store.player)
	local sign = store.model:FindFirstChild("Sign")
	local label = sign and sign:FindFirstChild("SurfaceGui") and (sign :: any).SurfaceGui:FindFirstChild("Name")
	if data and label then
		label.Text = string.upper(store.player.DisplayName .. "'s " .. Stats.storeLevel(data).name)
	end
end

local function buildShelves(store: Store)
	for i, shelfDef in Config.SHELVES do
		local x = SHELF_X[i] or 0
		local frame = local3(store, x, 0, 3)
		local base = part({ Name = "Shelf_" .. shelfDef.key, Size = Vector3.new(7, 5, 0.6), CFrame = frame * CFrame.new(0, 3, -1), Color = Color3.fromRGB(70, 70, 76) }, store.model)
		for _, y in BOARD_Y do
			part({ Name = "Board", Size = Vector3.new(7, 0.3, 2.2), CFrame = frame * CFrame.new(0, y + 1, 0), Color = Color3.fromRGB(90, 90, 98) }, store.model)
		end
		local tag = part({ Name = "ShelfTag", Size = Vector3.new(4, 0.8, 0.2), CFrame = frame * CFrame.new(0, 0.9, 1.2), Color = Color3.fromRGB(243, 239, 230) }, store.model)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(200, 40)
		gui.LightInfluence = 0
		gui.Parent = tag
		local text = Instance.new("TextLabel")
		text.Name = "Text"
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.TextScaled = true
		text.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
		text.TextColor3 = Color3.fromRGB(20, 20, 20)
		text.Parent = gui

		local state: ShelfState = { def = shelfDef, frame = frame, part = base, tag = tag, props = {} }
		store.shelves[shelfDef.key] = state
		deps.World.addPrompt(base, "Restock", shelfDef.key, function(player: Player)
			if player == store.player then
				StoreService.restock(player, shelfDef.key)
			end
		end, 0.4)
	end
end

---------------------------------------------------------------------------
-- Shelf stock as props
---------------------------------------------------------------------------
local function luckyActive(player: Player): boolean
	local u = player:GetAttribute("LuckyUntil")
	return typeof(u) == "number" and u > os.time()
end

local function syncShelf(store: Store, key: string)
	local data = deps.Data.get(store.player)
	local state = store.shelves[key]
	if not data or not state then
		return
	end
	-- Drop props that left the shelf (grabbed) from the list.
	local kept = {}
	for _, p in state.props do
		if p.Parent and p:GetAttribute("Shelf") == key then
			table.insert(kept, p)
		end
	end
	state.props = kept
	local unlocked = shelfUnlocked(data, state.def)
	local want = if unlocked then math.min(data.store.stock[key] or 0, Config.SHELF_CAPACITY) else 0
	while #state.props > want do
		local p = table.remove(state.props) :: BasePart
		p:Destroy()
	end
	local slot = #state.props
	while #state.props < want do
		slot += 1
		local col = SLOT_X[((slot - 1) % #SLOT_X) + 1]
		local row = BOARD_Y[math.floor((slot - 1) / #SLOT_X) % #BOARD_Y + 1]
		local pool = state.def.props
		local id = pool[math.random(1, #pool)]
		if luckyActive(store.player) and math.random() < 0.35 then
			id = LUCKY_POOL[math.random(1, #LUCKY_POOL)]
		end
		local def = Config.PROPS[id]
		local cf = state.frame * CFrame.new(col, row + 1.15 + def.size.Y / 2, 0)
		local p = deps.Prop.create(id, cf, { storeOwner = store.player.UserId, shelf = key, anchored = true })
		if not p then
			break
		end
		table.insert(state.props, p)
	end
	-- Shelf tag text.
	local label = state.tag:FindFirstChild("SurfaceGui") and (state.tag :: any).SurfaceGui:FindFirstChild("Text")
	if label then
		label.Text = if unlocked then string.format("%s %d/%d", string.upper(key), data.store.stock[key] or 0, Config.SHELF_CAPACITY) else string.format("LOCKED  LV %d", state.def.unlockLevel + 1)
	end
end

local function syncAll(store: Store)
	for key in store.shelves do
		syncShelf(store, key)
	end
	updateSign(store)
end

local function ensureCounterPen(store: Store)
	if store.counterPen and store.counterPen.Parent and store.counterPen:GetAttribute("StoreOwner") then
		return
	end
	-- Taken: a new pen turns up on the counter after a short wait.
	if store.counterPen then
		local t = os.clock()
		if not store.penTakenAt then
			store.penTakenAt = t
			return
		elseif t - store.penTakenAt < 15 then
			return
		end
	end
	store.penTakenAt = nil
	store.counterPen =deps.Prop.create("pen", local3(store, 3, 4.6, -11) * CFrame.Angles(0, math.rad(30), 0), { storeOwner = store.player.UserId, shelf = "Counter", anchored = true })
end

---------------------------------------------------------------------------
-- Restock and upgrade
---------------------------------------------------------------------------
function StoreService.restock(player: Player, key: string, quiet: boolean?): boolean
	local store = stores[player]
	local data = deps.Data.get(player)
	local shelfDef = nil
	for _, s in Config.SHELVES do
		if s.key == key then
			shelfDef = s
		end
	end
	if not store or not data or not shelfDef then
		return false
	end
	if not shelfUnlocked(data, shelfDef) then
		if not quiet then
			toast(player, { kind = "error", title = "Shelf locked", body = string.format("Upgrade your store to level %d first!", shelfDef.unlockLevel + 1) })
		end
		return false
	end
	local missing = Config.SHELF_CAPACITY - (data.store.stock[key] or 0)
	if missing <= 0 then
		if not quiet then
			toast(player, { kind = "info", title = "Already full", body = shelfDef.key .. " is full." })
		end
		return false
	end
	local cost = math.ceil(shelfDef.restockCost * missing / Config.SHELF_CAPACITY)
	if not deps.Progression.spendCash(player, cost, "Shop", "Restock_" .. key) then
		if not quiet then
			toast(player, { kind = "error", title = "Not enough Cash", body = string.format("You need %s%s.", Config.CURRENCY_CODE, Format.commas(cost)) })
		end
		return false
	end
	data.store.stock[key] = Config.SHELF_CAPACITY
	deps.Data.changed(player)
	syncShelf(store, key)
	Remotes.event("CombatFx"):FireClient(player, { kind = "restock", pos = store.shelves[key].part.Position })
	deps.Quest.notify(player, "restock")
	deps.Analytics.funnel(player, "FirstRestock")
	return true
end

-- Restocks every unlocked shelf you can afford, cheapest first. One toast.
function StoreService.restockAll(player: Player): number
	local data = deps.Data.get(player)
	if not data then
		return 0
	end
	local order = table.clone(Config.SHELVES)
	table.sort(order, function(a, b)
		return a.restockCost < b.restockCost
	end)
	local filled, wanted = 0, 0
	for _, shelf in order do
		if shelfUnlocked(data, shelf) and (data.store.stock[shelf.key] or 0) < Config.SHELF_CAPACITY then
			wanted += 1
			if StoreService.restock(player, shelf.key, true) then
				filled += 1
			end
		end
	end
	if wanted == 0 then
		toast(player, { kind = "info", title = "Already full", body = "Every shelf is stocked." })
	elseif filled == 0 then
		toast(player, { kind = "error", title = "Not enough Cash", body = "Knock out some bad guys first!" })
	elseif filled < wanted then
		toast(player, { kind = "info", title = "Restocked some", body = string.format("%d of %d shelves. Earn more Cash for the rest.", filled, wanted) })
	end
	return filled
end

function StoreService.upgrade(player: Player): boolean
	local store = stores[player]
	local data = deps.Data.get(player)
	if not store or not data then
		return false
	end
	local nextLevel = Config.STORE_LEVELS[(data.store.level or 0) + 2]
	if not nextLevel then
		toast(player, { kind = "info", title = "Max level", body = "Your store is already a local legend." })
		return false
	end
	if not deps.Progression.spendCash(player, nextLevel.cost, "Shop", "StoreUpgrade") then
		toast(player, { kind = "error", title = "Not enough Cash", body = string.format("You need %s%s.", Config.CURRENCY_CODE, Format.commas(nextLevel.cost)) })
		return false
	end
	data.store.level += 1
	deps.Data.changed(player)
	syncAll(store)
	toast(player, { kind = "reward", title = "Store upgraded", body = nextLevel.name })
	return true
end

---------------------------------------------------------------------------
-- Customers
---------------------------------------------------------------------------
local PASTELS = {
	Color3.fromRGB(170, 200, 230),
	Color3.fromRGB(230, 190, 170),
	Color3.fromRGB(190, 220, 180),
	Color3.fromRGB(220, 200, 230),
	Color3.fromRGB(235, 225, 170),
}

local function ownerNear(store: Store): boolean
	local root = store.player.Character and store.player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - store.origin.Position).Magnitude < 45
end

local function walkTo(humanoid: Humanoid, target: Vector3, timeout: number): boolean
	humanoid:MoveTo(target)
	local done = false
	local reached = false
	local conn = humanoid.MoveToFinished:Connect(function(ok)
		done = true
		reached = ok
	end)
	local t = os.clock()
	while not done and os.clock() - t < timeout do
		task.wait(0.1)
	end
	conn:Disconnect()
	return reached
end

local function leave(store: Store, model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local prompt = model:FindFirstChild("RingUp", true)
	if prompt then
		prompt:Destroy()
	end
	if humanoid then
		walkTo(humanoid, (local3(store, 0, 3, Config.STORE_SIZE.Z / 2 + 8)).Position, 6)
	end
	local i = table.find(store.customers, model)
	if i then
		table.remove(store.customers, i)
	end
	if model.Parent and not CollectionService:HasTag(model, "Enemy") then
		model:Destroy()
	end
end

local function pickStockedShelf(store: Store, data: any): string?
	local options = {}
	for key, state in store.shelves do
		if shelfUnlocked(data, state.def) and (data.store.stock[key] or 0) > 0 then
			table.insert(options, key)
		end
	end
	if #options == 0 then
		return nil
	end
	return options[math.random(1, #options)]
end

local function assassinFor(data: any): string
	local tier = Config.bountyTier(data.bestBounty)
	return Config.ASSASSIN_BY_TIER[tier] or "thug"
end

local function runCustomer(store: Store, assassin: boolean)
	local player = store.player
	local data = deps.Data.get(player)
	if not data then
		return
	end
	local model = deps.Enemy.makeRig("customer", PASTELS[math.random(1, #PASTELS)], 1)
	model.Name = "Customer"
	model:PivotTo(local3(store, math.random(-3, 3), 4, Config.STORE_SIZE.Z / 2 + 6) * CFrame.Angles(0, math.pi, 0))
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayName = "Customer"
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.WalkSpeed = 9
	CollectionService:AddTag(model, "Customer")
	model:SetAttribute("StoreOwner", player.UserId)
	model.Parent = store.model
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
	deps.Enemy.playLoop(humanoid)
	table.insert(store.customers, model)

	-- Honest customers carry a basket. Assassins don't.
	if not assassin and root then
		local basket = part({ Name = "Basket", Size = Vector3.new(1.4, 1, 1), Color = Color3.fromRGB(215, 38, 30), Anchored = false, CanCollide = false, Massless = true }, model)
		local hand = model:FindFirstChild("LeftHand") or model:FindFirstChild("Left Arm") or root
		basket.CFrame = (hand :: BasePart).CFrame * CFrame.new(0, -0.8, 0)
		local w = Instance.new("WeldConstraint")
		w.Part0 = hand :: BasePart
		w.Part1 = basket
		w.Parent = basket
	end

	if assassin then
		walkTo(humanoid, (local3(store, 0, 3, -7)).Position, 10)
		task.wait(1.2)
		if model.Parent then
			local i = table.find(store.customers, model)
			if i then
				table.remove(store.customers, i)
			end
			deps.Enemy.convert(model, assassinFor(data), { storeOwner = player.UserId })
		end
		return
	end

	local shelfKey = pickStockedShelf(store, data)
	if shelfKey then
		local state = store.shelves[shelfKey]
		walkTo(humanoid, (state.frame * CFrame.new(0, 3, 3)).Position, 10)
		task.wait(1.2)
		if (data.store.stock[shelfKey] or 0) > 0 then
			data.store.stock[shelfKey] -= 1
			deps.Data.changed(player)
			syncShelf(store, shelfKey)
		else
			shelfKey = nil
		end
	end
	if not shelfKey then
		leave(store, model)
		return
	end
	walkTo(humanoid, (local3(store, math.random(-2, 2), 3, -7)).Position, 10)
	if not model.Parent or not root then
		return
	end

	local served = false
	local prompt = deps.World.addPrompt(root, "Ring up", "Customer", function(by: Player)
		if by ~= player or served then
			return
		end
		served = true
		local level = Stats.storeLevel(data)
		local tips = if data.unlocks["boost:RegisterTips"] then 1.25 else 1
		local cash = math.floor(level.saleCash * tips * deps.Bounty.cashMult(player))
		data.store.sales += 1
		deps.Progression.addCash(player, cash, "Gameplay", "Sale")
		Remotes.event("CombatFx"):FireClient(player, { kind = "register", pos = root.Position, cash = cash })
		deps.Quest.notify(player, "serve")
		task.spawn(leave, store, model)
	end)
	prompt.Name = "RingUp"
	local waited = 0
	while not served and model.Parent and waited < Config.CUSTOMER_PATIENCE do
		task.wait(0.5)
		waited += 0.5
	end
	if not served and model.Parent then
		leave(store, model)
	end
end

local function tickCustomers()
	local t = os.clock()
	for player, store in stores do
		local data = deps.Data.get(player)
		if not data or not ownerNear(store) then
			continue
		end
		ensureCounterPen(store)
		-- Auto Restock pass: refill empty unlocked shelves at cost.
		if deps.Monetization.hasPass(player, "AutoRestock") then
			for key, state in store.shelves do
				if shelfUnlocked(data, state.def) and (data.store.stock[key] or 0) == 0 then
					StoreService.restock(player, key)
				end
			end
		end
		-- A brand new player meets an assassin within seconds.
		if Config.FIRST_SPAWN_ASSASSIN and not store.firstAssassinDone and data.kos == 0 then
			store.firstAssassinDone = true
			store.nextCustomer = t + Stats.storeLevel(data).customerEvery
			task.spawn(runCustomer, store, true)
			continue
		end
		store.firstAssassinDone = true
		if t >= store.nextCustomer and #store.customers < Config.MAX_CUSTOMERS then
			store.nextCustomer = t + Stats.storeLevel(data).customerEvery
			local tier = Config.bountyTier(data.bestBounty)
			local chance = Config.ASSASSIN_CHANCE_BY_TIER[tier] or 0.3
			-- One armed assassin at a time per store.
			local armed = false
			for _, m in deps.Enemy.folder():GetChildren() do
				if m:GetAttribute("StoreOwner") == player.UserId and deps.Enemy.isAlive(m) then
					armed = true
				end
			end
			task.spawn(runCustomer, store, (not armed) and math.random() < chance)
		end
	end
end

---------------------------------------------------------------------------
-- Claim and release
---------------------------------------------------------------------------
local function claim(player: Player)
	local index = nil
	for i = 1, Config.STORE_PLOTS do
		if not plotTaken[i] then
			index = i
			break
		end
	end
	if not index then
		warn("[StoreService] no free plot for", player.Name)
		return
	end
	local lot = deps.World.plot(index)
	if not lot then
		return
	end
	plotTaken[index] = player
	local model = Instance.new("Model")
	model.Name = "Store_" .. player.UserId
	model:SetAttribute("Owner", player.UserId)
	model.Parent = lot
	local base = lot.PrimaryPart :: BasePart
	local store: Store = {
		player = player,
		plotIndex = index,
		model = model,
		origin = CFrame.new(base.Position.X, 0, base.Position.Z),
		shelves = {},
		customers = {},
		counterPen = nil,
		penTakenAt = nil,
		nextCustomer = os.clock() + 6,
		firstAssassinDone = false,
	}
	stores[player] = store
	buildShell(store)
	buildShelves(store)
	syncAll(store)
	ensureCounterPen(store)
	player:SetAttribute("StorePlot", index)
end

local function release(player: Player)
	local store = stores[player]
	if not store then
		return
	end
	stores[player] = nil
	plotTaken[store.plotIndex] = nil
	for _, p in deps.Prop.folder():GetChildren() do
		if p:GetAttribute("StoreOwner") == player.UserId then
			p:Destroy()
		end
	end
	deps.Enemy.clearStore(player.UserId)
	store.model:Destroy()
end

-- Where the player spawns: behind their own counter. Falls back to the street.
function StoreService.spawnCFrame(player: Player): CFrame
	local store = stores[player]
	if store then
		return local3(store, 0, 4, -14) * CFrame.Angles(0, math.pi, 0)
	end
	return CFrame.new(0, 6, Config.STORE_ROW_Z + 30)
end

function StoreService.init(dependencies: any)
	deps = dependencies

	deps.Data.Loaded:Connect(function(player: Player)
		claim(player)
	end)
	Players.PlayerRemoving:Connect(release)

	-- Grabbing a shelf prop uses up stock.
	deps.Prop.Grabbed:Connect(function(player: Player, _p: BasePart, _id: string, shelf: any)
		local store = stores[player]
		local data = deps.Data.get(player)
		if not store or not data or typeof(shelf) ~= "string" then
			return
		end
		if data.store.stock[shelf] then
			data.store.stock[shelf] = math.max(0, data.store.stock[shelf] - 1)
			deps.Data.changed(player)
			syncShelf(store, shelf)
		end
	end)

	Remotes.event("StoreAction").OnServerEvent:Connect(function(player: Player, action: any, arg: any)
		if not RateLimit.check(player, "StoreAction") then
			return
		end
		if action == "restockAll" then
			StoreService.restockAll(player)
		elseif action == "restock" and typeof(arg) == "string" then
			StoreService.restock(player, arg)
		elseif action == "upgrade" then
			StoreService.upgrade(player)
		end
	end)

	-- Lucky Delivery refresh: re-roll shelves when it starts.
	Players.PlayerAdded:Connect(function(player)
		player:GetAttributeChangedSignal("LuckyUntil"):Connect(function()
			local store = stores[player]
			if store then
				for _, state in store.shelves do
					for _, p in state.props do
						p:Destroy()
					end
					state.props = {}
				end
				syncAll(store)
			end
		end)
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(tickCustomers)
			if not ok then
				warn("[StoreService] tick failed:", err)
			end
		end
	end)
end

return StoreService
