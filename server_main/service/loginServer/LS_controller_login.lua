local skynet = require "skynet"
local mysqlutil = require "mysqlutil"
local pbServiceHelper = require "serviceHelper.pb"
local LS_CONST = require "define.lsConst"
local LS_EVENT = require "define.eventLoginServer"
local addressResolver = require "addressResolver"
local resourceResolver = require "resourceResolver"
local timerUtility = require "utility.timer"
local ServerUserItem = require "sui"

local _cachedProtoStr={}
local loginTypeForTest = 0

local function doLoginserverLogin(platformID, nickName, ipAddr, machineID)
	local sql = string.format(
		"call QPAccountsDB.sp_loginserver_login(%d, '%s', '%s', '%s')",
		platformID,
		mysqlutil.escapestring(nickName),
		ipAddr,
		mysqlutil.escapestring(machineID)
	)
	local mysqlConn = addressResolver.getMysqlConnection()
	local rows = skynet.call(mysqlConn, "lua", "call", sql)
	if type(rows)~="table" then
		error(string.format("%s.doLoginserverLogin error sql=%s", SERVICE_NAME, sql))
	end
	
	local result = rows[1]
	for k, v in pairs(result) do
		if k~="retMsg" and k~="NickName" and k~="Signature" and k~="PlatformFace" then
			result[k]=tonumber(v)
		end
	end
	
	return result
end

local function getPlatformIDBySession(session)
	local platformID, status
	local tryCnt = 0
	repeat
		platformID, status = skynet.call(addressResolver.getAddressByServiceName("LS_model_sessionManager"), "lua", "getPlatformIDBySession", session)
		tryCnt = tryCnt + 1
		if platformID==nil and tryCnt < LS_CONST.LOGIN_CONTROL.RETRY_COUNT then
			skynet.sleep(LS_CONST.LOGIN_CONTROL.RETRY_INTERVAL_TICK)
		end
	until tryCnt>=LS_CONST.LOGIN_CONTROL.RETRY_COUNT or platformID~=nil
	return platformID, status
end

local function registerUser(userInfo, platformID, agent, ipAddr, machineID)
	return skynet.call(
		addressResolver.getAddressByServiceName("LS_model_sessionManager"), 
		"lua", 
		"registerUser", 
		platformID,
		{
			userID=userInfo.UserID,
			gameID=userInfo.GameID,
			platformID=userInfo.PlatformID,
			nickName=userInfo.NickName,
			signature=userInfo.Signature,
			
			gender=userInfo.Gender,
			faceID=userInfo.FaceID,
			platformFace=userInfo.PlatformFace,
			userRight=userInfo.UserRight,
			masterRight=userInfo.MasterRight,
			memberOrder=userInfo.MemberOrder,
			masterOrder=userInfo.MasterOrder,
			score=userInfo.Score,
			insure=userInfo.Insure,
			medal=userInfo.UserMedal,
			gift=userInfo.Gift,
			present=userInfo.Present,
			experience=userInfo.Experience,
			loveliness=userInfo.LoveLiness,
			winCount=userInfo.WinCount,
			lostCount=userInfo.LostCount,
			drawCount=userInfo.DrawCount,
			fleeCount=userInfo.FleeCount,
			contribution=userInfo.Contribution,
			dbStatus=userInfo.Status,
		},
		{
			logonTime = math.floor(skynet.time()),
			userStatus=LS_CONST.USER_STATUS.US_LS,
			isAndroid = false,
			agent = agent,
			ipAddr = ipAddr,
			machineID = machineID,
		}
	)
end



local REQUEST = {
	-- 登录
	[0x000100] = function(tcpAgent, pbObj, tcpAgentData)
		local re = {userId=2,name="test_3717",gold=10000}
		return 0x000100, re
	end,
}

local conf = {
	loginCheck = false,
	protocalHandlers = REQUEST,
	initFunc = function()
		loginTypeForTest = (skynet.getenv("isTest") == "true" and true or false)
		
		resourceResolver.init()
		local pbParser = resourceResolver.get("pbParser")
		
	end
}

pbServiceHelper.createService(conf)
