local GS_CONST = require "define.gsConst"
local ServerUserItem = require "sui"
local skynet = require "skynet"
local COMMON_CONST = require "define.commonConst"
local timerUtility = require "utility.timer"
local cardUtility = require "paijiu.lualib.cardUtility"
local gameConst = require "paijiu.lualib.const"
local mysqlutil = require "mysqlutil"
local resourceResolver = require "resourceResolver"
local addressResolver = require "addressResolver"
local currencyUtility = require "utility.currency"
local arc4 = require "arc4random"

local _gameName = skynet.getenv("game")

local _onTimerFree, _checkUserLimit

--桌子
local _data = {
	tableFrame = nil,
	config = nil,
	timerId = 0,
	
	--椅子属性
	chairId2GameData = {},
	bet = {0,0,0,0,0,0},
	
	--桌子属性
	state = 0, -- 0未开放，1下注状态，2结算状态，3空闲
	result = {},
	beginTime = 0, -- 每种状态开始时的时间
	history = {}, -- 历史记录
	historyNum = 1,
	
	reset = false, -- 做庄是否重置
	bankerList = {}, -- 上庄玩家列表
	nowBanker = 0, -- 当前上庄玩家chairId（0表示系统）
	bankerNum = 0, -- 当前上庄次数
	
	rewardSize = 0, -- 当前奖池盈利
	rewardBet = {0,0,0,0,0,0} -- 当前奖池下注情况（系统坐庄时,下注统计为玩家；玩家坐庄时，下注统计为机器人）
}
local _criticalSection

local function onTimerFree()
	_criticalSection(_onTimerFree)
end
local function getGameDataItem(chairId)
	return _data.chairId2GameData[chairId]
end


local function createGameDataItem(userItem, score, isAndroid)	
	return {
		userItem = userItem,
		isAndroid = isAndroid, -- 是否是机器人
		isReady = false, -- 是否准备（收到gameoption后为true）
		score = score, -- 玩家携带筹码
		bet = {0,0,0,0,0,0}, -- 初门，天门，底门，初角，底角，桥
	}
end

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
		elseif _data.chairId2GameData[v].score >= _data.config.bankerChip then -- 可以上庄
			_data.nowBanker = v
			_data.bankerNum = 0
			stp = 1
			--群发上庄信息
			_broadcastAll(0x04000A, {chairId = v})
		else
			--群发取消上庄信息
			_broadcastAll(0x040008, {chairId = v})
		end
	end
	_data.bankerList = temp
	if isMustChange == true and stp == 0 then -- 必须换庄
		_data.nowBanker = 0
		_data.bankerNum = 0
		_broadcastAll(0x04000A, {chairId = 0})
	end
end

