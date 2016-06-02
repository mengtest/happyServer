local skynet = require "skynet"
local pbServiceHelper = require "serviceHelper.pb"
local addressResolver = require "addressResolver"


local REQUEST = {
	[0x000B00] = function(tcpAgent, pbObj, tcpAgentData)
		local re = skynet.call(addressResolver.getAddressByServiceName("LS_model_duobao"), "lua", "intoDuobao", tcpAgentData.userID)
		return 0x000B00, re
	end,
	[0x000B01] = function(tcpAgent, pbObj, tcpAgentData)
		local re = skynet.call(addressResolver.getAddressByServiceName("LS_model_duobao"), "lua", "chip", tcpAgentData.userID, tcpAgentData.sui, pbObj)
		return 0x000B01, re
	end,
}

local conf = {
	loginCheck = true,
	protocalHandlers = REQUEST,
	initFunc = function()
	end,
}

pbServiceHelper.createService(conf)
