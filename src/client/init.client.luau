--!strict
-- Client bootstrap for Clocked Out.
-- ScreenGui -> design-space root with UIScale (1280x720, clamp 0.45 to 1.35,
-- x1.1 on touch-only) -> State -> HUD, toasts, banners, Ledger, input, combat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local UIFolder = script:WaitForChild("UI")
local Theme = require(UIFolder.Theme)
local Motion = require(UIFolder.Motion)
local Router = require(UIFolder.Router)
local Toasts = require(UIFolder.Toasts)
local Banners = require(UIFolder.Banners)
local State = require(script.State)
local Sound = require(script.Sound)
local Hud = require(script.Hud)
local Ledger = require(script.Ledger)
local Input = require(script.Input)
local AdminPanel = require(script.AdminPanel)
local Combat = require(script.Combat)

local player = Players.LocalPlayer

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

---------------------------------------------------------------------------
-- Screen and scaling
---------------------------------------------------------------------------
local DESIGN = Vector2.new(1280, 720)

local screen = Instance.new("ScreenGui")
screen.Name = "ClockedOut"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = false
screen.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = player:WaitForChild("PlayerGui")

local root = Instance.new("Frame")
root.Name = "Root"
root.BackgroundTransparency = 1
root.Parent = screen

local scale = Instance.new("UIScale")
scale.Parent = root

local userScale = 1

local function rescale()
	local size = screen.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	local s = math.min(size.X / DESIGN.X, size.Y / DESIGN.Y)
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		s *= 1.1
	end
	s = math.clamp(s * userScale, 0.45, 1.35)
	scale.Scale = s
	-- Root covers the whole screen in design units.
	root.Size = UDim2.fromOffset(size.X / s, size.Y / s)
end

screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
rescale()

---------------------------------------------------------------------------
-- Modules
---------------------------------------------------------------------------
State.init()
Sound.init()
Toasts.init(root)
Toasts.setSoundHook(Sound.play)
Banners.init(root)
Banners.setSoundHook(Sound.play)
Hud.init(root)
Ledger.init(root)
Input.init()
AdminPanel.init(root)
Combat.init(root)

Router.Changed:Connect(function(open)
	Sound.play(if open then "ui_open" else "ui_close")
end)

Remotes.event("Toast").OnClientEvent:Connect(Toasts.push)
Remotes.event("Banner").OnClientEvent:Connect(Banners.show)
Remotes.event("OpenLedger").OnClientEvent:Connect(function(tab: any)
	if typeof(tab) == "string" then
		Router.open("Ledger", tab)
	end
end)

-- Apply saved settings whenever the profile changes.
State.observe(function(data)
	local s = data.settings or Config.DEFAULT_SETTINGS
	Motion.setReduceMotion(s.reduceMotion == true)
	Theme.setPanelOpacity(s.panelOpacity or 1)
	if s.uiScale and s.uiScale ~= userScale then
		userScale = s.uiScale
		rescale()
	end
end)

print(string.format("[%s] client %s ready", Config.GAME_NAME, Config.VERSION))
