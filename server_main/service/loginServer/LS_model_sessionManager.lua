local skynet = require "skynet"
local commonServiceHelper = require "serviceHelper.common"
local addressResolver = require "addressResolver"
local resourceResolver = require "resourceResolver"
local COMMON_CONST = require "define.commonConst"
local LS_CONST = require "define.lsConst"
local timerUtility = require "utility.timer"
local ServerUserItem = require "sui"
local CItemBuffer = require "utility.cItemBuffer"

CItemBuffer.init(ServerUserItem)

local _cachedProtoStr = {}

local _hash = {
	session = {},
	platformID = {},
	userID = {},
}

local _hallNum = 0
local _onlineNum = {
		[1100] = 0,
		[1101] = 0,
		[1103] = 0,} -- 1103人数，1100人数，1101人数

local function writeOnlineNum()
	local sql = string.format("insert into QPRecordDB.online_num values('%s', %d, %d, %d, %d)", 
			os.date("%Y-%m-%d %H:%M:%S", os.time()), _hallNum, _onlineNum[1103], _onlineNum[1100], _onlineNum[1101])
	local dbConn = addressResolver.getMysqlConnection()
	skynet.call(dbConn, "lua", "query", sql)
end

local function createItem(session, platformID)
	return {
		platformID=platformID,
		session=session,
		sessionActiveTS=skynet.now(),
		sui=nil,
		suiActiveTS=nil,
	}
end

local function kickLSAgent(agent)
	if agent ~= 0 then
		local isSuccess, msg = pcall(skynet.call, agent, "lua", "clearCache")
		if not isSuccess then
			skynet.error(string.format("%s.kickLSAgent agent=[:%08x] clearCache error: %s", SERVICE_NAME, agent, tostring(msg)))
		end
		skynet.send(agent, "lua", "forward", _cachedProtoStr["0x000101_ACCOUNT_LOGIN_SOMEWHERE"])
		skynet.send(agent, "lua", "exit")
	end
end

local function kickLS(item, newUserStatus)
	local attr = ServerUserItem.getAttribute(item.sui, {"agent", "userStatus", "userID"})
	kickLSAgent(attr.agent)
	if attr.userStatus == LS_CONST.USER_STATUS.US_LS then
		_hallNum = _hallNum - 1
	end
	ServerUserItem.setAttribute(item.sui, {
		agent=0,
		ipAddr='',
		machineID='',
		userStatus=newUserStatus,
	})
	if newUserStatus==LS_CONST.USER_STATUS.US_NULL then
		item.suiActiveTS = skynet.now()
	end
	--skynet.error(string.format("%s.kickLS userID=%d userStatus改变: %d=>%d", SERVICE_NAME, attr.userID, attr.userStatus, newUserStatus))
end

local function kickGS(serverID, userID)
	skynet.send(addressResolver.getAddressByServiceName("LS_model_GSProxy"), "lua", "send", {serverID}, COMMON_CONST.LSNOTIFY_EVENT.EVT_LSNOTIFY_USER_LOGIN_OTHER_SERVER, {
		userID = userID,
	})
end

local function getUserInitializeInfo(userItem)
	return ServerUserItem.getAttribute(userItem, {
		"userID", "gameID", "platformID", "nickName", "signature", 
		"gender", "faceID", "platformFace", "userRight", "masterRight",
		"memberOrder", "masterOrder", "score", "insure", "medal",
		"gift", "present", "experience", "loveliness", "winCount", 
		"lostCount", "drawCount", "fleeCount", "contribution", "dbStatus",
	})
end

