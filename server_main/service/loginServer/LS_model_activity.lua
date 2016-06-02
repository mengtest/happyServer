local skynet = require "skynet"
local commonServiceHelper = require "serviceHelper.common"
local addressResolver = require "addressResolver"
local resourceResolver = require "resourceResolver"
local timerUtility = require "utility.timer"
local mysqlutil = require "mysqlutil"
local COMMON_CONST = require "define.commonConst"
local ServerUserItem = require "sui"
local lsConst = require "define.lsConst"
local currencyUtility = require "utility.currency"
local xLog = require "xLog"

local _data = {
}

local function cmd_onEventLoginSuccess(data)
	local nowTime = os.time()
	local nowDate = tonumber(os.date("%Y%m%d", nowTime))
	local lastDate = tonumber(os.date("%Y%m%d", data.lastLoginDate))
	if lastDate < nowDate then -- 写数据库
		local sql = string.format("call `QPAccountsDB`.p_activity_user_login(%d,%d,0)", data.userID,nowDate)
		local dbConn = addressResolver.getMysqlConnection()
		skynet.call(dbConn, "lua", "call", sql)
	end
end

local function cmd_intoLoginReward(userId)
	local re = {}
	local sql = string.format("select loginDate,monthNum,opState from `QPAccountsDB`.`s_user_login` where id=%d", userId)
	local dbConn = addressResolver.getMysqlConnection()
	local rows = skynet.call(dbConn, "lua", "query", sql)
	if rows[1] ~= nil then
		re.loginDate = tonumber(rows[1].loginDate)
		re.opState = tonumber(rows[1].opState)
	end
	return re
end

local function cmd_getLoginOne(userId, sui)
	local re = {code = "RC_OK"}
	
	local sql = string.format("select opState from `QPAccountsDB`.`s_user_login` where id=%d", userId)
	local dbConn = addressResolver.getMysqlConnection()
	local rows = skynet.call(dbConn, "lua", "query", sql)
	if rows[1] == nil then
		re.code = "RC_OTHER"
		re.msg = "请求错误"
		return re
	end
	if opState & 1 == 0 then -- 可以领取
		local r = arc4.random(1,1000)
		if _data.loginOne[r] then
			ServerUserItem.addAttribute(sui, {_data.loginOne[r][1], present = _data.loginOne[r][2]})
		end
	end
	
	local attr = ServerUserItem.getAttribute(sui, {"present", "score"})
	re.gold = attr.score
	re.present = attr.present
	return re
end

local function cmd_getLoginMore(userId, sui)
	local re = {code = "RC_OK"}
	
	local sql = string.format("call `QPAccountsDB`.p_get_login_more(%d)", userId)
	local dbConn = addressResolver.getMysqlConnection()
	local rows = skynet.call(dbConn, "lua", "call", sql)
	if tonumber(rows[1].retCode)~=0 then
		re.code = "RC_OTHER"
		re.msg = rows[1].retMsg
		return re
	end
	
	ServerUserItem.addAttribute(sui, {score = tonumber(rows[1].gold)})
	local attr = ServerUserItem.getAttribute(sui, {"score"})
	re.gold = attr.score
	return re
end

local function cmd_getLoginEgg(userId, sui)
	local re = {code = "RC_OK"}
	local attr = ServerUserItem.getAttribute(sui, {"present", "memberOrder"})
	if attr.present <= 10000 then
		re.code = "RC_OTHER"
		re.msg = "礼券不足"
		return re
	end
	ServerUserItem.addAttribute(sui, {present = -10000})
	local sql = string.format("update `QPAccountsDB`.`AccountsInfo` set `Present`=`Present`-10000 where UserID=%d", userId)
	local dbConn = addressResolver.getMysqlConnection()
	local rows = skynet.call(dbConn, "lua", "query", sql)
	
	local r = arc4.random(1,1000)
	if _data.loginEgg[r] then
		re.eggId = _data.loginEgg[r]
		local t = _data.loginEggInfo[_data.loginEgg[r]]
		if t.tp == 1 then --金币
			ServerUserItem.addAttribute(sui, {score=t.num})
			sql = string.format("update `QPTreasureDB`.`GameScoreInfo` set `Score`=`Score`+%d where UserID=%d", t.num, userId)
			skynet.call(dbConn, "lua", "query", sql)
		elseif t.tp == 2 then --礼券
			ServerUserItem.addAttribute(sui, {present=t.num})
			sql = string.format("update `QPAccountsDB`.`AccountsInfo` set `Present`=`Present`+%d where UserID=%d", t.num, userId)
			skynet.call(dbConn, "lua", "query", sql)
		elseif t.tp == 3 then --vip
			if attr.memberOrder < t.num then
				ServerUserItem.setAttribute(sui, {memberOrder=t.num})
			end
			string.format("call `QPTreasureDB`.`s_write_vip`(%d,%d,%d)", userId, t.num, 1)
			skynet.call(dbConn, "lua", "call", sql)
		elseif t.tp == 4 then --子弹
		end
	end
	return re
end

