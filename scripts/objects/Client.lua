local Client = Class()

local log, logWarn, logError, logDebug
function Client:setLoggers()
	log = function(msg)
		Logger.log(msg, "client")
	end
	logWarn = function(msg)
		Logger.warn(msg, "client")
	end
	logError = function(msg)
		Logger.error(msg, "client")
	end
	logDebug = function(msg)
		Logger.debug(msg, "client")
	end
end

function Client:init()
	self:setLoggers()

	Logger.log("Created a client!")
	self.udp = SOCKET.udp()
	self.udp:settimeout(0)
	self.udp:setpeername("localhost", 44444)

	self.entity = tostring(love.math.random(9999))
	local dg = string.format("%s %s", self.entity, 'connect')
	logDebug("Sending packet: \""..dg.."\"")
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
			logDebug("Data received:", serverid, cmd, parms)

			if cmd == "server_connection_approved" then
				self.serverid = serverid
				log("Connection was approved by server "..serverid.."!")
			elseif cmd == "disconnect" then
				if serverid == self.serverid then
					log("Server has disconnected the client. Reason: "..parms)
					self:close()
					break -- needed as udp:receive() goes insane and cause an infinite loop otherwise after closing the socket
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
				logWarn("Connection failure: Timeout.")
				self:close()
				return
			end

			local dg = string.format("%s %s", self.entity, 'connect')
			logDebug("Sending packet: \""..dg.."\"")
			self.udp:send(dg)
		end
	end
end

function Client:send(cmd, ...)
	local parms = table.concat({...}, " ")
	local dg = string.format("%s %s %s", self.entity, cmd, parms)
	logDebug("Sending packet: \""..dg.."\"")
	self.udp:send(dg)
end

function Client:close()
	Logger.log("Closing client!")
	self.udp:close()
	self.dead = true
end

return Client