--[[
local USER_STATUS = {
	US_NULL 			= 0x00,								--没有状态
	US_LS 				= 0x01,								--登录服务器
	US_GS 				= 0x02,								--游戏服务器
	US_GS_OFFLINE 		= 0x03,								--游戏掉线
	US_LS_GS 			= 0x04,								--登录在线，游戏在线
	US_LS_GS_OFFLINE 	= 0x05,								--登录在线，游戏掉线
}
--]]
local function cmd_registerSession(session, platformID, status)
	if type(session)~="string" or type(platformID)~="number" then
		return
	end
	
	local item = _hash.platformID[platformID]
	if item then
		_hash.session[item.session] = nil
		_hash.session[session] = item
		item.session = session
		item.sessionActiveTS=skynet.now()
		
		if item.sui then
			local attr = ServerUserItem.getAttribute(item.sui, {"userStatus", "userID", "serverID"})
			if attr.userStatus == LS_CONST.USER_STATUS.US_LS then
				kickLS(item, LS_CONST.USER_STATUS.US_NULL)
			elseif attr.userStatus == LS_CONST.USER_STATUS.US_GS then
				kickGS(attr.serverID, attr.userID)
			elseif attr.userStatus == LS_CONST.USER_STATUS.US_GS_OFFLINE then
				-- do nothing
			elseif attr.userStatus == LS_CONST.USER_STATUS.US_LS_GS then
				kickLS(item, LS_CONST.USER_STATUS.US_GS)
				kickGS(attr.serverID, attr.userID)
			elseif attr.userStatus == LS_CONST.USER_STATUS.US_LS_GS_OFFLINE then
				kickLS(item, LS_CONST.USER_STATUS.US_GS_OFFLINE)
			end
		end
	else
		item = createItem(session, platformID)
		_hash.platformID[platformID] = item
		_hash.session[session] = item
	end
	_hash.session[session].status = status
end

local function cmd_getPlatformIDBySession(session)
	local item = _hash.session[session]
	if item then
		return item.platformID, item.status
	else
		return nil
	end
end

local function cmd_getUserItemByUserID(userID)
	local item = _hash.userID[userID]
	if item then
		return item.sui
	end
end

local function cmd_getUserItemByPlatformID(platformID, updateSuiTS)
	local item = _hash.platformID[platformID]
	if item and item.sui then
		if updateSuiTS and item.suiActiveTS~=nil then
			item.suiActiveTS = skynet.now()
		end
		return item.sui
	end
end

local function cmd_getUserItemBySession(session)
	local item = _hash.session[session]
	if item and item.sui then
		return item.sui
	end
end

local function cmd_switchUserItem(platformID, newAttribute)
	local item = _hash.platformID[platformID]
	if not item.sui then
		error(string.format("%s.cmd_switchUserItem 错误: 找不到sui platformID=%s", SERVICE_NAME, tostring(platformID)))
	end
	
	item.sessionActiveTS=skynet.now()
	item.suiActiveTS = nil
	
	local newUserStatus
	local attr = ServerUserItem.getAttribute(item.sui, {"agent", "userStatus", "machineID", "isAndroid", "serverID", "userID"})
	if attr.userStatus == LS_CONST.USER_STATUS.US_NULL then
		newUserStatus = LS_CONST.USER_STATUS.US_LS
	elseif attr.userStatus == LS_CONST.USER_STATUS.US_LS then
		kickLSAgent(attr.agent)
		_hallNum = _hallNum - 1
		newUserStatus = LS_CONST.USER_STATUS.US_LS
	elseif attr.userStatus == LS_CONST.USER_STATUS.US_GS then
		newUserStatus = LS_CONST.USER_STATUS.US_LS_GS
	elseif attr.userStatus == LS_CONST.USER_STATUS.US_GS_OFFLINE then
		newUserStatus = LS_CONST.USER_STATUS.US_LS_GS_OFFLINE
	elseif attr.userStatus == LS_CONST.USER_STATUS.US_LS_GS then	
		kickLSAgent(attr.agent)
		newUserStatus = LS_CONST.USER_STATUS.US_LS_GS
	elseif attr.userStatus == LS_CONST.USER_STATUS.US_LS_GS_OFFLINE then
		kickLSAgent(attr.agent)
		newUserStatus = LS_CONST.USER_STATUS.US_LS_GS_OFFLINE
	end

	ServerUserItem.setAttribute(item.sui, {
		agent=newAttribute.agent,
		ipAddr=newAttribute.ipAddr,
		machineID=newAttribute.matchineID,
		userStatus=newUserStatus,
	})
	--skynet.error(string.format("%s.cmd_switchUserItem userID=%d userStatus改变: %d=>%d", SERVICE_NAME, attr.userID, attr.userStatus, newUserStatus));
	if newUserStatus == LS_CONST.USER_STATUS.US_LS then
		_hallNum = _hallNum + 1
	end
	skynet.call(newAttribute.agent, "lua", "setCache", item.session, item.sui, attr.userID)

	--安全提示
	if not attr.isAndroid and attr.userStatus ~= LS_CONST.USER_STATUS.US_NULL and attr.machineID ~= newAttribute.matchineID then
		skynet.send(newAttribute.agent, "lua", "forward", 0xff0000, {
			type = COMMON_CONST.SYSTEM_MESSAGE_TYPE.SMT_NORMAL,
			msg = "请注意，您的帐号已从另一设备登录，对方被迫离开！"
		})
	end
