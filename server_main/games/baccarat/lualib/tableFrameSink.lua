local GS_CONST = require "define.gsConst"
local ServerUserItem = require "sui"
local skynet = require "skynet"
local COMMON_CONST = require "define.commonConst"
local timerUtility = require "utility.timer"
local cardUtility = require "baccarat.lualib.cardUtility"
local mysqlutil = require "mysqlutil"
local resourceResolver = require "resourceResolver"
local addressResolver = require "addressResolver"
local currencyUtility = require "utility.currency"

local betInfo = {
}

local _onTimerFree

local _data = {
	tableFrame = nil,
	config = nil,
	chairID2GameData = {},
	timerId = 0,
	bet = {0,0,0,0,0},
	reset = false,
	
	state = 0, -- 1下注状态，2结算状态，3空闲
	bankerCard = {},
	playerCard = {},
	result = {},
	beginTime = 0, -- 每种状态开始时的时间
	totalNum = 0, -- 总局数
	cardNum = 0, -- 剩余牌数
	bootNum = 0, -- 靴次
	history = "",
	
	bankerList = {}, -- 上庄玩家列表
	nowBanker = 0, -- 当前上庄玩家chairId（0表示系统）
	bankerNum = 0, -- 当前上庄次数
	
	rewardSize = 0, -- 当前奖池盈利
	rewardBet = {0,0,0,0,0} -- 当前奖池下注情况（系统坐庄时,下注统计为玩家；玩家坐庄时，下注统计为机器人）
}
local _criticalSection


local function _broadcastAll(pbNo, pbObj)
	local pbParser = resourceResolver.get("pbParser")
	local packetStr = skynet.call(pbParser, "lua", "encode", pbNo, pbObj, true)
	if packetStr then
		_data.tableFrame.broadcastTable(packetStr)
		_data.tableFrame.broadcastLookon(packetStr)
	end
end

local function changeBanker(isMustChange)--换庄
	local stp = 0
	local temp = {}
	for _,v in ipairs(_data.bankerList) do
		if stp == 1 then
			table.insert(temp, v)
		elseif _data.chairID2GameData[v].score >= _data.config.bankerChip then -- 可以上庄
			_data.nowBanker = v
			_data.bankerNum = 0
			stp = 1
			--群发上庄信息
			_broadcastAll(0x03000A, {chairId = v})
		else
			--群发取消上庄信息
			_broadcastAll(0x030008, {chairId = v})
		end
	end
	_data.bankerList = temp
	if isMustChange == true and stp == 0 then -- 必须换庄
		_data.nowBanker = 0
		_data.bankerNum = 0
		_broadcastAll(0x03000A, {chairId = 0})
	end
end

local function initialize(tableFrame, criticalSection)
	_data.tableFrame = tableFrame
	_criticalSection = criticalSection
	
	_data.config = require(string.format("baccarat.config.server_%d", _data.tableFrame.getServerConfig().ServerID))
	_data.tableFrame.setStartMode(GS_CONST.START_MODE.MASTER_CONTROL)
	
end

local function drawInit()
	_data.bankerCard = {}
	_data.playerCard = {}
	if _data.cardNum < 60 then -- 小于60张，洗牌，数值和cardUtility里面相关
		cardUtility.shuffleCard()
		_data.history = ""
		_data.bootNum = _data.bootNum + 1
		if _data.bootNum > 999 then
			_data.bootNum = 1
		end
	end
	_data.cardNum = cardUtility.getCardNum()
	_data.totalNum = cardUtility.getTotalNum()
end

local function onTimerFree()
	_criticalSection(_onTimerFree)
end
local function getGameDataItem(chairID)
	return _data.chairID2GameData[chairID]
end

local function createGameDataItem(userItem, score, isAndroid)	
	return {
		userItem = userItem,
		isAndroid = isAndroid,
		score = score,
		bet = {0,0,0,0,0}, -- 闲平庄闲对庄对（金额）
	}
end

