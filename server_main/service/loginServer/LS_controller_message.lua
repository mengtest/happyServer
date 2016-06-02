local skynet = require "skynet"
local pbServiceHelper = require "serviceHelper.pb"
local addressResolver = require "addressResolver"

local REQUEST = {
	[0x000302] = function(tcpAgent, pbObj, tcpAgentData)
		skynet.send(addressResolver.getAddressByServiceName("LS_model_message"), "lua", "sendExchangeMessage", tcpAgent)
	end,
}

local conf = {
	loginCheck = true,
	protocalHandlers = REQUEST,
}

pbServiceHelper.createService(conf)
