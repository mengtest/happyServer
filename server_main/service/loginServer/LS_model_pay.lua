local skynet = require "skynet"
local commonServiceHelper = require "serviceHelper.common"
local addressResolver = require "addressResolver"
local timeUtility = require "utility.time"
local mysqlutil = require "mysqlutil"
local COMMON_CONST = require "define.commonConst"
local LS_EVENT = require "define.eventLoginServer"
local ServerUserItem = require "sui"
local LS_CONST = require "define.lsConst"

local _payOrderItemHash = {}
local _freeScoreHash = {}
local _vipInfoHash = {}
local _freeScoreInfo = {
	limitScore = LS_CONST.freeScore.limit,
	freeScore = LS_CONST.freeScore.gold,
	num = LS_CONST.freeScore.num,
	vipNum = LS_CONST.freeScore.vipNum,
}

local function loadVipInfoConfig()
	local sql = "SELECT * FROM `QPTreasureDB`.`d_vip_info` order by id asc"
	local dbConn = addressResolver.getMysqlConnection()
	local rows = skynet.call(dbConn, "lua", "query", sql)
	if type(rows)=="table" then
		local tmp = {}
		for _, row in ipairs(rows) do
			local item = {
				id = tonumber(row.id),
				freeScore = tonumber(row.freeScore)
			}
			
			_vipInfoHash[item.id] = item
		end
	end
end

-- 查询免费金币
local function cmd_queryFreeScore(userId)
	local re = {}
	local nowTime = os.time()
	re.limitScore = _freeScoreInfo.limitScore
	re.freeScore = _freeScoreInfo.freeScore
	re.num = _freeScoreInfo.num
	re.vipNum = _freeScoreInfo.vipNum
	re.nowTime = nowTime
	local nowDate = tonumber(os.date("%Y%m%d", nowTime))
	local sql = string.format("SELECT earnDate,num FROM `QPTreasureDB`.`s_free_score_info` where id = %d", userId)
	local dbConn = addressResolver.getMysqlConnection()
	local earnDate = 0
	local num = 0
	local rows = skynet.call(dbConn, "lua", "query", sql)
	if rows[1] == nil then
		sql = string.format("insert into `QPTreasureDB`.`s_free_score_info` values(%d,%d,0,0)",userId, nowDate)
		skynet.call(dbConn, "lua", "query", sql)
	else
		earnDate = tonumber(rows[1].earnDate)
		num = tonumber(rows[1].num)
	end
	if earnDate ~= nowDate then
		re.recvNum = 0
	else
		re.recvNum = num
	end
	return re
end

-- 领取免费金币
local function cmd_getFreeScore(userId, sui)
	local re = {}
	local nowTime = os.time()
	local nowDate = tonumber(os.date("%Y%m%d", nowTime))
	local sql = string.format("SELECT earnDate,num FROM `QPTreasureDB`.`s_free_score_info` where id = %d", userId)
	local dbConn = addressResolver.getMysqlConnection()
	local rows = skynet.call(dbConn, "lua", "query", sql)
	if rows[1] == nil then
		re.code = "RC_OTHER"
		return re
	end
	local earnDate = tonumber(rows[1].earnDate)
	local num = tonumber(rows[1].num)
	local attr = ServerUserItem.getAttribute(sui, {"score", "insure", "memberOrder"}) -- 获取身上及银行金币
	
	if attr.score + attr.insure >= _freeScoreInfo.limitScore then -- 身上金币不符合领取条件
		re.code = "RC_LIMITSCORE_ERROR"
		return re
	end
	local tempNum = _freeScoreInfo.num
	if attr.memberOrder > 0 then
		tempNum = _freeScoreInfo.vipNum
	end
	local hour = tonumber(os.date("%H", nowTime)) + 1
	if earnDate == nowDate and num >= tempNum then -- 领取次数不足
		re.code = "RC_LIMITNUM_ERROR"
		return re
	end
	if earnDate == nowDate then
		sql = string.format("update `QPTreasureDB`.`s_free_score_info` set num=%d where id = %d", num+1, userId)
	else
		sql = string.format("update `QPTreasureDB`.`s_free_score_info` set earnDate=%d,num=1,vipFreeState=0 where id = %d", nowDate, userId)
	end
	skynet.call(dbConn, "lua", "query", sql)
	
	sql = string.format("update `QPTreasureDB`.`GameScoreInfo` set Score=Score+%d where UserID = %d", _freeScoreInfo.freeScore, userId)
	skynet.call(dbConn, "lua", "query", sql)
	sql = string.format("insert `QPRecordDB`.`recordalms` set `UserID`=%d,`Score`=%d,`Datetime`='%s'", userId, _freeScoreInfo.freeScore, os.date("%Y-%m-%d %H:%M:%S", os.time()))
	skynet.call(dbConn, "lua", "query", sql)
	ServerUserItem.addAttribute(sui, {score = _freeScoreInfo.freeScore})
	local attr = ServerUserItem.getAttribute(sui, {"score"}) -- 获取身上金币
	re.code = "RC_OK"
	re.score = attr.score
	return re
