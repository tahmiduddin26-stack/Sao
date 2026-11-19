--!strict
-- MonetizationService: game passes and developer products (plan 11).
-- Never sells power or the climb. Passes and products with ID 0 are not created
-- on Roblox yet; in Studio the client can simulate buying them so every flow
-- can be tested first. Receipts are stored in the profile (no double grants).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local RateLimit = require(Shared.RateLimit)

local MonetizationService = {}

local DataService: any
local ProgressionService: any
local Analytics: any

local function toast(player: Player, payload: any)
	Remotes.event("Toast"):FireClient(player, payload)
end

local function passKeyForId(id: number): string?
	for key, def in Config.PASSES :: any do
		if def.id ~= 0 and def.id == id then
			return key
		end
	end
	return nil
end

local function productKeyForId(id: number): string?
	for key, def in Config.PRODUCTS :: any do
		if def.id ~= 0 and def.id == id then
			return key
		end
	end
	return nil
end

function MonetizationService.hasPass(player: Player, key: string): boolean
	local data = DataService.get(player)
	return data ~= nil and data.passes[key] == true
end

function MonetizationService.grantPass(player: Player, key: string)
	local data = DataService.get(player)
	local def = (Config.PASSES :: any)[key]
	if not data or not def then
		return
	end
	if not data.passes[key] then
		data.passes[key] = true
		toast(player, { kind = "reward", title = def.name, body = "Unlocked. Thank you for supporting the game." })
	end
	player:SetAttribute("Pass_" .. key, true)
	DataService.changed(player)
end

-- Product handlers. Each returns true when the grant is applied.
local PRODUCT_HANDLERS: { [string]: (Player) -> boolean } = {
	RespecScroll = function(player)
		ProgressionService.respec(player)
		toast(player, { kind = "info", title = "Stats reset", body = "All stat points are back to spend." })
		return true
	end,
	CardinalsBlessing = function(player)
		local now = os.time()
		local untilTime = Workspace:GetAttribute("BlessingUntil")
		local stacks = Workspace:GetAttribute("BlessingStacks")
		if typeof(untilTime) ~= "number" or untilTime < now then
			untilTime = now
			stacks = 0
		end
		Workspace:SetAttribute("BlessingUntil", (untilTime :: number) + Config.BLESSING_SECONDS)
		Workspace:SetAttribute("BlessingStacks", math.min(((stacks :: number?) or 0) + 1, Config.BLESSING_MAX_STACKS))
		Workspace:SetAttribute("BlessingBy", player.DisplayName)
		for _, p in Players:GetPlayers() do
			toast(p, { kind = "info", title = "Server blessing", body = player.DisplayName .. " blessed the server. XP boost for everyone." })
		end
		return true
	end,
	ReviveToken = function(player)
		local data = DataService.get(player)
		data.tokens.Revive += 1
		return true
	end,
	DyeSlot = function(player)
		local data = DataService.get(player)
		data.tokens.Dye += 1
		return true
	end,
}

local function grantProduct(player: Player, key: string): boolean
	local handler = PRODUCT_HANDLERS[key]
	if not handler then
		warn("[Monetization] No handler for product", key)
		return false
	end
	local ok, result = pcall(handler, player)
	if not ok then
		warn("[Monetization] Handler failed:", result)
		return false
	end
	DataService.changed(player)
	return result == true
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService.waitFor(player, 30)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not DataService.canSave(player) then
		-- Never grant into a session that cannot persist the receipt.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if DataService.hasReceipt(player, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local key = productKeyForId(receipt.ProductId)
	if not key or not grantProduct(player, key) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	DataService.addReceipt(player, purchaseId)
	if not DataService.saveNow(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Analytics.custom(player, "ProductPurchased", receipt.CurrencySpent, { Product = key })
	toast(player, { kind = "purchase", title = (Config.PRODUCTS :: any)[key].name, body = "Purchase complete." })
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function refreshOwnedPasses(player: Player)
	for key, def in Config.PASSES :: any do
		if def.id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, def.id)
			end)
			if ok and owns then
				MonetizationService.grantPass(player, key)
			end
		end
	end
	local data = DataService.get(player)
	if data then
		for key in data.passes do
			player:SetAttribute("Pass_" .. key, true)
		end
	end
end

function MonetizationService.init(dataService: any, progressionService: any, analytics: any)
	DataService = dataService
	ProgressionService = progressionService
	Analytics = analytics

	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		if not purchased then
			return
		end
		local key = passKeyForId(passId)
		if key then
			MonetizationService.grantPass(player, key)
			Analytics.custom(player, "PassPurchased", 1, { Pass = key })
		end
	end)

	DataService.Loaded:Connect(function(player: Player)
		task.spawn(refreshOwnedPasses, player)
	end)

	-- Studio only: simulate buying items whose ID is still 0.
	Remotes.event("SimulatePurchase").OnServerEvent:Connect(function(player: Player, kind: any, key: any)
		if not RunService:IsStudio() or not RateLimit.check(player, "SimulatePurchase") then
			return
		end
		if typeof(kind) ~= "string" or typeof(key) ~= "string" then
			return
		end
		if kind == "pass" and (Config.PASSES :: any)[key] and (Config.PASSES :: any)[key].id == 0 then
			MonetizationService.grantPass(player, key)
		elseif kind == "product" and (Config.PRODUCTS :: any)[key] and (Config.PRODUCTS :: any)[key].id == 0 then
			if grantProduct(player, key) then
				toast(player, { kind = "purchase", title = (Config.PRODUCTS :: any)[key].name, body = "Studio test purchase." })
			end
		end
	end)
end

return MonetizationService
