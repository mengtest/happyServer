local skynet = require "skynet"
local webServiceHelper = require "serviceHelper.web"
local addressResolver = require "addressResolver"
local jsonHttpResponseUtility = require "utility.jsonHttpResponse"
require "utility.string"
local xLog = require "xLog"

local _allowIPHash = {}

local function onlineView()
	local ret = skynet.call(addressResolver.getAddressByServiceName("LS_model_sessionManager"), "lua", "viewOnline")
	return jsonHttpResponseUtility.getResponse({isSuccess=true, data=ret})
end

local function onlineQuery(post)
	local uidlist = post.uidlist
	if type(uidlist)~="string" or string.len(uidlist)==0 then
		return jsonHttpResponseUtility.getSimpleResponse(false, "invalid argument")
	end
	
	local userIDList = {}
	local temp = uidlist:split(",")
	for _, v in pairs(temp) do
		local iv = math.tointeger(v)
		if iv ~= nil then
			table.insert(userIDList, iv)
		end
	end
	
	if #userIDList==0 then
		return jsonHttpResponseUtility.getSimpleResponse(false, "no userID specified")
	end
	
	local ret = skynet.call(addressResolver.getAddressByServiceName("LS_model_sessionManager"), "lua", "checkOnline", userIDList)
	return jsonHttpResponseUtility.getResponse({isSuccess=true, data=ret})
end

local function ping()
	return jsonHttpResponseUtility.getResponse({isSuccess=true})
end

local CMD = {}
function CMD.interface(param)
	if string.lower(param.method) ~= "post" then
		return jsonHttpResponseUtility.getSimpleResponse(false, "request method not support")
	end	
	
	if not _allowIPHash[param.ipAddr] then
		return 403
	end
		xLog("recv from tongyi:", param.post)
	
	local isSuccess, msg
	local requestType = param.post.type
	if requestType=="onlineQuery" then
		return onlineQuery(param.post)
	elseif requestType=="ping" then
		return ping()
	elseif requestType=="onlineView" then
		return onlineView()
	elseif requestType == "changeLoveliness" then --魅力值变更
		isSuccess, msg = skynet.call(addressResolver.getAddressByServiceName("LS_model_pay"), "lua", "changeLoveliness", param.post)
	elseif requestType == "changePresent" then --礼券变更
		isSuccess, msg = skynet.call(addressResolver.getAddressByServiceName("LS_model_pay"), "lua", "changePresent", param.post)
	elseif requestType == "changeGold" then --金币变更
		isSuccess, msg = skynet.call(addressResolver.getAddressByServiceName("LS_model_pay"), "lua", "changeGold", param.post)
	elseif requestType == "presentToItem" then --礼券换实物
		isSuccess, msg = skynet.call(addressResolver.getAddressByServiceName("LS_model_pay"), "lua", "presentToItem", param.post)
	else
		return jsonHttpResponseUtility.getSimpleResponse(false, "unknown request type")
	end
	if isSuccess then
		xLog("send to tongyi:true")
		return jsonHttpResponseUtility.getSimpleResponse(true)
	else
		xLog("send to tongyi:"..msg)
		return jsonHttpResponseUtility.getSimpleResponse(false, msg)
	end
end

local conf = {
	methods = CMD,
	initFunc = function() 
		local allowIPList = skynet.getenv("httpInterfaceAllowIPList")
		if type(allowIPList)~="string" then
			error(string.format("invalid config entry httpInterfaceAllowIPList: %s", tostring(allowIPList)))
		end
		
		local ipList = allowIPList:split(",")
		for _, ip in pairs(ipList) do
			_allowIPHash[ip] = true
		end
	end,
}

webServiceHelper.createService(conf)