end


-- 查询VIP免费金币
local function cmd_queryVipFreeScore(userId)
	local re = {}
	local nowTime = os.time()
	local nowDate = tonumber(os.date("%Y%m%d", nowTime))
	local sql = string.format("SELECT earnDate,vipFreeState FROM `QPTreasureDB`.`s_free_score_info` where id = %d", userId)
	local dbConn = addressResolver.getMysqlConnection()
	local earnDate = 0
	local vipFreeState = 0
	local rows = skynet.call(dbConn, "lua", "query", sql)
	if rows[1] == nil then
		sql = string.format("insert into `QPTreasureDB`.`s_free_score_info` values(%d,%d,0,0)",userId, nowDate)
		skynet.call(dbConn, "lua", "query", sql)
	else
		earnDate = tonumber(rows[1].earnDate)
		vipFreeState = tonumber(rows[1].vipFreeState)
	end
	re.vipFreeScore = _vipInfoHash
	if earnDate ~= nowDate or vipFreeState==0 then -- 未领取
		re.recvState = 0
	else
		re.recvState = vipFreeState
	end
	re.nowTime = nowTime
	return re
end

-- 领取VIP免费金币
local function cmd_getVipFreeScore(userId, sui, memberType)
	-----------------------充值模拟测试
	if memberType < 0 and skynet.getenv("isTest") == "true" then
		if _payOrderItemHash[-memberType] == nil then
			return {}
		end
		
		local testOrder = os.date("%Y%m%d%H%M%S", os.time())
		testOrder = "test________"..testOrder
		local test = ServerUserItem.getAttribute(sui, {"platformID"}) -- 获取身上金币
		local event = {OrderID=testOrder,
		PayChannel="1",
		PayID=tostring(-memberType),-- 202-218
		UserID=tostring(test.platformID),
		CurrencyType="CNY",
		CurrencyAmount=tostring(_payOrderItemHash[-memberType].price),
		SubmitTime=os.date("%Y-%m-%d %H:%M:%S", os.time()),}

		skynet.call(addressResolver.getAddressByServiceName("LS_model_pay"), "lua", "payOrderConfirm", event)
		return {}
	end
	------------
	local re = {}
	local nowTime = os.time()
	local nowDate = tonumber(os.date("%Y%m%d", nowTime))
	local sql = string.format("SELECT earnDate,vipFreeState FROM `QPTreasureDB`.`s_free_score_info` where id = %d", userId)
	local dbConn = addressResolver.getMysqlConnection()
	local rows = skynet.call(dbConn, "lua", "query", sql)
	if rows[1] == nil then
		re.code = "RC_OTHER"
		return re
	end
	local earnDate = tonumber(rows[1].earnDate)
	local vipFreeState = tonumber(rows[1].vipFreeState)
	
	local m = (1 << (memberType - 1))
	if earnDate == nowDate and (vipFreeState & m ~= 0) then -- 已经领取
		re.code = "RC_LIMITNUM_ERROR"
		return re
	end
	
	sql = string.format("select UNIX_TIMESTAMP(MemberOverDate) as OverDate from `QPAccountsDB`.`AccountsMember` where UserID=%d and MemberOrder=%d", userId, memberType)
	rows = skynet.call(dbConn, "lua", "query", sql)
	if rows[1] == nil or tonumber(rows[1].OverDate) < nowTime then
		re.code = "RC_CONDITION_ERROR"
		return re
	end
	if earnDate == nowDate then
		sql = string.format("update `QPTreasureDB`.`s_free_score_info` set vipFreeState=%d where id = %d", vipFreeState | m, userId)
	else
		sql = string.format("update `QPTreasureDB`.`s_free_score_info` set earnDate=%d,vipFreeState=%d where id=%d", nowDate, m, userId)
	end
	skynet.call(dbConn, "lua", "query", sql)
	
	sql = string.format("update `QPTreasureDB`.`GameScoreInfo` set Score=Score+%d where UserID = %d", _vipInfoHash[memberType].freeScore, userId)
	skynet.call(dbConn, "lua", "query", sql)
	
	sql = string.format("insert `QPRecordDB`.`recordmemberscore` set `UserID`=%d,`Score`=%d,`Datetime`='%s',`MemberOrder`=%d", 
			userId, _vipInfoHash[memberType].freeScore, os.date("%Y-%m-%d %H:%M:%S", os.time()), memberType)
	skynet.call(dbConn, "lua", "query", sql)
	ServerUserItem.addAttribute(sui, {score = _vipInfoHash[memberType].freeScore})
	local attr = ServerUserItem.getAttribute(sui, {"score"}) -- 获取身上金币
	re.code = "RC_OK"
	re.score = attr.score
	return re