end

local function cmd_registerUser(platformID, userInfo, userInfoPlus)
	local item = _hash.platformID[platformID]
	if not item then
		error(string.format("%s.registerUser platformID=%d item找不到", SERVICE_NAME, platformID))
	end
	
	if item.sui then
		error(string.format("%s.registerUser platformID=%d item.sui~=nil", SERVICE_NAME, platformID))
	end
	
	item.sui = CItemBuffer.allocate()
	ServerUserItem.initialize(item.sui, userInfo, userInfoPlus)
	--skynet.error(string.format("%s.cmd_registerUser userID=%d 生成sui数据 userStatus=%d", SERVICE_NAME, userInfo.userID, userInfoPlus.userStatus));
	
	item.sessionActiveTS=skynet.now()
	item.suiActiveTS = nil
	
	local attr = ServerUserItem.getAttribute(item.sui, {"userID", "agent"})
	_hash.userID[attr.userID] = item
	_hallNum = _hallNum + 1
	skynet.call(attr.agent, "lua", "setCache", item.session, item.sui, attr.userID)

	return item.sui
end

--[[
data = {
	session = pbObj.session,
	kindID = _serverData.KindID,
	nodeID = _serverData.NodeID,
	serverID = _serverData.ServerID,
}
--]]
local function cmd_gs_login(data)
	local item = _hash.session[data.session]
	if not item then
		return COMMON_CONST.GS_LOGIN_CODE.GLC_INVALID_SESSION
	end
	
	if not item.sui then
		return COMMON_CONST.GS_LOGIN_CODE.GLC_LS_LOGIN_FIRST
	end
	
	local retCode, updateAttr
	local attr = ServerUserItem.getAttribute(item.sui, {"userStatus", "agent", "serverID", "userID"})
	if attr.userStatus == LS_CONST.USER_STATUS.US_NULL then
		updateAttr = {kindID=data.kindID, nodeID=data.nodeID, serverID=data.serverID, userStatus=LS_CONST.USER_STATUS.US_GS}
		retCode = COMMON_CONST.GS_LOGIN_CODE.GLC_SUCCESS
	elseif attr.userStatus == LS_CONST.USER_STATUS.US_LS then
		updateAttr = {kindID=data.kindID, nodeID=data.nodeID, serverID=data.serverID, userStatus=LS_CONST.USER_STATUS.US_LS_GS}
		retCode = COMMON_CONST.GS_LOGIN_CODE.GLC_SUCCESS
	elseif attr.userStatus == LS_CONST.USER_STATUS.US_GS then
		if attr.serverID == data.serverID then
			retCode = COMMON_CONST.GS_LOGIN_CODE.GLC_SUCCESS
		else
			retCode = COMMON_CONST.GS_LOGIN_CODE.GLC_RETRY
		end
	elseif attr.userStatus == LS_CONST.USER_STATUS.US_GS_OFFLINE then
		if attr.serverID == data.serverID then
			updateAttr = {userStatus=LS_CONST.USER_STATUS.US_GS}
			retCode = COMMON_CONST.GS_LOGIN_CODE.GLC_SUCCESS
		else
			retCode = COMMON_CONST.GS_LOGIN_CODE.GLC_RETRY
		end
	elseif attr.userStatus == LS_CONST.USER_STATUS.US_LS_GS then
		if attr.serverID == data.serverID then
			retCode = COMMON_CONST.GS_LOGIN_CODE.GLC_SUCCESS
		else
			retCode = COMMON_CONST.GS_LOGIN_CODE.GLC_RETRY
		end
	elseif attr.userStatus == LS_CONST.USER_STATUS.US_LS_GS_OFFLINE then
		if attr.serverID == data.serverID then
			updateAttr = {userStatus=LS_CONST.USER_STATUS.US_LS_GS}
			retCode = COMMON_CONST.GS_LOGIN_CODE.GLC_SUCCESS
		else
			retCode = COMMON_CONST.GS_LOGIN_CODE.GLC_RETRY
		end
	else
		error(string.format("%s.cmd_gs_login 预期外的userStatus userStatus=%d", SERVICE_NAME, attr.userStatus))
	end
	
	if retCode == COMMON_CONST.GS_LOGIN_CODE.GLC_SUCCESS then
		if updateAttr~=nil then
			if attr.userStatus == LS_CONST.USER_STATUS.US_LS then
				_hallNum = _hallNum - 1
			end
			ServerUserItem.setAttribute(item.sui, updateAttr)
			if updateAttr.userStatus == LS_CONST.USER_STATUS.US_LS_GS or updateAttr.userStatus == LS_CONST.USER_STATUS.US_GS then
				_onlineNum[data.nodeID] = _onlineNum[data.nodeID] + 1
			end
			--skynet.error(string.format("%s.cmd_gs_login userID=%d userStatus改变: %d=>%d", SERVICE_NAME, attr.userID, attr.userStatus, updateAttr.userStatus));
		end
		item.suiActiveTS = nil
		
		return retCode, getUserInitializeInfo(item.sui)
	elseif retCode == COMMON_CONST.GS_LOGIN_CODE.GLC_RETRY then
		kickGS(attr.serverID, attr.userID)
		return retCode
	else
		error(string.format("%s.cmd_gs_login 预期外的结果 retCode=%d", SERVICE_NAME, retCode))
	end
