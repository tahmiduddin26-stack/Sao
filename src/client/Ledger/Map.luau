--!strict
-- MAP tab: a comic page of eight panels, your store and the seven districts.
-- Each panel says one thing: GO, HERE, or what bounty unlocks it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Stats = require(Shared.Stats)

local UIFolder = script.Parent.Parent.UI
local Theme = require(UIFolder.Theme)
local UI = require(UIFolder.UI)
local Router = require(UIFolder.Router)

local C = Theme.Color
local player = Players.LocalPlayer

local Tab = { title = "Map" }

local COLS = 4

function Tab.render(content: Frame, data: any, _ctx: any)
	local entries = { { code = "Store", name = "Your Store", bounty = 0 } }
	for _, def in Config.DISTRICTS do
		table.insert(entries, { code = def.code, name = def.name, bounty = def.bounty })
	end
	local rows = math.ceil(#entries / COLS)
	for i, e in entries do
		local col = (i - 1) % COLS
		local row = math.floor((i - 1) / COLS)
		local here = player:GetAttribute("Area") == e.code or (e.code == "Store" and player:GetAttribute("Area") == nil)
		local open = e.code == "Store" or Stats.districtUnlocked(data, e.code)
		local cleared = data.bossesBeaten and data.bossesBeaten[e.code]
		local card = UI.panel({
			Position = UDim2.new(col / COLS, 0, row / rows, 0),
			Size = UDim2.new(1 / COLS, -14, 1 / rows, -14),
			Parent = content,
		}, {
			color = if here then C.Red elseif open then C.Paper else C.Tone,
			tone = if open then "BR" else nil,
		})
		local ink = if here then C.Paper else C.Ink
		UI.text(if e.code == "Store" then "HOME" else e.code, "monoBold", Theme.TextSize.Caption, {
			Position = UDim2.fromOffset(12, 10),
			Size = UDim2.new(1, -24, 0, 18),
			TextColor3 = ink,
			Parent = card,
		})
		UI.text(string.upper(e.name), "display", Theme.TextSize.Heading, {
			Position = UDim2.fromOffset(12, 28),
			Size = UDim2.new(1, -24, 0, 56),
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = ink,
			Parent = card,
		})
		if cleared then
			UI.sticker("CLEARED", C.Ink, C.Paper, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 6), Rotation = 6, Parent = card })
		end
		if here then
			UI.text("YOU ARE HERE", "display", Theme.TextSize.Label, {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 12, 1, -14),
				Size = UDim2.new(1, -24, 0, 26),
				TextColor3 = C.Paper,
				Parent = card,
			})
		elseif open then
			UI.bigButton("GO!", "primary", function()
				Remotes.event("TravelToDistrict"):FireServer(e.code)
				Router.close()
			end, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -10), Size = UDim2.new(1, -24, 0, 50), Parent = card })
		else
			UI.text("LOCKED", "display", Theme.TextSize.Label, {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 12, 1, -36),
				Size = UDim2.new(1, -24, 0, 22),
				TextTransparency = Theme.TextDim,
				Parent = card,
			})
			UI.text("BOUNTY " .. Format.commas(e.bounty), "monoBold", Theme.TextSize.Caption, {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 12, 1, -14),
				Size = UDim2.new(1, -24, 0, 18),
				Parent = card,
			})
		end
	end
end

return Tab