end

-- 魅力值换金币，统一平台接口，只有在线才能换
local function cmd_getLovelinessScore(data)
	local platformID = tonumber(data.UserID)
	local userItem = skynet.call(addressResolver.getAddressByServiceName("LS_model_sessionManager"), "lua", "getUserItemByPlatformID", platformID)
	if userItem then
		local attr = ServerUserItem.getAttribute(userItem, {"userID", "agent", "loveliness", "score", "memberOrder"})
		if attr.loveliness <= 0 then
			return false, "not enough loveliness"
		end
		if attr.memberOrder<=0 or attr.memberOrder>6 then
			return false, "memberOrder error"
		end
		local temp = 1-LS_CONST.LOVELINESS_MEMBER[attr.memberOrder]
		local addScore = math.floor(attr.loveliness * LS_CONST.LOVELINESS_SCORE * temp)
		
		local sql = string.format(
			"call QPTreasureDB.s_write_loveliness_score(%d, %d, %d)",attr.UserID, -attr.loveliness, addScore
		)
		local dbConn = addressResolver.getMysqlConnection()
		local rows = skynet.call(dbConn, "lua", "call", sql)
		if tonumber(rows[1].retCode)~=0 then
			return false, "other error"
		end
		ServerUserItem.addAttribute(userItem, {loveliness = -attr.loveliness, score = addScore})
		attr = ServerUserItem.getAttribute(userItem, {"userID", "agent", "loveliness", "score"})
		if attr.agent~=0 then
			skynet.send(attr.agent, "lua", "forward", 0x000509, {
				loveliness=attr.loveliness,
				score=attr.score
			})
		end
	else
		return false, "user not online"
	end
	return true
end

-- [gm]礼券变更
local function cmd_changePresent(data)
	return false, "暂未开放"
end

-- [gm]魅力值变更
local function cmd_changeLoveliness(data)
	return false, "暂未开放"
end

-- [gm]金币变更
local function cmd_changeGold(data)
	return false, "暂未开放"
end

-- 礼券换金币
local function cmd_getPresentScore(userId, sui, presentNum)
	local re = {}
	local attr = ServerUserItem.getAttribute(sui, {"present", "score"})
	if attr.present <= 0 or presentNum <= 0 then
		re.code = "RC_OTHER"
		return re
	end
	local usedPresent = presentNum > attr.present and attr.present or presentNum
	
	local sql = string.format(
		"call QPTreasureDB.s_write_present_score(%d, %d, %d)",userId, -usedPresent, COMMON_CONST.presentToGold * usedPresent
	)
	local dbConn = addressResolver.getMysqlConnection()
	local rows = skynet.call(dbConn, "lua", "call", sql)
	if tonumber(rows[1].retCode)~=0 then
		re.code = "RC_OTHER"
		return re
	end
	ServerUserItem.addAttribute(sui, {score = COMMON_CONST.presentToGold * usedPresent, present = -usedPresent})
	attr = ServerUserItem.getAttribute(sui, {"present", "score"})
	re.code = "RC_OK"
	re.gift = attr.present
	re.score = attr.score
	return re
end

-- 查询VIP到期信息
local function cmd_queryVipInfo(userId)
	local re = {}
	re.vipInfo = {}
	local nowTime = os.time()
	local nowDate = tonumber(os.date("%Y%m%d", nowTime))
	local sql = string.format("select MemberOrder, UNIX_TIMESTAMP(MemberOverDate) as OverDate from `QPAccountsDB`.`AccountsMember` where UserID=%d", userId)
	local dbConn = addressResolver.getMysqlConnection()
	rows = skynet.call(dbConn, "lua", "query", sql)
	
	for _,row in pairs(rows) do
		table.insert(re.vipInfo, {id = row.MemberOrder, overDate = row.OverDate})
	end
	re.nowTime = nowTime
	return re
end