end

--[[
local data = {
	kindID=,
	nodeID=,
	serverID=,
	userID=,
}
--]]
local function cmd_gs_logout(data)
	local item = _hash.userID[data.userID]
	if not item then
		skynet.error(string.format("%s.cmd_gs_logout item not found userID=%s", SERVICE_NAME, tostring(data.userID)))
		return
	end
	
	if not item.sui then
		error(string.format("%s.cmd_gs_logout item.sui not found userID=%s", SERVICE_NAME, tostring(data.userID)))
	end	
	
	local attr = ServerUserItem.getAttribute(item.sui, {"agent", "platformID", "userStatus", "kindID", "nodeID", "serverID"})
	local newUserStatus
	
	if attr.userStatus==LS_CONST.USER_STATUS.US_GS or attr.userStatus == LS_CONST.USER_STATUS.US_GS_OFFLINE then
		newUserStatus = LS_CONST.USER_STATUS.US_NULL
	elseif attr.userStatus==LS_CONST.USER_STATUS.US_LS_GS or attr.userStatus==LS_CONST.USER_STATUS.US_LS_GS_OFFLINE then
		newUserStatus = LS_CONST.USER_STATUS.US_LS
		_hallNum = _hallNum + 1
	else
		error(string.format("%s.cmd_gs_logout 预期外的userStatus userStatus=%d", SERVICE_NAME, attr.userStatus))
	end
	
	if attr.kindID==data.kindID and attr.nodeID==data.nodeID and attr.serverID==data.serverID then
		
		if attr.userStatus == LS_CONST.USER_STATUS.US_LS_GS or attr.userStatus==LS_CONST.USER_STATUS.US_GS then
			_onlineNum[data.nodeID] = _onlineNum[data.nodeID] - 1
		end
		local updateAttr = data.updateAttr
		if updateAttr==nil then
			updateAttr = {}
		end
		updateAttr.userStatus=newUserStatus
		updateAttr.kindID=0
		updateAttr.nodeID=0
		updateAttr.serverID=0
		
		ServerUserItem.setAttribute(item.sui, updateAttr)
		if newUserStatus==LS_CONST.USER_STATUS.US_NULL then
			item.suiActiveTS = skynet.now()
		end
		--skynet.error(string.format("%s.cmd_gs_logout userID=%d userStatus改变: %d=>%d", SERVICE_NAME, data.userID, attr.userStatus, newUserStatus));
		
		if newUserStatus==LS_CONST.USER_STATUS.US_LS and data.updateAttr~=nil then
			local newAttr = ServerUserItem.getAttribute(item.sui, {"agent", "medal", "experience", "loveliness", "score", "insure", "gift", "present"})
			skynet.send(newAttr.agent, "lua", "forward", 0x000102, {
				medal=newAttr.medal,
				experience=newAttr.experience,
				loveLiness=newAttr.loveliness,
				score=newAttr.score,
				insure=newAttr.insure,
				gift=newAttr.gift,
				present=newAttr.present,
			})
			skynet.send(addressResolver.getAddressByServiceName("LS_model_serverManager"), "lua", "sendDefenseList", data.userID, attr.platformID, newAttr.agent)
		end
	else
		error(string.format(
			"%s.cmd_gs_logout 服务器不匹配 expect[kindID=%d nodeID=%d serverID=%d]   got[kindID=%d nodeID=%d serverID=%d]",
			SERVICE_NAME,
			attr.kindID, attr.nodeID, attr.serverID,
			data.kindID, data.nodeID, data.serverID
		))
	end
