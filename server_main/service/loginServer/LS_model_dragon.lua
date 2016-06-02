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

local serverIdList = {} -- 当前参与的房间id

local _data = {
	status = 0,			-- 状态，0表示结束，1金龙进行中，2小宝箱进行中，3等待时间
	id = 1,
	pool = 0,
	maxPool = 0,		--大奖池
	winner = nil,		-- 大奖玩家的信息
	winnerTp = 0,		-- 0表示已经领取，1表示未领取
	beginTime = 0,
	
	smallOpen = false,	-- 小宝箱是否开启
	smallTime = 0,
	smallPool = 0,		--小奖池
	smallWinner = nil,	-- 小奖玩家的信息
	smallWinnerTp = 0,	-- 0表示已经领取，1表示未领取
}
local _winnerList = {
	dragonWinner = {},
	dragonNo = 1,
	smallWinner = {},
	smallNo = 1,
}
local dragonOverTimer = nil
local dragonWriteTimer = nil
local smallOpenTimer = nil

local _gmControl = {
		dragon={1,1,1,1,1,1},
		small={1,1,1,1,1,1},
		black={},
		}

local _smallTimeInfo= {2000,2030,2100,2130,2200,2230,2300,2330}
local _smallTimeNo = 1

local function changeStatus()
	if _data.status == 3 then
		_data.status = 0
	end
end
local function dragonWrite()
	local sql = string.format("update `s_dragon` set `pool`=%d where `id`=%d", math.floor(_data.pool), _data.id)
	local dbConn = addressResolver.getMysqlConnection()
	skynet.call(dbConn, "lua", "query", sql)
end
local function smallOpen()
	local now = tonumber(os.date("%H%M", os.time()))
	if _data.smallTime >= _smallTimeInfo[8] then
		_data.smallTime = now
		return
	end
	if now >= _smallTimeInfo[_smallTimeNo] then
		_smallTimeNo = _smallTimeNo%8 + 1
		_data.smallOpen = true
		_data.smallTime = now
		return
	end
end

local function smallOver(data)--宝箱大礼包结束
	_data.status = 3
	timerUtility.setTimeout(changeStatus, 30)
	_data.beginTime = 0
	timerUtility.clearTimer(dragonOverTimer)
	dragonOverTimer = nil
	local sql
	local dbConn = addressResolver.getMysqlConnection()
	_data.smallWinner = nil
	if data ~= nil then
		_data.smallWinner = {}
		_data.smallWinnerTp = 1
		_data.smallWinner.userId = data.userId
		_data.smallWinner.gameId = data.gameId
		_data.smallWinner.name = data.name
		_data.smallWinner.memberOrder = data.memberOrder
		_data.smallWinner.platformFace = data.platformFace
		_data.smallWinner.score = lsConst.dragonInfo.smallPool
		sql = string.format(
			"insert into `QPAccountsDB`.`s_dragon_egg` set `pool`=%d,`overTime`=now(),userId=%d,gameId=%d,name='%s',memberOrder=%d,platformFace='%s'",
			lsConst.dragonInfo.smallPool, data.userId, data.gameId, data.name, data.memberOrder, data.platformFace)
		skynet.call(dbConn, "lua", "query", sql)
				_winnerList.smallWinner[_winnerList.smallNo] = {
					userId = _data.smallWinner.userId,
					gameId = _data.smallWinner.gameId,
					name = _data.smallWinner.name,
					memberOrder = _data.smallWinner.memberOrder,
					score = _data.smallWinner.score,
					overTime = math.floor(skynet.time()),
				}
				_winnerList.smallNo=_winnerList.smallNo%5+1
		local temp = {
			[0] = "普通",
			[1] = "绿钻",
			[2] = "蓝钻",
			[3] = "紫钻",
			[4] = "金钻",
			[5] = "皇冠",
		}
		local msgBody = {
			type = COMMON_CONST.SYSTEM_MESSAGE_TYPE.SMT_NORMAL,
			msg = string.format(COMMON_CONST.message.smallOver, temp[data.memberOrder],
					data.name, currencyUtility.formatCurrency(lsConst.dragonInfo.smallPool))
		}
		local pbParser = resourceResolver.get("pbParser")
		local packetStr = skynet.call(pbParser, "lua", "encode", 0xff0000, msgBody, true)
		if packetStr then
			skynet.send(addressResolver.getAddressByServiceName("LS_model_sessionManager"), "lua", "broadcastLoginServer", packetStr)
		end	
	else
		sql = string.format(
			"insert into `QPAccountsDB`.`s_dragon_egg` set `pool`=%d,`overTime`=now(),userId=0",
			lsConst.dragonInfo.smallPool)
		skynet.call(dbConn, "lua", "query", sql)
	end
	dragonWriteTimer = timerUtility.setInterval(dragonWrite, 10)
		local serverList = skynet.call(addressResolver.getAddressByServiceName("LS_model_serverManager"), "lua", "getServerIDListByKindID", 2010)
	skynet.send(addressResolver.getAddressByServiceName("LS_model_GSProxy"), "lua", "send", serverList, COMMON_CONST.LSNOTIFY_EVENT.dragonInfo, {
		tp = 3,
		info = {winner = _data.smallWinner,
			isSmallPool = true,
		}
	})
