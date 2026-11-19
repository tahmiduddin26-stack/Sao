--!strict
-- SettingsService: validates and stores per-profile player settings.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local RateLimit = require(Shared.RateLimit)

local SettingsService = {}

local DataService: any

-- key -> validator returning the sanitised value or nil
local VALIDATORS: { [string]: (any) -> any } = {
	reduceMotion = function(v)
		return if typeof(v) == "boolean" then v else nil
	end,
	uiScale = function(v)
		return if typeof(v) == "number" and v == v then math.clamp(v, Config.UI_SCALE_MIN, Config.UI_SCALE_MAX) else nil
	end,
	panelOpacity = function(v)
		return if typeof(v) == "number" and v == v then math.clamp(v, 0.5, 1) else nil
	end,
	sfxVolume = function(v)
		return if typeof(v) == "number" and v == v then math.clamp(v, 0, 1) else nil
	end,
	musicVolume = function(v)
		return if typeof(v) == "number" and v == v then math.clamp(v, 0, 1) else nil
	end,
}

function SettingsService.init(dataService: any)
	DataService = dataService
	Remotes.event("SetSetting").OnServerEvent:Connect(function(player: Player, key: any, value: any)
		if not RateLimit.check(player, "SetSetting") then
			return
		end
		if typeof(key) ~= "string" then
			return
		end
		local validate = VALIDATORS[key]
		if not validate then
			return
		end
		local clean = validate(value)
		if clean == nil then
			return
		end
		local data = DataService.get(player)
		if not data then
			return
		end
		data.settings[key] = clean
		DataService.changed(player)
	end)
end

return SettingsService
