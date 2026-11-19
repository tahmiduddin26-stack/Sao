--!strict
-- Input: menu controls on every platform (plan 24.1).
--  Ledger: Tab or M (PC), Start (gamepad), menu button (touch).
--  Back / close: Esc or Backspace (PC), B (gamepad, only while a menu is open), close button.
-- Combat bindings (attack, Sword Skills, dodge, Switch, crystal) arrive with combat.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)
local Router = require(script.Parent.UI.Router)

local Input = {}

local BACK_ACTION = "SBO_Back"

local function onLedger(_name: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		if UserInputService:GetFocusedTextBox() then
			return Enum.ContextActionResult.Pass
		end
		Router.toggle("Ledger")
	end
	return Enum.ContextActionResult.Sink
end

local function onBack(_name: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin and Router.back() then
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

function Input.init()
	ContextActionService:BindAction("SBO_Ledger", onLedger, false, Enum.KeyCode.Tab, Enum.KeyCode.M, Enum.KeyCode.ButtonStart)

	-- B and Esc only consume input while something is open, so they keep their
	-- normal jobs otherwise.
	Router.Changed:Connect(function(open)
		if open then
			ContextActionService:BindActionAtPriority(BACK_ACTION, onBack, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonB, Enum.KeyCode.Escape, Enum.KeyCode.Backspace)
		else
			ContextActionService:UnbindAction(BACK_ACTION)
		end
	end)

	-- Onboarding funnel: first time the player moves.
	local player = Players.LocalPlayer
	local sent = false
	local function watch(character: Model)
		if sent then
			return
		end
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if not humanoid then
			return
		end
		local conn: RBXScriptConnection
		conn = (humanoid :: Humanoid):GetPropertyChangedSignal("MoveDirection"):Connect(function()
			if not sent and (humanoid :: Humanoid).MoveDirection.Magnitude > 0.1 then
				sent = true
				conn:Disconnect()
				Remotes.event("FunnelStep"):FireServer("FirstMove")
			end
		end)
	end
	if player.Character then
		task.spawn(watch, player.Character)
	end
	player.CharacterAdded:Connect(watch)
end

return Input