end

local function dragonOver(data)--龙宫结束
	if data ~= nil then
		for _,v in pairs(_gmControl.black) do
			if v == data.userId then
				return
			end
		end
	end
	if _data.status == 0 or _data.status == 3 then
		return
	elseif _data.status == 2 then --龙蛋
		if data ~= nil and _gmControl.small[data.memberOrder+1] == 0 then
			return
		end
		smallOver(data)
		return
	end
	if data ~= nil then
		for _,v in pairs(_winnerList.dragonWinner) do
			if v.userId == data.userId then
				return
			end
		end
	end
	--金龙
	if data ~= nil and _gmControl.dragon[data.memberOrder+1] == 0 then
		return
	end
	_data.status = 3
	timerUtility.setTimeout(changeStatus, 30)
	_data.beginTime = 0
	timerUtility.clearTimer(dragonOverTimer)
	dragonOverTimer = nil
	local sql
	local dbConn = addressResolver.getMysqlConnection()
	if data ~= nil then
		_data.winner = {}
		_data.winnerTp = 1
		_data.winner.userId = data.userId
		_data.winner.gameId = data.gameId
		_data.winner.name = data.name
		_data.winner.memberOrder = data.memberOrder
		_data.winner.platformFace = data.platformFace
		_data.winner.score = _data.maxPool
		_data.pool = _data.pool - _data.maxPool
		_data.maxPool = lsConst.dragonInfo.firstPool
		sql = string.format(
			"update `s_dragon` set `overTime`=now(),userId=%d,gameId=%d,name='%s',memberOrder=%d,platformFace='%s' where `id`=%d",
			data.userId, data.gameId, data.name, data.memberOrder, data.platformFace, _data.id)
		skynet.call(dbConn, "lua", "query", sql)
				_winnerList.dragonWinner[_winnerList.dragonNo] = {
					userId = _data.winner.userId,
					gameId = _data.winner.gameId,
					name = _data.winner.name,
					memberOrder = _data.winner.memberOrder,
					score = _data.winner.score,
					overTime = math.floor(skynet.time()),
				}
				_winnerList.dragonNo=_winnerList.dragonNo%5+1
		local temp = {
			[0] = "普通",
			[1] = "绿钻",
			[2] = "蓝钻",
			[3] = "紫钻",
			[4] = "金钻",
			[5] = "皇冠",
		}
		local msgBody = {
			type = COMMON_CONST.SYSTEM_MESSAGE_TYPE.SMT_NORMAL,
			msg = string.format(COMMON_CONST.message.dragonOver, temp[_data.winner.memberOrder],
					_data.winner.name, currencyUtility.formatCurrency(_data.winner.score))
		}
		local pbParser = resourceResolver.get("pbParser")
		local packetStr = skynet.call(pbParser, "lua", "encode", 0xff0000, msgBody, true)
		if packetStr then
			skynet.send(addressResolver.getAddressByServiceName("LS_model_sessionManager"), "lua", "broadcastLoginServer", packetStr)
		end	
	else
		_data.maxPool = _data.maxPool + lsConst.dragonInfo.addPool
		sql = string.format(
			"update `s_dragon` set `overTime`=now(),userId=-1 where `id`=%d", _data.id)
		skynet.call(dbConn, "lua", "query", sql)
	end
	_data.id = _data.id+1
	sql = string.format("insert into `QPAccountsDB`.`s_dragon` set id=%d,pool=%d,maxPool=%d", _data.id, math.floor(_data.pool), math.floor(_data.maxPool))
	skynet.call(dbConn, "lua", "query", sql)
	dragonWriteTimer = timerUtility.setInterval(dragonWrite, 10)
		local serverList = skynet.call(addressResolver.getAddressByServiceName("LS_model_serverManager"), "lua", "getServerIDListByKindID", 2010)
	skynet.send(addressResolver.getAddressByServiceName("LS_model_GSProxy"), "lua", "send", serverList, COMMON_CONST.LSNOTIFY_EVENT.dragonInfo, {
		tp = 3,
		info = {winner = _data.winner,
			pool = _data.pool,
			maxPool = _data.maxPool
		}
	})
