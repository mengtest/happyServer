local skynet = require "skynet"
local GS_CONST = require "define.gsConst"
local timerUtility = require "utility.timer"
local ServerUserItem = require "sui"
local AndroidUserItem = require "aui"

local _data = {
	android = nil,
	level = 1, -- 人工智能级别，越大越智能
	
	score = 0,
	state = 0,
	
	timerIDHash = {},
	
	betTime = 0,		-- 下注时间
	chip = {},			-- 筹码面值
	
	remainTime = 0,		-- 剩余时间
	betNum = 0,
	betScore = 0,
	sitCount = 0,
	
	drawCount = 0, -- 局数
}

local function initialize(android, chairPerTable)
	_data.android = android
	--bulletUtility.setChairPerTable(chairPerTable)
	_data.level = math.random(1, 3)
	
end

local function onTimerStandUp()
	_data.timerIDHash.standUP = nil
	_data.android.sendSocketData(0x010204, {isForce=true})
end

local function onResponseTimeFree(pbObj)
	_data.state = 3
	for _, timerID in pairs(_data.timerIDHash) do
		timerUtility.clearTimer(timerID)
	end
	_data.timerIDHash = {}
end

local function onTimerBet()
	_data.timerIDHash.bet = nil
	if _data.state ~= 1 then
		return
	end
	
	--checkBulletMultiple()
	if _data.score - _data.betScore < _data.chip[1] then
		--skynet.error("机器人钱不够, 站起")
		_data.timerIDHash.bet = nil
		_data.timerIDHash.standUP = timerUtility.setTimeout(onTimerStandUp, 3)
	else
		local userItem = _data.android.getServerUserItem()
		local userAttr = ServerUserItem.getAttribute(userItem, {"chairID",})
		
		local pRan = math.random(1, 215)
		local pPos = 1
		if pRan <= 100 then
			pPos = 3
		elseif pRan <=195 then
			pPos = 1
		elseif pRan <=201 then
			pPos = 4
		elseif pRan <=207 then
			pPos = 5
		else
			pPos = 2
		end-------------------------------------------
		local chip = _data.chip
		local score = _data.score - _data.betScore
		local temp1 = {}
		if score < chip[2] then temp1 = {1, 1, 1, 1,1, 1}
		elseif score < chip[3] then temp1 = {1, 1,1, 1, 1, 2}
		elseif score < chip[4] then temp1 = {1,1,1,2,2,3}
		else temp1 = {1,1,2,2,3,4} end
		local betSize = temp1[math.random(1,6)] -- 下注筹码面值
		if pPos ~= 1 and pPos ~= 3 and betSize >= 3 then 
			betSize = betSize - 2
		end
		local ran = math.random(1, 4)
		local k = 1
		while k <= ran do
			if score >= _data.chip[betSize] then 
				score = score - _data.chip[betSize]
				_data.betScore = _data.betScore + _data.chip[betSize]
				_data.android.sendSocketData(0x030000, {
					amount = _data.chip[betSize],
					num = 1,
					pos = pPos
				})
			else
				break
			end
			k = k + 1
		end
		_data.timerIDHash.bet = nil
		_data.betNum = _data.betNum - 1
		if _data.betNum > 0 and _data.score - _data.betScore < _data.chip[1] and _data.remainTime >= 2 then
			local t = math.random(1, _data.remainTime - 1)
			_data.remainTime = _data.remainTime - t
			_data.timerIDHash.bet = timerUtility.setTimeout(onTimerBet, t)
		end
	
		--_data.timerIDHash.fire = timerUtility.setTimeout(onTimerFire, math.random(1, 2))
		--skynet.error("设置开炮定时器")
	end
end

local function onResponseGameConfig(pbObj)
	--skynet.error("onResponseGameConfig ", protocalObj.bulletMultipleMin, protocalObj.bulletMultipleMax)
	_data.betTime = pbObj.betTime
	_data.chip = pbObj.chip
	local userItem = _data.android.getAndroidUserItem()
	local androidAttr = AndroidUserItem.getAttribute(userItem, {"residualPlayDraw"})
	_data.drawCount = androidAttr.residualPlayDraw
	--bulletUtility.setMultipleLimit(protocalObj.bulletMultipleMin, protocalObj.bulletMultipleMax)
	--_data.currentBulletMultiple = protocalObj.bulletMultipleMin
	--skynet.error("onResponseGameConfig "..tostring(_data.currentBulletMultiple))
