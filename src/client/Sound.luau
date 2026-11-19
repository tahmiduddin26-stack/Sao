--!strict
-- Sound: plays named UI sound slots from Config.SOUNDS (plan 28).
-- Empty slots are silent, so the game runs before audio is uploaded.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI.UI)

local Sound = {}

local cache: { [string]: Sound } = {}
local lastHover = 0

local function volume(): number
	local d = State.data
	return d and d.settings and d.settings.sfxVolume or Config.DEFAULT_SETTINGS.sfxVolume
end

function Sound.play(slot: string)
	local id = (Config.SOUNDS :: any)[slot]
	if typeof(id) ~= "string" or id == "" then
		return
	end
	local s = cache[slot]
	if not s then
		local created = Instance.new("Sound")
		created.Name = slot
		created.SoundId = id
		created.Parent = SoundService
		cache[slot] = created
		s = created
	end
	assert(s)
	s.Volume = volume() * (if slot == "ui_hover" then 0.3 else 1)
	SoundService:PlayLocalSound(s)
end

function Sound.init()
	UI.onHover = function()
		local now = os.clock()
		if now - lastHover > 0.05 then
			lastHover = now
			Sound.play("ui_hover")
		end
	end
	UI.onClick = function()
		Sound.play("ui_confirm")
	end
end

return Sound
