local Client = Class()

function Client:init()
	print("Created a client!")
	self.udp = SOCKET.udp()
	self.udp:settimeout(0)
	self.udp:setpeername("localhost", 44444)

	self.entity = tostring(love.math.random(9999))
	local dg = string.format("%s %s", self.entity, 'connect')
	print("[Multiplayer Client] Sending packet: \""..dg.."\"")
	self.udp:send(dg)

	self.connection_timeout = 1200
	self.connection_retry = 3

	self.serverid = nil -- the server the client is connected to

	self.dead = false
end

function Client:preUpdate()
	local data
	repeat
		data, msg = self.udp:receive()

		if data then
			local serverid, cmd, parms = data:match("^(%S*) (%S*) (.*)")
			if serverid == nil then
				serverid, cmd, parms = data:match("^(%S*) (%S*)")
			end
			print("[Multiplayer Client] Data received:", serverid, cmd, parms)

			if cmd == "server_connection_approved" then
				self.serverid = serverid
				print("[Multiplayer Client] Connection was approved by server "..serverid.."!")
			elseif cmd == "disconnect" then
				if serverid == self.serverid then
					print("[Multiplayer Client] Server has disconnected the client. Reason: "..parms)
					self:close()
					return -- needed as udp:receive() goes insane and cause an infinite loop otherwise after closing the socket
				end
			end
		end
	until data == nil
end

function Client:postUpdate()
	if not self.serverid then
		self.connection_timeout = self.connection_timeout - DTMULT

		if self.connection_timeout <= 0 then
			self.connection_retry = self.connection_retry - 1

			if self.connection_retry <= 0 then
				print("[Multiplayer Client] Connection failure: Timeout.")
				self:close()
				return
			end

			local dg = string.format("%s %s", self.entity, 'connect')
			print("[Multiplayer Client] Sending packet: \""..dg.."\"")
			self.udp:send(dg)
		end
	end
end

function Client:send(cmd, ...)
	local parms = table.concat({...}, " ")
	local dg = string.format("%s %s %s", self.entity, cmd, parms)
	print("[Multiplayer Client] Sending packet: \""..dg.."\"")
	self.udp:send(dg)
end

function Client:close()
	print("Closing client!")
	self.udp:close()
	self.dead = true
end

return Client