end

local function cmd_addPool(num) -- 池子增加
	_data.pool = _data.pool + math.floor(num)
	if _data.status ~= 0 then
		return _data.pool
	end
	
	if _data.pool >= _data.maxPool and _data.status == 0 then -- 爆发
		--_data.smallPool = lsConst.dragonInfo.smallPoolCondition
		_data.status = 1
		_data.winnerTp = 0
		_data.winner = nil
		_data.beginTime = skynet.now()
		local serverList = skynet.call(addressResolver.getAddressByServiceName("LS_model_serverManager"), "lua", "getServerIDListByKindID", 2010)
		
		skynet.send(addressResolver.getAddressByServiceName("LS_model_GSProxy"), "lua", "send", serverList, COMMON_CONST.LSNOTIFY_EVENT.dragonInfo, {
			tp = 2,
			info = {
				maxPool = _data.maxPool,
				beginTime = _data.beginTime,
			}
		})
		dragonWrite()
		local msgBody = {
			type = COMMON_CONST.SYSTEM_MESSAGE_TYPE.SMT_DRAGON_OPEN,
			msg = string.format(COMMON_CONST.message.dragonOpen,
					currencyUtility.formatCurrency(_data.maxPool))
		}
		local pbParser = resourceResolver.get("pbParser")
		local packetStr = skynet.call(pbParser, "lua", "encode", 0xff0000, msgBody, true)
		if packetStr then
			skynet.send(addressResolver.getAddressByServiceName("LS_model_sessionManager"), "lua", "broadcastLoginServer", packetStr)
		end	
		timerUtility.clearTimer(dragonWriteTimer)
		dragonOverTimer = timerUtility.setTimeout(dragonOver, lsConst.dragonInfo.lastTime)
	elseif _data.smallOpen and _data.status == 0 then -- 龙蛋爆发
		_data.status = 2
		_data.smallOpen = false
		_data.smallWinnerTp = 0
		_data.smallWinner = nil
		_data.beginTime = skynet.now()
		local serverList = skynet.call(addressResolver.getAddressByServiceName("LS_model_serverManager"), "lua", "getServerIDListByKindID", 2010)
		
		skynet.send(addressResolver.getAddressByServiceName("LS_model_GSProxy"), "lua", "send", serverList, COMMON_CONST.LSNOTIFY_EVENT.dragonInfo, {
			tp = 2,
			info = {
				maxPool = lsConst.dragonInfo.smallPool,
				beginTime = _data.beginTime,
				isSmallPool = true,
			}
		})
		--dragonWrite()
		local msgBody = {
			type = COMMON_CONST.SYSTEM_MESSAGE_TYPE.SMT_DRAGON_OPEN,
			msg = string.format(COMMON_CONST.message.smallOpen,
					currencyUtility.formatCurrency(lsConst.dragonInfo.smallPool))
		}
		local pbParser = resourceResolver.get("pbParser")
		local packetStr = skynet.call(pbParser, "lua", "encode", 0xff0000, msgBody, true)
		if packetStr then
			skynet.send(addressResolver.getAddressByServiceName("LS_model_sessionManager"), "lua", "broadcastLoginServer", packetStr)
		end	
		timerUtility.clearTimer(dragonWriteTimer)
		dragonOverTimer = timerUtility.setTimeout(dragonOver, lsConst.dragonInfo.lastTime)
	end
	return _data.pool
