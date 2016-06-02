local skynet = require "skynet"
local GS_CONST = require "define.gsConst"
local pbServiceHelper = require "serviceHelper.pb"
local ServerUserItem = require "sui"
local addressResolver = require "addressResolver"

local function doProtocalAgent(tcpAgent, pbObj, tcpAgentData, protocalNo)
	local userItem = assert(
		skynet.call(addressResolver.getAddressByServiceName("GS_model_userManager"), "lua", "getUserItem", tcpAgentData.userID),
		string.format("%s: 无法获取用户信息", SERVICE_NAME)
	)
	
	local userAttr = ServerUserItem.getAttribute(userItem, {"tableID", "chairID", "userStatus"})
	if userAttr.tableID == GS_CONST.INVALID_TABLE or userAttr.tableID == GS_CONST.INVALID_CHAIR then
		error(string.format("%s: 桌子号或椅子号错误", SERVICE_NAME))
	end
	
	if userAttr.userStatus == GS_CONST.USER_STATUS.US_LOOKON then
		return
	end
	
	local tableAddress = addressResolver.getTableAddress(userAttr.tableID)
	if not tableAddress then
		error(string.format("%s: 找不到桌子No.%d", SERVICE_NAME, userAttr.tableID))
	end
	
	skynet.call(tableAddress, "lua", "gameMessage", userAttr.chairID, userItem, protocalNo, pbObj)
end


local REQUEST = {
	-- 下注
	[0x030000] = function(tcpAgent, pbObj, tcpAgentData) doProtocalAgent(tcpAgent, pbObj, tcpAgentData, 0x030000) end,
	-- 申请上庄
	[0x030001] = function(tcpAgent, pbObj, tcpAgentData) doProtocalAgent(tcpAgent, pbObj, tcpAgentData, 0x030001) end,
	-- 取消申请
	[0x030002] = function(tcpAgent, pbObj, tcpAgentData) doProtocalAgent(tcpAgent, pbObj, tcpAgentData, 0x030002) end,
}

local conf = {
	sessionCheck = true,
	protocalHandlers = REQUEST,
}

pbServiceHelper.createService(conf)