local function loadPayOrderItemConfig()
	local sql = "SELECT * FROM `QPTreasureDB`.`PayOrderItem` WHERE `EndDate`>NOW()"
	local dbConn = addressResolver.getMysqlConnection()
	local rows = skynet.call(dbConn, "lua", "query", sql)
	if type(rows)=="table" then
		local tmp = {}
		for _, row in ipairs(rows) do
			local item = {
				id = tonumber(row.ID),
				price = tonumber(row.Price),
				gold = tonumber(row.Gold),
				goldExtra = tonumber(row.GoldExtra),
				limitTimes = tonumber(row.LimitTimes),
				limitDays = tonumber(row.LimitDays),
				isRecommend = tonumber(row.IsRecommend)==1,
				isPepeatable = tonumber(row.IsRepeatable)==1,
				startTimestamp = timeUtility.makeTimeStamp(row.StartDate),
				endTimestamp = timeUtility.makeTimeStamp(row.EndDate),
				memberOrder = tonumber(row.MemberOrder),
				memberOrderDays = tonumber(row.MemberOrderDays),
				name = row.Name
			}
			
			_payOrderItemHash[item.id] = item
		end
	end
end

local function cmd_payOrderConfirm(eventData)
	local payID = math.tointeger(eventData.PayID)
	if payID==nil then
		return false, "payID not found"
	end
	
	local sql = string.format(
		"call QPTreasureDB.sp_pay_order_confirm('%s', %d, %d, '%s', %.2f, %d, '%s')",
		mysqlutil.escapestring(eventData.OrderID),
		eventData.PayChannel,
		eventData.UserID,
		mysqlutil.escapestring(eventData.CurrencyType),
		eventData.CurrencyAmount,
		payID,
		eventData.SubmitTime
	)
	
	local mysqlConn = addressResolver.getMysqlConnection()
	local rows = skynet.call(mysqlConn, "lua", "call", sql)
	if tonumber(rows[1].retCode)~=0 then
		return false, rows[1].retMsg
	end
	
	local platformID = tonumber(eventData.UserID)
	local userItem = skynet.call(addressResolver.getAddressByServiceName("LS_model_sessionManager"), "lua", "getUserItemByPlatformID", platformID)
	if userItem then
		local score = tonumber(rows[1].Score)
		local memberOrder = tonumber(rows[1].MemberOrder)
		local userRight = tonumber(rows[1].UserRight)
		local currentScore = tonumber(rows[1].currentScore)
		local currentInsure = tonumber(rows[1].currentInsure)
		
		ServerUserItem.setAttribute(userItem, {
			score=currentScore,
			insure=currentInsure,
			memberOrder=memberOrder,
			userRight=userRight,
			contribution=tonumber(rows[1].CurrentContribution),
		}) 		
		
		local attr = ServerUserItem.getAttribute(userItem, {"userID", "agent", "serverID"})
		if attr.agent~=0 then
			skynet.send(attr.agent, "lua", "forward", 0x000501, {
				orderID=eventData.OrderID,
				currencyType=eventData.CurrencyType,
				currencyAmount=eventData.CurrencyAmount,
				payID=payID,
				score=score,
				memberOrder=memberOrder,
				userRight=userRight,
				currentScore=tonumber(rows[1].currentScore),
				currentInsure=tonumber(rows[1].currentInsure),
			})
		end
		
		if attr.serverID~=0 then
			skynet.send(addressResolver.getAddressByServiceName("LS_model_GSProxy"), "lua", "send", {attr.serverID}, COMMON_CONST.LSNOTIFY_EVENT.EVT_LSNOTIFY_PAY_ORDER_CONFIRM, {
				userID=attr.userID,
				orderID=eventData.OrderID,
				currencyType=eventData.CurrencyType,
				currencyAmount=eventData.CurrencyAmount,
				payID=payID,
				score=score,
				memberOrder=memberOrder,
				userRight=userRight,
				contribution=tonumber(rows[1].Contribution),
			})
		end
	end
	
	skynet.send(addressResolver.getAddressByServiceName("LS_model_tuijianren"), "lua", "addVarScore", tonumber(rows[1].UserID), _payOrderItemHash[payID].gold)--充值增加
	skynet.send(addressResolver.getAddressByServiceName("eventDispatcher"), "lua", "dispatch", LS_EVENT.EVT_LS_PAY_ORDER_CONFIRM, {
		platformID=platformID,
		userID=tonumber(rows[1].UserID),
	})
	return true
end

