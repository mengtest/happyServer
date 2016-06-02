local skynet = require "skynet"
local pbServiceHelper = require "serviceHelper.pb"
local addressResolver = require "addressResolver"

local REQUEST = {
	[0x000400] = function(tcpAgent, pbObj, tcpAgentData)
		skynet.send(addressResolver.getAddressByServiceName("LS_model_ranking"), "lua", "sendWealthRankingList", tcpAgent)
	end,
}

local conf = {
	loginCheck = true,
	protocalHandlers = REQUEST,
}

pbServiceHelper.createService(conf)