end

-- 第四步：各个房间将消耗的金币推送到大厅，大厅开始结算，写数据库
local function cmd_dragonOverCal(data)
	if data == nil then
		return
	end
	local sql
	local mysqlConn = addressResolver.getMysqlConnection()
	for userId,score in pairs(data) do
		if _data.winnerTp == 1 and _data.winner and userId == _data.winner.userId then
			_data.winnerTp = 0
			score = score + _data.winner.score
			sql = string.format("update `QPFishDB`.`s_luck` set `lostGold`=`lostGold`-%d where `id`=%d", _data.winner.score, userId)
			skynet.call(mysqlConn, "lua", "query", sql)
		end
		if _data.smallWinnerTp == 1 and _data.smallWinner and userId == _data.smallWinner.userId then
			_data.smallWinnerTp = 0
			score = score + _data.smallWinner.score
			sql = string.format("update `QPFishDB`.`s_luck` set `lostGold`=`lostGold`-%d where `id`=%d", _data.smallWinner.score, userId)
			skynet.call(mysqlConn, "lua", "query", sql)
		end
		sql = string.format("update `QPTreasureDB`.`GameScoreInfo` set `Score`=`Score`+%d where `UserID`=%d", score, userId)
		skynet.call(mysqlConn, "lua", "query", sql)
	
		local userItem = skynet.call(addressResolver.getAddressByServiceName("LS_model_sessionManager"), "lua", "getUserItemByUserID", userId)
		if userItem then
			ServerUserItem.addAttribute(userItem, {score=score})
			local attr = ServerUserItem.getAttribute(userItem, {"userID", "agent", "serverID", "score"})
			if attr.agent~=0 then
				if attr.serverID~=0 then
					skynet.send(addressResolver.getAddressByServiceName("LS_model_GSProxy"), "lua", "send", {attr.serverID}, COMMON_CONST.LSNOTIFY_EVENT.changeUserScore, {
						userId = userId,
						score = score
					})
				else
					skynet.send(attr.agent, "lua", "forward", 0x00050A, {
						score=score
					})
				end
			end
		end
	end
end

local function cmd_getPoolInfo()
	return {
		status = _data.status,
		pool = _data.pool,
		maxPool = _data.maxPool,
	}
end

local function cmd_intoDragon()
	local re = {
		status = _data.status,
		pool = _data.pool,
		maxPool = _data.maxPool
	}
	if _data.winner ~= nil then
		re.userId = _data.winner.userId
		re.gameId = _data.winner.gameId
		re.name = _data.winner.name
		re.memberOrder = _data.winner.memberOrder
		re.platformFace = _data.winner.platformFace
		re.score = _data.winner.score
	end
	return re
end

local function cmd_getDragonRecord()
	local re = {
		dragonWinner = _winnerList.dragonWinner,
		smallWinner = _winnerList.smallWinner
	}
	return re
end

local function cmd_setGmControl(tp,num)
	if tp == 0 then -- 龙宫控制
		local temp = {0,0,0,0,0,0}
		temp[6]=num%10
		temp[5]=num//10%10
		temp[4]=num//100%10
		temp[3]=num//1000%10
		temp[2]=num//10000%10
		temp[1]=num//100000%10
		_gmControl.dragon = temp
		return temp
	elseif tp == 1 then -- 龙蛋控制
		local temp = {0,0,0,0,0,0}
		temp[6]=num%10
		temp[5]=num//10%10
		temp[4]=num//100%10
		temp[3]=num//1000%10
		temp[2]=num//10000%10
		temp[1]=num//100000%10
		_gmControl.small = temp
		return temp
	elseif tp == 2 then -- 添加黑名单
		table.insert(_gmControl.black,num)
	elseif tp == 3 then -- 清除黑名单
		_gmControl.black={}
	end
end

