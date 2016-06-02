local skynet = require "skynet"
local webServiceHelper = require "serviceHelper.web"
local uniformPlatformHttpUtility = require "utility.uniformPlatformHttp"
local jsonHttpResponseUtility = require "utility.jsonHttpResponse"
local addressResolver = require "addressResolver"
require "utility.string"

local CMD = {}
function CMD.uniformpay(param)
	local isOK, appid, serverid, event = uniformPlatformHttpUtility.getUniformPlatformData(param.method, param.post)
	if not isOK then
		return jsonHttpResponseUtility.getSimpleResponse(isOK, appid)
	end

	if event.TYPE == "EVENT_PAY_ORDER_CONFIRM" then
		local isSuccess, msg = skynet.call(addressResolver.getAddressByServiceName("LS_model_pay"), "lua", "payOrderConfirm", event.DATA)
		
		if isSuccess then
			return jsonHttpResponseUtility.getSimpleResponse(true)
		else
			return jsonHttpResponseUtility.getSimpleResponse(false, msg)
		end
	else
		return jsonHttpResponseUtility.getSimpleResponse(false, "unknown event")
	end
end

function CMD.uniformother(param)
	local isOK, appid, serverid, event = uniformPlatformHttpUtility.getUniformPlatformData(param.method, param.post)
	if not isOK then
		return jsonHttpResponseUtility.getSimpleResponse(isOK, appid)
	end
	
	if event.TYPE == "EVENT_ACCOUNT_SESSION" then
		local platformID = math.tointeger(event.DATA.UserID)
		local session = event.DATA.SessionID
		local userStatus = math.tointeger(event.DATA.UserStatus)
		skynet.send(addressResolver.getAddressByServiceName("LS_model_sessionManager"), "lua", "registerSession", session, platformID, userStatus)
		return jsonHttpResponseUtility.getSimpleResponse(true)
	else
		return jsonHttpResponseUtility.getSimpleResponse(false, "unknown event")
	end
end

local conf = {
	methods = CMD,
	initFunc = function()
		local serverKeyString = skynet.getenv("uniformPlatformServerKey")
		if type(serverKeyString)~="string" then
			error(string.format("不正确的配置项 uniformPlatformServerKey: %s", tostring(serverKeyString)))
		end
		
		local hash = {}
		local list = serverKeyString:split(";")
		for _, item in pairs(list) do
			local itemPart = item:split(":")
			local appID = math.tointeger(itemPart[1])
			local serverID = math.tointeger(itemPart[2])
			local serverKey = itemPart[3]
			
			if appID==nil or serverID==nil or serverKey==nil then
				error(string.format("不正确的配置项 uniformPlatformServerKey: %s", tostring(serverKeyString)))
			end
			
			if type(hash[appID])~="table" then
				hash[appID] = {}
			end
			hash[appID][serverID] = serverKey
		end
		uniformPlatformHttpUtility.setUpServerKeyHash(hash)
	end,
}

webServiceHelper.createService(conf)
