--!strict
-- Shop tab: Floor Pass featured, direct-price passes and products, a plain note
-- that there are no loot boxes (plan 11, 25). Prices always show the Robux amount.
-- Items with ID 0 are not on sale yet; in Studio, buying them simulates a grant.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local UIFolder = script.Parent.Parent.UI
local Theme = require(UIFolder.Theme)
local UI = require(UIFolder.UI)
local Toasts = require(UIFolder.Toasts)
local Common = require(script.Parent.Common)

local C = Theme.Color
local player = Players.LocalPlayer

local Tab = { title = "Shop" }

local function buy(kind: "pass" | "product", key: string)
	local def = if kind == "pass" then (Config.PASSES :: any)[key] else (Config.PRODUCTS :: any)[key]
	if not def then
		return
	end
	if def.id ~= 0 then
		if kind == "pass" then
			MarketplaceService:PromptGamePassPurchase(player, def.id)
		else
			MarketplaceService:PromptProductPurchase(player, def.id)
		end
	elseif RunService:IsStudio() then
		Remotes.event("SimulatePurchase"):FireServer(kind, key)
	else
		Toasts.push({ kind = "info", title = def.name, body = "Not on sale yet." })
	end
end

local function itemRow(parent: Instance, order: number, name: string, blurb: string, price: number, owned: boolean, onBuy: () -> ())
	local row = UI.plate({ Size = UDim2.new(1, 0, 0, 60), LayoutOrder = order, Parent = parent }, { UI.padding(8, 12) })
	UI.text(name, "bold", Theme.TextSize.Body, { Size = UDim2.new(1, -110, 0, 22), Parent = row })
	UI.text(blurb, "body", Theme.TextSize.Caption, {
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, -110, 0, 20),
		TextTransparency = Theme.TextDim,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})
	local btn = UI.button(if owned then "Owned" else string.format("R$ %d", price), "secondary", onBuy, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(96, 36),
		FontFace = Theme.Font.MonoBold,
		TextSize = Theme.TextSize.Caption,
		Parent = row,
	})
	UI.setDisabled(btn, owned)
end

function Tab.render(content: Frame, data: any, ctx: any)
	local _, left, right = Common.columns(content, 0.5)

	-- Floor Pass card
	local fp = Config.FLOOR_PASS
	local card = UI.block(C.Steel, { Size = UDim2.new(1, 0, 0, 260), Parent = left }, { UI.stroke(C.Lantern, 0.3), UI.padding(16) })
	local col = Common.stack(card, 8)
	UI.text(string.format("SEASON %d   %s", fp.season, string.upper(fp.bandLabel)), "mono", Theme.TextSize.Caption, {
		TextColor3 = C.Lantern,
		LayoutOrder = 1,
		Parent = col,
	})
	UI.displayText("Floor Pass", Theme.TextSize.Title, { LayoutOrder = 2, Parent = col })
	UI.paragraph(fp.blurb, { LayoutOrder = 3, TextSize = Theme.TextSize.Caption, TextTransparency = Theme.TextDim, Parent = col })
	local tiers = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 4, Parent = col }, {
		UI.list(Enum.FillDirection.Horizontal, 6),
	})
	for i = 1, 8 do
		UI.slot(if i <= 3 then "Legendary" else nil, nil, { Size = UDim2.fromOffset(28, 28), LayoutOrder = i, Selectable = false, Parent = tiers })
	end
	local fpBtn = UI.button(string.format("Get Floor Pass  R$ %d", fp.price), "primary", function() end, {
		Size = UDim2.fromOffset(220, 38),
		LayoutOrder = 5,
		Parent = col,
	})
	UI.setDisabled(fpBtn, true)
	UI.text("Floor Pass opens with the first season.", "body", Theme.TextSize.Caption, {
		TextTransparency = Theme.TextDim,
		LayoutOrder = 6,
		Parent = col,
	})

	-- Passes and products
	local scroll = ctx.scroll("shop", { Parent = right })
	UI.list(Enum.FillDirection.Vertical, 8).Parent = scroll
	UI.caption("Game passes", { LayoutOrder = 0, Parent = scroll })
	for i, key in Config.PASS_ORDER do
		local def = (Config.PASSES :: any)[key]
		itemRow(scroll, i, def.name, def.blurb, def.price, data.passes and data.passes[key] == true, function()
			buy("pass", key)
		end)
	end
	UI.caption("Items", { LayoutOrder = 20, Parent = scroll })
	for i, key in Config.PRODUCT_ORDER do
		local def = (Config.PRODUCTS :: any)[key]
		itemRow(scroll, 20 + i, def.name, def.blurb, def.price, false, function()
			buy("product", key)
		end)
	end
	itemRow(scroll, 40, Config.CHARTER.name, Config.CHARTER.blurb, Config.CHARTER.price, false, function()
		Toasts.push({ kind = "info", title = Config.CHARTER.name, body = "Subscriptions open at launch." })
	end)
	UI.text("No loot boxes. Every item shows exactly what you get.", "body", Theme.TextSize.Caption, {
		TextTransparency = Theme.TextDim,
		LayoutOrder = 50,
		Parent = scroll,
	})
end

return Tab
