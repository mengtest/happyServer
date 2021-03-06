local skynet = require "skynet"
local socket = require "socket"
local pbcc = require "pbcc"
local queue = require "skynet.queue"
local skynetHelper = require "skynetHelper"
local addressResolver = require "addressResolver"
local resourceResolver = require "resourceResolver"
local controllerResolveConfig = require "define.controllerResolveConfig"
local commonServiceHelper = require "serviceHelper.common"
local MCClinetUtility = require "utility.mcClient"
local xLog = require "xLog"
local protobuf = require "protobuf"
local pbConfig = require "define.pbConfig"

local _fd
local _gate							-- address of tcpGateway
local _cache = {}					-- {addr, session, userID, sui}
local _event = {}					-- {disconnect }
local _heartBeatData = {}			-- {protocalNo, protocalStr}
local _criticalSection = queue()

local function sendPacket(msg, sz)
	if _fd then
		socket.write(_fd, msg, sz)
	elseif type(msg)=="userdata" then
		skynetHelper.free(msg)
	end
end

local function exit()
	--skynet.error(string.format("tcpConnection.exit: close fd=%s", tostring(_fd)))
	if _cache.session then
		skynet.send(addressResolver.getAddressByServiceName("eventDispatcher"), "lua", "dispatch", _event.disconnect, {
			session=_cache.session, 
			userID=_cache.userID, 
			agent=skynet.self(),
		})
		_cache.session = nil
	end
	
	if _gate and _fd then
		local fd = _fd
		_fd = nil
		skynet.call(_gate, "lua", "kick", fd)
	end
	
	MCClinetUtility.unsubscribeAll()
	
	skynet.exit()
end

local xLogStatus = false
local xLogGame = skynet.getenv("game")
local xLogPbConfig
local function xLogInit()
	local dir = skynet.getenv("pbs_dir")
	if xLogGame == nil then xLogGame = "loginServer" end
	xLogPbConfig = pbConfig.getConfig(xLogGame).files
	for _, v in pairs(xLogPbConfig) do
		protobuf.register_file(string.format("%s/%s", dir, v))
	end
	xLogPbConfig = pbConfig.getConfig(xLogGame).s2c
end

local function sendMessage(protocalNo, protocalObj)
	_criticalSection(function()	-- 新加，保证消息次序
	if type(protocalNo)=="string" and protocalObj==nil then
		--send net packet directly
		local pNo, pStr = pbcc.unpackNetPayload(string.sub(protocalNo, 3), string.len(protocalNo)-2)
		local pObj = {}
		local te = false
		if pStr~=nil and string.len(pStr)>0 then
			pObj, te = protobuf.decode(xLogPbConfig[pNo], pStr, string.len(pStr))
		end
		--if pNo ~= 0x020010 then
			xLog(string.format("s[%06X][%d] ", pNo, _cache.userID or 0), pObj)
		--end
		sendPacket(protocalNo)
	elseif type(protocalNo)=="number" and type(protocalObj)=="table" then
		local pbParser = resourceResolver.get("pbParser")
		local ptr, sz = skynet.call(pbParser, "lua", "encode", protocalNo, protocalObj, false)
		if ptr==nil then
			return exit()
		else
			xLog(string.format("s[%06X][%d] ", protocalNo, _cache.userID or 0), protocalObj)
			sendPacket(ptr, sz)
		end
	else
		skynet.error(string.format("%s: 不能识别的信息格式 no.=%s, obj=%s", SERVICE_NAME, tostring(protocalNo), tostring(protocalObj)))
		return exit()
	end
	end)
end


local function cmd_start(data)
	_gate = data.gateway
	_fd = data.fd
	_cache.addr = data.addr
	
	if data.type=="loginServer" then
		addressResolver.configKey(controllerResolveConfig.getConfig("loginServer"))
		local eventList = require "define.eventLoginServer"
		_event.disconnect = eventList.EVT_LS_CLIENT_DISCONNECT
		_heartBeatData.protocalNo = 0x000000
	else
		addressResolver.configKey(controllerResolveConfig.getConfig(data.type))
		addressResolver.configKey(controllerResolveConfig.getConfig("gameServer"))
		local eventList = require "define.eventGameServer"
		_event.disconnect = eventList.EVT_GS_CLIENT_DISCONNECT
		_heartBeatData.protocalNo = 0x010000
	end
	
	
	skynet.call(_gate, "lua", "forward", _fd)
end

local function cmd_forward(protocalNo, protocalObj)
	sendMessage(protocalNo, protocalObj)
end

local function cmd_forwardMultiple(msgList)
	for _, item in ipairs(msgList) do
		sendMessage(item[1], item[2])
	end
end

local function cmd_setCache(session, sui, userID)
	_cache.session = session
	_cache.sui = sui
	_cache.userID = userID
end

local function cmd_clearCache()
	_cache.session = nil
	_cache.sui = nil
	_cache.userID = nil	
end

local function pbPacketDispatch(_, _, protocalNo, pbStr)
	local responseNo, responseObj
	_criticalSection(function()	
		local pbParser = resourceResolver.get("pbParser")
		local protocalObj = {}
		if pbStr~=nil and string.len(pbStr)>0 then
			protocalObj = skynet.call(pbParser, "lua", "decode", protocalNo, pbStr)
			if not protocalObj then
				skynet.error(string.format("%s: 解析协议错误 protocalNo=0x%06X", SERVICE_NAME, protocalNo))
				return exit()
			end
		end
		
		if protocalNo == _heartBeatData.protocalNo then
			sendPacket(_heartBeatData.protocalStr)
			return
		end
		
		xLog(string.format("r[%06X][%d] ", protocalNo, _cache.userID or 0), protocalObj)
		local controllerAddress = addressResolver.getAddressByKey(protocalNo & 0xffff00)
		if not controllerAddress then
			skynet.error(string.format("%s: 找不到处理协议的服务 protocalNo=0x%06X", SERVICE_NAME, protocalNo))
			return exit()
		end
		
		local isSuccess
		isSuccess, responseNo, responseObj = skynet.call(controllerAddress, "lua", "request", skynet.self(), protocalNo, protocalObj, _cache)
		if not isSuccess then
			return exit()
		end
		if responseNo~=nil then
			sendMessage(responseNo, responseObj)
		end
	end)

end

local conf = {
	methods = {
		["start"] = {["func"]=cmd_start, ["isRet"]=false},
		["exit"] = {["func"]=function() _criticalSection(exit) end, ["isRet"]=false},
		["forward"] = {["func"]=cmd_forward, ["isRet"]=false},
		["forwardMultiple"] = {["func"]=cmd_forwardMultiple, ["isRet"]=false},
		["setCache"] = {["func"]=cmd_setCache, ["isRet"]=true},
		["clearCache"] = {["func"]=cmd_clearCache, ["isRet"]=true},
		["subscribeChannel"] = {["func"]=MCClinetUtility.subscribeChannel, ["isRet"]=false},
		["unsubscribeChannel"] = {["func"]=MCClinetUtility.unsubscribeChannel, ["isRet"]=false},
	},
	initFunc = function()
		resourceResolver.init()
		xLogInit()
		skynet.register_protocol {
			name = "wirePacketStr",
			id = skynet.PTYPE_CLIENT,
			unpack = function (msg, sz)
				return pbcc.unpackNetPayload(msg, sz)
			end,
			dispatch = pbPacketDispatch,
		}
	end,
}
commonServiceHelper.createService(conf)

