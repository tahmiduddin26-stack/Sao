--!strict
-- Combat (client): input, aim, grab targeting and every combat cosmetic.
-- The server decides all outcomes; this module only sends intent and draws.
--  * Inputs on PC, gamepad and touch (on-screen buttons) per DESIGN.md.
--  * Grab target: nearest grabbable prop gets a red outline and an "E" tag.
--  * Dodge is applied locally (the client owns its character) and validated
--    for i-frames on the server.
--  * Procedural swings on the right shoulder until real animations exist.
--  * Enemy wind-up tell: a red "!" over the head while WindupUntil is ahead.
--  * Impact frames, damage numbers, KO stamps, Serious speed lines. Screen
--    flashes and shakes are skipped with Reduce Motion.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.UI.Theme)
local UI = require(script.Parent.UI.UI)
local Motion = require(script.Parent.UI.Motion)
local Router = require(script.Parent.UI.Router)
local Sound = require(script.Parent.Sound)

local C = Theme.Color
local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local Combat = {}

local screenRoot: Frame
local flash: Frame
local speedLines: Frame
local grabTarget: BasePart? = nil
local highlight: Highlight
local grabTag: BillboardGui
local nextDodge = 0
local heavyHoldStart: number? = nil

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function rootPart(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function canAct(): boolean
	if Router.isOpen() or UserInputService:GetFocusedTextBox() then
		return false
	end
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0
end

---------------------------------------------------------------------------
-- Aim
---------------------------------------------------------------------------
local function aimPoint(): Vector3
	local root = rootPart()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	if player.Character then
		table.insert(ignore, player.Character)
	end
	local props = Workspace:FindFirstChild("Props")
	if props then
		table.insert(ignore, props)
	end
	params.FilterDescendantsInstances = ignore

	local ray: Ray
	if UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
		local m = UserInputService:GetMouseLocation()
		ray = camera:ViewportPointToRay(m.X, m.Y)
	else
		local v = camera.ViewportSize
		ray = camera:ViewportPointToRay(v.X / 2, v.Y * 0.45)
	end
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	local point = if result then result.Position else ray.Origin + ray.Direction * 120
	-- Never throw backwards: if the aim is behind the character, use its facing.
	if root and (point - root.Position):Dot(root.CFrame.LookVector) < 0 then
		point = root.Position + root.CFrame.LookVector * 60
	end
	return point
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------
local function light()
	if canAct() then
		Remotes.event("Attack"):FireServer("light")
	end
end

local function heavy()
	if canAct() then
		Remotes.event("Attack"):FireServer("heavy")
	end
end

local function grab()
	if not canAct() then
		return
	end
	if grabTarget and grabTarget.Parent then
		Remotes.event("Grab"):FireServer(grabTarget)
	elseif player:GetAttribute("Holding") then
		Remotes.event("Grab"):FireServer(nil)
	end
end

local function throw()
	if canAct() and player:GetAttribute("Holding") then
		Remotes.event("Throw"):FireServer(aimPoint())
	end
end

local function dodge()
	if not canAct() or os.clock() < nextDodge then
		return
	end
	nextDodge = os.clock() + Config.DODGE_COOLDOWN
	local root = rootPart()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if root and humanoid then
		local dir = humanoid.MoveDirection
		if dir.Magnitude < 0.1 then
			dir = -root.CFrame.LookVector
		end
		root.AssemblyLinearVelocity = dir.Unit * Config.DODGE_IMPULSE + Vector3.new(0, 8, 0)
	end
	Remotes.event("Dodge"):FireServer()
end

local function parry()
	if canAct() then
		Remotes.event("Parry"):FireServer()
	end
end

local function serious()
	if canAct() then
		Remotes.event("GoSerious"):FireServer()
	end
end

---------------------------------------------------------------------------
-- Input bindings
---------------------------------------------------------------------------
local KEY_ACTIONS: { [Enum.KeyCode]: () -> () } = {
	[Enum.KeyCode.E] = grab,
	[Enum.KeyCode.Q] = throw,
	[Enum.KeyCode.LeftShift] = dodge,
	[Enum.KeyCode.F] = parry,
	[Enum.KeyCode.R] = serious,
	[Enum.KeyCode.ButtonX] = light,
	[Enum.KeyCode.ButtonY] = heavy,
	[Enum.KeyCode.ButtonR1] = grab,
	[Enum.KeyCode.ButtonR2] = throw,
	[Enum.KeyCode.ButtonL1] = parry,
	[Enum.KeyCode.ButtonL2] = serious,
}

local function bindInputs()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			light()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			heavy()
		elseif input.KeyCode == Enum.KeyCode.ButtonB and not Router.isOpen() then
			dodge()
		else
			local fn = KEY_ACTIONS[input.KeyCode]
			if fn then
				fn()
			end
		end
	end)