end

--[[
local data = {
	kindID=,
	nodeID=,
	serverID=,
	userID=,
}
local USER_STATUS = {
	US_NULL 			= 0x00,								--没有状态
	US_LS 				= 0x01,								--登录服务器
	US_GS 				= 0x02,								--游戏服务器
	US_GS_OFFLINE 		= 0x03,								--游戏掉线
	US_LS_GS 			= 0x04,								--登录在线，游戏在线
	US_LS_GS_OFFLINE 	= 0x05,								--登录在线，游戏掉线
}
--]]
local function cmd_gs_offline(data)
	local item = _hash.userID[data.userID]
	if not item then
		skynet.error(string.format("%s.cmd_gs_offline item not found userID=%s", SERVICE_NAME, tostring(data.userID)))
		return
	end
	
	if not item.sui then
		error(string.format("%s.cmd_gs_offline item.sui not found userID=%s", SERVICE_NAME, tostring(data.userID)))
	end	
	
	local attr = ServerUserItem.getAttribute(item.sui, {"userStatus", "kindID", "nodeID", "serverID"})
	local newUserStatus
	
	if attr.userStatus==LS_CONST.USER_STATUS.US_GS or attr.userStatus == LS_CONST.USER_STATUS.US_GS_OFFLINE then
		newUserStatus = LS_CONST.USER_STATUS.US_GS_OFFLINE
	elseif attr.userStatus==LS_CONST.USER_STATUS.US_LS_GS or attr.userStatus==LS_CONST.USER_STATUS.US_LS_GS_OFFLINE then
		newUserStatus = LS_CONST.USER_STATUS.US_LS_GS_OFFLINE
	else
		error(string.format("%s.cmd_gs_offline 预期外的userStatus userStatus=%d", SERVICE_NAME, attr.userStatus))
	end
	
	if attr.kindID==data.kindID and attr.nodeID==data.nodeID and attr.serverID==data.serverID then
		ServerUserItem.setAttribute(item.sui, {userStatus=newUserStatus})
		if attr.userStatus==LS_CONST.USER_STATUS.US_LS_GS or attr.userStatus==LS_CONST.USER_STATUS.US_GS then
			_onlineNum[attr.nodeID] = _onlineNum[attr.nodeID] - 1
		end
		--skynet.error(string.format("%s.cmd_gs_offline userID=%d userStatus改变: %d=>%d", SERVICE_NAME, data.userID, attr.userStatus, newUserStatus));
	else
		error(string.format(
			"%s.cmd_gs_offline 服务器不匹配 expect[kindID=%d nodeID=%d serverID=%d]   got[kindID=%d nodeID=%d serverID=%d]",
			SERVICE_NAME,
			attr.kindID, attr.nodeID, attr.serverID,
			data.kindID, data.nodeID, data.serverID
		))
	end
