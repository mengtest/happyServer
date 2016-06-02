root_dir = "."

thread = 4
logger = root_dir.."/server1/log/loginserver.log"
daemon = root_dir.."/server1/log/loginserver.pid"
harbor = 0
start = "mainLoginServer"
bootstrap = "snlua bootstrap"

cluster = root_dir.."/server1/clustername.lua"
pbs_dir = root_dir.."/server1/pbs"
lualoader = root_dir.."/lualib/loader.lua"
cpath = root_dir.."/cservice/?.so"
lua_cpath = root_dir.."/server1/luaclib/?.so;"..root_dir.."/luaclib/?.so"
luaservice = root_dir.."/server1/service/loginServer/?.lua;"..root_dir.."/server1/service/?.lua;"..root_dir.."/service/?.lua"
lua_path = root_dir.."/server1/lualib/?.lua;"..root_dir.."/lualib/?.lua"

resManager_pbParserPoolSize = 3
resManager_wordFilterPoolSize = 1

tcpGatewayTimeoutThreshold = 12
tcpGatewayTimeoutCheckInterval = 5

port = 5000
address = "0.0.0.0"

httpPort = 2002
httpAddress = "0.0.0.0"
httpWorkerPoolSize = 3
httpInterfaceAllowIPList = "192.168.0.71,192.168.0.1,192.168.0.44,192.168.0.143"

uniformPlatformServerKey = "1015:1:726871d1de79c3fbdca09a930469ad72;1015:2:c4ca4238a0b923820dcc509a6f75849b;"

mysqlHost = "127.0.0.1"
mysqlUser = "root"
mysqlPassword = "vmware"
mysqlDataBase = "QPAccountsDB"
mysqlPoolSize = 3
mysqlConnectionTimeOut = 14400

sessionLifeTime = 21600				-- six hours
sessionCheckInterval = 600			-- 10 minutes

serverManagerTickerStep = 1000				-- 10 seconds
serverManagerTimerInterval = 1				-- 30 seconds
serverManagerTimeoutThreshold = 20			-- 40 seconds

telnetPort = 2003
defenseList = root_dir.."/server/lualib/defenseList.lua"

isTest = true -- true表示测试（测试时玩家不能通过统一平台登陆充值等等），部署到正式服时请注释或false

logPath = "./log"
logLevel = "DEBUG"
