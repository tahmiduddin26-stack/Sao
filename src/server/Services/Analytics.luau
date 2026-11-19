--!strict
-- Analytics: thin wrapper over Roblox AnalyticsService.
-- Funnel steps log once per player profile. Every call is pcall-guarded so
-- analytics can never break gameplay.

local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Analytics = {}

local DataService: any = nil

function Analytics.init(dataService: any)
	DataService = dataService
end

-- Onboarding funnel: one event per step per profile, in Config order.
function Analytics.funnel(player: Player, step: string)
	local index = table.find(Config.ONBOARDING_FUNNEL, step)
	if not index then
		return
	end
	local data = DataService and DataService.get(player)
	if not data or data.funnel[step] then
		return
	end
	data.funnel[step] = true
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, index, step)
	end)
end

function Analytics.progression(player: Player, districtIndex: number, status: "Start" | "Complete" | "Fail")
	pcall(function()
		local enumStatus = (Enum.AnalyticsProgressionType :: any)[status]
		AnalyticsService:LogProgressionEvent(player, string.format("D%02d", districtIndex), enumStatus)
	end)
end

-- flow: "Source" | "Sink"; transactionType is an Enum.AnalyticsEconomyTransactionType name.
function Analytics.economy(player: Player, flow: "Source" | "Sink", currency: string, amount: number, balance: number, transactionType: string, sku: string?)
	if amount <= 0 then
		return
	end
	pcall(function()
		local flowEnum = (Enum.AnalyticsEconomyFlowType :: any)[flow]
		local txType = (Enum.AnalyticsEconomyTransactionType :: any)[transactionType]
		AnalyticsService:LogEconomyEvent(player, flowEnum, currency, amount, balance, txType.Name, sku)
	end)
end

function Analytics.custom(player: Player, name: string, value: number?, fields: { [string]: string }?)
	pcall(function()
		AnalyticsService:LogCustomEvent(player, name, value or 1, fields)
	end)
end

return Analytics