local function cmd_getSkin(userId)
	local re = {}
	
	local sql = string.format("call `QPAccountsDB`.p_get_user_skin(%d)", userId)
	local dbConn = addressResolver.getMysqlConnection()
	local rows = skynet.call(dbConn, "lua", "call", sql)
	if tonumber(rows[1].retCode)~=0 then
		return re
	end
	
	re.skin = tonumber(rows[1].skin)
	re.useSkinId = tonumber(rows[1].useSkinId)
	return re
end

local function cmd_buySkin(userId, sui, skinId)
	local re = {}
	
	if skinId <= 0 or skinId > 64 then
		return
	end
	
	local dbConn = addressResolver.getMysqlConnection()
	local sql = string.format("select skin from `QPTreasureDB`.`s_user_skin` where id=%d", userId)
	local rows = skynet.call(dbConn, "lua", "query", sql)
	if rows[1]==nil or (tonumber(rows[1].skin) & 1<<(skinId-1))~=0 then
		re.code = "RC_OTHER"
		re.msg = "已经拥有该皮肤"
		return re
	end
	local skin = tonumber(rows[1].skin)
	
	sql = string.format("select skin from `QPTreasureDB`.`d_skin_info` where id=%d", skinId)
	rows = skynet.call(dbConn, "lua", "query", sql)
	if rows[1] ==nil or tonumber(rows[1].tp) == 0 or tonumber(rows[1].tp) == 2 then
		re.code = "RC_OTHER"
		re.msg = "该皮肤无法用金币购买"
		return re
	end
	
	local attr = ServerUserItem.getAttribute(sui, {"score"})
	if attr.score < tonumber(rows[1].gold) then
		re.code = "RC_OTHER"
		re.msg = "金币不足"
		return re
	end
	ServerUserItem.addAttribute(sui, {score = -tonumber(rows[1].gold)})
	sql = string.format("update `QPTreasureDB`.`GameScoreInfo` set Score=Score-%d where UserID = %d", tonumber(rows[1].gold), userId)
	skynet.call(dbConn, "lua", "query", sql)
	sql = string.format("update `QPTreasureDB`.`s_user_skin` set skin=%d where UserID = %d", skin | (1<<(skinId-1)), userId)
	skynet.call(dbConn, "lua", "query", sql)
	
	
	re.code = "RC_OK"
	re.gold = attr.score - tonumber(rows[1].gold)
	return re
end

local function cmd_setSkin(userId, skinId)
	local re = {}
	
	if skinId < -1 or skinId > 64 then
		return
	end
	
	if skinId > 0 then
		local dbConn = addressResolver.getMysqlConnection()
		local sql = string.format("select skin from `QPTreasureDB`.`s_user_skin` where id=%d", userId)
		local rows = skynet.call(dbConn, "lua", "query", sql)
		if rows[1]==nil or (tonumber(rows[1].skin) & 1<<(skinId-1))==0 then
			re.code = "RC_OTHER"
			re.msg = "当前未拥有该皮肤"
			return re
		end
	end
	sql = string.format("update `QPTreasureDB`.`s_user_skin` set useSkinId=%d where id=%d", skinId, userId)
	skynet.call(dbConn, "lua", "query", sql)
	
	re.code = "RC_OK"
	return re
end

local conf = {
	methods = {
		["onEventLoginSuccess"] = {["func"]=cmd_onEventLoginSuccess, ["isRet"]=false},
		
		["intoLoginReward"] = {["func"]=cmd_intoLoginReward, ["isRet"]=true},
		["getLoginOne"] = {["func"]=cmd_getLoginOne, ["isRet"]=true},
		["getLoginMore"] = {["func"]=cmd_getLoginMore, ["isRet"]=true},
	},
	initFunc = function()
		resourceResolver.init()
		
		local LS_EVENT = require "define.eventLoginServer"
		skynet.send(addressResolver.getAddressByServiceName("eventDispatcher"), 
				"lua", "addEventListener", LS_EVENT.EVT_LS_LOGIN_SUCCESS, 
				skynet.self(), "onEventLoginSuccess")
				
		local sql = "select * from `QPAccountsDB`.`d_login_one`"
		
		local dbConn = addressResolver.getMysqlConnection()
		local rows = skynet.call(dbConn, "lua", "query", sql)
		_data.loginOne = {}
		local t = 0
		for _,row in pairs(rows) do
			local k = tonumber(row.permillage)
			if k > 0 then
				for i=1+t,k+t do 
					_data.loginOne[i] = {tonumber(row.gold),tonumber(row.present)}
				end
				t = t + k
			end
		end
		
		sql = "select * from `QPAccountsDB`.`d_login_egg`"
		rows = skynet.call(dbConn, "lua", "query", sql)
		_data.loginEgg = {}
		_data.loginEggInfo = {}
		t = 0
		for _,row in pairs(rows) do
			local k = tonumber(row.permillage)
			if k > 0 then
				_data.loginEggInfo[tonumber(row.id)]={tp=tonumber(row.tp),num=tonumber(row.num)}
				for i=1+t,k+t do 
					_data.loginEgg[i] = tonumber(row.id)
				end
				t = t + k
			end
		end
		
	end,
}

commonServiceHelper.createService(conf)
