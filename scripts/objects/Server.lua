local Server = Class()

local log, logWarn, logError, logDebug
function Server:setLoggers()
	log = function(msg)
		Logger.log(msg, "server")
	end
	logWarn = function(msg)
		Logger.warn(msg, "server")
	end
	logError = function(msg)
		Logger.error(msg, "server")
	end
	logDebug = function(msg)
		Logger.debug(msg, "server")
	end
end

function Server:init()
	self:setLoggers()

	Logger.log("Created a server (host)!")
	self.udp = SOCKET.udp()
	self.udp:settimeout(0)
	self.udp:setsockname('*', 44444)

	self.clients = {}
	self.nextClientID = 1

	self.serverid = love.math.random(99999)

	self.dead = false
end

function Server:connectClient(clientid, ip, port)
	if self:clientIDexists(clientid) then
		return false, "The provided Client ID already exists."
	end
	if ip == nil or port == nil then
		return false, "No IP or Port provided."
	end

	local data = {
		clientid = clientid,
		ip = ip,
		port = port,
		timeout_tracker = 0,
		game = {
			x = 0,
			y = 0,
			room = "",
			facing = "down",
		}
	}

	local id = self.nextClientID
	self.nextClientID = self.nextClientID + 1

	self.clients[id] = data

	local packet = string.format("%i %s", self.serverid, "server_connection_approved")
	logDebug("Sending packet: \""..packet.."\"")
	self.udp:sendto(packet, data.ip, data.port)
	return true
end

function Server:disconnectClient(clientid, reason)
	local id = self:findClientByClientID(clientid)
	local client = self.clients[id]
	if not client then
		logError("Tried to disconnect a client ("..clientid..") that doesn't exist.")
		return
	end
	local packet = string.format("%i %s %s", self.serverid, "disconnect", reason)
	logDebug("Sending packet: \""..packet.."\"")
	self.udp:sendto(packet, client.ip, client.port)

	self.clients[id] = nil
end

function Server:preUpdate()
	-- NOTE: ip may become an error message
	local data, ip, port = self.udp:receivefrom()
	if data then
		local entity, cmd, parms = data:match("^(%S*) (%S*) (.*)")
		if entity == nil then -- if no parms have been passed, the first match will return nil so...
			entity, cmd, parms = data:match("^(%S*) (%S*)")
		end

		local id = self:findClientByClientID(entity)
		if id then
			self.clients[id].timeout_tracker = 0
		end

		logDebug("Data received:", entity, cmd, parms)

		if cmd == "connect" then
			log(string.format("Player %s connected!", entity))
			local succ, msg = self:connectClient(entity, ip, port)
			if not succ then
				logError("An error occured during connection: "..msg)
			end
		elseif cmd == "disconnect" then
			log(string.format("Player %s left.", entity))
			self:disconnectClient(entity, "disconnect_request")
		else
			logWarn("unrecognised command:", cmd)
		end
	elseif ip ~= 'timeout' then
		logWarn("Unknown network error: "..tostring(ip))
	end

	for id,client in pairs(self.clients) do
		local timer = client.timeout_tracker
		self.clients[id].timeout_tracker = client.timeout_tracker + DTMULT

		if timer > 1200 then
			log(string.format("Player %s (%s) timeout.", id, client.clientid))
			self:disconnectClient(client.clientid, "server_declared_timeout")
		end
	end
end

function Server:postUpdate()

end

function Server:close()
	Logger.log("Closing server!")

	for id,client in pairs(self.clients) do
		self:disconnectClient(client.clientid, "server_closed")
	end

	self.udp:close()

	self.dead = true
end


----------------------------------------
---- Utils functions for the server ----
----------------------------------------

function Server:clientIDexists(clientid)
	for id,client in pairs(self.clients) do
		if client.clientid == clientid then
			return true
		end
	end
	return false
end

function Server:findClientByClientID(clientid)
	for id,client in pairs(self.clients) do
		if client.clientid == clientid then
			return id
		end
	end
	return nil
end

return Server