local function _onTimerPayOff() -- 下注下好，状态改为FREE，开始发牌算点数
	_data.state = 2
	_data.beginTime = skynet.time()
	
	local pbObj = {}
	pbObj.chipInfo = {}
	
	local bankerCard, playerCard, result = cardUtility.getCardsFromStack(false)
	local nowReward = 0 -- 该局盈利
	local usedInLog = 0
	if _data.rewardBet[1] ~= 0 or _data.rewardBet[2] ~= 0 or _data.rewardBet[3] ~= 0 
			or _data.rewardBet[4] ~= 0 or _data.rewardBet[5] ~= 0 then
		local reTemp = false
		while bankerCard ~= nil do
			local temp = 0
			if result[2] == 1 then -- 和
				if _data.rewardBet[2] ~= 0 then
					temp = temp + _data.config.odds[2] * _data.rewardBet[2]
				end
				if _data.rewardBet[4] ~= 0 then
					if result[4] == 1 then
						temp = temp + _data.config.odds[4] * _data.rewardBet[4]
					else
						temp = temp - _data.rewardBet[4]
					end
				end
				if _data.rewardBet[5] ~= 0 then
					if result[5] == 1 then
						temp = temp + _data.config.odds[5] * _data.rewardBet[5]
					else
						temp = temp - _data.rewardBet[5]
					end
				end
			else
				for k, v in pairs(result) do
					if _data.rewardBet[k] ~= 0 then
						if v == 1 then
							temp = temp + _data.config.odds[k] * _data.rewardBet[k]
						else
							temp = temp - _data.rewardBet[k]
						end
					end
				end
			end
			if _data.nowBanker == 0 then
				temp = 0 - temp
			end
			if reTemp == false then
				reTemp = true
				nowReward = temp
			end
			if _data.config.rewardSize == -1 then -- 未设置奖池
				nowReward = temp
				break
			elseif _data.rewardSize >= _data.config.rewardSize then
				if _data.rewardSize + temp >= _data.config.rewardSize then -- 不需要作弊
					nowReward = temp
					break
				end
			else
				if temp >= 0 then -- 不需要作弊
					nowReward = temp
					break
				end
			end
			
			bankerCard, playerCard, result = cardUtility.getCardsFromStack(true)
			usedInLog = usedInLog + 1
		end
		if bankerCard == nil then
			bankerCard, playerCard, result = cardUtility.getCardsFromStack(false)
			usedInLog = 0
		end
		_data.rewardSize = _data.rewardSize + nowReward
		if nowReward ~= 0 and _data.rewardSize > 0 then
			_data.rewardSize = _data.rewardSize - math.floor(math.abs(_data.rewardSize) * _data.config.rewardReduce / 1000)
		end
	end
	cardUtility.cardEnd()
	pbObj.bankerCard = bankerCard
	pbObj.playerCard = playerCard
	pbObj.result = result[1] + result[2] * 2 + result[3] * 4 + result[4] * 8 + result[5] * 16
	_data.bankerCard = bankerCard
	_data.playerCard = playerCard
	_data.history = string.format("%s%c", _data.history, pbObj.result)
	_data.cardNum = cardUtility.getCardNum()
	_data.totalNum = cardUtility.getTotalNum()
	
	local totalScore = 0
	for chairId, gameData in pairs(_data.chairID2GameData) do-------------------------------
		local temp = 0
		if result[2] == 1 then -- 和
			 gameData.bet[1] = 0
			 gameData.bet[3] = 0
		end
		for k, v in pairs(result) do
			if gameData.bet[k] ~= 0 then
				if v == 1 then
					temp = temp + _data.config.odds[k] * gameData.bet[k]
				else
					temp = temp - gameData.bet[k]
				end
				gameData.bet[k] = 0
			end
		end
		if temp ~= 0 then
			totalScore = totalScore + temp
			gameData.score = gameData.score + temp
			local tagScoreInfo = {}
			if temp > 0 then
				temp = temp - math.floor(temp / 1000) * _data.tableFrame.getServerConfig().RevenueRatio
			end
			tagScoreInfo.score = temp
			tagScoreInfo.type = temp>0 and GS_CONST.SCORE_TYPE.ST_WIN or GS_CONST.SCORE_TYPE.ST_LOSE
			--tagScoreInfo.medal = math.floor(tagScoreInfo.score/10000)   --这是经验
			_data.tableFrame.writeUserScore(chairId, tagScoreInfo, nil, true)
			table.insert(pbObj.chipInfo, {chairId = chairId, chip = temp})
		end
	end
	-- 添加上庄玩家收益
	if _data.nowBanker ~= 0 then
		if totalScore < 0 then -- 赢
			local tagScoreInfo = {}
			local temp = 0-totalScore
			temp = temp - math.floor(temp / 1000) * _data.tableFrame.getServerConfig().RevenueRatio
			tagScoreInfo.score = temp
			tagScoreInfo.type = GS_CONST.SCORE_TYPE.ST_WIN
			--tagScoreInfo.medal = math.floor(tagScoreInfo.score/10000)   --这是经验
			_data.tableFrame.writeUserScore(_data.nowBanker, tagScoreInfo, nil, true)
		elseif totalScore > 0 then -- 输
			local tagScoreInfo = {}
			tagScoreInfo.score = 0-totalScore
			tagScoreInfo.type = GS_CONST.SCORE_TYPE.ST_LOSE
			--tagScoreInfo.medal = math.floor(tagScoreInfo.score/10000)   --这是经验
			_data.tableFrame.writeUserScore(_data.nowBanker, tagScoreInfo, nil, true)
		end
		table.insert(pbObj.chipInfo, {chairId = _data.nowBanker, chip = 0 - totalScore})
	end
	_broadcastAll(0x030005, pbObj)
	
	_data.timerId = timerUtility.setTimeout(onTimerFree, _data.config.payOffTime)
