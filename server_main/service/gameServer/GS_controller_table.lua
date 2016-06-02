local skynet = require "skynet"
local pbServiceHelper = require "serviceHelper.pb"
local GS_CONST = require "define.gsConst"
local GS_EVENT = require "define.eventGameServer"
local ServerUserItem = require "sui"
local addressResolver = require "addressResolver"
local currencyUtility = require "utility.currency"

local _serverConfig

local REQUEST = {
	
	[0x010200] = function(tcpAgent, pbObj, tcpAgentData)
		if pbObj.tableID < 1 or pbObj.tableID > _serverConfig.TableCount then
			pbObj.tableID = GS_CONST.INVALID_TABLE
			pbObj.chairID = GS_CONST.INVALID_CHAIR
		end
		
		if pbObj.chairID < 1 or pbObj.chairID > _serverConfig.ChairPerTable then
			pbObj.chairID = GS_CONST.INVALID_CHAIR
		end
		
		if pbObj.tableID <= _serverConfig.TableCount and pbObj.chairID <= _serverConfig.ChairPerTable then
			local tableAddress = addressResolver.getTableAddress(pbObj.tableID)
			local tableUserItem = skynet.call(tableAddress, "lua", "getUserItem", pbObj.chairID)
			if tcpAgentData.sui==tableUserItem then
				-- 重复判断，用户已经坐在桌子上
				return
			end
		end
		
		local userAttr = ServerUserItem.getAttribute(tcpAgentData.sui, {"userStatus", "tableID", "masterOrder", "memberOrder", "score", "isAndroid", "agent"})
		if (_serverConfig.ServerRule & GS_CONST.SERVER_RULE.SR_FORFEND_GAME_ENTER) ~= 0 and userAttr.memberOrder == 0 then
			return 0x010200, {code="RC_ROOM_CONFIG_FORBID"}
		end
		
		if userAttr.userStatus == GS_CONST.USER_STATUS.US_PLAYING then
			return 0x010200, {code="RC_USER_STATUS_PLAYING"}
		end
		
		if (_serverConfig.ServerType & GS_CONST.GAME_GENRE.MATCH) ~= 0 then
			skynet.call(addressResolver.getAddressByServiceName("GS_model_userManager"), "lua", "insertWaitDistribute", tcpAgentData.userID)
			return 0x010200, {code="RC_WAIT_DISTRIBUTE"}
		end
		
		--离开处理
		if userAttr.tableID ~= GS_CONST.INVALID_TABLE then
			local oldTableAddress = addressResolver.getTableAddress(userAttr.tableID)
			skynet.call(oldTableAddress, "lua", "performStandUpAction", tcpAgentData.userID)
		end
		
		--防作弊
		if (_serverConfig.ServerRule & GS_CONST.SERVER_RULE.SR_ALLOW_AVERT_CHEAT_MODE)~=0 and _serverConfig.ChairPerTable<GS_CONST.MAX_CHAIR then
			skynet.call(addressResolver.getAddressByServiceName("GS_model_userManager"), "lua", "insertWaitDistribute", tcpAgentData.userID)
			return 0x010200, {code="RC_WAIT_DISTRIBUTE"}
		end
		
		if _serverConfig.MinTableScore~=0 and userAttr.masterOrder==0 and userAttr.score < _serverConfig.MinTableScore then
			local msg
			if (_serverConfig.ServerType & GS_CONST.GAME_GENRE.GOLD)~= 0 then
				msg = string.format("对不起，您的游戏筹码小于桌子最低限制%s！", currencyUtility.formatCurrency(_serverConfig.MinTableScore))
			else
				msg = string.format("对不起，您的游戏积分小于桌子最低限制%s！", currencyUtility.formatCurrency(_serverConfig.MinTableScore))
			end
			return 0x010200, {code="RC_MIN_TABLE_SCORE", msg=msg}	
		end		
		
		if _serverConfig.MinEnterScore~=0 and userAttr.masterOrder==0 and userAttr.score < _serverConfig.MinEnterScore then
			local msg
			if (_serverConfig.ServerType & GS_CONST.GAME_GENRE.GOLD)~= 0 then
				msg = string.format("对不起，您的游戏筹码小于进入房间最低限制%s！", currencyUtility.formatCurrency(_serverConfig.MinEnterScore))
			else
				msg = string.format("对不起，您的游戏积分小于进入房间最低限制%s！", currencyUtility.formatCurrency(_serverConfig.MinEnterScore))
			end
			return 0x010200, {code="RC_MIN_ENTER_SCORE", msg=msg}
		end
		
		if _serverConfig.MaxEnterScore~=0 and userAttr.masterOrder==0 and userAttr.score > _serverConfig.MaxEnterScore then
			local msg
			if (_serverConfig.ServerType & GS_CONST.GAME_GENRE.GOLD)~= 0 then
				msg = string.format("对不起，您的游戏筹码大于进入房间最高限制%s！", currencyUtility.formatCurrency(_serverConfig.MaxEnterScore))
			else
				msg = string.format("对不起，您的游戏积分大于进入房间最高限制%s！", currencyUtility.formatCurrency(_serverConfig.MaxEnterScore))
			end
			return 0x010200, {code="RC_MAX_ENTER_SCORE", msg=msg}
		end
		
		if _serverConfig.MinEnterMember~=0 and userAttr.masterOrder==0 and userAttr.memberOrder < _serverConfig.MinEnterMember then
			return 0x010200, {code="RC_MIN_ENTER_MEMBER"}
		end
		
		if _serverConfig.MaxEnterMember~=0 and userAttr.masterOrder==0 and userAttr.memberOrder > _serverConfig.MaxEnterMember then
			return 0x010200, {code="RC_MAX_ENTER_MEMBER"}
		end
		
		local tableAddress
		if pbObj.tableID == GS_CONST.INVALID_TABLE then
			tableAddress = skynet.call(addressResolver.getAddressByServiceName("GS_model_tableManager"), "lua", "findAvailableTable")
		else
			tableAddress = addressResolver.getTableAddress(pbObj.tableID)
		end
		
		if tableAddress == nil then
			return 0x010200, {code="RC_ROOM_FULL"}
		end
		
		local isSuccess, retCode, msg = skynet.call(tableAddress, "lua", "sitDown", tcpAgentData.sui, pbObj.chairID, pbObj.password)
		if not isSuccess then
			local protoObj={code=retCode}
			if msg then
				protoObj.msg = msg
			end
			return 0x010200, protoObj
		end
		
		skynet.send(addressResolver.getAddressByServiceName("eventDispatcher"), "lua", "dispatch", GS_EVENT.EVT_GS_SIT_DOWN, {userID=tcpAgentData.userID})
	end,
	[0x010202] = function(tcpAgent, pbObj, tcpAgentData)
		local userAttr = ServerUserItem.getAttribute(tcpAgentData.sui, {"tableID", "chairID"})
		if userAttr.tableID == GS_CONST.INVALID_TABLE or userAttr.chairID == GS_CONST.INVALID_CHAIR then
			skynet.error(string.format("%s: 桌子号或椅子号错误", SERVICE_NAME))
			return
		end
		
		local tableAddress = addressResolver.getTableAddress(userAttr.tableID)
		if not tableAddress then
			error(string.format("%s: 找不到桌子No.%d", SERVICE_NAME, userAttr.tableID))
		end
		
		skynet.call(tableAddress, "lua", "gameOption", tcpAgentData.sui, pbObj.isAllowLookon)
	end,
	[0x010204] = function(tcpAgent, pbObj, tcpAgentData)
		if (_serverConfig.ServerRule & GS_CONST.SERVER_RULE.SR_ALLOW_AVERT_CHEAT_MODE)~=0 and _serverConfig.ChairPerTable < GS_CONST.MAX_CHAIR then
			skynet.call(addressResolver.getAddressByServiceName("GS_model_userManager"), "lua", "removeWaitDistribute", tcpAgentData.userID)
		end
		
		local userAttr = ServerUserItem.getAttribute(tcpAgentData.sui, {"tableID", "chairID", "userStatus"})
		if userAttr.tableID==GS_CONST.INVALID_TABLE then
			return
		end
		
		if not pbObj.isForce and userAttr.userStatus==GS_CONST.USER_STATUS.US_PLAYING then
			return 0x010204, {code="RC_CANNOT_WHILE_PLAYING"}
		end
		
		local tableAddress = addressResolver.getTableAddress(userAttr.tableID)
		if tableAddress then
			-- m_pIGameMatchServiceManager->OnUserLeaveGame 通知比赛服务的工作交给tableFrame gameMatchSink.onActionUserStandUp
			skynet.call(tableAddress, "lua", "standUp", tcpAgentData.sui)
		end
	end
}

local conf = {
	loginCheck = true,
	protocalHandlers = REQUEST,
	initFunc = function()
		_serverConfig = skynet.call(addressResolver.getAddressByServiceName("GS_model_serverStatus"), "lua", "getServerData")
		if not _serverConfig then
			error("server config not initialized")
		end
	end
}

pbServiceHelper.createService(conf)

