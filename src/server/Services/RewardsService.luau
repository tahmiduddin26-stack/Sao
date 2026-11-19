--!strict
-- RewardsService: free rewards that bring players back.
--  * Daily streak: one claim per UTC day; missing a day restarts at 1.
--  * Playtime gifts: unlock at Config.PLAYTIME_GIFTS minutes of this session.
--    The session clock is the "SessionStart" player attribute.
--  * Codes: Config.CODES, once per profile, case-insensitive.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local RateLimit = require(Shared.RateLimit)

local RewardsService = {}

local deps: any = {}
local claimedGifts: { [Player]: { [number]: boolean } } = {}

local function toast(player: Player, payload: any)
	Remotes.event("Toast"):FireClient(player, payload)
end

local function today(): number
	return math.floor(os.time() / 86400)
end

local function grant(player: Player, reward: any, source: string): string
	local parts = {}
	if reward.cash then
		deps.Progression.addCash(player, reward.cash, "Gameplay", source)
		table.insert(parts, Config.CURRENCY_CODE .. Format.commas(reward.cash))
	end
	if reward.xp then
		deps.Progression.addXp(player, reward.xp, source)
		table.insert(parts, Format.commas(reward.xp) .. " XP")
	end
	if reward.focus then
		player:SetAttribute("Focus", Config.FOCUS_MAX)
		table.insert(parts, "Full Focus")
	end
	return table.concat(parts, "  ")
end

function RewardsService.claimDaily(player: Player): boolean
	local data = deps.Data.get(player)
	if not data or data.daily.lastDay == today() then
		return false
	end
	local day = today()
	data.daily.streak = if data.daily.lastDay == day - 1 then data.daily.streak + 1 else 1
	data.daily.lastDay = day
	local reward = Config.DAILY_REWARDS[((data.daily.streak - 1) % #Config.DAILY_REWARDS) + 1]
	local text = grant(player, reward, "DailyStreak")
	toast(player, { kind = "reward", title = string.format("Day %d streak", data.daily.streak), body = text })
	deps.Data.changed(player)
	return true
end

function RewardsService.claimGift(player: Player, index: number): boolean
	local gift = Config.PLAYTIME_GIFTS[index]
	local started = player:GetAttribute("SessionStart")
	local claimed = claimedGifts[player]
	if not gift or typeof(started) ~= "number" or not claimed or claimed[index] then
		return false
	end
	if Workspace:GetServerTimeNow() - started < gift.minutes * 60 then
		return false
	end
	claimed[index] = true
	local mask = 0
	for i in claimed do
		mask += 2 ^ (i - 1)
	end
	player:SetAttribute("GiftsClaimed", mask)
	toast(player, { kind = "reward", title = "Gift", body = grant(player, gift, "PlaytimeGift") })
	return true
end

function RewardsService.redeem(player: Player, raw: string): boolean
	local data = deps.Data.get(player)
	local code = string.upper((string.gsub(raw, "%s", "")))
	local reward = Config.CODES[code]
	if not data then
		return false
	end
	if not reward then
		toast(player, { kind = "error", title = "Unknown code", body = "Check the spelling and try again." })
		return false
	end
	if data.codes[code] then
		toast(player, { kind = "error", title = "Already used", body = "That code is already on your profile." })
		return false
	end
	data.codes[code] = true
	toast(player, { kind = "reward", title = "Code redeemed", body = grant(player, reward, "Code") })
	deps.Data.changed(player)
	return true
end

function RewardsService.init(dependencies: any)
	deps = dependencies

	Remotes.event("ClaimDaily").OnServerEvent:Connect(function(player: Player)
		if RateLimit.check(player, "ClaimDaily") then
			RewardsService.claimDaily(player)
		end
	end)
	Remotes.event("ClaimGift").OnServerEvent:Connect(function(player: Player, index: any)
		if RateLimit.check(player, "ClaimGift") and typeof(index) == "number" then
			RewardsService.claimGift(player, math.floor(index))
		end
	end)
	Remotes.event("RedeemCode").OnServerEvent:Connect(function(player: Player, code: any)
		if RateLimit.check(player, "RedeemCode") and typeof(code) == "string" and #code <= 32 then
			RewardsService.redeem(player, code)
		end
	end)

	deps.Data.Loaded:Connect(function(player: Player)
		claimedGifts[player] = {}
		player:SetAttribute("SessionStart", Workspace:GetServerTimeNow())
		player:SetAttribute("GiftsClaimed", 0)
	end)
	Players.PlayerRemoving:Connect(function(player)
		claimedGifts[player] = nil
	end)
end

return RewardsService