end
local function onTimerPayOff()
	_criticalSection(_onTimerPayOff)
end

local function _onTimerBet() -- 游戏开始，状态改为PLAY；开始等待玩家下注
	if _data.state ~= 0 then
		_data.tableFrame.drawStart()
	end
	_data.bet = {0,0,0,0,0}
	_data.rewardBet = {0,0,0,0,0}
	for _, gameData in pairs(_data.chairID2GameData) do
		gameData.bet[1] = 0
		gameData.bet[2] = 0
		gameData.bet[3] = 0
		gameData.bet[4] = 0
		gameData.bet[5] = 0
	end
	_broadcastAll(0x030004, {})
	
	_data.state = 1 -- 下注时间
	_data.beginTime = skynet.time()
	_data.timerId = timerUtility.setTimeout(onTimerPayOff, _data.config.betTime)
end
local function onTimerBet()
	_criticalSection(_onTimerBet)
end

_onTimerFree = function()
	_data.state = 3 -- 空闲时间
	_data.beginTime = skynet.time()
	_data.tableFrame.drawStop()
	drawInit()
	
	_data.bankerNum = _data.bankerNum + 1
	
	if _data.reset == true then
		changeBanker(true)
		_data.reset = false
	elseif _data.nowBanker > 0 then --当前玩家坐庄
		if _data.chairID2GameData[_data.nowBanker].score >= _data.config.bankerChip then -- 钱足够
			if _data.bankerNum >= _data.config.bankerNum then -- 次数超了
				--标识有人就换
				changeBanker(false)
			end
		else
			-- 不管有没有人都换
			changeBanker(true)
		end
	else
		_data.bankerNum = 0
		--标识有人就换
		changeBanker(false)
	end
	
	--需要广播的信息：局数，牌数
	local pbObj = {
		remainCard = _data.cardNum,
		totalNum = _data.totalNum,
		bootNum = _data.bootNum
	}
	_broadcastAll(0x030009, pbObj)
	_data.timerId = timerUtility.setTimeout(onTimerBet, _data.config.freeTime)
end


local function onEventGameStart()
	timerUtility.start(GS_CONST.TIMER.TICK_STEP) -- TICK_STEP=100时表示1秒执行一次
	drawInit()
	onTimerBet()
end

local function broadcastNewPlayer(chairId, chip) -- 群发新玩家信息
	local pbObj = {}
	pbObj.chipInfo = {chairId = chairId, chip = chip}
	
	_broadcastAll(0x030006, pbObj)
end

-- TableFrameSink::OnActionUserSitDown
local function onActionUserSitDown(chairID, userItem, isLookon)
	if isLookon then
		return;
	end
	
	local userAttr = ServerUserItem.getAttribute(userItem, {"agent", "score", "isAndroid"})
	_data.chairID2GameData[chairID] = createGameDataItem(userItem, userAttr.score, userAttr.isAndroid)
	
end

local function onActionUserStandUp(chairID)
	_data.chairID2GameData[chairID] = nil
	if chairID == _data.nowBanker then -- 庄家退出
		_data.nowBanker = 0
		_data.bankerNum = 0
		if _data.state == 3 then --空闲时间
			changeBanker(true)
		elseif _data.state == 2 then --开牌时间
			_data.reset = true
		elseif _data.state == 1 then -- 下注时间
			--发送系统消息，庄家逃跑，游戏提前结束
			_broadcastAll(0xff0000, {
				type = COMMON_CONST.SYSTEM_MESSAGE_TYPE.SMT_NORMAL,
				msg = "庄家逃跑，本轮提前结束",
			})
			timerUtility.clearTimer(_data.timerId)
			_data.reset = true
			onTimerFree()
		end
	else
		local temp = {}
		local tp = 0
		for _,v in ipairs(_data.bankerList) do
			if chairID == v then
				tp = 1
				_broadcastAll(0x030008, {chairId = v})
			else
				table.insert(temp, v)
			end
		end
		if tp == 1 then
			_data.bankerList = temp
		end
	end
