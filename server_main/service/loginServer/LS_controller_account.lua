local skynet = require "skynet"
local pbServiceHelper = require "serviceHelper.pb"
local addressResolver = require "addressResolver"
local resourceResolver = require "resourceResolver"
local wordFilterUtility = require "wordfilter"
local mysqlutil = require "mysqlutil"
local ServerUserItem = require "sui"

local REQUEST = {
	[0x000600] = function(tcpAgent, pbObj, tcpAgentData)
		if pbObj.faceID >= 0xffff then
			error(string.format("%s protocal=0x000600 invalid faceID=%d", SERVICE_NAME, pbObj.faceID))
		end
		
		local sql = string.format("update `QPAccountsDB`.`AccountsInfo` set `FaceID`=%d where `UserID`=%d", pbObj.faceID, tcpAgentData.userID)
		local dbConn = addressResolver.getMysqlConnection()
		skynet.call(dbConn, "lua", "query", sql)
		
			--临时添加解决
			ServerUserItem.setAttribute(tcpAgentData.sui, {faceID = pbObj.faceID})
		return 0x000600, {code="RC_OK"}
	end,
	[0x000601] = function(tcpAgent, pbObj, tcpAgentData)		
		local signatureLen = string.len(pbObj.signature)
		if signatureLen>=255 then
			return 0x000601, {code="RC_TOO_LONG"}
		end
			
		if signatureLen > 0 then
			local swfObj = resourceResolver.get("sensitiveWordFilter")
			if wordFilterUtility.hasMatch(swfObj, pbObj.signature) then
				return 0x000601, {code="RC_SENSITIVE_WORD_FOUND"}
			end
		end
				
		local sql
		if signatureLen==0 then
			sql = string.format("delete from `QPAccountsDB`.`AccountsSignature` where `UserID`=%d", tcpAgentData.userID)
		else
			sql = string.format(
				"insert `QPAccountsDB`.`AccountsSignature` (`UserID`, `Signature`) values (%d, '%s') on duplicate key update `Signature`=values(`Signature`)", 
				tcpAgentData.userID,
				mysqlutil.escapestring(pbObj.signature)
			)
		end
		
		local dbConn = addressResolver.getMysqlConnection()
		skynet.call(dbConn, "lua", "query", sql)
			
			--临时添加解决
			ServerUserItem.setAttribute(tcpAgentData.sui, {signature = pbObj.signature})
		return 0x000601, {code="RC_OK"}
	end,
	[0x000602] = function(tcpAgent, pbObj, tcpAgentData)
		local nicknameLen = string.len(pbObj.nickName)
		if nicknameLen==0 or nicknameLen>31 then
			return 0x000602, {code="RC_INVALID_NICKNAME_LEN"}
		end
		
		local swfObj = resourceResolver.get("sensitiveWordFilter")
		if wordFilterUtility.hasMatch(swfObj, pbObj.nickName) then
			return 0x000602, {code="RC_SENSITIVE_WORD_FOUND"}
		end		
		
		local isScoreCharged = 0
		if pbObj.isScoreCharged then
			local attr = ServerUserItem.getAttribute(tcpAgentData.sui, {"serverID"})
			if attr.serverID~=0 then
				local serverName = skynet.call(addressResolver.getAddressByServiceName("LS_model_serverManager"), "lua", "getServerName", serverID)
				return 0x000602, {code="RC_STILL_IN_GAME", msg=string.format("对不起，您还在【%s】进行游戏，无法修改", serverName)}
			end
			isScoreCharged = 1
		end
		
		local sql = string.format("call QPAccountsDB.sp_change_nickname(%d, '%s', %d)", tcpAgentData.userID, mysqlutil.escapestring(pbObj.nickName), isScoreCharged)
		local dbConn = addressResolver.getMysqlConnection()
		local rows = skynet.call(dbConn, "lua", "call", sql)
		local row = rows[1]
		row.retCode = tonumber(row.retCode)
		if row.retCode==0 then
			local attrToSet = {nickName=pbObj.nickName}
			if isScoreCharged == 1 then
				attrToSet.score = math.tointeger(row.Score)
			end
			ServerUserItem.setAttribute(tcpAgentData.sui, attrToSet)
			local attr = ServerUserItem.getAttribute(tcpAgentData.sui, {"score"})
			return 0x000602, {code="RC_OK", score = attr.score}
		elseif row.retCode==2 then
			return 0x000602, {code="RC_SAME_NICKNAME"}
		elseif row.retCode==3 then
			return 0x000602, {code="RC_NICKNAME_ALREADY_USED"}			
		elseif row.retCode==4 then
			return 0x000602, {code="RC_NOT_ENOUGH_SCORE", msg=row.retMsg}
		end
	end,
	[0x000603] = function(tcpAgent, pbObj, tcpAgentData)
		local swfObj = resourceResolver.get("sensitiveWordFilter")
		if wordFilterUtility.hasMatch(swfObj, pbObj.nickName) then
			return 0x000603, {code="RC_SENSITIVE_WORD_FOUND"}
		end
		
		local sql = string.format("call QPAccountsDB.sp_is_nickname_used('%s')", mysqlutil.escapestring(pbObj.nickName))
		local dbConn = addressResolver.getMysqlConnection()
		local rows = skynet.call(dbConn, "lua", "call", sql)
		local ret = tonumber(rows[1].ret)
		if ret==0 then
			return 0x000603, {code="RC_OK"}
		else
			return 0x000603, {code="RC_NICKNAME_ALREADY_USED"}
		end
	end,
	[0x000604] = function(tcpAgent, pbObj, tcpAgentData)
		if pbObj.gender >= 127 then
			error(string.format("%s protocal=0x000604 invalid gender=%d", SERVICE_NAME, pbObj.gender))
		end
		local sql = string.format("UPDATE `QPAccountsDB`.`AccountsInfo` SET `Gender`=%d WHERE `UserID`=%d", pbObj.gender, tcpAgentData.userID)
		local dbConn = addressResolver.getMysqlConnection()
		skynet.call(dbConn, "lua", "query", sql)
		
			--临时添加解决
			ServerUserItem.setAttribute(tcpAgentData.sui, {gender = pbObj.gender})
		return 0x000604, {code="RC_OK"}
	end,
	[0x000605] = function(tcpAgent, pbObj, tcpAgentData)
		if string.len(pbObj.platformFace) ~= 32 then
			error(string.format("%s protocal=0x000605 invalid platformFace=%s", SERVICE_NAME, tostring(pbObj.platformFace)))
		end
		local sql = string.format("call QPAccountsDB.sp_set_platform_face(%d, '%s')", tcpAgentData.userID, mysqlutil.escapestring(pbObj.platformFace))
		local dbConn = addressResolver.getMysqlConnection()
		skynet.call(dbConn, "lua", "call", sql)
			--临时添加解决
			ServerUserItem.setAttribute(tcpAgentData.sui, {platformFace = pbObj.platformFace})
		
		return 0x000605, {code="RC_OK"}
	end,
}

local conf = {
	loginCheck = true,
	protocalHandlers = REQUEST,
	initFunc = function()
		resourceResolver.init()
	end,
}

pbServiceHelper.createService(conf)