end

local function buildTouchButtons()
	if not UserInputService.TouchEnabled then
		return
	end
	local pad = UI.new("Frame", {
		Name = "TouchPad",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -110),
		Size = UDim2.fromOffset(260, 220),
		Parent = screenRoot,
	})
	local function button(label: string, pos: UDim2, size: number, variant: UI.ButtonVariant, fn: () -> ()): TextButton
		local b = UI.bigButton(label, variant, fn, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = pos,
			Size = UDim2.fromOffset(size, size),
			FontFace = Theme.Font.Display,
			TextSize = Theme.TextSize.Heading,
			Parent = pad,
		})
		return b
	end
	-- Attack: tap = light, hold = heavy.
	local attack = button("HIT", UDim2.new(1, -50, 1, -50), 96, "primary", function() end)
	attack.MouseButton1Down:Connect(function()
		heavyHoldStart = os.clock()
	end)
	attack.MouseButton1Up:Connect(function()
		local held = heavyHoldStart and os.clock() - heavyHoldStart or 0
		heavyHoldStart = nil
		if held >= 0.35 then
			heavy()
		else
			light()
		end
	end)
	button("GRAB", UDim2.new(1, -150, 1, -30), 60, "secondary", grab)
	button("THROW", UDim2.new(1, -140, 1, -100), 60, "secondary", throw)
	button("DODGE", UDim2.new(1, -60, 1, -150), 60, "secondary", dodge)
	button("PARRY", UDim2.new(1, -130, 1, -170), 60, "secondary", parry)
	button("R", UDim2.new(1, -210, 1, -140), 50, "primary", serious)
end

---------------------------------------------------------------------------
-- Grab targeting
---------------------------------------------------------------------------
local function grabbable(p: BasePart, root: BasePart): boolean
	local props = Workspace:FindFirstChild("Props")
	if p.Parent ~= props or p:GetAttribute("InFlight") then
		return false
	end
	local owner = p:GetAttribute("StoreOwner")
	if typeof(owner) == "number" and owner ~= player.UserId then
		return false
	end
	return (p.Position - root.Position).Magnitude <= Config.GRAB_RANGE + p.Size.Magnitude / 2
end

local function updateGrabTarget()
	local root = rootPart()
	local best: BasePart? = nil
	if root and canAct() then
		local bestDist = math.huge
		for _, inst in CollectionService:GetTagged("Prop") do
			if inst:IsA("BasePart") and grabbable(inst, root) then
				local d = (inst.Position - root.Position).Magnitude
				if d < bestDist then
					best, bestDist = inst, d
				end
			end
		end
	end
	grabTarget = best
	highlight.Adornee = best
	highlight.Enabled = best ~= nil
	grabTag.Adornee = best
	grabTag.Enabled = best ~= nil
	if best then
		local def = Config.PROPS[best:GetAttribute("PropId") :: string]
		local label = grabTag:FindFirstChild("Label") :: TextLabel
		label.Text = string.format("E  %s", if def then string.upper(def.name) else "GRAB")
	end
end

---------------------------------------------------------------------------
-- Procedural swings (replaced by real animations later)
---------------------------------------------------------------------------
local function shoulderOf(character: Model): Motor6D?
	local arm = character:FindFirstChild("RightUpperArm")
	local m = arm and arm:FindFirstChild("RightShoulder")
	if not m then
		local torso = character:FindFirstChild("Torso")
		m = torso and torso:FindFirstChild("Right Shoulder")
	end
	return if m and m:IsA("Motor6D") then m else nil
end