local function _onTimerPayOff() -- 结算时间，开始发牌算点数
	_data.state = 2
	_data.beginTime = skynet.time()
	
	local pbObj = {}
	pbObj.chipInfo = {}
	
	local playCards, result
	local nowReward = 0
	local index = 1
	while index <= 4 do
		playCards, result = cardUtility.getPlayingCards(index)
		result[4] = 2
		result[5] = 2
		result[6] = 2
		if result[1] == 0 and result[2] == 0 then
			result[4] = 0
		elseif result[1] == 1 and result[2] == 1 then
			result[4] = 1
		end
		if result[2] == 0 and result[3] == 0 then
			result[5] = 0
		elseif result[2] == 1 and result[3] == 1 then
			result[5] = 1
		end
		if result[1] == 0 and result[3] == 0 then
			result[6] = 0
		elseif result[1] == 1 and result[3] == 1 then
			result[6] = 1
		end
		local temp = 0
		for k, v in pairs(result) do
			if _data.rewardBet[k] ~= 0 then
				if v == 1 then --1赢，0输，2和
					temp = temp + _data.rewardBet[k]
				elseif v == 0 then 
					temp = temp - _data.rewardBet[k]
				end
			end
		end
		if _data.nowBanker == 0 then --系统庄
			temp = 0 - temp
		end
		nowReward = temp
		if _data.config.rewardSize == -1 then -- 未设置奖池
			break
		elseif _data.rewardSize >= _data.config.rewardSize then
			if _data.rewardSize + temp >= _data.config.rewardSize then -- 不需要作弊
				break
			end
		else
			if temp >= 0 then -- 不需要作弊
				break
			end
		end
		index = index + 1
	end
	-- 奖池改变
	_data.rewardSize = _data.rewardSize + nowReward
	if nowReward ~= 0 and _data.rewardSize > 0 then -- 奖池衰减
		_data.rewardSize = _data.rewardSize - math.floor(_data.rewardSize * _data.config.rewardReduce / 1000)
	end
	
	cardUtility.cardEnd()
	
	pbObj.playCards = playCards
	pbObj.result = result[1] + result[2] * 2 + result[3] * 4
	_data.history[_data.historyNum] = pbObj.result
	_data.historyNum = _data.historyNum % 16 + 1
	
	local totalScore = 0
	for chairId, gameData in pairs(_data.chairId2GameData) do -- 遍历在座玩家
		local temp = 0
		for k, v in pairs(result) do
			if gameData.bet[k] ~= 0 then
				if v == 1 then --1赢，0输，2和
					temp = temp + gameData.bet[k]
				elseif v == 0 then 
					temp = temp - gameData.bet[k]
				end
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
	pbObj.randNum = arc4.random(0, 35)
	_broadcastAll(0x040005, pbObj)
	
	_data.timerId = timerUtility.setTimeout(onTimerFree, _data.config.payOffTime)
end
local function onTimerPayOff()
	_criticalSection(_onTimerPayOff)
end

local function _onTimerBet() -- 游戏开始，状态改为PLAY；开始等待玩家下注
	if _data.state ~= 0 then
		_data.tableFrame.drawStart()
	end
	local pbObj = {isShuffle=false}
	_data.state = 1 -- 下注时间
	_data.bet = {0,0,0,0,0,0}
	_data.rewardBet = {0,0,0,0,0,0}
	for _, gameData in pairs(_data.chairId2GameData) do
		gameData.bet[1] = 0
		gameData.bet[2] = 0
		gameData.bet[3] = 0
		gameData.bet[4] = 0
		gameData.bet[5] = 0
		gameData.bet[6] = 0
	end
	if cardUtility.getRound() >= _data.config.shuffleNum then
		cardUtility.shuffle()--此处洗牌
		pbObj.isShuffle = true
	end
	_broadcastAll(0x040004, pbObj)
	
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
	_broadcastAll(0x040006, {})
	
	_data.bankerNum = _data.bankerNum + 1
	
	if _data.reset == true then
		changeBanker(true)
		_data.reset = false
	elseif _data.nowBanker > 0 then --当前玩家坐庄
		if _data.chairId2GameData[_data.nowBanker].score >= _data.config.bankerChip then -- 钱足够
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
	
	_data.timerId = timerUtility.setTimeout(onTimerBet, _data.config.freeTime)
end


local function onEventGameStart()
	timerUtility.start(GS_CONST.TIMER.TICK_STEP) -- TICK_STEP=100时表示1秒执行一次
	cardUtility.shuffle()--第一次洗牌
	onTimerBet()
end


