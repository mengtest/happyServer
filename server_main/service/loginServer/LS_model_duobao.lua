local skynet = require "skynet"
local arc4 = require "arc4random"
local commonServiceHelper = require "serviceHelper.common"
local addressResolver = require "addressResolver"
local timerUtility = require "utility.timer"
local mysqlutil = require "mysqlutil"
local COMMON_CONST = require "define.commonConst"
local ServerUserItem = require "sui"
local LS_CONST = require "define.lsConst"
local httpc = require "http.httpc"
local cjson = require "cjson"

local _config = {
	maxGoldChip = 1000,
	historyNum = 5,	--历史记录条数
}

local _data = {
	goldNo = 0,
	goldNow = nil, -- 当前金币场投注
	goldUser = {}, -- 下注玩家
	goldRandom = {}, -- 随机夺宝号分配顺序
	goldRandomNo = 0, -- 已购买注数
	goldHistory = {}, --金币场历史
	goldHistoryNo = 0,
	goldWait = nil, --等待结算
	goldWaitUser = nil,
	goldNowRecord = {},--昵称-购买注数
	goldNowRecordNo = 0,
}

local function addNow(userId, num, name)
	local nowTime = os.time()
	local mysqlConn = addressResolver.getMysqlConnection()
	for i=1,num do
		_data.goldRandomNo = _data.goldRandomNo + 1
		_data.goldUser[_data.goldRandom[_data.goldRandomNo]] = userId
		local sql = string.format("insert into s_duobao_gold_record values(%d,%d,%d,'%s')", 
				_data.goldNo, _data.goldRandom[_data.goldRandomNo], userId, os.date("%Y-%m-%d %H:%M:%S",nowTime))
		skynet.call(mysqlConn, "lua", "query", sql)
	end
	_data.goldNowRecordNo = _data.goldNowRecordNo%20 + 1
	_data.goldNowRecord[_data.goldNowRecordNo] = {name = name, chipNum = num, chipTime = nowTime}
	
	if _data.goldRandomNo >= 1000 and goldWait == nil then
	end
end

local function addHistory(data)
	_data.goldHistoryNo = _data.goldHistoryNo%_config.historyNum + 1
	_data.goldHistory[_data.goldHistoryNo] = {
		id = data.id,	--期号
		beginTime = data.beginTime,
		endTime = data.endTime,
		sscId = data.sscId,
		sscNo = data.sscNo,
		winnerId = data.winnerId,
		winnerGameId = data.winnerGameId,
		winnerName = data.winnerName,
		winnerNum = data.winnerNum,
		overTime = data.overTime
	}
end

local function sendReward(sscData)-- 记录数据，发送奖励
	local t = sscData.opencode
	local sscNum = tonumber(string.sub(t,1,1)) -- 中奖号码
	for i=2,5 do
		sscNum = sscNum * 10 + tonumber(string.sub(t,i*2-1,i*2-1))
	end
	local winnerId = _data.goldWaitUser[sscNum%1000 + 1]
	local chipNum = 0
	for i=1,1000 do
		if _data.goldWaitUser[i] == winnerId then
			chipNum = chipNum + 1
		end
	end
	local sql = string.format("select GameID,NickName from AccountsInfo where UserID=%d", winnerId)
	local mysqlConn = addressResolver.getMysqlConnection()
	local rows = skynet.call(mysqlConn, "lua", "query", sql)
	if rows[1] == nil then
		return
	end
	local overTime = os.time()
	sql = string.format("update s_duobao_gold set sscNo=%d,winnerId=%d,winnerGameId=%d,winnerName='%s',winnerNum=%d,overTime='%s' where id=%d",
			sscNum, winnerId, tonumber(rows[1].GameID), rows[1].NickName, chipNum, os.date("%Y-%m-%d %H:%M:%S", overTime), _data.goldWait.id)
	skynet.call(mysqlConn, "lua", "query", sql)
	
	_data.goldWait.sscNo = sscNum
	_data.goldWait.winnerId = winnerId
	_data.goldWait.winnerGameId = tonumber(rows[1].GameID)
	_data.goldWait.winnerName = rows[1].NickName
	_data.goldWait.winnerNum = chipNum
	_data.goldWait.overTime = overTime
	--加钱，扣手续费
	addHistory(_data.goldWait)
	_data.goldWait = nil
	_data.goldWaitUser = nil
end