local function swingArm(character: Model, heavyMove: boolean, throwMove: boolean?)
	local motor = shoulderOf(character)
	if not motor then
		return
	end
	if motor:GetAttribute("RestC0") == nil then
		motor:SetAttribute("RestC0", motor.C0)
	end
	local rest = motor:GetAttribute("RestC0") :: CFrame
	local windup = if heavyMove then rest * CFrame.Angles(math.rad(150), 0, math.rad(-20)) else rest * CFrame.Angles(math.rad(70), 0, 0)
	local strike = rest * CFrame.Angles(math.rad(-50), math.rad(if throwMove then 0 else 30), 0)
	local t1 = if heavyMove then 0.12 else 0.05
	local tw1 = TweenService:Create(motor, TweenInfo.new(t1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = windup })
	tw1:Play()
	tw1.Completed:Once(function()
		local tw2 = TweenService:Create(motor, TweenInfo.new(0.08, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { C0 = strike })
		tw2:Play()
		tw2.Completed:Once(function()
			TweenService:Create(motor, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = rest }):Play()
		end)
	end)
end

---------------------------------------------------------------------------
-- Screen effects
---------------------------------------------------------------------------
local function impactFlash(color: Color3, strength: number)
	if Motion.reduced() then
		return
	end
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 1 - strength
	flash.Visible = true
	task.delay(1 / 30, function()
		TweenService:Create(flash, TweenInfo.new(0.08), { BackgroundTransparency = 1 }):Play()
	end)
end

local shakeUntil = 0
local shakeAmount = 0
local function shake(amount: number, seconds: number)
	if Motion.reduced() then
		return
	end
	shakeAmount = math.max(shakeAmount, amount)
	shakeUntil = math.max(shakeUntil, os.clock() + seconds)
end

local function worldText(position: Vector3, text: string, color: Color3, size: number, rise: number?)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.1
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = Workspace
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 60)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.FontFace = Theme.Font.Display
	label.TextSize = size
	label.TextColor3 = color
	label.TextStrokeColor3 = C.Paper
	label.TextStrokeTransparency = 0
	label.Parent = gui
	local goal = position + Vector3.new(math.random(-10, 10) / 10, rise or 3, 0)
	TweenService:Create(anchor, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(goal) }):Play()
	TweenService:Create(label, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.45), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 0.9)
end

local function headPos(model: Instance?): Vector3?
	if not model or not model:IsA("Model") then
		return nil
	end
	local head = model:FindFirstChild("Head") :: BasePart?
	if head then
		return head.Position + Vector3.new(0, 1.5, 0)
	end
	return model:GetPivot().Position + Vector3.new(0, 3, 0)
end

local function flashModel(model: Instance?, color: Color3)
	if not model or not model:IsA("Model") then
		return
	end
	local h = Instance.new("Highlight")
	h.FillColor = color
	h.FillTransparency = 0.2
	h.OutlineColor = C.Ink
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = model
	h.Parent = model
	TweenService:Create(h, TweenInfo.new(0.15), { FillTransparency = 1 }):Play()
	Debris:AddItem(h, 0.2)
end

local function debris(position: Vector3, color: Color3)
	for _ = 1, 6 do
		local p = Instance.new("Part")
		p.Size = Vector3.one * (math.random(15, 35) / 100)
		p.Color = color
		p.CanCollide = false
		p.CanQuery = false
		p.CFrame = CFrame.new(position)
		p.AssemblyLinearVelocity = Vector3.new(math.random(-20, 20), math.random(10, 30), math.random(-20, 20))
		p.Parent = Workspace
		Debris:AddItem(p, 1)
	end
end

local function setSpeedLines(on: boolean)
	speedLines.Visible = on and not Motion.reduced()
end

---------------------------------------------------------------------------
-- CombatFx handler
---------------------------------------------------------------------------
local function isMe(model: any): boolean
	return model ~= nil and model == player.Character
end