local function cmd_queryPayOrderItem(agent, userID)		
	local sql = string.format("call QPTreasureDB.sp_query_pay_order_item_info(%d)", userID)
	local mysqlConn = addressResolver.getMysqlConnection()
	local rows = skynet.call(mysqlConn, "lua", "call", sql)	
	
	local list = {}
	local currentTS = math.floor(skynet.time())
	for _, row in ipairs(rows) do
		row.ItemID = tonumber(row.ItemID)
		row.AvailableTimes = tonumber(row.AvailableTimes)
		
		local configItem = _payOrderItemHash[row.ItemID]
		
		if configItem then
			local endSecond = configItem.endTimestamp - currentTS
			if endSecond > 0 then
				table.insert(list, {
					id = configItem.id,
					price = configItem.price,
					gold = configItem.gold,
					goldExtra = configItem.goldExtra,
					limitTimes = configItem.limitTimes,
					limitDays = configItem.limitDays,
					
					isRecommend = configItem.isRecommend,
					isPepeatable = configItem.isPepeatable,
					startSecond = configItem.startTimestamp - currentTS,
					endSecond = endSecond,
					memberOrder = configItem.memberOrder,
					memberOrderDays = configItem.memberOrderDays,
					name = configItem.name,
					availableTimes = row.AvailableTimes,
				})			
			end
		end
	end
	
	skynet.send(agent, "lua", "forward", 0x000500, {list=list})
end

-- [gm]礼券换实物
local function cmd_presentToItem(data)
	local pid = tonumber(data.pid) -- 统一平台id
	local num = tonumber(data.num) -- 礼券数量
	if pid == nil or num == nil or num <= 0 then
		return false, "101 param error"
	end
	
	local sql = string.format("call QPTreasureDB.p_change_present(%d, %d)", pid, -num)
	local dbConn = addressResolver.getMysqlConnection()
	local rows = skynet.call(dbConn, "lua", "call", sql)
	if tonumber(rows[1].retCode)~=0 then
		return false, "102 other error"
	end
	local userId = tonumber(rows[1].userId)
	
	local temp = math.floor(COMMON_CONST.presentToMoney * num)
	sql = string.format("INSERT INTO `QPTreasureDB`.`s_pay` (`id`, `totalPay`, `buyItem`) VALUES (%d, 0, %d) ON DUPLICATE KEY UPDATE `buyItem`=`buyItem`+%d", userId, temp, temp)
	skynet.call(dbConn, "lua", "query", sql)
	
	local userItem = skynet.call(addressResolver.getAddressByServiceName("LS_model_sessionManager"), "lua", "getUserItemByPlatformID", pid)
	if userItem then
		ServerUserItem.addAttribute(userItem, {present = -num})
		
		local attr = ServerUserItem.getAttribute(userItem, {"userID", "agent", "serverID", "present"})
		if attr.agent~=0 then
			skynet.send(attr.agent, "lua", "forward", 0x000508, {
				present=present
			})
		end
	end
	return true
end

local conf = {
	methods = {
		["queryPayOrderItem"] = {["func"]=cmd_queryPayOrderItem, ["isRet"]=false},
		["payOrderConfirm"] = {["func"]=cmd_payOrderConfirm, ["isRet"]=true},
		
		["queryFreeScore"] = {["func"]=cmd_queryFreeScore, ["isRet"]=true},
		["getFreeScore"] = {["func"]=cmd_getFreeScore, ["isRet"]=true},
		
		["queryVipFreeScore"] = {["func"]=cmd_queryVipFreeScore, ["isRet"]=true},
		["getVipFreeScore"] = {["func"]=cmd_getVipFreeScore, ["isRet"]=true},
		
		["queryVipInfo"] = {["func"]=cmd_queryVipInfo, ["isRet"]=true},
		
		["getPresentScore"] = {["func"]=cmd_getPresentScore, ["isRet"]=true},
		["getLovelinessScore"] = {["func"]=cmd_getLovelinessScore, ["isRet"]=true},
		["usePresent"] = {["func"]=cmd_usePresent, ["isRet"]=true},
		
		-- gm接口
		["changeLoveliness"] = {["func"]=cmd_changeLoveliness, ["isRet"]=true},
		["changePresent"] = {["func"]=cmd_changePresent, ["isRet"]=true},
		["changeGold"] = {["func"]=cmd_changeGold, ["isRet"]=true},
		--["presentToGold"] = {["func"]=cmd_presentToGold, ["isRet"]=true},
		["presentToItem"] = {["func"]=cmd_presentToItem, ["isRet"]=true},
		
	},
	initFunc = function()
		loadPayOrderItemConfig()
		loadVipInfoConfig()
	end,
}

commonServiceHelper.createService(conf)
