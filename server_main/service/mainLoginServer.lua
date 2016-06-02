local skynet = require "skynet"
require "skynet.manager"
local xLog = require "xLog"

skynet.start(function()
	skynet.name(".xLogService", skynet.uniqueservice("xLogService"))
	xLog("log success")
	skynet.uniqueservice("eventDispatcher")
	local resManager = skynet.uniqueservice("resourceManager")
	skynet.call(resManager, "lua", "initialize", "pbParser", "loginServer", tonumber(skynet.getenv("resManager_pbParserPoolSize")))
	
	skynet.uniqueservice("LS_controller_login")
	local tcpGateway = skynet.uniqueservice("tcpGateway")
	skynet.call(tcpGateway, "lua", "initialize", "loginServer")
	skynet.call(tcpGateway, "lua", "open" , {
		address = skynet.getenv("address"),
		port = tonumber(skynet.getenv("port")),
		nodelay = true,
	})
	
	skynet.exit()
end)
