local skynet = require "skynet"
local arc4 = require "arc4random"
local GS_CONST = require "define.gsConst"
local FISH_CONST = require "fish.lualib.const"
local timerUtility = require "utility.timer"
local ServerUserItem = require "sui"

local _data = {
	android = nil,
	type = FISH_CONST.ANDROID_TYPE.AT_RANDOM,
	
	nowMultiple = 0,
	bulletID = 0, 
	
	fishScore = 0,
	
	timerIDHash = {},
	chairId = 0,
	angle = 0, --初始角度
	chairPerTable = 0, -- 每桌总人数
	bulletNum = 0, -- 子弹数量
	bulletType = 4, -- 状态：1直射，2左右扫射，3点射，4休息，5锁定
	bulletType1 = 0,
	minMultiple = 0,
	maxMultiple = 0,
	sceneId = 0,
}

local function upMultiple(n)
	if n == 0 then
		return
	end
	for i=1,n do
		if _data.nowMultiple == _data.maxMultiple then
			return
		end
		if _data.nowMultiple < _data.minMultiple * 10 then
			_data.nowMultiple = _data.nowMultiple + _data.minMultiple
		elseif _data.nowMultiple < _data.minMultiple * 100 then
			_data.nowMultiple = _data.nowMultiple + _data.minMultiple * 10
		elseif _data.nowMultiple < _data.minMultiple * 1000 then
			_data.nowMultiple = _data.nowMultiple + _data.minMultiple * 100
		end
		_data.android.sendSocketData(0x020002, {bulletMultiple=_data.nowMultiple})
	end
end

local function downMultiple(n)
	for i=1,n do
		if _data.nowMultiple == _data.minMultiple then
			return
		end
		if _data.nowMultiple > _data.minMultiple * 1000 then
			_data.nowMultiple = _data.nowMultiple - _data.minMultiple * 1000
		elseif _data.nowMultiple > _data.minMultiple * 100 then
			_data.nowMultiple = _data.nowMultiple - _data.minMultiple * 100
		elseif _data.nowMultiple > _data.minMultiple * 10 then
			_data.nowMultiple = _data.nowMultiple - _data.minMultiple * 10
		else
			_data.nowMultiple = _data.nowMultiple - _data.minMultiple
		end
		_data.android.sendSocketData(0x020002, {bulletMultiple=_data.nowMultiple})
	end
end

local function changeBulletMultiple()
	if _data.nowMultiple * 1000 >= _data.fishScore then -- 当前倍数能开2000炮
		if _data.nowMultiple == _data.maxMultiple then
			return
		end
		--升1-5档
		upMultiple(arc4.random(0,4))
	elseif _data.nowMultiple * 600 >= _data.fishScore then
		if _data.nowMultiple == _data.maxMultiple then
			return
		end
		--升1-5档
		upMultiple(arc4.random(0,3))
	elseif _data.nowMultiple * 400 >= _data.fishScore then
		if _data.nowMultiple == _data.maxMultiple then
			return
		end
		--升1-5档
		upMultiple(arc4.random(0,2))
	elseif _data.nowMultiple * 100 <= _data.fishScore then
		if _data.nowMultiple == _data.minMultiple then
			return
		end
		--升1-5档
		downMultiple(arc4.random(0,2))
	else
		if _data.nowMultiple == _data.minMultiple then
			return
		end
		--升1-5档
		downMultiple(arc4.random(0,1))
	end
end

local function initialize(android, chairPerTable)
	_data.android = android
	_data.chairPerTable = chairPerTable
	_data.bulletType1 = arc4.random(0,1)
	if arc4.random(0, 1)==1 then
		_data.type = FISH_CONST.ANDROID_TYPE.AT_RANDOM
	else
		_data.type = FISH_CONST.ANDROID_TYPE.AT_BIGTARGET
	end
	
end

local function onTimerStandUp()
	_data.timerIDHash.standUP = nil
	_data.android.sendSocketData(0x010204, {isForce=true})
end