local function getSscTimer()
	if _data.goldWait == nil then
		return
	end
	local code,body
	code,body = httpc.get("f.apiplus.cn","/cqssc.json")
	if code ~= 200 then
		timerUtility.setTimeout(getSscTimer,1)
		return -- 获取结果失败
	end
	
	if type(body) ~= "string" then
		timerUtility.setTimeout(getSscTimer,1)
		return
	end
	local isOK, event = pcall(cjson.decode, body)
	if not isOK then
		timerUtility.setTimeout(getSscTimer,1)
		return
	end
	local isFind = false
	for _,v in pairs(event.data) do
		if tonumber(v.expect) == _data.goldWait.sscId then--匹配上
			sendReward(v)
			isFind = true
			break
		end
	end
	if isFind == false then
		timerUtility.setTimeout(getSscTimer,1)
	else
		timerUtility.stop()
	end
	
end

local function getSscIdFromTime(t)
	local n = tonumber(os.date("%Y%m%d", _data.goldWait.endTime))
	local x = os.date("%H%M", t)
	local m = x//100 * 60 + x%100
	if m < 120 then
		return n*1000 + m//5+1
	elseif m >= 1320 then
		return n*1000 + (m-1320)//5+97
	elseif m < 600 then
		return n*1000+24
	else
		return n*1000 + (m-600)//10+25
	end
end

local function addWait() --产生新一期夺宝
	if _data.goldWait ~= nil then
		return
	end
	if _data.goldNow ~= nil then
		if _data.goldRandomNo >= 1000 then
			_data.goldWait = _data.goldNow
			_data.goldWaitUser = _data.goldUser
			_data.goldWait.endTime = os.time()
			_data.goldWait.sscId = getSscIdFromTime(_data.goldWait.endTime)
			local sql = string.format("update s_duobao_gold set sscId=%d,endTime='%s' where id=%d",
					_data.goldWait.sscId, os.date("%Y-%m-%d %H:%M:%S", _data.goldWait.endTime), _data.goldWait.id)
			local mysqlConn = addressResolver.getMysqlConnection()
			skynet.call(mysqlConn, "lua", "query", sql)
			timerUtility.start(6000)
			timerUtility.setTimeout(getSscTimer, 1)
		else
			return
		end
	end
	_data.goldNo = _data.goldNo + 1
	_data.goldNow = {id = _data.goldNo,sscId = 0,beginTime = os.time()}
	_data.goldUser = {}
	
	local temp2 = 0
	_data.goldRandomNo = 0
	for j=1,1000 do
		_data.goldRandom[j] = j-1
	end
	for k,v in pairs(_data.goldRandom) do
		local r = arc4.random(k, 1000)
		temp2 = v
		_data.goldRandom[k] = _data.goldRandom[r]
		_data.goldRandom[r] = temp2
	end
	-- 插入数据库
	local sql = string.format("insert into s_duobao_gold set id=%d,sscId=%d,beginTime='%s'",
			_data.goldNow.id, _data.goldNow.sscId, os.date("%Y-%m-%d %H:%M:%S", _data.goldNow.beginTime))
	local mysqlConn = addressResolver.getMysqlConnection()
	skynet.call(mysqlConn, "lua", "query", sql)
end