end

local function cmd_checkOnline(userIDList)
	local ret = {}
	for _, userID in ipairs(userIDList) do
		local item = _hash.userID[userID]
		local retValue
		if item then
			local attr = ServerUserItem.getAttribute(item.sui, {"userStatus", "kindID", "nodeID", "serverID"})
			retValue = {
				kindID = attr.kindID,
				nodeID = attr.nodeID,
				serverID = attr.serverID,
			}
		else
			retValue = false
		end
		ret[tostring(userID)] = retValue
	end
	return ret
end

local function cmd_viewOnline()
	local ret = {}
	for _, item in pairs(_hash.userID) do
		if item.sui then
			local attr = ServerUserItem.getAttribute(item.sui, {"userID", "userStatus", "serverID", "nickName"})
			table.insert(ret, attr)
		end
	end
	return ret
end

local function cmd_onEventClientDisconnect(data)
	local item = _hash.userID[data.userID]
	if not item or not item.sui then
		return
	end
	
	local attr = ServerUserItem.getAttribute(item.sui, {"userStatus"})
	local newUserStatus
	if attr.userStatus==LS_CONST.USER_STATUS.US_NULL or attr.userStatus==LS_CONST.USER_STATUS.US_LS then
		newUserStatus = LS_CONST.USER_STATUS.US_NULL
	elseif attr.userStatus==LS_CONST.USER_STATUS.US_GS or attr.userStatus==LS_CONST.USER_STATUS.US_LS_GS then
		newUserStatus = LS_CONST.USER_STATUS.US_GS
	elseif attr.userStatus==LS_CONST.USER_STATUS.US_GS_OFFLINE or attr.userStatus==LS_CONST.USER_STATUS.US_LS_GS_OFFLINE then
		newUserStatus = LS_CONST.USER_STATUS.US_GS_OFFLINE
	else
		error(string.format("%s.cmd_onEventClientDisconnect 预期外的userStatus=%d", SERVICE_NAME, attr.userStatus))
	end
	
	if attr.userStatus==LS_CONST.USER_STATUS.US_LS then
		_hallNum = _hallNum - 1
	end
	ServerUserItem.setAttribute(item.sui, {
		agent=0,
		ipAddr='',
		machineID='',
		userStatus=newUserStatus,
	})
	--skynet.error(string.format("%s.cmd_onEventClientDisconnect userID=%d userStatus改变: %d=>%d", SERVICE_NAME, data.userID, attr.userStatus, newUserStatus));
	if newUserStatus==LS_CONST.USER_STATUS.US_NULL then
		item.suiActiveTS = skynet.now()
	end
end

local function cmd_onEventGameServerDisconnect(data)
	for session, item in pairs(_hash.session) do
		if item.sui then
			local attr = ServerUserItem.getAttribute(item.sui, {"agent", "serverID", "userID"})
			if attr.serverID==data.serverID then
				kickLSAgent(attr.agent)
				_hash.userID[attr.userID] = nil
				CItemBuffer.release(item.sui)
				item.sui = nil
				item.suiActiveTS = nil
			end
		end
	end
end

local function cmd_ping()

end

