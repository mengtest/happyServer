local skynet = require "skynet"
local netpack = require "netpack"
local socket = require "socket"

local queue = require "skynet.queue"
local protobuf = require "protobuf"
local pbcc = require "pbcc"
local pbco = require "pbco"
local pbConfig = require "pbConfig"

local xLog = require "xLog"

local WATCHDOG
local host
local send_request
local pbTest

local CMD = {}
local REQUEST = {}
local client_fd
local _attr = {}

local _criticalSection = queue()






local function sendMessage(pbNo, pbObj)
	xLog(string.format("s[%06X][%d] ", pbNo, _attr.userId or 0), pbObj)
	local pbStr, sz = pbTest:encode2netPacket(pbNo, pbObj, false)
	socket.write(client_fd, pbStr, sz)
end

function CMD.forward(pbNo, pbObj)
	sendMessage(pbNo, pbObj)
end

local function pbPacketDispatch(_, _, pbNo, pbStr)
	local responseNo, responseObj
	_criticalSection(function()	
		local pbObj = {}
		if pbStr~=nil and string.len(pbStr)>0 then
			pbObj = pbTest:decode(pbNo, pbStr)
			if not pbObj then
				skynet.error("解析协议错误")
				skynet.exit()
			end
		end
		
		xLog(string.format("r[%06X][%d] ", pbNo, _attr.userId or 0), pbObj)
		local controllerAddress = skynet.queryservice(pbConfig.deal[pbNo & 0xffff00])
		if not controllerAddress then
			skynet.error("找不到处理协议的服务")
			skynet.exit()
		end
		
		local isSuccess
		isSuccess, responseNo, responseObj = skynet.call(controllerAddress, "lua", "request", skynet.self(), pbNo, pbObj, _attr)
		if not isSuccess then
			skynet.error("返回错误")
			skynet.exit()
		end
		if responseNo~=nil then
			sendMessage(responseNo, responseObj)
		end
	end)

end

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = function (msg, sz)
		return pbcc.unpackNetPayload(msg, sz)
	end,
	dispatch = pbPacketDispatch,
}

function CMD.start(conf)
	local fd = conf.client
	local gate = conf.gate
	WATCHDOG = conf.watchdog
	-- slot 1,2 set at main.lua
	--pbTest = conf.pbTest

	pbTest = pbco:new(skynet.getenv("pbs_dir"))
	pbTest:config(pbConfig.client, pbConfig.server, pbConfig.file)
	client_fd = fd
	skynet.call(gate, "lua", "forward", fd)
end

function CMD.disconnect()
	-- todo: do something before exit
	skynet.exit()
end

function CMD.setAttr(attr)
	if attr.aid then
		_attr.aid = attr.aid
	end
	if attr.userId then
		_attr.userId = attr.userId
	end
	if attr.gold then
		_attr.gold = attr.gold
	end
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
end)
