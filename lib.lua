local Lib = {}

Lib.servers = {}
Lib.clients = {}

function Lib:cleanUp()
	log("Cleaning up...")
	for _,client in ipairs(Lib.clients) do
		client:close()
	end
	for _,server in ipairs(Lib.servers) do
		server:close()
	end

	createServer = nil
	createClient = nil
	log = nil
	logWarn = nil
	logError = nil
	logDebug = nil
	MultiplayerLib = nil

	SOCKET = nil
	package.loaded["socket"] = nil
end

function Lib:init()
	SOCKET = require("socket")
	print("Multiplayer "..(love.math.random()<0.8 and "Library" or "Librarby").." loaded.")

	local l = Logger()
	Lib.logger = l
	Game.logger = l

	log = Logger.log
	logWarn = Logger.warn
	logError = Logger.error
	logDebug = Logger.debug

	-- Probably horrible but possibly needed to make sure all networking stuff is gone even if something crashes
	Utils.hook(Kristal, "errorHandler", function(orig, ...)
		pcall(self.cleanUp, self) -- Use pcall to make sure an error in the clean up doesn't cause LÖVE to explode
		return orig(...)
	end)
end

function Lib:postInit()
	Game.stage:addChild(Game.logger)
end

function Lib:unload()
	self:cleanUp()
end

function Lib:preUpdate()
	local markedAsDeadClients = {}
	local markedAsDeadServers = {}
	for _,client in ipairs(Lib.clients) do
		if client.dead then
			table.insert(markedAsDeadClients, client)
		else
			client:preUpdate()
		end
	end
	for _,server in ipairs(Lib.servers) do
		if server.dead then
			table.insert(markedAsDeadServers, server)
		else
			server:preUpdate()
		end
	end

	for _,obj in ipairs(markedAsDeadClients) do
		Utils.removeFromTable(Lib.clients, obj)
	end
	for _,obj in ipairs(markedAsDeadServers) do
		Utils.removeFromTable(Lib.servers, obj)
	end
end

function Lib:postUpdate()
	for _,client in ipairs(Lib.clients) do
		client:postUpdate()
	end
	for _,server in ipairs(Lib.servers) do
		server:postUpdate()
	end
end

function createServer()
	local s = Server()
	table.insert(Lib.servers, s)
	return s
end
Lib.createServer = createServer -- to allow Kristal.libCall("createServer") to work

function createClient()
	local c = Client()
	table.insert(Lib.clients, c)
	return c
end
Lib.createClient = createClient -- to allow Kristal.libCall("createClient") to work

MultiplayerLib = Lib
return Lib