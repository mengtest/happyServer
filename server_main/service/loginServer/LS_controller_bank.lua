local skynet = require "skynet"
local pbServiceHelper = require "serviceHelper.pb"
local addressResolver = require "addressResolver"
local ServerUserItem = require "sui"

local function isStillInGame(userItem)
	local attr = ServerUserItem.getAttribute(userItem, {"serverID"})
	if attr.serverID~=0 then
		local serverName = skynet.call(addressResolver.getAddressByServiceName("LS_model_serverManager"), "lua", "getServerName", serverID)
		return true, {code="RC_STILL_IN_GAME", msg=string.format("对不起，您还在【%s】进行游戏，不能进行银行操作", serverName)}
	end	
	
	return false
end

local REQUEST = {
	[0x000700] = function(tcpAgent, pbObj, tcpAgentData)
		local isInGame, retObj = isStillInGame(tcpAgentData.sui)
		if isInGame then
			return 0x000700, retObj
		end
		
		local sql = string.format("call QPTreasureDB.sp_bank_deposit(%d, %d)", tcpAgentData.userID, pbObj.amount)
		local dbConn = addressResolver.getMysqlConnection()
		local rows = skynet.call(dbConn, "lua", "call", sql)
		local row = rows[1]
		row.retCode = math.tointeger(row.retCode)
		if row.retCode==0 then
			--临时添加解决
			ServerUserItem.setAttribute(tcpAgentData.sui, {score=math.tointeger(row.Score), insure=math.tointeger(row.Insure)})
			return 0x000700, {code="RC_OK", score=math.tointeger(row.Score), insure=math.tointeger(row.Insure)}
		elseif row.retCode==-1 then
			error(row.retMsg)
		elseif row.retCode==1 then
			return 0x000700, {code="RC_BANK_PREREQUISITE", msg=row.retMsg}
		elseif row.retCode==2 then
			return 0x000700, {code="RC_NO_SCORE_INFO_RECORD", msg=row.retMsg}
		elseif row.retCode==3 then
			return 0x000700, {code="RC_NOT_ENOUGH_MONEY", msg=row.retMsg}
		end
	end,
	
	[0x000701] = function(tcpAgent, pbObj, tcpAgentData)
		local isInGame, retObj = isStillInGame(tcpAgentData.sui)
		if isInGame then
			return 0x000701, retObj
		end
		
		local sql = string.format("call QPTreasureDB.sp_bank_withdraw(%d, %d)", tcpAgentData.userID, pbObj.amount)
		local dbConn = addressResolver.getMysqlConnection()
		local rows = skynet.call(dbConn, "lua", "call", sql)
		local row = rows[1]
		row.retCode = math.tointeger(row.retCode)
		if row.retCode==0 then
			--临时添加解决
			ServerUserItem.setAttribute(tcpAgentData.sui, {score=math.tointeger(row.Score), insure=math.tointeger(row.Insure)})
			return 0x000701, {code="RC_OK", score=math.tointeger(row.Score), insure=math.tointeger(row.Insure)}
		elseif row.retCode==-1 then
			error(row.retMsg)
		elseif row.retCode==1 then
			return 0x000701, {code="RC_BANK_PREREQUISITE", msg=row.retMsg}
		elseif row.retCode==2 then
			return 0x000701, {code="RC_NO_SCORE_INFO_RECORD", msg=row.retMsg}
		elseif row.retCode==3 then
			return 0x000701, {code="RC_NOT_ENOUGH_MONEY", msg=row.retMsg}
		end
	end,
	
	[0x000702] = function(tcpAgent, pbObj, tcpAgentData)
		local isInGame, retObj = isStillInGame(tcpAgentData.sui)
		if isInGame then
			return 0x000702, retObj
		end
		
		local attr = ServerUserItem.getAttribute(tcpAgentData.sui, {"score", "insure"})
		return 0x000702, {code="RC_OK", score=attr.score, insure=attr.insure}
	end,
}

local conf = {
	loginCheck = true,
	protocalHandlers = REQUEST,
}

pbServiceHelper.createService(conf)
