local skynet = require "skynet"
local cluster = require "cluster"
local ServerUserItem = require "sui"
local commonServiceHelper = require "serviceHelper.common"
local addressResolver = require "addressResolver"
local resourceResolver = require "resourceResolver"
local GS_CONST = require "define.gsConst"
local COMMON_CONST = require "define.commonConst"
local GS_EVENT = require "define.eventGameServer"

local _serverSignature
local _LS_GSProxyAddress

local function relayMessageSystemMessage(data)
	local pbParser = resourceResolver.get("pbParser")
	local packetStr = skynet.call(pbParser, "lua", "encode", 0xff0000, data, true)
	if packetStr then
		skynet.call(addressResolver.getAddressByServiceName("GS_model_userManager"), "lua", "broadcast", packetStr)
	end
end

local function relayMessageBigTrumpet(data)
	local pbParser = resourceResolver.get("pbParser")
	local packetStr = skynet.call(pbParser, "lua", "encode", 0x010308, data, true)
	if packetStr then
		skynet.call(addressResolver.getAddressByServiceName("GS_model_userManager"), "lua", "broadcast", packetStr)
	end
end

local function lsNotifyDragonInfo(data)
	skynet.call(addressResolver.getAddressByServiceName("GS_model_tableManager"), "lua", "dragonInfo", data)
end

local function lsNotifyDragonPoolAdd(data)
	skynet.call(addressResolver.getAddressByServiceName("GS_model_tableManager"), "lua", "dragonPoolAdd", data)
end

local function lsNotifyLoginOtherServer(data)
	skynet.call(addressResolver.getAddressByServiceName("GS_model_userManager"), "lua", "kickUser", data.userID, "对不起，您的帐号在其他地方登录，您被迫下线")
end

local function lsNotifyChangeUserScore(data)
	skynet.call(addressResolver.getAddressByServiceName("GS_model_userManager"), "lua", "changeUserScore", data)
end

local function lsNotifyPayOrderConfirm(data)
	local userItem = skynet.call(addressResolver.getAddressByServiceName("GS_model_userManager"), "lua", "getUserItem", data.userID)
	if not userItem then
		return
	end
	
	local userAttr = ServerUserItem.getAttribute(userItem, {"tableID", "agent"})
	
	ServerUserItem.addAttribute(userItem, {
		score=data.score,
		contribution=data.contribution,
	})
	ServerUserItem.setAttribute(userItem, {
		memberOrder=data.memberOrder,
		userRight=data.userRight,
	})

	skynet.call(addressResolver.getAddressByServiceName("GS_model_attemperEngine"), "lua", "broadcastUserScore", userItem)

	if userAttr.agent~=0 then
		skynet.send(userAttr.agent, "lua", "forward", 0x01ff02, {
			orderID=data.orderID,
			currencyType=data.currencyType,
			currencyAmount=data.currencyAmount,
			payID=data.payID,
			score=data.score,
			memberOrder=data.memberOrder,
			userRight=data.userRight,
		})
	end
	
	local tableAddress
	if userAttr.tableID~=GS_CONST.INVALID_TABLE then
		tableAddress = addressResolver.getTableAddress(userAttr.tableID)
	end
	
	if tableAddress then
		skynet.call(tableAddress, "lua", "onUserScoreNotify", userItem)
	end
end

local function processLSNotify(msgNo, msgBody)
	if msgNo==COMMON_CONST.LSNOTIFY_EVENT.EVT_LSNOTIFY_USER_LOGIN_OTHER_SERVER then
		lsNotifyLoginOtherServer(msgBody)
	elseif msgNo==COMMON_CONST.LSNOTIFY_EVENT.EVT_LSNOTIFY_PAY_ORDER_CONFIRM then
		lsNotifyPayOrderConfirm(msgBody)
	elseif msgNo==COMMON_CONST.LSNOTIFY_EVENT.dragonPoolAdd then
		lsNotifyDragonPoolAdd(msgBody)
	elseif msgNo==COMMON_CONST.LSNOTIFY_EVENT.dragonInfo then
		lsNotifyDragonInfo(msgBody)
	elseif msgNo==COMMON_CONST.LSNOTIFY_EVENT.changeUserScore then
		lsNotifyChangeUserScore(msgBody)
	else
		error(string.format("%s: 不能识别的登录服务推送消息", SERVICE_NAME))
	end
end

local function processRelayMessage(msgNo, msgBody)
	if msgNo==COMMON_CONST.RELAY_MESSAGE_TYPE.RMT_SYSTEM_MESSAGE then
		relayMessageSystemMessage(msgBody)
	elseif msgNo==COMMON_CONST.RELAY_MESSAGE_TYPE.RMT_BIG_TRUMPET then
		relayMessageBigTrumpet(msgBody)
	else
		error(string.format("%s: 不能识别的转发消息", SERVICE_NAME))
	end
end

local function doPulling()
	local list = cluster.call("loginServer", _LS_GSProxyAddress, "gs_pull", _serverSignature.serverID, _serverSignature.sign)
--[[	
	do
		local jsonUtil = require "cjson.util"
		skynet.error(string.format("%s %d\n%s", SERVICE_NAME, skynet.now(), jsonUtil.serialise_value(list)))
	end
--]]	
	for _, item in ipairs(list) do
		if (item.msgNo & COMMON_CONST.LSNOTIFY_EVENT_MASK)~=0 then
			processLSNotify(item.msgNo, item.msgData)
		elseif (item.msgNo & COMMON_CONST.RELAY_MESSAG_MASK)~=0 then
			processRelayMessage(item.msgNo, item.msgData)
		else
			error(string.format("%s: 不能识别的消息类型", SERVICE_NAME))
		end
	end
end

local function cmd_onEventServerRegisterSuccess(data)
	local isPullingStarted = _serverSignature~=nil
	
	_serverSignature = data
	
	if not isPullingStarted then
		skynet.fork(function()
			while true do
				local isSuccess, errMsg = pcall(doPulling)
				if not isSuccess then
					skynet.error(string.format("%s 连接登录服务器失败: %s", SERVICE_NAME, tostring(errMsg)))
					skynet.sleep(1000)
				end	
			end
		end)
	end
end


local conf = {
	methods = {
		["onEventServerRegisterSuccess"] = {["func"]=cmd_onEventServerRegisterSuccess, ["isRet"]=false},
	},
	initFunc = function()
		_LS_GSProxyAddress = cluster.query("loginServer", "LS_model_GSProxy")
		resourceResolver.init()
		skynet.send(addressResolver.getAddressByServiceName("eventDispatcher"), "lua", "addEventListener", GS_EVENT.EVT_GS_SERVER_REGISTER_SUCCESS, skynet.self(), "onEventServerRegisterSuccess")
	end,
}

commonServiceHelper.createService(conf)