local function onTimerFire()
	_data.timerIDHash.fire = nil
	
	if _data.fishScore < _data.nowMultiple then
		--skynet.error("机器人钱不够, 站起")
		_data.timerIDHash.standUP = timerUtility.setTimeout(onTimerStandUp, 6)
	else
		local userItem = _data.android.getServerUserItem()
		local userAttr = ServerUserItem.getAttribute(userItem, {"chairID",})
		_data.bulletID = _data.bulletID + 1
		local angle = 0
		local lockFishId = 0
		if _data.bulletNum <= 0 then -- 当前轮子弹射完
			_data.bulletType = arc4.random(1,9)
			if _data.bulletType == 9 then
				_data.bulletType = 5
			else
				_data.bulletType = _data.bulletType % 4 + 1
			end
			_data.bulletNum = arc4.random(FISH_CONST.android.angleType[_data.bulletType][1], 
					FISH_CONST.android.angleType[_data.bulletType][2])
		end
		_data.bulletNum = _data.bulletNum - 1
		if _data.bulletType == 4 then
			changeBulletMultiple()
			_data.bulletID = _data.bulletID - 1
			_data.timerIDHash.fire = timerUtility.setTimeout(onTimerFire, arc4.random(1, 2))
			return
		elseif _data.bulletType == 3 then
			if arc4.random(1,2) == 1 then
				_data.bulletID = _data.bulletID - 1
				_data.timerIDHash.fire = timerUtility.setTimeout(onTimerFire, arc4.random(3, 4))
				return
			end
			angle = arc4.random(-20,20)
			if _data.angle + angle >=90 or _data.angle + angle <=-90 then
				angle = arc4.random(-90,90)
			end
		elseif _data.bulletType == 2 then
			angle = arc4.random(0,8)
			if _data.bulletType1 == 0 then
				if _data.angle - angle <= -90 then
					angle = _data.angle + angle
					_data.bulletType1 = 1
				else
					angle = _data.angle - angle
				end
			else
				if _data.angle + angle >= 90 then
					angle = _data.angle - angle
					_data.bulletType1 = 0
				else
					angle = _data.angle + angle
				end
			end
		elseif _data.bulletType == 1 then
			angle = _data.angle
			if arc4.random(1,5) == 1 then
				angle = _data.angle + arc4.random(-2,2)
				if angle <= -90 or angle >= 90 then
					angle = arc4.random(-80,80)
				end
			end
		elseif _data.bulletType == 5 then --锁定
			lockFishId = -1
			angle = _data.angle
		end
		_data.angle = angle 
		if _data.chairId > _data.chairPerTable/2 then
			angle = angle + 180
		end
		local ttt = _data.nowMultiple
		if _data.sceneId == 5 then
			ttt = 1000
		end
		_data.android.sendSocketData(0x020000, {
			bulletKind = 0,
			bulletID = _data.bulletID,
			angle = angle,
			bulletMultiple = ttt,
			lockFishID = lockFishId,
		})
	
		_data.timerIDHash.fire = timerUtility.setTimeout(onTimerFire, arc4.random(1, 2))
		--skynet.error("设置开炮定时器")
	end
end

local function onResponseGameScene(protocalObj)
	local gameStatus = _data.android.getGameStatus()
	_data.sceneId = protocalObj.sceneId
	--skynet.error(string.format( "%s.onResponseGameScene %s gameStatus=%d", SERVICE_NAME, os.date('%Y-%m-%d %H:%M:%S', math.floor(skynet.time())), gameStatus ))
	if gameStatus==GS_CONST.GAME_STATUS.FREE or gameStatus==GS_CONST.GAME_STATUS.PLAY then
		_data.bulletID = 0
		_data.timerIDHash.fire = timerUtility.setTimeout(onTimerFire, arc4.random(4, 8))
		--skynet.error(string.format("%s.onResponseGameScene %s 初始化开炮定时器", SERVICE_NAME, os.date('%Y-%m-%d %H:%M:%S', math.floor(skynet.time()))))
	end
end

local function onResponseExchangeFishScore(protocalObj)
	local userItem = _data.android.getServerUserItem()
	local userAttr = ServerUserItem.getAttribute(userItem, {"chairID",})
	
	if userAttr.chairID==protocalObj.chairID then
		_data.fishScore = protocalObj.fishScore
		if _data.bulletType == 4 and arc4.random(1,3) == 1 then
			changeBulletMultiple()
		end
	end