local function onFx(p: any)
	if typeof(p) ~= "table" then
		return
	end
	local kind = p.kind
	if kind == "swing" then
		if typeof(p.attacker) == "Instance" and p.attacker:IsA("Model") then
			swingArm(p.attacker, p.move == "heavy")
		end
		if isMe(p.attacker) then
			Sound.play(if p.move == "heavy" then "swing_heavy" else "swing_light")
		end
	elseif kind == "hit" then
		flashModel(p.target, if p.serious then C.Red else C.Paper)
		if isMe(p.attacker) then
			Sound.play(if p.heavy then "hit_heavy" else "hit_light")
			impactFlash(if p.serious then C.Red else C.Paper, if p.heavy then 0.35 else 0.15)
			shake(if p.heavy then 0.35 else 0.12, 0.08)
		end
	elseif kind == "dmg" then
		local pos = headPos(p.target)
		if pos then
			worldText(pos, tostring(p.amount), C.Ink, 26)
		end
	elseif kind == "throw" then
		if typeof(p.attacker) == "Instance" and p.attacker:IsA("Model") then
			swingArm(p.attacker, false, true)
		end
		if isMe(p.attacker) then
			Sound.play("throw")
		end
	elseif kind == "break" then
		if typeof(p.pos) == "Vector3" then
			debris(p.pos, C.Ink)
			worldText(p.pos, "BREAK", C.Ink, 20, 2)
		end
		Sound.play("prop_break")
	elseif kind == "dodge" then
		if isMe(p.attacker) then
			Sound.play("dodge")
		end
	elseif kind == "perfect" then
		local pos = headPos(p.attacker)
		if pos then
			worldText(pos, "PERFECT", C.Red, 30)
		end
		if isMe(p.attacker) then
			impactFlash(C.Paper, 0.25)
		end
	elseif kind == "parry" then
		if isMe(p.attacker) then
			Sound.play("ui_tab")
		end
	elseif kind == "parried" then
		local pos = headPos(p.attacker)
		if pos then
			worldText(pos, "PARRY", C.Ink, 28)
		end
		Sound.play("hit_heavy")
	elseif kind == "catch" then
		local pos = headPos(p.attacker)
		if pos then
			worldText(pos, "CAUGHT", C.Red, 32)
		end
		if isMe(p.attacker) then
			Sound.play("catch")
			impactFlash(C.Red, 0.25)
		end
	elseif kind == "hurt" then
		flashModel(p.target, C.Red)
		if isMe(p.target) then
			impactFlash(C.Red, 0.3)
			shake(0.4, 0.12)
			Sound.play("hit_heavy")
		end
	elseif kind == "ko" then
		local pos = headPos(p.target)
		if pos and not isMe(p.target) then
			worldText(pos, if p.boss then "BOSS K.O." else "K.O.", C.Red, 44, 4)
		end
		Sound.play("ko")
	elseif kind == "serious" then
		if isMe(p.attacker) then
			setSpeedLines(p.on == true)
			if p.on then
				impactFlash(C.Red, 0.5)
				shake(0.3, 0.2)
				Sound.play("serious_on")
			else
				Sound.play("serious_off")
			end
		end
		local pos = headPos(p.attacker)
		if pos and p.on then
			worldText(pos, "SERIOUS", C.Red, 40, 5)
		end
	elseif kind == "reveal" then
		local pos = headPos(p.attacker)
		if pos then
			worldText(pos, "!?", C.Red, 48, 2)
		end
		Sound.play("ui_error")
	elseif kind == "enrage" then
		local pos = headPos(p.attacker)
		if pos then
			worldText(pos, "ENRAGED", C.Danger, 40, 4)
		end
	elseif kind == "enemySwing" or kind == "enemyThrow" then
		if typeof(p.attacker) == "Instance" and p.attacker:IsA("Model") then
			swingArm(p.attacker, kind == "enemySwing", kind == "enemyThrow")
		end
	elseif kind == "cleanup" then
		if typeof(p.pos) == "Vector3" then
			debris(p.pos, C.Paper)
		end
	elseif kind == "restock" then
		Sound.play("restock")
		if typeof(p.pos) == "Vector3" then
			worldText(p.pos + Vector3.new(0, 4, 0), "RESTOCKED", C.Ink, 24)
		end
	elseif kind == "register" then
		Sound.play("register")
		if typeof(p.pos) == "Vector3" then
			worldText(p.pos + Vector3.new(0, 3, 0), "+" .. Config.CURRENCY_CODE .. tostring(p.cash or 0), C.Ink, 30)
		end
	end
end

