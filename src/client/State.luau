--!strict
-- State: client mirror of the server profile snapshot, plus a Changed signal.
-- The client never edits this; it only reads and asks the server to act.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)

local State = {}

State.data = nil :: any
State.Changed = Signal.new() -- (data)

local function apply(snapshot: any)
	if typeof(snapshot) ~= "table" then
		return
	end
	-- Floor sets arrive as arrays; turn them back into sets for easy lookup.
	local unlocked, cleared = {}, {}
	for _, id in snapshot.unlockedFloors or {} do
		unlocked[id] = true
	end
	for _, id in snapshot.clearedFloors or {} do
		cleared[id] = true
	end
	snapshot.unlockedFloors = unlocked
	snapshot.clearedFloors = cleared
	State.data = snapshot
	State.Changed:Fire(snapshot)
end

function State.init()
	Remotes.event("Snapshot").OnClientEvent:Connect(apply)
	task.spawn(function()
		while State.data == nil do
			local ok, snap = pcall(function()
				return Remotes.func("GetSnapshot"):InvokeServer()
			end)
			if ok and snap and State.data == nil then
				apply(snap)
			end
			if State.data == nil then
				task.wait(1)
			end
		end
	end)
end

function State.waitForData(): any
	while State.data == nil do
		State.Changed:Wait()
	end
	return State.data
end

-- Calls fn now (if data exists) and on every change.
function State.observe(fn: (any) -> ())
	if State.data then
		task.spawn(fn, State.data)
	end
	return State.Changed:Connect(fn)
end

return State
