--!strict
-- DistrictService: where each player is, travel between their store and the
-- districts, and boss clears. A district opens once the player's best bounty
-- reaches Config.DISTRICTS[*].bounty (Stats.districtUnlocked).
-- The "Area" player attribute (district code or "Store") is what enemy and
-- prop spawning read to know where players are.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local RateLimit = require(Shared.RateLimit)
local Stats = require(Shared.Stats)

local DistrictService = {}

local deps: any = {}
local lastTravel: { [Player]: number } = {}

local function toast(player: Player, payload: any)
	Remotes.event("Toast"):FireClient(player, payload)
end

function DistrictService.travel(player: Player, code: string): boolean
	local data = deps.Data.get(player)
	local character = player.Character
	if not data or not character then
		return false
	end
	local t = os.clock()
	if lastTravel[player] and t - lastTravel[player] < Config.TRAVEL_COOLDOWN then
		return false
	end

	if code == "Store" then
		lastTravel[player] = t
		deps.Prop.drop(player)
		character:PivotTo(deps.Store.spawnCFrame(player))
		return true
	end

	local def = Config.getDistrict(code)
	local refs = deps.World.district(code)
	if not def or not refs then
		return false
	end
	if not Stats.districtUnlocked(data, code) then
		toast(player, { kind = "error", title = "Not yet", body = string.format("%s opens at a bounty of %s.", def.name, Format.commas(def.bounty)) })
		return false
	end
	lastTravel[player] = t
	deps.Prop.drop(player)
	character:PivotTo(refs.spawn.CFrame + Vector3.new(0, 4, 0))
	player:SetAttribute("Area", code)
	toast(player, { kind = "info", title = def.code .. "  " .. def.name, body = def.blurb })
	deps.Quest.notify(player, "visit:" .. code)
	deps.Analytics.funnel(player, "FirstDistrict")
	return true
end

function DistrictService.bossBeaten(player: Player, code: string)
	local data = deps.Data.get(player)
	local def = Config.getDistrict(code)
	if not data or not def then
		return
	end
	local first = not data.bossesBeaten[code]
	data.bossesBeaten[code] = true
	if first then
		deps.Analytics.progression(player, Config.districtIndex(code), "Complete")
	end
	deps.Data.changed(player)
	Remotes.event("Banner"):FireClient(player, { kind = "DistrictCleared", district = code, boss = def.boss.name, first = first })
end

local function trackAreas()
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local area = deps.World.areaAt(root.Position)
			if player:GetAttribute("Area") ~= area then
				player:SetAttribute("Area", area)
			end
		end
	end
end

function DistrictService.init(dependencies: any)
	deps = dependencies

	Remotes.event("TravelToDistrict").OnServerEvent:Connect(function(player: Player, code: any)
		if not RateLimit.check(player, "TravelToDistrict") or typeof(code) ~= "string" then
			return
		end
		DistrictService.travel(player, code)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastTravel[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(0.5)
			pcall(trackAreas)
		end
	end)
end

return DistrictService
