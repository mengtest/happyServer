local skynet = require "skynet"
local pbServiceHelper = require "serviceHelper.pb"
local addressResolver = require "addressResolver"

local REQUEST = {
	[0x000C00] = function(tcpAgent, pbObj, tcpAgentData)
		local re = skynet.call(addressResolver.getAddressByServiceName("LS_model_dragon"), "lua", "intoDragon")
		return 0x000C00, re
	end,
	[0x000C04] = function(tcpAgent, pbObj, tcpAgentData)
		local re = skynet.call(addressResolver.getAddressByServiceName("LS_model_dragon"), "lua", "getDragonRecord")
		return 0x000C04, re
	end,
	[0x000C01] = function(tcpAgent, pbObj, tcpAgentData)
		local re = skynet.call(addressResolver.getAddressByServiceName("LS_model_activity"), "lua", "intoLoginReward", tcpAgentData.userID)
		return 0x000C01, re
	end,
	[0x000C02] = function(tcpAgent, pbObj, tcpAgentData)
		local re = skynet.call(addressResolver.getAddressByServiceName("LS_model_activity"), "lua", "getLoginOne", tcpAgentData.userID, tcpAgentData.sui)
		return 0x000C02, re
	end,
	[0x000C03] = function(tcpAgent, pbObj, tcpAgentData)
		local re = skynet.call(addressResolver.getAddressByServiceName("LS_model_activity"), "lua", "getLoginMore", tcpAgentData.userID, tcpAgentData.sui)
		return 0x000C03, re
	end,
	[0x000C05] = function(tcpAgent, pbObj, tcpAgentData)
		local re = skynet.call(addressResolver.getAddressByServiceName("LS_model_activity"), "lua", "getSkin", tcpAgentData.userID)
		return 0x000C05, re
	end,
	[0x000C06] = function(tcpAgent, pbObj, tcpAgentData)
		local re = skynet.call(addressResolver.getAddressByServiceName("LS_model_activity"), "lua", "buySkin", tcpAgentData.userID, tcpAgentData.sui, pbObj.skinId)
		return 0x000C06, re
	end,
	[0x000C07] = function(tcpAgent, pbObj, tcpAgentData)
		local re = skynet.call(addressResolver.getAddressByServiceName("LS_model_activity"), "lua", "setSkin", tcpAgentData.userID, pbObj.skinId)
		return 0x000C07, re
	end,
	[0x000C08] = function(tcpAgent, pbObj, tcpAgentData)
		local re = skynet.call(addressResolver.getAddressByServiceName("LS_model_activity"), "lua", "getLoginEgg", tcpAgentData.userID)
		return 0x000C08, re
	end,
}

local conf = {
	loginCheck = true,
	protocalHandlers = REQUEST,
}

pbServiceHelper.createService(conf)