---------------------------------------------------------------------------
-- Enemy wind-up tells
---------------------------------------------------------------------------
local tells: { [Model]: BillboardGui } = {}

local function tellFor(model: Model): BillboardGui
	local gui = tells[model]
	if gui and gui.Parent then
		return gui
	end
	local made = Instance.new("BillboardGui")
	made.Name = "Tell"
	made.Size = UDim2.fromOffset(60, 60)
	made.StudsOffset = Vector3.new(0, 3.2, 0)
	made.AlwaysOnTop = true
	made.LightInfluence = 0
	made.Enabled = false
	local head = model:FindFirstChild("Head")
	made.Adornee = if head and head:IsA("BasePart") then head else model.PrimaryPart
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "!"
	label.FontFace = Theme.Font.Display
	label.TextScaled = true
	label.TextColor3 = C.Red
	label.TextStrokeColor3 = C.Paper
	label.TextStrokeTransparency = 0
	label.Parent = made
	made.Parent = model
	tells[model] = made
	return made
end

local function updateTells()
	local folder = Workspace:FindFirstChild("Enemies")
	if not folder then
		return
	end
	local t = now()
	for _, model in folder:GetChildren() do
		if model:IsA("Model") then
			local w = model:GetAttribute("WindupUntil")
			local active = typeof(w) == "number" and w > t
			if active or tells[model] then
				tellFor(model).Enabled = active
			end
		end
	end
	for model in tells do
		if not model.Parent then
			tells[model] = nil
		end
	end
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------
function Combat.init(root: Frame)
	screenRoot = root

	flash = UI.block(C.Paper, {
		Name = "ImpactFlash",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 50,
		Parent = root,
	})

	-- Serious speed lines: thin ink slashes radiating from the edges.
	speedLines = UI.new("Frame", { Name = "SpeedLines", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 0, Parent = root })
	local rng = Random.new(7)
	for i = 1, 36 do
		local angle = (i / 36) * math.pi * 2
		local r = 0.55
		UI.block(C.Red, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + math.cos(angle) * r, 0.5 + math.sin(angle) * r),
			Size = UDim2.fromOffset(rng:NextInteger(140, 260), rng:NextInteger(2, 4)),
			Rotation = math.deg(angle),
			BackgroundTransparency = 0.35,
			Parent = speedLines,
		})
	end

	highlight = Instance.new("Highlight")
	highlight.Name = "GrabHighlight"
	highlight.FillTransparency = 1
	highlight.OutlineColor = C.Red
	highlight.Enabled = false
	highlight.Parent = Workspace

	grabTag = Instance.new("BillboardGui")
	grabTag.Name = "GrabTag"
	grabTag.ResetOnSpawn = false -- PlayerGui resets on respawn; keep the tag alive
	grabTag.Size = UDim2.fromOffset(200, 28)
	grabTag.StudsOffset = Vector3.new(0, 1.8, 0)
	grabTag.AlwaysOnTop = true
	grabTag.LightInfluence = 0
	grabTag.Enabled = false
	local tagLabel = Instance.new("TextLabel")
	tagLabel.Name = "Label"
	tagLabel.Size = UDim2.fromScale(1, 1)
	tagLabel.BackgroundColor3 = C.Paper
	tagLabel.BorderSizePixel = 0
	tagLabel.FontFace = Theme.Font.MonoBold
	tagLabel.TextSize = 14
	tagLabel.TextColor3 = C.Ink
	tagLabel.AutomaticSize = Enum.AutomaticSize.X
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.Line
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = tagLabel
	tagLabel.Parent = grabTag
	grabTag.Parent = player:WaitForChild("PlayerGui")

	bindInputs()
	buildTouchButtons()
	Remotes.event("CombatFx").OnClientEvent:Connect(onFx)

	player.CharacterAdded:Connect(function()
		setSpeedLines(false)
	end)

	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc >= 0.1 then
			acc = 0
			updateGrabTarget()
		end
		updateTells()
		if os.clock() < shakeUntil then
			local a = shakeAmount
			camera.CFrame *= CFrame.new(math.random(-100, 100) / 100 * a, math.random(-100, 100) / 100 * a, 0)
		else
			shakeAmount = 0
		end
	end)

end

return Combat
