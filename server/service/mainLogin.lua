local skynet = require "skynet"
require "skynet.manager"
local xLog = require "xLog"


skynet.start(function()
	skynet.name(".xLogService", skynet.uniqueservice("xLogService"))
	skynet.uniqueservice("mysqlConnect")
	skynet.uniqueservice("ls_login")
	skynet.uniqueservice("ls_fqzs")
	skynet.uniqueservice("ls_telnet", tonumber(skynet.getenv("telnetPort")))
	xLog("log success")
	local watchdog = skynet.newservice("watchDog")
	skynet.call(watchdog, "lua", "start", {
		address = skynet.getenv("address"),
		port = skynet.getenv("port"),
		nodelay = true,
	})

	skynet.exit()
end)
