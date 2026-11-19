--!strict
-- Signal: a tiny script signal for module-to-module events on one side.

export type Connection = { Disconnect: (self: Connection) -> (), Connected: boolean }
export type Signal = {
	Connect: (self: Signal, fn: (...any) -> ()) -> Connection,
	Once: (self: Signal, fn: (...any) -> ()) -> Connection,
	Fire: (self: Signal, ...any) -> (),
	Wait: (self: Signal) -> ...any,
}

local Signal = {}
Signal.__index = Signal

function Signal.new(): Signal
	local self = setmetatable({ _handlers = {} :: { any } }, Signal)
	return (self :: any) :: Signal
end

function Signal:Connect(fn: (...any) -> ()): Connection
	local conn = { Connected = true, _fn = fn }
	local handlers = self._handlers
	function conn.Disconnect(c: any)
		if not c.Connected then
			return
		end
		c.Connected = false
		local i = table.find(handlers, c)
		if i then
			table.remove(handlers, i)
		end
	end
	table.insert(handlers, conn)
	return (conn :: any) :: Connection
end

function Signal:Once(fn: (...any) -> ()): Connection
	local conn: Connection
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end

function Signal:Fire(...: any)
	for _, conn: any in table.clone(self._handlers) do
		if conn.Connected then
			task.spawn(conn._fn, ...)
		end
	end
end

function Signal:Wait(): ...any
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

return Signal