local conf = {
	methods = {
		["getPoolInfo"] = {["func"]=cmd_getPoolInfo, ["isRet"]=true},
		["addPool"] = {["func"]=cmd_addPool, ["isRet"]=true},
		["dragonOverCal"] = {["func"]=cmd_dragonOverCal, ["isRet"]=true},
		
		["intoDragon"] = {["func"]=cmd_intoDragon, ["isRet"]=true},
		["getDragonRecord"] = {["func"]=cmd_getDragonRecord, ["isRet"]=true},
		["dragonOver"] = {["func"]=dragonOver, ["isRet"]=true},
		
		["setGmControl"] = {["func"]=cmd_setGmControl, ["isRet"]=true},
	},
	initFunc = function()
		resourceResolver.init()
		-- 读取数据库，初始化信息
		local sql = "select * from `s_dragon` order by `id` desc limit 1"
		local dbConn = addressResolver.getMysqlConnection()
		local rows = skynet.call(dbConn, "lua", "query", sql)
		if rows[1] == nil then
			sql = string.format("insert into `QPAccountsDB`.`s_dragon` set id=1,pool=0,maxPool=%d", lsConst.dragonInfo.firstPool)
			skynet.call(dbConn, "lua", "query", sql)
			sql = "select * from `s_dragon` order by `id` desc limit 1"
			rows = skynet.call(dbConn, "lua", "query", sql)
		end
		_data.id = tonumber(rows[1].id)
		_data.pool = tonumber(rows[1].pool)
		_data.maxPool = tonumber(rows[1].maxPool)
		_data.status = 0
		if _data.id == 1 then
			_data.winner = nil
		end
		sql = string.format("select * from `s_dragon` where `id`=%d", _data.id-1)
		rows = skynet.call(dbConn, "lua", "query", sql)
		if rows[1] == nil or tonumber(rows[1].userId) <= 0 then
			_data.winner = nil
		else
			_data.winner = {
				userId = tonumber(rows[1].userId),
				gameId = tonumber(rows[1].gameId),
				name = rows[1].name,
				memberOrder = tonumber(rows[1].memberOrder),
				platformFace = rows[1].platformFace,
				score = tonumber(rows[1].maxPool),
			}
		end
		
		-- 读取最近5条获奖玩家记录
		_winnerList.dragonNo = 1
		_winnerList.smallNo = 1
		sql = "select userId, gameId, name, memberOrder, maxPool, UNIX_TIMESTAMP(overTime) as overTime from `s_dragon` where userId > 0 order by overTime desc limit 5"
		rows = skynet.call(dbConn, "lua", "query", sql)
		for i=5,1,-1 do
			if rows[i] == nil then
				_winnerList.dragonNo = i
			else
				local winner = {
					userId = tonumber(rows[i].userId),
					gameId = tonumber(rows[i].gameId),
					name = rows[i].name,
					memberOrder = tonumber(rows[i].memberOrder),
					score = tonumber(rows[i].maxPool),
					overTime = tonumber(rows[i].overTime),
				}
				_winnerList.dragonWinner[6-i]=winner
			end
		end
		sql = "select userId, gameId, name, memberOrder, pool, UNIX_TIMESTAMP(overTime) as overTime from `s_dragon_egg` where userId > 0 order by overTime desc limit 5"
		rows = skynet.call(dbConn, "lua", "query", sql)
		for i=5,1,-1 do
			if rows[i] == nil then
				_winnerList.smallNo = i
			else
				local winner = {
					userId = tonumber(rows[i].userId),
					gameId = tonumber(rows[i].gameId),
					name = rows[i].name,
					memberOrder = tonumber(rows[i].memberOrder),
					score = tonumber(rows[i].pool),
					overTime = tonumber(rows[i].overTime),
				}
				_winnerList.smallWinner[6-i]=winner
			end
		end
		
		timerUtility.start(lsConst.timer.secondTick)
		
		dragonWriteTimer = timerUtility.setInterval(dragonWrite, 10)
		
		smallOpenTimer = timerUtility.setInterval(smallOpen, 8)
		_data.smallTime = tonumber(os.date("%H%M", os.time()))
		for k,v in ipairs(_smallTimeInfo) do
			if _data.smallTime < v then
				_smallTimeNo = k
				break
			end
		end
	end,
}

commonServiceHelper.createService(conf)
