local skynet = require "skynet"
local commonServiceHelper = require "serviceHelper.common"
local addressResolver = require "addressResolver"
local timerUtility = require "utility.timer"
local mysqlutil = require "mysqlutil"
local COMMON_CONST = require "define.commonConst"
local ServerUserItem = require "sui"
local LS_CONST = require "define.lsConst"

local _todayTotalScore = {} -- [id]={boxNum,totalScore}

local _todayDate = 0 --20151208

local function cmd_upTuijianren(agent, userId, data)
	local re = {}
	--���Ϸ���--
	local mysqlConn = addressResolver.getMysqlConnection()
	local sql = string.format("select fatherId from `QPAccountsDB`.`s_activity_tjr` where id=%d", userId)
	local rows = skynet.call(mysqlConn, "lua", "query", sql)
	if rows[1] == nil or tonumber(rows[1].fatherId) ~= 0 then -- �Ƽ����Ѵ��ڻ��Ѿ���ʱ�޷���д
		re.code = "RC_OTHER"
		return re
	end
	local nowTime = os.time()
	--��ȡ��ҵ�ע��ʱ��
	sql = string.format("select UNIX_TIMESTAMP(RegisterDate) as registerTime from `QPAccountsDB`.`AccountsInfo` where UserID=%d", userId)
	rows = skynet.call(mysqlConn, "lua", "query", sql)
	local userTime = tonumber(rows[1].registerTime)
	
	if nowTime - userTime > 86400 then
		re.code = "RC_INVALID_BETWEEN_DATE"
		return re
	end
	
	--��ȡ�Ƽ���ע��ʱ��
	sql = string.format("select UserID,NickName, UNIX_TIMESTAMP(RegisterDate) as registerTime from `QPAccountsDB`.`AccountsInfo` where GameID=%d", data.gameId)
	rows = skynet.call(mysqlConn, "lua", "query", sql)
	if rows[1] == nil then
		re.code = "RC_INVALID_ID"
		return re
	end
	
	local tjrTime = tonumber(rows[1].registerTime)
	local tjrId = tonumber(rows[1].UserID)
	local tjrName = rows[1].NickName
	if tjrTime >= userTime then
		re.code = "RC_INVALID_REGISTER_DATE"
		return re
	end
	
	sql = string.format("update `QPAccountsDB`.`s_activity_tjr` set fatherId=%d,kindId=%d where id=%d", tjrId, data.kindId, userId)
	skynet.call(mysqlConn, "lua", "query", sql)
	--��������-------
	local memberOrder = 1
	local memberDay = 2
	sql = string.format("call QPTreasureDB.s_write_vip(%d, %d, %d)", userId, memberOrder, memberDay)
	skynet.call(mysqlConn, "lua", "call", sql)
	
	re.code = "RC_OK"
	re.name = tjrName
	re.gameId = data.gameId
	return re
end

local function cmd_intoTuijianren(agent, userId, sui)
	local nowTime = os.time()
	local re = {userInfo = {}}
	re.date = tonumber(os.date("%Y%m%d", nowTime))
	--��ȡ������Ϣ
	local sql = string.format("select fatherId,recvScore,recvBox from `QPAccountsDB`.`s_activity_tjr` where id=%d", userId)
	local mysqlConn = addressResolver.getMysqlConnection()
	local rows = skynet.call(mysqlConn, "lua", "query", sql)
	local fatherId,recvScore,recvBox
	if rows[1] == nil then -- ����Ϣ�������
		sql = string.format("insert into `QPAccountsDB`.`s_activity_tjr` set id=%d", userId)
		skynet.call(mysqlConn, "lua", "query", sql)
		fatherId = 0
		recvScore = 0
		recvBox = 0
	else
		fatherId = tonumber(rows[1].fatherId)
		recvScore = tonumber(rows[1].recvScore)
		recvBox = tonumber(rows[1].recvBox)
	end
	
	if fatherId == -1 then -- ��ʾ���Ƽ�������дʱ���ѹ���
		re.tjrId = -1
	elseif fatherId == 0 then -- �ж�ע������
		re.tjrId = 0
		sql = string.format("select UNIX_TIMESTAMP(RegisterDate) as registerTime from `QPAccountsDB`.`AccountsInfo` where UserID=%d", 
				userId)
		rows = skynet.call(mysqlConn, "lua", "query", sql)
		if tonumber(rows[1].registerTime) + 86400 <= nowTime then -- �ѳ���24Сʱ
			sql = string.format("update `QPAccountsDB`.`s_activity_tjr` set fatherId=-1 where id=%d", userId)
			skynet.call(mysqlConn, "lua", "query", sql)
			re.tjrId = -1
		end
	else
		sql = string.format("select GameID,NickName from `QPAccountsDB`.`AccountsInfo` where UserID=%d", 
				fatherId)
		rows = skynet.call(mysqlConn, "lua", "query", sql)
		if rows[1] ~= nil then
			re.tjrId = tonumber(rows[1].GameID)
			re.tjrName = rows[1].NickName
		end
	end
	
	sql = string.format("select a.id, a.kindId, a.totalScore, a.yesterScore, b.NickName, b.GameID from `QPAccountsDB`.`s_activity_tjr` as a INNER JOIN `QPAccountsDB`.`AccountsInfo` as b on a.id=b.UserID where a.fatherId=%d", userId)
	rows = skynet.call(mysqlConn, "lua", "query", sql)
	local totalTemp = 0 -- �ܽ���
	for _,row in ipairs(rows) do
		local temp = {}
		temp.kindId = tonumber(row.kindId)
		temp.gameId = tonumber(row.GameID)
		temp.name = row.NickName
		temp.yesterdayScore = math.floor(tonumber(row.yesterScore) * 0.2)
		temp.totalScore = math.floor(tonumber(row.totalScore) * 0.2)
		totalTemp = totalTemp + temp.totalScore
		table.insert(re.userInfo, temp)
	end
	re.score = totalTemp - recvScore
	re.score = re.score > 0 and re.score or 0
	_todayTotalScore[userId] = {recvBox, totalTemp}
	local temp = totalTemp - recvBox*200000000
	re.boxType = (recvBox + 1)%6
	if temp >= 200000000 then
		re.boxPercent = 100
	elseif temp <= 0 then
		re.boxPercent = 0
	else
		re.boxPercent = math.floor(temp*100/200000000)
	end
	
	return re
