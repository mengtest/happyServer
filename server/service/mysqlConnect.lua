local skynet = require "skynet"
local mysql = require "mysql"

local _db = nil


local CMD = {}


function CMD.query(sql)
	return _db:query(sql)
end

skynet.start(function()

	_db=mysql.connect{
		host="127.0.0.1",
		port=3301,
		database="qpgame",
		user="root",
		password="",
		max_packet_size = 1024 * 1024
	}
	if not _db then
		print("failed to connect")
		skynet.exit()
	end

	_db:query("set names utf8")
	
	skynet.dispatch("lua", function(session, source, cmd, ...)
		local f = assert(CMD[cmd])
		skynet.ret(skynet.pack(f(...)))
	end)
	
	


	--db:disconnect()
	--skynet.exit()
end)