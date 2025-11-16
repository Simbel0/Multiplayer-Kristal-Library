local Server = Class()

function Server:init()
	print("Created a server (host)!")
	self.udp = SOCKET.udp()
	self.udp:settimeout(0)
	self.udp:setsockname('*', 44444)

	self.clients = {}
	self.nextClientID = 0

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
	print("[Multiplayer Server] Sending packet: \""..packet.."\"")
	self.udp:sendto(packet, data.ip, data.port)
	return true
end

function Server:disconnectClient(clientid, reason)
	local id = self:findClientByClientID(clientid)
	local client = self.clients[id]
	if not client then
		print("Tried to disconnect a client ("..clientid..") that doesn't exist.")
		return
	end
	local packet = string.format("%i %s %s", self.serverid, "disconnect", reason)
	print("[Multiplayer Server] Sending packet: \""..packet.."\"")
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

		print("[Multiplayer Server] Data received:", entity, cmd, parms)

		if cmd == "connect" then
			print(string.format("[Multiplayer Server] Player %s connected!", entity))
			local succ, msg = self:connectClient(entity, ip, port)
			if not succ then
				print("[Multiplayer Server] An error occured during connection: "..msg)
			end
		elseif cmd == "disconnect" then
			print(string.format("[Multiplayer Server] Player %s left.", entity))
			self:disconnectClient(entity, "disconnect_request")
		else
			print("unrecognised command:", cmd)
		end
	elseif ip ~= 'timeout' then
		error("Unknown network error: "..tostring(ip))
	end

	for id,client in pairs(self.clients) do
		local timer = client.timeout_tracker
		self.clients[id].timeout_tracker = client.timeout_tracker + DTMULT

		if timer > 1200 then
			print(string.format("[Multiplayer Server] Player %s (%s) timeout.", id, client.clientid))
			self:disconnectClient(client.clientid, "server_declared_timeout")
		end
	end
end

function Server:postUpdate()

end

function Server:close()
	print("Closing server!")

	for id,client in pairs(self.clients) do
		self:disconnectClient(client[id].clientid, "server_closed")
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