local function d_config()
	local mysqlConn = addressResolver.getMysqlConnection()
	local sql = string.format("select id,UNIX_TIMESTAMP(beginTime) as beginTime,UNIX_TIMESTAMP(endTime) as endTime,sscId,sscNo,winnerId,winnerGameId,winnerName,winnerNum,UNIX_TIMESTAMP(overTime) as overTime from `QPAccountsDB`.`s_duobao_gold` order by `id` desc limit %d",
			_config.historyNum + 2)
	local rows = skynet.call(mysqlConn, "lua", "query", sql)
	_data.goldNo = 0
	if rows[1] ~= nil then
		_data.goldNo = tonumber(rows[1].id)
	end
	
	for i=_config.historyNum + 2,1,-1 do
		local row = rows[i]
		if row ~= nil then
			if tonumber(row.sscId) == -1 then -- 取消
				addHistory({id = tonumber(row.id), sscId = -1})
			elseif tonumber(row.sscId) == 0 then -- 正在投注
				_data.goldNow = {id = tonumber(row.id), sscId = 0}
				
	local sqlTemp = string.format("select * from `QPAccountsDB`.`s_duobao_gold_record` where `id` = %d",
			tonumber(row.id))
	local rowsTemp = skynet.call(mysqlConn, "lua", "query", sqlTemp)
	local duobaoTemp = {}
	for j=1,1000 do
		duobaoTemp[j] = j-1
	end
	for _,rowTemp in ipairs(rowsTemp) do
		_data.goldUser[tonumber(rowTemp.duobaoId)] = tonumber(rowTemp.userId)
		_data.goldRandomNo = _data.goldRandomNo + 1
		_data.goldRandom[_data.goldRandomNo] = tonumber(rowTemp.duobaoId)
		duobaoTemp[tonumber(rowTemp.duobaoId) + 1] = nil
	end
	local temp1 = {}
	local k = 1
	for _,v in pairs(duobaoTemp) do
		temp1[k] = v
		k = k + 1
	end
	local size = k - 1
	local temp2 = 0
	local temp3 = _data.goldRandomNo
	for k,v in pairs(temp1) do
		local r = arc4.random(k, size)
		temp2 = v
		temp3 = temp3 + 1
		_data.goldRandom[temp3] = temp1[r]
		temp1[r] = temp2
	end
	
			else -- 正在开奖或已经开奖
				if tonumber(row.winnerId) == 0 then --正在开奖
					_data.goldWait = {
						id = tonumber(row.id),
						beginTime = tonumber(row.beginTime),
						endTime = tonumber(row.endTime),
						sscId = tonumber(row.sscId),
					}
					local waitSql = string.format("select * from s_duobao_gold_record where id=%d", _data.goldWait.id)
					
					local waitTemp = skynet.call(mysqlConn, "lua", "query", waitSql)
					_data.goldWaitUser = {}
					for k,v in ipairs(waitTemp) do
						_data.goldWaitUser[tonumber(v.duobaoId)+1] = tonumber(v.userId)
					end
					timerUtility.start(6000)
					timerUtility.setTimeout(getSscTimer, 1)
				else -- 已经开奖
					addHistory({
						id = tonumber(row.id),
						beginTime = tonumber(row.beginTime),
						endTime = tonumber(row.endTime),
						sscId = tonumber(row.sscId),
						sscNo = tonumber(row.sscNo),
						winnerId = tonumber(row.winnerId),
						winnerGameId = tonumber(row.winnerGameId),
						winnerName = row.winnerName,
						winnerNum = tonumber(row.winnerNum),
						overTime = tonumber(row.overTime),
					})
				end
			end
		end
	end
	
	--数据库加载完毕
	if _data.goldNow == nil then -- 第一次,数据库还没有信息
		addWait()
	end
end

local function cmd_intoDuobao(userId)
	local re = {}
	re.goldId = _data.goldNo
	re.goldChipNum = _data.goldRandomNo
	re.goldChipInfo = _data.goldNowRecord
	re.goldDuobaoInfo = _data.goldHistory
	local tempNow = {}
	for k,v in pairs(_data.goldUser) do
		if v == userId then
			table.insert(tempNow, k)
		end
	end
	re.goldNowChip = tempNow
	if _data.goldWaitUser ~= nil then
		local tempWait = {}
		for k,v in pairs(_data.goldWaitUser) do
			if v == userId then
				table.insert(tempWait, k)
			end
		end
		re.goldWaitChip = tempWait
	end
	return re
end

local function cmd_chip(userId, sui, pbObj)
	local re = {}
	if pbObj.num <= 0 then
		return
	end
	local nowTime = os.time()
	local t = tonumber(os.date("%H%M", nowTime))
	if t>130 and t <1000 then
		re.code = "RC_OTHER"
		re.msg = "还没有到开放购买时间"
		return re
	end
	if pbObj.id ~= _data.goldNo then
		re.code = "RC_OTHER"
		re.msg = "当期购买已经结束"
		return re
	end
	
	if pbObj.tp == 1 then -- 金币投注
		if _data.goldRandomNo + pbObj.num > 1000 then
			re.code = "RC_OTHER"
			re.msg = "剩余注数不足"
			return re
		end
		local attr = ServerUserItem.getAttribute(sui, {"score", "nickName"}) -- 获取身上金币
		if attr.score < pbObj.num * 100000 then
			re.code = "RC_OTHER"
			re.msg = "金币不足"
			return re
		end
		-- 数据库扣除金币
		ServerUserItem.addAttribute(sui, {score = - pbObj.num * 100000})
		addNow(userId, pbObj.num, attr.nickName)
		if _data.goldRandomNo >= 1000 then
			addWait()
		end
		re.score = attr.score - pbObj.num * 100000
	elseif pbObj.tp == 2 then -- 礼券投注
	end
	re.code = "RC_OK"
	return re
end

local conf = {
	methods = {
		["intoDuobao"] = {["func"]=cmd_intoDuobao, ["isRet"]=true},
		["chip"] = {["func"]=cmd_chip, ["isRet"]=true},
	},
	initFunc = function()
		d_config()
	end,
}

commonServiceHelper.createService(conf)