end


local function onResponseBetBegin(pbObj)
	_data.state = 1
	if _data.betTime <= 2 then
		return
	end
	if _data.sitCount > 10 then
		local t = math.random(0, _data.sitCount)
		if t > 10 then
			return
		end
	end
	
	_data.betScore = 0
	local temp = math.random(0, 9)
	if temp == 0 then _data.betNum = 0
	elseif temp <= 1 then _data.betNum = 1
	elseif temp <= 5 then _data.betNum = 2
	elseif temp <= 8 then _data.betNum = 3
	else _data.betNum = 4 end
	
	if _data.betNum >= _data.betTime then
		_data.betNum = _data.betTime - 1
	end
	
	temp = math.random(0, _data.betTime - _data.betNum)
	_data.remainTime = _data.betTime - temp - 1
	
	_data.timerIDHash.bet = timerUtility.setTimeout(onTimerBet, temp + 1)
end

local function onResponseGameScene(pbObj)
	if _data.timerIDHash.bet then
		timerUtility.clearTimer(_data.timerIDHash.bet)
		_data.timerIDHash.bet = nil
	end
	--skynet.error("设置开炮定时器")
	--_data.timerIDHash.bet = timerUtility.setTimeout(onTimerBet, FISH_CONST.ANDROID_TIMER.TICKSPAN_SWITCH_SCENE_WAIT + math.random(0, 3))
end

local function onResponseNewPlayerChip(pbObj)
	local userItem = _data.android.getServerUserItem()
	local userAttr = ServerUserItem.getAttribute(userItem, {"chairID",})
	
	if userAttr.chairID==pbObj.chipInfo.chairId then
		_data.score = pbObj.chipInfo.chip
	end
end

local function onResponseTimePayOff(pbObj)
	_data.state = 2
	if _data.timerIDHash.bet then
		timerUtility.clearTimer(_data.timerIDHash.bet)
		_data.timerIDHash.bet = nil
	end
	local userItem = _data.android.getServerUserItem()
	local userAttr = ServerUserItem.getAttribute(userItem, {"chairID",})
	if pbObj.chipInfo == nil then
		return
	end
	for _,v in pairs(pbObj.chipInfo) do
		if userAttr.chairID==v.chairId then
			_data.score = _data.score + v.chip
		end
	end
end

local function onResponseTimeFree(pbObj)
	_data.state = 3
	for _, timerID in pairs(_data.timerIDHash) do
		timerUtility.clearTimer(timerID)
	end
	_data.timerIDHash = {}
	_data.drawCount = _data.drawCount - 1
	if _data.drawCount <= 0 and _data.timerIDHash.standUP == nil then
		local t = math.random(1,4)
		_data.timerIDHash.standUP = timerUtility.setTimeout(onTimerStandUp, t)
	end
end

local function onResponseSitCount(pbObj)
	_data.sitCount = pbObj.sitCount
end

--CAndroidUserItemSink::OnEventGameMessage
local function dispatchProtocal(protocalNo, protocalObj)
	if protocalNo==0x030000 then --	房间配置信息
		onResponseGameConfig(protocalObj)
	elseif protocalNo==0x030001 then
		onResponseGameScene(protocalObj)
	elseif protocalNo==0x030004 then -- 下注时间开始
		onResponseBetBegin(protocalObj)
	elseif protocalNo==0x030005 then -- 结算时间开始
		onResponseTimePayOff(protocalObj)
	elseif protocalNo==0x030009 then -- 空闲时间开始
		onResponseTimeFree(protocalObj)
	elseif protocalNo==0x030006 then -- 筹码变化
		onResponseNewPlayerChip(protocalObj)
	elseif protocalNo==0x010104 then -- 当时玩家人数
		onResponseSitCount(protocalObj)
	else
		--skynet.error(string.format("%s: 未处理的协议 0x%X", SERVICE_NAME, protocalNo))
	end
end

local function onEventStopGameLogic()
	
	_data.score = 0
	
	for _, timerID in pairs(_data.timerIDHash) do
		timerUtility.clearTimer(timerID)
	end
	
	_data.timerIDHash = {}
end

return {
	initialize = initialize,
	dispatchProtocal = dispatchProtocal,
	onEventStopGameLogic = onEventStopGameLogic,
}