end

local function onResponseGameConfig(protocalObj)
	_data.minMultiple = protocalObj.bulletMultipleMin
	_data.maxMultiple = protocalObj.bulletMultipleMax
	if _data.minMultiple < 1000 then _data.minMultiple = 1000 end
	_data.nowMultiple = _data.minMultiple
end


local function onResponseCatchFish(protocalObj)
	local userItem = _data.android.getServerUserItem()
	local userAttr = ServerUserItem.getAttribute(userItem, {"chairID",})
	
	if userAttr.chairID==protocalObj.chairID then
		_data.fishScore = _data.fishScore + protocalObj.fishScore
	end
end

local function onResponseCatchSweepFish(protocalObj)
	local userItem = _data.android.getServerUserItem()
	local userAttr = ServerUserItem.getAttribute(userItem, {"chairID",})
	
	if userAttr.chairID==protocalObj.chairID then
		_data.fishScore = _data.fishScore + protocalObj.fishScore
	end
end

local function onResponseSwitchScene(protocalObj)
	if _data.timerIDHash.fire then
		timerUtility.clearTimer(_data.timerIDHash.fire)
		_data.timerIDHash.fire = nil
	end
	_data.sceneId = protocalObj.sceneId
	--skynet.error("设置开炮定时器")
	if protocalObj.sceneId == 5 then
		_data.timerIDHash.fire = timerUtility.setTimeout(onTimerFire, math.ceil((FISH_CONST.scene[5].duration-60)/4) + arc4.random(12, 18))
	else
		_data.timerIDHash.fire = timerUtility.setTimeout(onTimerFire, FISH_CONST.ANDROID_TIMER.TICKSPAN_SWITCH_SCENE_WAIT + arc4.random(0, 8))
	end
end

local function onResponseUserFire(protocalObj)
	local userItem = _data.android.getServerUserItem()
	local userAttr = ServerUserItem.getAttribute(userItem, {"chairID",})
	
	if userAttr.chairID==protocalObj.chairID then
		_data.fishScore = _data.fishScore - protocalObj.bulletMultiple
		
		_data.android.sendSocketData(0x02000F, {
			bulletID = protocalObj.bulletID,
			androidType = _data.type
		})
	end
end

local function onResponseBulletCompensate(protocalObj)
	local userItem = _data.android.getServerUserItem()
	local userAttr = ServerUserItem.getAttribute(userItem, {"chairID",})
	
	if userAttr.chairID==protocalObj.chairID then
		_data.fishScore = _data.fishScore + protocalObj.compensateScore
	end
end

--CAndroidUserItemSink::OnEventGameMessage
local function dispatchProtocal(protocalNo, protocalObj)
	if protocalNo==0x020005 then
		onResponseGameConfig(protocalObj)
	elseif protocalNo==0x020006 then
		onResponseGameScene(protocalObj)
	elseif protocalNo==0x020007 then
		onResponseExchangeFishScore(protocalObj)
	elseif protocalNo==0x02000B then
		onResponseCatchFish(protocalObj)
	elseif protocalNo==0x02000C then
		onResponseCatchSweepFish(protocalObj)
	elseif protocalNo==0x020003 then
		onResponseSwitchScene(protocalObj)
	elseif protocalNo==0x020000 then
		onResponseUserFire(protocalObj)
	elseif protocalNo==0x02000E then
		onResponseBulletCompensate(protocalObj)	
	else
		--skynet.error(string.format("%s: 未处理的协议 0x%X", SERVICE_NAME, protocalNo))
	end
end

--坐下后初始化信息
local function onEventStartGameLogic(tableId, chairId)
	_data.chairId = chairId
	_data.angle = arc4.random(-80,80)
end

local function onEventStopGameLogic()
	_data.nowMultiple = 0
	_data.bulletID = 0
	
	_data.fishScore = 0
	
	for _, timerID in pairs(_data.timerIDHash) do
		timerUtility.clearTimer(timerID)
	end
	
	_data.timerIDHash = {}
end

return {
	initialize = initialize,
	dispatchProtocal = dispatchProtocal,
	onEventStopGameLogic = onEventStopGameLogic,
	onEventStartGameLogic = onEventStartGameLogic,
}