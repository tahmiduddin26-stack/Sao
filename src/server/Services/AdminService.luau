--!strict
-- AdminService: owner and listed-ID tools for testing. Every command is
-- validated on the server; the client panel is only a convenience.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local RateLimit = require(Shared.RateLimit)

local AdminService = {}

local deps: any = {}

function AdminService.isAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if table.find(Config.ADMIN_IDS, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User and game.CreatorId == player.UserId then
		return true
	end
	local groupId = if game.CreatorType == Enum.CreatorType.Group then game.CreatorId else Config.GROUP_ID
	if groupId ~= 0 then
		local ok, rank = pcall(function()
			return player:GetRankInGroupAsync(groupId)
		end)
		if ok and rank >= Config.ADMIN_GROUP_RANK then
			return true
		end
	end
	return false
end

local function num(v: any, default: number): number
	local n = tonumber(v)
	if not n or n ~= n then
		return default
	end
	return n
end

local function rootOf(player: Player): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local COMMANDS: { [string]: (Player, any) -> () } = {
	give_xp = function(player, args)
		deps.Progression.addXp(player, math.clamp(num(args, 500), 1, 1e7), "Admin")
	end,
	give_cash = function(player, args)
		deps.Progression.addCash(player, math.clamp(num(args, 1000), 1, 1e9), "Gameplay", "Admin")
	end,
	set_level = function(player, args)
		deps.Progression.setLevel(player, num(args, 10))
	end,
	give_bounty = function(player, args)
		deps.Bounty.addBounty(player, math.clamp(num(args, 25000), 1, 1e9))
	end,
	unlock_all = function(player)
		local last = Config.DISTRICTS[#Config.DISTRICTS]
		local data = deps.Data.get(player)
		if data and data.bestBounty < last.bounty then
			deps.Bounty.addBounty(player, last.bounty - data.bounty)
		end
	end,
	full_focus = function(player)
		player:SetAttribute("Focus", Config.FOCUS_MAX)
	end,
	give_prop = function(player, args)
		if typeof(args) == "string" and Config.PROPS[args] then
			deps.Prop.giveToHand(player, args)
		end
	end,
	spawn_enemy = function(player, args)
		local root = rootOf(player)
		local id = if typeof(args) == "string" and Config.ENEMIES[args] then args else "thug"
		if root then
			local area = player:GetAttribute("Area")
			local ctx = if area == "Store" then { storeOwner = player.UserId } else { district = area }
			deps.Enemy.spawn(id, root.CFrame * CFrame.new(0, 0, -14), ctx)
		end
	end,
	advance_quest = function(player, args)
		if typeof(args) == "string" then
			deps.Quest.advance(player, args)
		end
	end,
	reset_daily = function(player)
		local data = deps.Data.get(player)
		if data then
			data.daily.lastDay = -1
			deps.Data.changed(player)
		end
	end,
	test_banner = function(player, args)
		if args == "boss" then
			local d = Config.DISTRICTS[1]
			Remotes.event("Banner"):FireClient(player, { kind = "BossIntro", name = d.boss.name, title = d.boss.title, district = d.code })
		else
			Remotes.event("Banner"):FireClient(player, { kind = "DistrictCleared", district = "D01", boss = Config.DISTRICTS[1].boss.name, first = true })
		end
	end,
}

function AdminService.init(dependencies: any)
	deps = dependencies

	local function mark(player: Player)
		task.spawn(function()
			player:SetAttribute("IsAdmin", AdminService.isAdmin(player))
		end)
	end
	Players.PlayerAdded:Connect(mark)
	for _, p in Players:GetPlayers() do
		mark(p)
	end

	Remotes.event("AdminCommand").OnServerEvent:Connect(function(player: Player, command: any, args: any)
		if not RateLimit.check(player, "AdminCommand") then
			return
		end
		if typeof(command) ~= "string" or not AdminService.isAdmin(player) then
			return
		end
		local fn = COMMANDS[command]
		if not fn then
			return
		end
		if not deps.Data.isReady(player) then
			return
		end
		print(string.format("[Admin] %s ran %s %s", player.Name, command, tostring(args)))
		fn(player, args)
	end)
end

return AdminService