end



-- 下注
local function pbBet(userItem, protocalData)
	if _data.state ~= 1 then
		return
	end
	local userAttr = ServerUserItem.getAttribute(userItem, {"chairID", "isAndroid", "agent", "score"})
	local gameData = getGameDataItem(userAttr.chairID)
	
	if protocalData.amount ~= _data.config.chip[1] and protocalData.amount ~= _data.config.chip[2] 
			and protocalData.amount ~= _data.config.chip[3] and protocalData.amount ~= _data.config.chip[4] then
		return
	end
	
	local usedChip = gameData.bet[1] + gameData.bet[2] + gameData.bet[3] + gameData.bet[4] + gameData.bet[5]
	
	usedChip = usedChip + protocalData.amount* protocalData.num
	if _data.config.userLimitChip > 0 and usedChip > _data.config.userLimitChip then --玩家限制
		return
	elseif _data.config.areaLimitChip > 0 and
			_data.bet[protocalData.pos] + protocalData.amount* protocalData.num > _data.config.areaLimitChip then --区域限制
		return
	elseif _data.nowBanker ~= 0 then --总盈利限制
		local t = _data.bet[4]*(1+_data.config.odds[4])+_data.bet[5]*(1+_data.config.odds[5])
		if protocalData.pos <= 3 
			and (_data.bet[protocalData.pos] + protocalData.amount* protocalData.num) * (1+_data.config.odds[protocalData.pos])
			+ t> _data.chairID2GameData[_data.nowBanker].score then
				return
		else
			local temp = _data.bet[1] * (1+_data.config.odds[1])
			if temp < _data.bet[2] * (1+_data.config.odds[2]) then temp = _data.bet[2] * (1+_data.config.odds[2]) end
			if temp < _data.bet[3] * (1+_data.config.odds[3]) then temp = _data.bet[3] * (1+_data.config.odds[3]) end
			if temp + t + _data.bet[protocalData.pos] * (1+_data.config.odds[protocalData.pos]) > _data.chairID2GameData[_data.nowBanker].score then
				return
			end
		end
	end
	
	local pbObj = {betInfo={}}
	--for _,v in pairs(protocalData.betInfo) do
	--	gameData.bet[v.pos] = gameData.bet[v.pos] + v.amount * v.num
	--	_data.bet[v.pos] = _data.bet[v.pos] + v.amount * v.num
	--	table.insert(pbObj.betInfo,{amount = v.amount, num = v.num, pos = v.pos})
	--end
	if _data.nowBanker == 0 and userAttr.isAndroid == false then
		_data.rewardBet[protocalData.pos] = _data.rewardBet[protocalData.pos] + protocalData.amount * protocalData.num
	elseif _data.nowBanker ~= 0 and userAttr.isAndroid then
		_data.rewardBet[protocalData.pos] = _data.rewardBet[protocalData.pos] + protocalData.amount * protocalData.num
	end
		gameData.bet[protocalData.pos] = gameData.bet[protocalData.pos] + protocalData.amount * protocalData.num
		_data.bet[protocalData.pos] = _data.bet[protocalData.pos] + protocalData.amount * protocalData.num
		table.insert(pbObj.betInfo,{amount = protocalData.amount, num = protocalData.num, pos = protocalData.pos})
	pbObj.chairId = userAttr.chairID
	
	
	_broadcastAll(0x030002, pbObj)
end

-- 申请上庄
local function pbApplyBanker(userItem, protocalData)
	local userAttr = ServerUserItem.getAttribute(userItem, {"chairID", "isAndroid", "agent", "score"})
	
	
	local gameData = getGameDataItem(userAttr.chairID)
	
	if gameData.score < _data.config.bankerChip then
		return
	end
	if userAttr.chairID == _data.nowBanker then
		return
	end
	for _,v in ipairs(_data.bankerList) do
		if v == userAttr.chairID then
			return
		end
	end
	table.insert(_data.bankerList, userAttr.chairID)
	if _data.state == 3 and _data.nowBanker == 0 then
		-- 触发换庄
		changeBanker(false)
	else
		_broadcastAll(0x030007, {chairId = userAttr.chairID})
	end
end

-- 取消申请
local function pbCancelBanker(userItem, protocalData)
	local userAttr = ServerUserItem.getAttribute(userItem, {"chairID", "isAndroid", "agent", "score"})
	
	local gameData = getGameDataItem(userAttr.chairID)
	
	if userAttr.chairID == _data.nowBanker then
		if _data.state == 3 then
			changeBanker(true)
		end
		return
	end
	
	local temp = {}
	for _,v in ipairs(_data.bankerList) do
		if userAttr.chairID == v then
			_broadcastAll(0x030008, {chairId = v})
		else
			table.insert(temp, v)
		end
	end
	_data.bankerList = temp
	
