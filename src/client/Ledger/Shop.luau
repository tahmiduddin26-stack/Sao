--!strict
-- SHOP tab: the Big Sale as a big red panel, a code box, then simple cards
-- with a name, a few words and the Robux price. No loot boxes.
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
		Toasts.push({ kind = "info", title = def.name, body = "Coming soon." })
	end
end

local function card(parent: Instance, order: number, def: any, owned: boolean, onBuy: () -> ())
	local face = UI.panel({ Size = UDim2.fromOffset(0, 0), LayoutOrder = order, Parent = parent })
	UI.text(string.upper(def.name), "display", Theme.TextSize.Heading, {
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -24, 0, 26),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = face,
	})
	UI.text(def.blurb, "bold", Theme.TextSize.Body, {
		Position = UDim2.fromOffset(12, 38),
		Size = UDim2.new(1, -24, 0, 40),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = face,
	})
	local btn = UI.bigButton(if owned then "OWNED" else "R$ " .. def.price, if owned then "secondary" else "primary", onBuy, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -10),
		Size = UDim2.new(1, -24, 0, 44),
		Parent = face,
	})
	UI.setDisabled(btn, owned)
end

function Tab.render(content: Frame, data: any, ctx: any)
	-- Featured: Big Sale, plus codes underneath.
	local sale = (Config.PRODUCTS :: any).BigSale
	local feature = UI.panel({ Size = UDim2.new(0, 260, 0, 250), Parent = content }, { color = C.Red })
	UI.splat(feature, UDim2.new(1, -30, 0, 30), 90, C.Ink, 11)
	UI.text("BIG SALE", "display", 46, { Position = UDim2.fromOffset(16, 14), Size = UDim2.new(1, -32, 0, 52), TextColor3 = C.Paper, Parent = feature })
	UI.text(sale.blurb, "bold", Theme.TextSize.Label, {
		Position = UDim2.fromOffset(16, 72),
		Size = UDim2.new(1, -32, 0, 60),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = C.Paper,
		Parent = feature,
	})
	UI.bigButton("R$ " .. sale.price, "secondary", function()
		buy("product", "BigSale")
	end, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -14), Size = UDim2.new(1, -32, 0, 56), Parent = feature })

	local codes = UI.panel({ Position = UDim2.fromOffset(0, 268), Size = UDim2.new(0, 260, 0, 104), Parent = content }, { color = C.Tone })
	UI.text("GOT A CODE?", "display", Theme.TextSize.Label, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 22), Parent = codes })
	local box: TextBox = UI.new("TextBox", {
		Position = UDim2.fromOffset(12, 40),
		Size = UDim2.new(1, -96, 0, 44),
		BackgroundColor3 = C.Paper,
		BorderSizePixel = 0,
		PlaceholderText = "CODE",
		Text = "",
		ClearTextOnFocus = false,
		FontFace = Theme.Font.MonoBold,
		TextSize = Theme.TextSize.Label,
		TextColor3 = C.Ink,
		PlaceholderColor3 = Theme.darker(C.Tone),
		Parent = codes,
	}, { UI.stroke(C.Line), UI.padding(0, 10) })
	UI.bigButton("GO", "primary", function()
		if box.Text ~= "" then
			Remotes.event("RedeemCode"):FireServer(box.Text)
			box.Text = ""
		end
	end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 38), Size = UDim2.fromOffset(72, 50), Parent = codes })

	-- Everything else as a grid of cards.
	local scroll = ctx.scroll("shop", { Position = UDim2.fromOffset(282, 0), Size = UDim2.new(1, -282, 1, 0), Parent = content })
	UI.new("UIGridLayout", {
		CellSize = UDim2.new(0.5, -14, 0, 164),
		CellPadding = UDim2.fromOffset(14, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroll,
	})
	local order = 0
	for _, key in Config.PASS_ORDER do
		order += 1
		local def = (Config.PASSES :: any)[key]
		card(scroll, order, def, data.passes and data.passes[key] == true, function()
			buy("pass", key)
		end)
	end
	for _, key in Config.PRODUCT_ORDER do
		if key ~= "BigSale" then
			order += 1
			local def = (Config.PRODUCTS :: any)[key]
			card(scroll, order, def, false, function()
				buy("product", key)
			end)
		end
	end
end

return Tab
