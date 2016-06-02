local skynet = require "skynet"
local pbServiceHelper = require "serviceHelper.pb"
local addressResolver = require "addressResolver"


local REQUEST = {
	[0x000A00] = function(tcpAgent, pbObj, tcpAgentData)
		local re = skynet.call(addressResolver.getAddressByServiceName("LS_model_tuijianren"), "lua", "upTuijianren", tcpAgent, tcpAgentData.userID, pbObj)
		return 0x000A00, re
	end,
	[0x000A01] = function(tcpAgent, pbObj, tcpAgentData)
		local re = skynet.call(addressResolver.getAddressByServiceName("LS_model_tuijianren"), "lua", "intoTuijianren", tcpAgent, tcpAgentData.userID, tcpAgentData.sui)
		return 0x000A01, re
	end,
	[0x000A02] = function(tcpAgent, pbObj, tcpAgentData)
		local re = skynet.call(addressResolver.getAddressByServiceName("LS_model_tuijianren"), "lua", "recvBox", tcpAgent, tcpAgentData.userID, tcpAgentData.sui)
		return 0x000A02, re
	end,
	[0x000A03] = function(tcpAgent, pbObj, tcpAgentData)
		local re = skynet.call(addressResolver.getAddressByServiceName("LS_model_tuijianren"), "lua", "recvScore", tcpAgent, tcpAgentData.userID, tcpAgentData.sui)
		return 0x000A03, re
	end,
	
}

local conf = {
	loginCheck = true,
	protocalHandlers = REQUEST,
	initFunc = function()
	end,
}

pbServiceHelper.createService(conf)
