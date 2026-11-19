--!strict
-- AdminPanel: a small test panel for admins (Studio, place owner, listed IDs).
-- Toggle with the backquote key. The server re-checks admin rights on every call.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)
local Theme = require(script.Parent.UI.Theme)
local UI = require(script.Parent.UI.UI)
local Motion = require(script.Parent.UI.Motion)

local player = Players.LocalPlayer

local AdminPanel = {}

local COMMANDS = {
	{ "give_xp", "Give XP", "500" },
	{ "give_gold", "Give gold", "1000" },
	{ "set_level", "Set level", "10" },
	{ "unlock_floor", "Unlock floor", "2" },
	{ "unlock_all", "Unlock all floors", "" },
	{ "clear_floor", "Clear floor", "1" },
	{ "give_item", "Give item", "tidecutter" },
	{ "advance_quest", "Advance quest", "F01_Side_ScarecrowThatMoves" },
	{ "reset_daily", "Reset daily", "" },
	{ "test_banner", "Test banner", "boss" },
}

function AdminPanel.init(root: Frame)
	local panel = UI.plate({
		Name = "AdminPanel",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 24, 1, -24),
		Size = UDim2.fromOffset(360, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		ZIndex = 30,
		Parent = root,
	}, { UI.padding(12), UI.list(Enum.FillDirection.Vertical, 6) })
	UI.caption("Admin", { LayoutOrder = 0, TextColor3 = Theme.Color.Ember, TextTransparency = 0, Parent = panel })

	local argBox: TextBox = UI.new("TextBox", {
		Name = "Arg",
		BackgroundColor3 = Theme.Color.Ink,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		PlaceholderText = "argument",
		Text = "",
		FontFace = Theme.Font.Mono,
		TextSize = Theme.TextSize.Caption,
		TextColor3 = Theme.Color.Bone,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 1,
		Parent = panel,
	}, { UI.padding(0, 8), UI.stroke() })

	for i, cmd in COMMANDS do
		UI.button(cmd[2], "secondary", function()
			local arg = if argBox.Text ~= "" then argBox.Text else cmd[3]
			Remotes.event("AdminCommand"):FireServer(cmd[1], arg)
		end, {
			Size = UDim2.new(1, 0, 0, 30),
			TextSize = Theme.TextSize.Caption,
			LayoutOrder = 10 + i,
			Parent = panel,
		})
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.Backquote then
			return
		end
		if player:GetAttribute("IsAdmin") ~= true then
			return
		end
		if panel.Visible then
			Motion.exit(panel, "fade", Theme.Motion.quick)
		else
			Motion.enter(panel, "up", Theme.Motion.base)
		end
	end)
end

return AdminPanel