end

local function pbMessage(userItem, protocalNo, protocalData)
	if protocalNo==0x030000 then -- 下注
		pbBet(userItem, protocalData)
	elseif protocalNo==0x030001 then -- 申请上庄
		pbApplyBanker(userItem, protocalData)
	elseif protocalNo==0x030002 then -- 取消申请
		pbCancelBanker(userItem, protocalData)
	end
end


local function onActionUserGameOption(chairID, userItem, gameStatus)
--[[	
	local userAttr = ServerUserItem.getAttribute(userItem, {"isClientReady", "agent"})
	skynet.error(string.format("onActionUserGameOption agent=[:%08x], gameStatus=%d", userAttr.agent, gameStatus))
--]]	
	if gameStatus==GS_CONST.GAME_STATUS.FREE or gameStatus==GS_CONST.GAME_STATUS.PLAY then
		local userAttr = ServerUserItem.getAttribute(userItem, {"isClientReady", "agent", "score"})
		if userAttr.isClientReady then
			skynet.send(userAttr.agent, "lua", "forward", 0x030000, {
					bankerChip = _data.config.bankerChip, 
					bankerNum = _data.config.bankerNum,
					areaLimitChip = _data.config.areaLimitChip,
					userLimitChip = _data.config.userLimitChip,
					betTime = _data.config.betTime,
					payOffTime = _data.config.payOffTime,
					freeTime = _data.config.freeTime,
					chip = _data.config.chip,}) -- 发送房间配置信息
			local pbObj = {
				state = _data.state,
				usedTime = math.floor((skynet.time() - _data.beginTime)*1000),
				bankerCard = _data.bankerCard,
				playerCard = _data.playerCard,
				remainCard = _data.cardNum,
				totalNum = _data.totalNum,
				history = _data.history,
				bootNum = _data.bootNum,
				chipInfo = {},
				bankerChairId = _data.nowBanker,
				bankerList = _data.bankerList,
			}
			for k,v in pairs(_data.chairID2GameData) do
				table.insert(pbObj.chipInfo, {chairId = k, chip = v.score})
			end
			skynet.send(userAttr.agent, "lua", "forward", 0x030001, pbObj) -- 发送场景信息(场上牌数，倒计时等等)
			broadcastNewPlayer(chairID, userAttr.score)
		end
		
		skynet.send(userAttr.agent, "lua", "forward", 0xff0000, {
			type = COMMON_CONST.SYSTEM_MESSAGE_TYPE.SMT_NORMAL,
			msg = string.format("当前区域限额:%d,玩家下注限额:%d,最低上庄筹码:%d,连庄次数:%d"
					,_data.config.areaLimitChip,_data.config.userLimitChip,_data.config.bankerChip,_data.config.bankerNum)
		})
	end
end


--外部积分变动通知游戏
local function onUserScoreNotify(chairID, userItem)
	local gameData = getGameDataItem(chairID)
	if gameData then
		local userAttr = ServerUserItem.getAttribute(userItem, {"score"})
		gameData.score = userAttr.score
		
		broadcastNewPlayer(chairID, userAttr.score)
	end
end

local function onEventGameConclude()
	_data.state = 0
	timerUtility.clearTimer(_data.timerId)
	_data.timerId = 0
end

local function getHistory()
	return {tableId = _data.tableFrame.getTableID(), bootNum = _data.bootNum, totalNum = _data.totalNum, history = _data.history}
end

return {
	initialize = initialize, -- 游戏房间初始化时调用（服务端开启时初始化）
	pbMessage = pbMessage, -- 游戏内部协议处理
	
	-- getPlayerTryScore = getPlayerTryScore, -- 获取试玩场的钱（暂无需求）
	-- calcScoreAndLock = calcScoreAndLock,
	-- releaseScoreLock = releaseScoreLock,
	
	onEventGameStart = onEventGameStart,
	onActionUserSitDown = onActionUserSitDown, -- 玩家坐下（暂时不处理）
	onActionUserStandUp = onActionUserStandUp,
	onActionUserGameOption = onActionUserGameOption, -- 玩家坐下初始化完毕后，服务端发送游戏相关信息
	onEventGameConclude = onEventGameConclude,
	onUserScoreNotify = onUserScoreNotify,
	
	getHistory = getHistory,
}
