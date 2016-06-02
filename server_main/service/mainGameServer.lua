local skynet = require "skynet"
local cluster = require "cluster"
require "skynet.manager"
local xLog = require "xLog"

skynet.start(function()
	skynet.name(".xLogService", skynet.uniqueservice("xLogService"))
	xLog("log success")
	local game = skynet.getenv("game")
	
	skynet.uniqueservice("resourceManager")
	skynet.uniqueservice("eventDispatcher")
	skynet.uniqueservice("mysqlConnectionPool")
	local resManager = skynet.uniqueservice("resourceManager")--设置敏感词过滤器及消息编解码
	skynet.call(resManager, "lua", "initialize", "pbParser", game, tonumber(skynet.getenv("resManager_pbParserPoolSize")))
	skynet.call(resManager, "lua", "initialize", "sensitiveWordFilter", tonumber(skynet.getenv("resManager_wordFilterPoolSize")))
	skynet.uniqueservice("simpleProtocalBuffer")
	
	-- models
	skynet.uniqueservice("GS_model_LSPuller")
	local serverStatus = skynet.uniqueservice("GS_model_serverStatus")--开始读取数据库的服务器配置
	skynet.call(serverStatus, "lua", "start", tonumber(skynet.getenv("serverID")))
	local serverConfig = skynet.call(serverStatus, "lua", "getServerData")
	
	if serverConfig.TelnetPort~=0 then
		skynet.uniqueservice("telnetServer", serverConfig.TelnetPort)
	end
	
	skynet.uniqueservice("GS_model_property")
	skynet.uniqueservice("GS_model_attemperEngine")
	skynet.uniqueservice("GS_model_userManager")
	--skynet.uniqueservice("GS_model_tableManager")
	local tableManager = skynet.uniqueservice("GS_model_tableManager")
	skynet.call(tableManager, "lua", "masterInit")
	
	local androidManager = skynet.uniqueservice("GS_model_androidManager")
	skynet.send(androidManager, "lua", "start")
	
	
	-- controllers
	skynet.uniqueservice("GS_controller_login")
	skynet.uniqueservice("GS_controller_table")
	skynet.uniqueservice("GS_controller_property")
	skynet.uniqueservice("GS_controller_chat")
	skynet.uniqueservice("GS_controller_ping")
	skynet.uniqueservice(string.format("%s_controller", game))
	
	
	local tcpGateway = skynet.uniqueservice("tcpGateway")
	skynet.call(tcpGateway, "lua", "initialize", game)
	skynet.call(tcpGateway, "lua", "open" , {
		port = serverConfig.ServerPort,
		nodelay = true,
	})

	skynet.exit()
end)