local function onActionUserStandUp(chairId)
	_data.chairId2GameData[chairId] = nil
	if chairId == _data.nowBanker then -- 庄家退出
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
			if chairId == v then
				tp = 1
				_broadcastAll(0x040008, {chairId = v})
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
	local usedChip = gameData.bet[1] + gameData.bet[2] + gameData.bet[3] + gameData.bet[4] + gameData.bet[5] + gameData.bet[6]
	
	usedChip = usedChip + protocalData.amount* protocalData.num
	
	if _data.config.userLimitChip > 0 and usedChip > _data.config.userLimitChip then --玩家限制
		return
	elseif _data.config.areaLimitChip > 0 and
			_data.bet[protocalData.pos] + protocalData.amount* protocalData.num > _data.config.areaLimitChip then --区域限制
		return
	elseif _data.nowBanker ~= 0 then --总盈利限制
		local t = _data.bet[1]+_data.bet[2]+_data.bet[3]+_data.bet[4]+_data.bet[5]+_data.bet[6]
		if t * 2 > _data.chairId2GameData[_data.nowBanker].score then
				return
		end
	end
	
	local pbObj = {betInfo={}}
	if _data.nowBanker == 0 and userAttr.isAndroid == false then
		_data.rewardBet[protocalData.pos] = _data.rewardBet[protocalData.pos] + protocalData.amount * protocalData.num
	elseif _data.nowBanker ~= 0 and userAttr.isAndroid then
		_data.rewardBet[protocalData.pos] = _data.rewardBet[protocalData.pos] + protocalData.amount * protocalData.num
	end
		gameData.bet[protocalData.pos] = gameData.bet[protocalData.pos] + protocalData.amount * protocalData.num
		_data.bet[protocalData.pos] = _data.bet[protocalData.pos] + protocalData.amount * protocalData.num
		table.insert(pbObj.betInfo,{amount = protocalData.amount, num = protocalData.num, pos = protocalData.pos})
	pbObj.chairId = userAttr.chairID
	
	_broadcastAll(0x040003, pbObj)
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
		_broadcastAll(0x040007, {chairId = userAttr.chairID})
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
			_broadcastAll(0x040008, {chairId = v})
		else
			table.insert(temp, v)
		end
	end
	_data.bankerList = temp
	
end


local function pbMessage(userItem, pbNo, pbData)
	if pbNo==0x040000 then -- 下注
		pbBet(userItem, pbData)
	elseif pbNo==0x040001 then -- 申请上庄
		pbApplyBanker(userItem, pbData)
	elseif pbNo==0x040002 then -- 取消申请
		pbCancelBanker(userItem, pbData)
	end
end

-- 桌子初始化
local function initialize(tableFrame, criticalSection)
	_data.tableFrame = tableFrame
	_criticalSection = criticalSection
	
	_data.config = require(string.format("%s.config.server_%d", _gameName, _data.tableFrame.getServerConfig().ServerID))
	_data.tableFrame.setStartMode(GS_CONST.START_MODE.MASTER_CONTROL)
	
end

-- 坐下
local function onActionUserSitDown(chairId, userItem, isLookon)
	if isLookon then
		return;
	end
	
	local userAttr = ServerUserItem.getAttribute(userItem, {"agent", "score", "isAndroid"})
	_data.chairId2GameData[chairId] = createGameDataItem(userItem, userAttr.score, userAttr.isAndroid)
end

local function onActionUserGameOption(chairId, userItem, gameStatus)
	assert(gameStatus==GS_CONST.GAME_STATUS.PLAY, "桌子游戏未开始")
	local userAttr = ServerUserItem.getAttribute(userItem, {"isClientReady", "agent", "score"})
	if userAttr.isClientReady then
		_data.chairId2GameData[chairId].isReady = true
		skynet.send(userAttr.agent, "lua", "forward", 0x040000, {
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
			chipInfo = {},
			history = {},
			bankerList = _data.bankerList,
			bankerChairId = _data.nowBanker
		}
		for i=0,15 do
			if _data.history[(_data.historyNum-1 + i)%16+1] then
				table.insert(pbObj.history, _data.history[(_data.historyNum-1 + i)%16+1])
			end
		end
		for k,v in pairs(_data.chairId2GameData) do
			table.insert(pbObj.chipInfo, {chairId = k, chip = v.score})
		end
		skynet.send(userAttr.agent, "lua", "forward", 0x040001, pbObj) -- 发送场景信息(场上牌数，倒计时等等)
		_broadcastAll(0x040002, {chairId = chairId, chip = userAttr.score})
	end
end

--外部积分变动通知游戏
local function onUserScoreNotify(chairId, userItem)
	local gameData = getGameDataItem(chairId)
	if gameData then
		local userAttr = ServerUserItem.getAttribute(userItem, {"score"})
		gameData.score = userAttr.score
		
		_broadcastAll(0x040002, {chairId = chairId, chip = userAttr.score})
	end
end

local function onEventGameConclude()
	_data.state = 0
	timerUtility.clearTimer(_data.timerId)
	_data.timerId = 0
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
}