local function cleanExpiredInfo()
	local currentTS = skynet.now()
	
	local userItemLifeTimeThreshold = LS_CONST.SESSION_CONTROL.USER_ITEM_LIFE_TIME * 100
	local sessionLifeTimeThreshold = LS_CONST.SESSION_CONTROL.SESSION_LIFE_TIME * 100
	
	for session, item in pairs(_hash.session) do
		if item.sui and item.suiActiveTS then
			if currentTS - item.suiActiveTS > userItemLifeTimeThreshold then
				local attr = ServerUserItem.getAttribute(item.sui, {"userStatus", "userID"})
				if attr.userStatus~=LS_CONST.USER_STATUS.US_NULL then
					error(string.format("%s.cleanExpiredInfo 预期外的userStatus userID=%d userStatus=%d", SERVICE_NAME, attr.userID, attr.userStatus))
				end
				_hash.userID[attr.userID] = nil
				CItemBuffer.release(item.sui)
				item.sui = nil
				item.suiActiveTS = nil
				
				--skynet.error(string.format("%s.cleanExpiredInfo 清除sui数据 userID=%d", SERVICE_NAME, attr.userID));
			end
		end
		
		if item.sui==nil then
			if currentTS - item.sessionActiveTS > sessionLifeTimeThreshold then
				_hash.session[item.session]=nil
				_hash.platformID[item.platformID]=nil
			end
		end
	end
end

local function cmd_broadcastLoginServer(packetStr)
	for session, item in pairs(_hash.session) do
		if item.sui then
			local attr = ServerUserItem.getAttribute(item.sui, {"agent", "userStatus", "serverID"})
			if attr and attr.userStatus==LS_CONST.USER_STATUS.US_LS and attr.serverID == 0 then
				skynet.send(attr.agent, "lua", "forward", packetStr)
			end
		end
	end
end

local conf = {
	methods = {
		["getPlatformIDBySession"] = {["func"]=cmd_getPlatformIDBySession, ["isRet"]=true},
		["getUserItemByUserID"] = {["func"]=cmd_getUserItemByUserID, ["isRet"]=true},
		["getUserItemByPlatformID"] = {["func"]=cmd_getUserItemByPlatformID, ["isRet"]=true},
		["getUserItemBySession"] = {["func"]=cmd_getUserItemBySession, ["isRet"]=true},
		
		["registerSession"] = {["func"]=cmd_registerSession, ["isRet"]=false},
		["registerUser"] = {["func"]=cmd_registerUser, ["isRet"]=true},
		["switchUserItem"] = {["func"]=cmd_switchUserItem, ["isRet"]=true},
		
		["broadcastLoginServer"] = {["func"]=cmd_broadcastLoginServer, ["isRet"]=false},
		
		["gs_login"] = {["func"]=cmd_gs_login, ["isRet"]=true},
		["gs_logout"] = {["func"]=cmd_gs_logout, ["isRet"]=true},
		["gs_offline"] = {["func"]=cmd_gs_offline, ["isRet"]=true},
		
		["checkOnline"] = {["func"]=cmd_checkOnline, ["isRet"]=true},
		["viewOnline"] = {["func"]=cmd_viewOnline, ["isRet"]=true},
		
		["ping"] = {["func"]=cmd_ping, ["isRet"]=true},
		
		["onEventClientDisconnect"] = {["func"]=cmd_onEventClientDisconnect, ["isRet"]=false},
		["onEventGameServerDisconnect"] = {["func"]=cmd_onEventGameServerDisconnect, ["isRet"]=false},
	},
	initFunc = function()
		resourceResolver.init()
		
		_cachedProtoStr["0x000101_ACCOUNT_LOGIN_SOMEWHERE"] = skynet.call(resourceResolver.get("pbParser"), "lua", "encode", 0x000101, {code="RC_ACCOUNT_LOGIN_SOMEWHERE"}, true)
	
		local LS_EVENT = require "define.eventLoginServer"
		skynet.send(addressResolver.getAddressByServiceName("eventDispatcher"), "lua", "addEventListener", LS_EVENT.EVT_LS_CLIENT_DISCONNECT, skynet.self(), "onEventClientDisconnect")
		skynet.send(addressResolver.getAddressByServiceName("eventDispatcher"), "lua", "addEventListener", LS_EVENT.EVT_LS_GAMESERVER_DISCONNECT, skynet.self(), "onEventGameServerDisconnect")
	
		timerUtility.start(LS_CONST.SESSION_CONTROL.CHECK_INTERVAL * 50)
		timerUtility.setInterval(cleanExpiredInfo, 2)
		timerUtility.setInterval(writeOnlineNum, 1)
	end
}

commonServiceHelper.createService(conf)
