--!strict
-- STORE tab: five shelf panels with stock pips, one RESTOCK ALL button and
-- one UPGRADE card. Unread = an empty shelf you could be fighting with.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Stats = require(Shared.Stats)

local UIFolder = script.Parent.Parent.UI
local Theme = require(UIFolder.Theme)
local UI = require(UIFolder.UI)

local C = Theme.Color

local Tab = { title = "Store" }

local function unlocked(data: any, shelf: any): boolean
	return (data.store.level or 0) >= shelf.unlockLevel or (data.unlocks and data.unlocks["shelf:" .. shelf.key]) == true
end

-- What RESTOCK ALL costs right now (only unlocked shelves that are not full).
local function restockAllCost(data: any): number
	local total = 0
	for _, shelf in Config.SHELVES do
		if unlocked(data, shelf) then
			local missing = Config.SHELF_CAPACITY - (data.store.stock[shelf.key] or 0)
			if missing > 0 then
				total += math.ceil(shelf.restockCost * missing / Config.SHELF_CAPACITY)
			end
		end
	end
	return total
end

function Tab.unread(data: any): boolean
	for _, shelf in Config.SHELVES do
		if unlocked(data, shelf) and (data.store.stock[shelf.key] or 0) == 0 then
			return true
		end
	end
	return false
end

function Tab.render(content: Frame, data: any, _ctx: any)
	-- Shelves
	local shelves = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 200), Parent = content })
	for i, shelf in Config.SHELVES do
		local open = unlocked(data, shelf)
		local stock = data.store.stock[shelf.key] or 0
		local card = UI.panel({
			Position = UDim2.new((i - 1) / #Config.SHELVES, 0, 0, 0),
			Size = UDim2.new(1 / #Config.SHELVES, -12, 1, 0),
			Parent = shelves,
		}, { color = if open then C.Paper else C.Tone })
		UI.text(string.upper(shelf.key), "display", Theme.TextSize.Heading, {
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.new(1, -20, 0, 26),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = card,
		})
		if open then
			UI.text(string.format("%d/%d", stock, Config.SHELF_CAPACITY), "display", 46, {
				Position = UDim2.fromOffset(10, 44),
				Size = UDim2.new(1, -20, 0, 56),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = if stock == 0 then C.Red else C.Ink,
				Parent = card,
			})
			UI.pips(Config.SHELF_CAPACITY, stock, if stock == 0 then C.Red else C.Ink, {
				Position = UDim2.fromOffset(12, 110),
				Size = UDim2.new(1, -24, 0, 16),
				Parent = card,
			})
			if stock == 0 then
				UI.sticker("EMPTY!", C.Red, C.Paper, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 142), Parent = card })
			end
		else
			UI.halftone(card, "BR", 12, 12, C.Ink, 0.75)
			UI.sticker("LOCKED", C.Ink, C.Paper, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 60), Parent = card })
			UI.text(string.format("STORE LV %d", shelf.unlockLevel + 1), "display", Theme.TextSize.Label, {
				Position = UDim2.fromOffset(10, 110),
				Size = UDim2.new(1, -20, 0, 24),
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = card,
			})
		end
	end

	-- Restock all
	local cost = restockAllCost(data)
	local restock = UI.bigButton(if cost > 0 then "RESTOCK ALL  " .. Config.CURRENCY_CODE .. Format.commas(cost) else "SHELVES FULL", "primary", function()
		Remotes.event("StoreAction"):FireServer("restockAll")
	end, {
		Position = UDim2.fromOffset(0, 226),
		Size = UDim2.new(0.5, -12, 0, 72),
		TextSize = Theme.TextSize.Title,
		Parent = content,
	})
	UI.setDisabled(restock, cost <= 0 or (data.cash or 0) < math.min(cost, Config.SHELVES[1].restockCost))

	-- Upgrade
	local level = Stats.storeLevel(data)
	local nextLevel = Config.STORE_LEVELS[(data.store.level or 0) + 2]
	local up = UI.panel({ Position = UDim2.new(0.5, 6, 0, 216), Size = UDim2.new(0.5, -6, 0, 140), Parent = content }, { tone = "TR" })
	UI.text("YOUR STORE", "display", Theme.TextSize.Label, { Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -32, 0, 22), Parent = up })
	UI.text(string.upper(level.name), "display", Theme.TextSize.Title, { Position = UDim2.fromOffset(16, 32), Size = UDim2.new(1, -32, 0, 34), TextColor3 = C.Red, Parent = up })
	if nextLevel then
		local btn = UI.bigButton("UPGRADE  " .. Config.CURRENCY_CODE .. Format.commas(nextLevel.cost), "primary", function()
			Remotes.event("StoreAction"):FireServer("upgrade")
		end, {
			Position = UDim2.fromOffset(16, 74),
			Size = UDim2.new(1, -32, 0, 52),
			Parent = up,
		})
		UI.setDisabled(btn, (data.cash or 0) < nextLevel.cost)
	else
		UI.sticker("MAX LEVEL!", C.Red, C.Paper, { Position = UDim2.fromOffset(16, 82), Parent = up })
	end
end

return Tab
