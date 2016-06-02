rootPath = "."

thread = 4
logger = rootPath.."/server/log/login.log"
daemon = rootPath.."/server/log/login.pid"
harbor = 0
start = "mainLogin"
bootstrap = "snlua bootstrap"


cluster = rootPath.."/server/clustername.lua"
pbs_dir = rootPath.."/server/pbs"
lualoader = rootPath.."/lualib/loader.lua"
cpath = rootPath.."/cservice/?.so"
lua_cpath = rootPath.."/server/clib/?.so;"..rootPath.."/luaclib/?.so"
luaservice = rootPath.."/server/service/?.lua;"..rootPath.."/service/?.lua"
lua_path = rootPath.."/server/lib/?.lua;"..rootPath.."/lualib/?.lua"

port = 5000
address = "0.0.0.0"

telnetPort = 5001

mysqlHost = "127.0.0.1"
mysqlUser = "root"
mysqlPassword = ""
mysqlDataBase = "QPAccountsDB"
mysqlPoolSize = 3
mysqlConnectionTimeOut = 14400

logPath = "./log"
logLevel = "DEBUG"