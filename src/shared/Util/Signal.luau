--!strict
-- Tiny pure-Luau signal (no BindableEvent allocation, handlers run in their own thread).

export type Connection = { Disconnect: (self: Connection) -> (), Connected: boolean }

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} :: { [any]: (...any) -> () } }, Signal)
end

function Signal:Connect(fn: (...any) -> ())
	local key = {}
	self._handlers[key] = fn
	local handlers = self._handlers
	local connection = { Connected = true }
	function connection.Disconnect(conn)
		conn.Connected = false
		handlers[key] = nil
	end
	return connection
end

function Signal:Fire(...: any)
	for _, fn in self._handlers do
		task.spawn(fn, ...)
	end
end

function Signal:DisconnectAll()
	table.clear(self._handlers)
end

return Signal