end

local function cmd_recvBox(agent, userId, sui)
	local re = {}
	if _todayTotalScore[userId] == nil then
		re.code = "RC_OTHER"
		return re
	end
	local boxNum = _todayTotalScore[userId][1]
	local totalScore = _todayTotalScore[userId][2]
	local temp = totalScore - boxNum * 200000000
	if temp >= 200000000 then
		re.code = "RC_OK"
		if (boxNum + 1)%6 == 0 then --��
			re.rewardNum = 10000000
		else -- ͭ
			re.rewardNum = 1000000
		end
		boxNum = boxNum + 1
		temp = temp - 200000000
		re.boxType = (boxNum + 1)%6
		if temp >= 200000000 then
			re.boxPercent = 100
		elseif temp <= 0 then
			re.boxPercent = 0
		else
			re.boxPercent = math.floor(temp*100/200000000)
		end
		_todayTotalScore[userId][1] = _todayTotalScore[userId][1] + 1
		
		--������ȯ,�޸����ݿⱦ����ȡ���,���ݿ�������ֵ��¼
		local sql = string.format("update `QPAccountsDB`.`s_activity_tjr` set recvBox=recvBox+1 where id=%d", userId)
		local mysqlConn = addressResolver.getMysqlConnection()
		local rows = skynet.call(mysqlConn, "lua", "query", sql)
		sql = string.format("UPDATE `QPAccountsDB`.`AccountsInfo` SET `Present`=`Present`+%d WHERE `UserID`=%d",re.rewardNum,userId)
		skynet.call(mysqlConn, "lua", "query", sql)
		ServerUserItem.addAttribute(sui, {present = re.rewardNum})
	else
		re.code="RC_ERROR"
	end
	return re
end

local function cmd_recvScore(agent, userId, sui)
	local re = {}
	if _todayTotalScore[userId] == nil then
		re.code = "RC_OTHER"
		return re
	end
	local sql = string.format("select recvScore from `QPAccountsDB`.`s_activity_tjr` where id=%d", userId)
	local mysqlConn = addressResolver.getMysqlConnection()
	local rows = skynet.call(mysqlConn, "lua", "query", sql)
	if rows[1]==nil then
		re.code = "RC_OTHER"
		return re
	end
	
	local totalScore = _todayTotalScore[userId][2]
	if totalScore <= tonumber(rows[1].recvScore) then
		re.code = "RC_OTHER"
		return re
	end
	
	sql = string.format("update `QPAccountsDB`.`s_activity_tjr` set recvScore=%d where id=%d", totalScore, userId)
	skynet.call(mysqlConn, "lua", "query", sql)
	sql = string.format("update `QPTreasureDB`.`GameScoreInfo` set Score=Score+%d where UserID = %d", totalScore-tonumber(rows[1].recvScore), userId)
	skynet.call(mysqlConn, "lua", "query", sql)
	ServerUserItem.addAttribute(sui, {score = totalScore-tonumber(rows[1].recvScore)})
	local attr = ServerUserItem.getAttribute(sui, {"score"}) -- ��ȡ���Ͻ��
	re.code = "RC_OK"
	re.score = attr.score
	return re
end

-----------------------------------------------------�����ÿ�ճ�ֵ����Ҫʵʱ�ӵ�����
local function _addPayScore(userId, addScore)
	local sql = string.format("update `QPAccountsDB`.`s_activity_tjr` set `nowScore`=`nowScore`+%d where `id`=%d", addScore, userId)
	local mysqlConn = addressResolver.getMysqlConnection()
	skynet.call(mysqlConn, "lua", "query", sql)
end

-----------------------------------------------------����ӽ��㶨ʱ��
local function _dealScoreTimer()
	local nowTime = os.time()
	local tempDate = tonumber(os.date("%Y%m%d", nowTime))
	if tempDate <= _todayDate then -- ʱ��δ��
		return
	end
	local mysqlConn = addressResolver.getMysqlConnection()
	local sql = string.format("call QPAccountsDB.s_write_tjr_score()", _todayDate, todayDateStr)
	skynet.call(mysqlConn, "lua", "call", sql)
	_todayDate = tempDate
end

local conf = {
	methods = {
		["upTuijianren"] = {["func"]=cmd_upTuijianren, ["isRet"]=true},
		["intoTuijianren"] = {["func"]=cmd_intoTuijianren, ["isRet"]=true},
		["recvBox"] = {["func"]=cmd_recvBox, ["isRet"]=true},
		["recvScore"] = {["func"]=cmd_recvScore, ["isRet"]=true},
		["addVarScore"] = {["func"]=_addPayScore, ["isRet"]=false},
		["upChannelId"] = {["func"]=cmd_upChannelId, ["isRet"]=false},
	},
	initFunc = function()
		local nowTime = os.time()
		_todayDate = tonumber(os.date("%Y%m%d", nowTime))
	------------------------------------------------------------------------------------------	
		timerUtility.start(1000)
		timerUtility.setInterval(_dealScoreTimer, 1)
	end,
}

commonServiceHelper.createService(conf)
