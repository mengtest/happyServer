local skynet = require "skynet"
local arc4 = require "arc4random"
local ServerUserItem = require "sui"
local GS_CONST = require "define.gsConst"
local FISH_CONST = require "fish.lualib.const"
local COMMON_CONST = require "define.commonConst"
local timerUtility = require "utility.timer"
local currencyUtility = require "utility.currency"
local pathUtility = require "utility.path"
local mysqlutil = require "mysqlutil"
local resourceResolver = require "resourceResolver"
local addressResolver = require "addressResolver"
require "utility.table"
local xLog = require "xLog"

local _gameName = skynet.getenv("game")
local _configType = skynet.getenv("configType")

local _payGongxian = {
	[1] = {0, 0.1, 0.2, 0.4, 0.5, 0.6, 0.6, 0.6, 0.6},--充值=0
	[2] = {0, 0.0, 0.1, 0.2, 0.3, 0.5, 0.5, 0.6, 0.6},--充值<10
	[3] = {0, 0.0, 0.0, 0.1, 0.2, 0.5, 0.5, 0.6, 0.6},--充值<100
	[4] = {0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.2, 0.4, 0.5},--充值<1000
	[5] = {0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.1, 0.5},--充值<10000
	[6] = {0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5},--充值>=100000
}

local _dragonMaxBullet = 0

local _data = {
	fishID = 1,
	tableFrame = nil,
	config = nil,
	chairID2GameData = {},
	timerIDHash = {},
	fishTypeRefreshTime = {},
	fishTraceHash = {},				--	TableFrameSink::active_fish_trace_vector_
	sweepFishHash = {},
	
	hasRealUser = false,
	currentScene = 0,				--当前场景id(0普通场景,1大小宝箱,2鲨鱼龙虾,3沙龙猪眼,4美人鱼,5小金龙)
	sceneBeginTime = 0,				--当前场景开始时间(1/100)
	sceneCnt = 0,					--第几次非普通场景
	
	pipelineDataHash = {},
	
	isJihuiyu = false,
	
	firstSpecialId = 0,
	isStart = false,
	localPool = 0,
	dragonUsed = nil,
	dragonTp = 0,
	dragonGrow = 0,
	isCatch = false,
	pool = 0,
	maxPool = 0,
	lastLockFish = 0,	--玩家当前锁定的鱼
	lastBigFish = 0,
}
local _criticalSection
local onTimerSwitchScene


local function _broadcastAll(pbNo, pbObj)
	local pbParser = resourceResolver.get("pbParser")
	local packetStr = skynet.call(pbParser, "lua", "encode", pbNo, pbObj, true)
	if packetStr then
		_data.tableFrame.broadcastTable(packetStr)
		_data.tableFrame.broadcastLookon(packetStr)
	end
end

local function getPayGongxianType(totalPay) -- 获取充值贡献度对应类型
	if totalPay <= 0 then
		return 1
	elseif totalPay <10 then
		return 2
	elseif totalPay <100 then
		return 3
	elseif totalPay <1000 then
		return 4
	elseif totalPay <10000 then
		return 5
	else
		return 6
	end
end

local function getGameDataItem(chairID)
	return _data.chairID2GameData[chairID]
end


local function createGameDataItem(score, insure)
	return {
		bulletID = 0,
		bulletCompensate = 0,
		bulletInfoHash = {},
		
		isScoreLocked = false,
		fishScore = score,
		countedFishScore = score,
		additionalCredit = {
			score = 0,
			present = 0,
			insure = 0,
		},
		insure = insure,
		firstInsure = insure,
		
		enterTime = math.floor(skynet.time()),
		netLose = 0,
		luck = {
			lostGold = 0,
			luckNum = -1,	-- -1表示没从数据库初始化，为机器人
			state = 0,
			reducePercent = 0,
		},
		lockFishId = 0,
		dragonBullet = 0,
		changeBullet = 0,
	}
end

-- 好运贡献值变更 gold>0表示赢，好运值扣除
local changeLuck = function(chairId, gold)
	local temp = _data.chairID2GameData[chairId].luck
	local needGold = 0
	if temp.luckNum == -1 then
		return
	end
	if temp.luckNum == 0 then
		needGold = 5000000
	elseif temp.luckNum == 1 then
		needGold = 10000000
	else
		needGold = 60000000+ 300000000 * (temp.luckNum - 2)
	end
	temp.lostGold = temp.lostGold - gold
	if temp.lostGold >= needGold then--当前贡献值
		temp.luckNum = temp.luckNum + 1
		temp.state = FISH_CONST.luck_init
	end
end

local addDragonPool = function(multiple)
	_data.localPool = _data.localPool + multiple / 1000 * _data.config.dragonPermillage
end

local function broadcastUserExchangeScore(chairID)
	local gameData = getGameDataItem(chairID)
	
	local pbParser = resourceResolver.get("pbParser")
	local packetStr = skynet.call(pbParser, "lua", "encode", 0x020007, {
		chairID=chairID,
		fishScore=gameData.fishScore,
	}, true)
	if packetStr then
		_data.tableFrame.broadcastTable(packetStr)
		_data.tableFrame.broadcastLookon(packetStr)
	end
end

local function getNewFishID()
	_data.fishID = _data.fishID + 1
	if _data.fishID > 0x0fffffff then
		_data.fishID = 1
	end
	return _data.fishID
end

local function onTimerJihuiyuBegin()
	_data.isJihuiyu = true
end

local function createFishTraceItem(fishKind, buildTick, pathId)
	local fishTraceItem = {
		fishKind=fishKind,
		buildTick=buildTick,
		fishID=getNewFishID(),
		pathId = pathId,
	}
	if _data.currentScene ~=5 and _data.isJihuiyu and fishKind ~= 23 and fishKind <= 40 then
		local t = _data.config.fishHash[fishKind].multiple
		local temp = 0
		if type(t)=="number" then
			temp  = t
		elseif type(t)=="table" then
			temp = t[2]
		end
		if temp >= 40 then
			_data.isJihuiyu = false
			fishTraceItem.isJihuiyu = true
			local jihuiTemp = arc4.random(_data.config.jihuiyuTime[1],_data.config.jihuiyuTime[2])
			timerUtility.setTimeout(onTimerJihuiyuBegin, jihuiTemp)
		end
	end
	if fishKind >= 15 and fishKind <=20 then
		_data.lastBigFish = fishTraceItem.fishID
	end
	_data.fishTraceHash[fishTraceItem.fishID] = fishTraceItem
	return fishTraceItem
end

local function clearFishTrace(isForce)
	if isForce then
		_data.fishTraceHash = {}
	else
		local nowTick = skynet.now()
		for fishID, traceItem in pairs(_data.fishTraceHash) do
			if traceItem.buildTick + FISH_CONST.fishLiveTime <= nowTick then
				_data.fishTraceHash[fishID] = nil
			end
		end
	end
end

local function getPlayerCount()
	local cnt = 0
	for _, _ in pairs(_data.chairID2GameData) do
		cnt = cnt + 1
	end
	return cnt
end

local function getPlayerTryScore()
	return _data.config.tryScore
end

local function checkRealUser()
	_data.hasRealUser = false
	for chairID, _ in pairs(_data.chairID2GameData) do
		local userItem = _data.tableFrame.getUserItem(chairID)
		if userItem then
			local userAttr = ServerUserItem.getAttribute(userItem, {"isAndroid"})
			if not userAttr.isAndroid then
				_data.hasRealUser = true
				break
			end
		end
	end
end

local function onActionUserSitDown(chairID, userItem, isLookon)
	if isLookon then
		return
	end
	
	local userAttr = ServerUserItem.getAttribute(userItem, {"userID", "score", "isAndroid", "insure"})
	
	_data.chairID2GameData[chairID] = createGameDataItem(userAttr.score, userAttr.insure)
	--读取数据库好运信息
	_data.chairID2GameData[chairID].userId = userAttr.userID
	if _data.tableFrame.getServerConfig().ServerType & GS_CONST.GAME_GENRE.EDUCATE == 0 and not userAttr.isAndroid then --非试玩场
		local mysqlConn = addressResolver.getMysqlConnection()
		local sql = string.format(
			"call QPFishDB.p_luck(%d, %d)",
			userAttr.userID, FISH_CONST.luck_init
		)
		local rows = skynet.call(mysqlConn, "lua", "call", sql)
		if tonumber(rows[1].retCode) == 0 then
			_data.chairID2GameData[chairID].luck = {
					lostGold=tonumber(rows[1].lostGold), 
					luckNum=tonumber(rows[1].luck), 
					state=tonumber(rows[1].state),
					reducePercent = tonumber(rows[1].reducePercent)
			}
		end
		
		sql = string.format(
			"call QPTreasureDB.p_pay(%d)",
			userAttr.userID
		)
		local rows = skynet.call(mysqlConn, "lua", "call", sql)
		if tonumber(rows[1].retCode) == 0 then
			_data.chairID2GameData[chairID].pay = {
				totalPay = tonumber(rows[1].totalPay),
				buyItem = tonumber(rows[1].buyItem),
				totalPayType = getPayGongxianType(tonumber(rows[1].totalPay))
			}
		end
	end
	--skynet.error(string.format("onActionUserSitDown score=%d", userAttr.score))
	
	if _data.tableFrame.getGameStatus() == GS_CONST.GAME_STATUS.FREE then
		_data.tableFrame.startGame()
	end	
	
	if (not _data.hasRealUser) and (not userAttr.isAndroid) then
		_data.hasRealUser = true
	end
end

local function buildFishTrace(fishCount, fishKindStart, fishKindEnd)
	local buildTick = skynet.now()
	local pbItemList = {}
	for i=1, fishCount do
		local pathID = pathUtility.getPathID(FISH_CONST.PATH_TYPE.PT_SINGLE, buildTick)
		if pathID == nil then
			skynet.error(string.format("%s.buildFishTrace: 找不到空闲的路径", SERVICE_NAME))
			break
		end
		local fishTraceItem = createFishTraceItem(arc4.random(fishKindStart, fishKindEnd), buildTick, pathID)
		
		local pbItem = {
			fishKind=fishTraceItem.fishKind,
			fishID=fishTraceItem.fishID,
		}
		
		pbItem.pathID = pathID
		table.insert(pbItemList, pbItem)
	end
	if #pbItemList > 0 then
		local pbParser = resourceResolver.get("pbParser")
		local packetStr = skynet.call(pbParser, "lua", "encode", 0x020010, {list=pbItemList}, true)
		if packetStr then
			_data.tableFrame.broadcastTable(packetStr)
			_data.tableFrame.broadcastLookon(packetStr)
		end
	end
end

local function doPipeline(pipelineType)
	_data.timerIDHash[pipelineType] = nil
	local pipelineData = _data.pipelineDataHash[pipelineType]
	if not pipelineData then
		skynet.error(string.format("%s.doPipeline: 找不到pipelineData %s", SERVICE_NAME, pipelineType))
		return
	end
		
	if pipelineData.fishNum > 0 then
		local nowTick = skynet.now()
		
		if pipelineData.pathID==nil then
			local pathID = pathUtility.getPathID(FISH_CONST.PATH_TYPE.PT_PIPELINE, nowTick)
			if pathID == nil then
				skynet.error(string.format("%s.doPipeline: %s 不能生成pathID", SERVICE_NAME, pipelineType))
				return
			end
			pipelineData.pathID = pathID
		end
		
		pipelineData.fishNum = pipelineData.fishNum - 1
		local fishTraceItem = createFishTraceItem(pipelineData.fishKind, nowTick, pipelineData.pathID)
		local pbItem = {
			fishKind=fishTraceItem.fishKind,
			fishID=fishTraceItem.fishID,
			pathID=pipelineData.pathID,
		}	
		
		local pbParser = resourceResolver.get("pbParser")
		local packetStr = skynet.call(pbParser, "lua", "encode", 0x020010, {list={pbItem}}, true)
		if packetStr then
			_data.tableFrame.broadcastTable(packetStr)
			_data.tableFrame.broadcastLookon(packetStr)
		end
	end	
	
	if pipelineData.fishNum > 0 then
		_data.timerIDHash[pipelineType] = timerUtility.setTimeout(doPipeline, 2, pipelineType)
	else
		_data.pipelineDataHash[pipelineType] = nil
	end
end

local function startPipeline(pipelineType)
	if _data.pipelineDataHash[pipelineType]~=nil then
		return
	end
	
	local fishKind, fishNum
	if pipelineType=="pipeline1" then
		fishKind = arc4.random(0, 1)
		fishNum = arc4.random(3, 7)
	elseif pipelineType=="pipeline2" then
		fishKind = arc4.random(0, 1)
		fishNum = arc4.random(3, 7)
	end
	
	_data.pipelineDataHash[pipelineType]={
		fishKind = fishKind,
		fishNum = fishNum,
	}
	--skynet.error(string.format("_data.pipelineDataHash[\"%s\"] set", pipelineType))
	
	doPipeline(pipelineType)
end

local function _onTimerBuildFishTrace()
	local playerCount = getPlayerCount()
	if playerCount<=0 or playerCount>=7 then
		--skynet.error(string.format("%s.onTimerBuildFishTrace: 游戏人数错误 playerCount=%d", SERVICE_NAME, playerCount))
		return
	end
	
	local nowTick = skynet.now()
	pathUtility.checkPathStatus(FISH_CONST.PATH_TYPE.PT_SINGLE, nowTick)
	pathUtility.checkPathStatus(FISH_CONST.PATH_TYPE.PT_PIPELINE, nowTick)
	
	for fishType, intervalArray in pairs(_data.config.pipelineBuildInterval) do
		local interval = intervalArray[playerCount] * 100
		if nowTick - _data.fishTypeRefreshTime[fishType] >= interval then
			if pathUtility.isPathAllUsed(FISH_CONST.PATH_TYPE.PT_PIPELINE) then
				break
			end
		
			if fishType=="pipeline1" or fishType=="pipeline2" then
				startPipeline(fishType)
			else
				skynet.error(string.format("unrecognized fishtype: %s", tostring(fishType)))
			end		
		
			_data.fishTypeRefreshTime[fishType] = nowTick
		end
		
	end
	
	
	for fishType, intervalArray in pairs(_data.config.singleBuildInterval) do
		local interval = intervalArray[playerCount] * 100
		if nowTick - _data.fishTypeRefreshTime[fishType] >= interval then
			if pathUtility.isPathAllUsed(FISH_CONST.PATH_TYPE.PT_SINGLE) then
				break
			end
			
			if fishType=="smallFish" then
				buildFishTrace(4 + arc4.random(0, 7), 0, 9)
			elseif fishType=="mediumFish" then
				buildFishTrace(1 + arc4.random(0, 1), 10, 16)
			elseif fishType=="fish17" then
				buildFishTrace(1, 17, 17)
			elseif fishType=="fish18" then
				buildFishTrace(1, 18, 18)
			elseif fishType=="fish19" then
				buildFishTrace(1, 19, 19)
			elseif fishType=="fish20" then
				-- 每一秒钟倍数+1，的功能可以在TableFrameSink::OnSubBigFishNetCatchFish里面实现，不需要定时器的
				buildFishTrace(1, 20, 20)
			elseif fishType=="bomb" then
				buildFishTrace(1, 22, 22)
			elseif fishType=="superBomb" then
				buildFishTrace(1, 23, 23)
			elseif fishType=="lockBomb" then
				buildFishTrace(1, 21, 21)
			elseif fishType=="tripleDouble" then
				buildFishTrace(2, 24, 26)
			elseif fishType=="big4" then
				buildFishTrace(2, 27, 29)
			elseif fishType=="smallBox" then
				buildFishTrace(1, 44, 44)
			elseif fishType=="bigBox" then
				buildFishTrace(1, 45, 45)
			elseif fishType=="jisu" then
				buildFishTrace(1, 47, 47)
			else
				skynet.error(string.format("unrecognized fishtype: %s", tostring(fishType)))
			end
		
			_data.fishTypeRefreshTime[fishType] = nowTick
		end
	end
end

local function onTimerBuildFishTrace()
	_criticalSection(_onTimerBuildFishTrace)
end

local function startBuildFishTraceTimer()
	local nowTick = skynet.now()
	for fishType, _ in pairs(_data.config.singleBuildInterval) do
		_data.fishTypeRefreshTime[fishType] = nowTick
	end
	for fishType, _ in pairs(_data.config.pipelineBuildInterval) do
		_data.fishTypeRefreshTime[fishType] = nowTick
	end
	if _data.timerIDHash.buildFishTrace then
		timerUtility.clearTimer(_data.timerIDHash.buildFishTrace)
		_data.timerIDHash.buildFishTrace = nil
	end
	_data.timerIDHash.buildFishTrace = timerUtility.setInterval(onTimerBuildFishTrace, FISH_CONST.TIMER.build_fish)
end

local function stopBuildFishTraceTimer()
	if _data.timerIDHash.buildFishTrace then
		timerUtility.clearTimer(_data.timerIDHash.buildFishTrace)
		_data.timerIDHash.buildFishTrace = nil
	end
	
	for pipelineType, _ in pairs(_data.pipelineDataHash) do
		if _data.timerIDHash[pipelineType] then
			timerUtility.clearTimer(_data.timerIDHash[pipelineType])
		end
	end
	_data.pipelineDataHash = {}
end


-- 创建场景
local function buildSceneKind(sceneId)
	stopBuildFishTraceTimer()
	clearFishTrace(true)
	_data.currentScene = sceneId
	local buildTick = skynet.now()
	_data.sceneBeginTime = buildTick
	if sceneId == 0 then
		_data.currentScene = 0
		startBuildFishTraceTimer()
		_data.timerIDHash.switchScene = timerUtility.setTimeout(onTimerSwitchScene, FISH_CONST.TIMER.normal_scene)
		_broadcastAll(0x020003, {sceneId = sceneId})
		return
	end
	local pbItemlist = {}
	local temp = FISH_CONST.scene[sceneId]
	
	_data.firstSpecialId = 0
	for _,v in ipairs(temp.fishList) do
		for i=1, v[2] do
		local fishTraceItem = createFishTraceItem(v[1], buildTick)
		if _data.firstSpecialId == 0 then
			_data.firstSpecialId = fishTraceItem.fishID
		end
		table.insert(pbItemlist, {fishId=fishTraceItem.fishID, fishKind=fishTraceItem.fishKind})
		end
	end
	if sceneId == 5 then
		if _data.timerIDHash.switchScene then
			timerUtility.clearTimer(_data.timerIDHash.switchScene)
			_data.timerIDHash.switchScene = nil
		end
		for _,v in pairs(_data.chairID2GameData) do
			v.bulletInfoHash = {}
		end
		_dragonMaxBullet = FISH_CONST.TIMER.upload_pool * FISH_CONST.dragonMaxBullet
		_broadcastAll(0x020003, {sceneId = sceneId, fishList = pbItemlist, tp = _data.dragonTp})
		return
	else
		_data.timerIDHash.switchScene = timerUtility.setTimeout(onTimerSwitchScene, temp.duration)
		_broadcastAll(0x020003, {sceneId = sceneId, fishList = pbItemlist})
	end
end

-- 普通和特殊场景切换
local function _onTimerSwitchScene()
	if _data.currentScene ~= 0 then
		buildSceneKind(0)
		return
	end
	
	_data.sceneCnt = _data.sceneCnt + 1
	
	if _data.config.boxSceneInterval and (_data.sceneCnt % _data.config.boxSceneInterval) == 0 then
		buildSceneKind(1)
	else
		local temp = (_data.sceneCnt-1)%(#FISH_CONST.sceneList)+1
		buildSceneKind(FISH_CONST.sceneList[temp])
	end
end
onTimerSwitchScene = function()
	_criticalSection(_onTimerSwitchScene)
end

local function calcScore(chairID, ignoreGameRecord)
	local gameData = getGameDataItem(chairID)
	local tagScoreInfo = gameData.additionalCredit
	gameData.additionalCredit = {
		score=0,
		present=0,
	}
	
	local bulletCompensate = gameData.bulletCompensate
	gameData.fishScore = gameData.fishScore + bulletCompensate
	changeLuck(chairID, bulletCompensate)
	gameData.bulletCompensate = 0
	
	tagScoreInfo.insure = 0
	local serverType = _data.tableFrame.getServerConfig().ServerType
	if (serverType & GS_CONST.GAME_GENRE.EDUCATE)==0 and (serverType & GS_CONST.GAME_GENRE.MATCH)==0 then
		tagScoreInfo.score = tagScoreInfo.score + gameData.fishScore - gameData.countedFishScore 
		tagScoreInfo.insure = gameData.insure - gameData.firstInsure 
	end
	
	-- 好运存储
	if (serverType & GS_CONST.GAME_GENRE.EDUCATE)==0 and gameData.luck.luckNum ~= -1 then
		local sql = string.format(
			"update `QPFishDB`.`s_luck` set lostGold=%d, luck=%d, state=%d where id=%d",
			gameData.luck.lostGold, gameData.luck.luckNum, gameData.luck.state, gameData.userId
		)	
		local mysqlConn = addressResolver.getMysqlConnection()
		skynet.call(mysqlConn, "lua", "query", sql)
	end
	
	gameData.countedFishScore = gameData.fishScore
	gameData.firstInsure = gameData.insure
	
	if bulletCompensate~=0 then
		local pbParser = resourceResolver.get("pbParser")
		local packetStr = skynet.call(pbParser, "lua", "encode", 0x02000E, {
			chairID=chairID,
			compensateScore=bulletCompensate,
		}, true)
		if packetStr then
			_data.tableFrame.broadcastTable(packetStr)
			_data.tableFrame.broadcastLookon(packetStr)
		end
		
		local userItem = _data.tableFrame.getUserItem(chairID)
		_data.tableFrame.onMatchScoreChange(userItem, bulletCompensate)
	end
	
	if tagScoreInfo.score~=0 or tagScoreInfo.present~=0 or tagScoreInfo.insure~=0 then
		local gamePlayTime
		if (serverType & GS_CONST.GAME_GENRE.EDUCATE)==0 and (serverType & GS_CONST.GAME_GENRE.MATCH)==0 then
			if tagScoreInfo.score > 0 then
				tagScoreInfo.type = GS_CONST.SCORE_TYPE.ST_WIN
				tagScoreInfo.medal = math.floor(tagScoreInfo.score/10000)   --这是经验
			elseif tagScoreInfo.score < 0 then
				tagScoreInfo.type = GS_CONST.SCORE_TYPE.ST_LOSE
			else
				tagScoreInfo.type = GS_CONST.SCORE_TYPE.ST_DRAW
			end
			local currentTS = math.floor(skynet.time())
			gamePlayTime = currentTS - gameData.enterTime			-- experience
			gameData.enterTime = currentTS
		else
			tagScoreInfo.type = GS_CONST.SCORE_TYPE.ST_PRESENT
			gamePlayTime = 0
		end
		_data.tableFrame.writeUserScore(chairID, tagScoreInfo, gamePlayTime, ignoreGameRecord);
	end
end

local function sendGameConfig(agent)	
	local pbObj = {
		bulletMultipleMin = _data.config.cannonMultiple.min,
		bulletMultipleMax = _data.config.cannonMultiple.max,
		bombRangeWidth = _data.config.bombRange.width,
		bombRangeHeight = _data.config.bombRange.height,
		fishList = {},
		bulletList = {},
	}
	
	for fishKind, fishItem in pairs(_data.config.fishHash) do
		table.insert(pbObj.fishList, {
			kind = fishKind,
			multiple = fishItem.multiple,
			speed = fishItem.speed,
			boundingBoxWidth = fishItem.boundingBox[1],
			boundingBoxHeight = fishItem.boundingBox[2],
		})
	end
	
	for bulletKind, bulletItem in pairs(_data.config.bulletHash) do
		table.insert(pbObj.bulletList, {
			kind = bulletKind,
			speed = bulletItem.speed,
		})
	end
	
	skynet.send(agent, "lua", "forward", 0x020005, pbObj)
end

local function sendGameScene(agent)
	local pbObj = {
		sceneId = _data.currentScene,
		scoreList = {},
	}
	local nowTime = skynet.now()
	if _data.currentScene ~= 0 then --非普通场景
		pbObj.usedTime = nowTime - _data.sceneBeginTime
	end
	
	for chairId, userData in pairs(_data.chairID2GameData) do
		table.insert(pbObj.scoreList, {chairId=chairId, score=userData.fishScore})
	end
	
	pbObj.fishList = {}
	pbObj.firstFishId = _data.firstSpecialId
	if _data.currentScene ~= 0 then -- 普通场景不恢复
		for _,v in pairs(_data.fishTraceHash) do
			local temp = {fishId=v.fishID, fishKind=v.fishKind}
			if _data.currentScene == 0 then --普通场景
				temp.usedTime = nowTime - v.buildTick
				temp.pathId = v.pathId
			end
			table.insert(pbObj.fishList, temp)
		end
	end
	pbObj.dragonPool = _data.pool
	pbObj.dragonMaxPool = _data.maxPool
	if _data.currentScene == 5 then --龙宫场景
		pbObj.tp = _data.dragonTp
	end
	
	skynet.send(agent, "lua", "forward", 0x020006, pbObj)
end


local function onActionUserGameOption(chairID, userItem, gameStatus)
	if gameStatus==GS_CONST.GAME_STATUS.FREE or gameStatus==GS_CONST.GAME_STATUS.PLAY then
		local userAttr = ServerUserItem.getAttribute(userItem, {"isClientReady", "agent", "isAndroid"})
		if userAttr.isClientReady then
			
			sendGameConfig(userAttr.agent)
			
			--if not userAttr.isAndroid then
			sendGameScene(userAttr.agent)
			--end
			broadcastUserExchangeScore(chairID)
		end
		getGameDataItem(chairID).bulletID = 0 
	end
end

-- 上传龙宫奖池
local function _onTimerUploadDragonPool()
	if _data.currentScene == 5 then
		for _, gameData in pairs(_data.chairID2GameData) do
			gameData.dragonBullet = 0
		end
		xLog("test:"..skynet.now()..",".._data.sceneBeginTime)
		if skynet.now() - _data.sceneBeginTime > (FISH_CONST.scene[5].duration-40) * 100 then
			_data.dragonGrow = _data.dragonGrow * FISH_CONST.dragonGrow
		end
	end
	if _data.localPool > 0 then
		local temp = _data.localPool
		_data.localPool = 0
		skynet.send(addressResolver.getAddressByServiceName("GS_model_tableManager"), "lua", 
				"addLocalPool", temp)
	end
end
local function onTimerUploadDragonPool()
	_criticalSection(_onTimerUploadDragonPool)
end

local function _onTimerClearTrace()
	clearFishTrace(false)
end

local function onTimerClearTrace()
	_criticalSection(_onTimerClearTrace)
end

local function _onTimerWriteScore()
	for chairID, _ in pairs(_data.chairID2GameData) do
		calcScore(chairID)
		if not _data.tableFrame.isDrawStarted() then
			-- 防止重入，如果游戏结束那么不需要
			break
		end
	end
end

local function onTimerWriteScore()
	_criticalSection(_onTimerWriteScore)
end

local function _onTimerLockTimeout()
	_data.timerIDHash.bomb = nil
	local packetStr = _data.tableFrame.getBufferedPacket(0x02000D)
	if packetStr then
		_data.tableFrame.broadcastTable(packetStr)
		_data.tableFrame.broadcastLookon(packetStr)
	end
	if _data.currentScene == 0 then
		startBuildFishTraceTimer()
	end
end

local function onTimerLockTimeout()
	_criticalSection(_onTimerLockTimeout)
end

local function onActionUserStandUp(chairID)
	calcScore(chairID)
	_data.chairID2GameData[chairID] = nil
	checkRealUser()
end

local function onEventGameConclude()
	_data.isStart = false
	_data.timerIDHash = {}
	
	_data.pipelineDataHash = {}
	pathUtility.resetAll()
	
	clearFishTrace(true)
	_data.sweepFishHash = {}
	
	_data.hasRealUser = false
end

--外部积分变动通知游戏
local function onUserScoreNotify(chairID, userItem)
	local gameData = getGameDataItem(chairID)
	if gameData then
		local userAttr = ServerUserItem.getAttribute(userItem, {"score"})
		local uncountedScore = gameData.fishScore - gameData.countedFishScore
		gameData.fishScore = userAttr.score + uncountedScore
		gameData.countedFishScore = userAttr.score
		
		broadcastUserExchangeScore(chairID)
	end
end

--外部积分变动通知游戏
local function changeUserMoney(chairID, score)
	local gameData = getGameDataItem(chairID)
	if gameData then
		gameData.fishScore = gameData.fishScore + score
		gameData.countedFishScore = gameData.countedFishScore + score
	end
end

-- 增加奖池积分，比如火山和个人纯输赢(系统赢、用户输为+)
local function addSystemScorePool(gameData, score, sspo)
	gameData.netLose = gameData.netLose + score
end

local function pbUserFire(userItem, protocalData)
	local userAttr = ServerUserItem.getAttribute(userItem, {"userID", "chairID", "isAndroid", "agent"})
	local gameData = getGameDataItem(userAttr.chairID)
	
	gameData.bulletID = gameData.bulletID + 1
	
	if gameData.isScoreLocked then
		return
	end
	if protocalData.bulletMultiple <= 0 then
		return
	end
	
	if gameData.bulletID~=protocalData.bulletID then
		error(string.format("[tableID=%d]子弹id不匹配: expect=%d got=%d", _data.tableFrame.getTableID(), gameData.bulletID, protocalData.bulletID))
	end
	
	if gameData.fishScore < protocalData.bulletMultiple then
		if userAttr.isAndroid then
			_data.tableFrame.standUp(userItem)
		else
			skynet.send(userAttr.agent, "lua", "forward", 0xff0000, {
				type = COMMON_CONST.SYSTEM_MESSAGE_TYPE.SMT_NORMAL,
				msg = "炮弹不足时可在[获取子弹]处购买子弹!",
			})
		end
		return
	end
	
	if _data.currentScene ~= 5 then
		if protocalData.bulletMultiple < _data.config.cannonMultiple.min or protocalData.bulletMultiple > _data.config.cannonMultiple.max then
			gameData.fishScore = gameData.fishScore - protocalData.bulletMultiple
			gameData.bulletCompensate = gameData.bulletCompensate + protocalData.bulletMultiple
			return
		end
	else
		if protocalData.bulletMultiple ~= 1000 then
			gameData.fishScore = gameData.fishScore - protocalData.bulletMultiple
			gameData.bulletCompensate = gameData.bulletCompensate + protocalData.bulletMultiple
			return
		end
	end
	
	gameData.fishScore = gameData.fishScore - protocalData.bulletMultiple
	if _data.currentScene == 5 then
		if _data.dragonUsed == nil then
			_data.dragonUsed = {}
		end
		if _data.dragonUsed[userAttr.userID] == nil then
			_data.dragonUsed[userAttr.userID] = protocalData.bulletMultiple
		else
			_data.dragonUsed[userAttr.userID] = _data.dragonUsed[userAttr.userID] + protocalData.bulletMultiple
		end
		gameData.dragonBullet = gameData.dragonBullet + 1
		if gameData.dragonBullet > _dragonMaxBullet then
			return
		end
	else
		changeLuck(userAttr.chairID, -protocalData.bulletMultiple)
		_data.tableFrame.onMatchScoreChange(userItem, -protocalData.bulletMultiple)
		if not userAttr.isAndroid then
			addSystemScorePool(gameData, protocalData.bulletMultiple)
		end
	end
	
	if not userAttr.isAndroid and protocalData.lockFishID~=0 and _data.fishTraceHash[protocalData.lockFishID]==nil then
		protocalData.lockFishID = 0
	end
	
	if not userAttr.isAndroid and protocalData.lockFishID~=0 then -- 不是机器人且锁定
		gameData.lockFishId = protocalData.lockFishID
		_data.lastLockFish = protocalData.lockFishID
	end
	if userAttr.isAndroid then
		if protocalData.lockFishID == 0 then
			gameData.lockFishId = 0
		else
			protocalData.lockFishID = 0
			-- 先判断上一次锁定的鱼有没有死，时间合不合法
			if gameData.lockFishId < 0 then-- 已经锁定过了
				if _data.fishTraceHash[-gameData.lockFishId] then
				 	protocalData.lockFishID = -gameData.lockFishId
				else
					gameData.lockFishId = 0
				end
			end
			if gameData.lockFishId >= 0 then -- 没锁定过
				if _data.fishTraceHash[_data.lastLockFish] then
					gameData.lockFishId = -_data.lastLockFish
				 	protocalData.lockFishID = _data.lastLockFish
				else -- 锁最新出来的鱼
					if _data.fishTraceHash[_data.lastBigFish] then
						gameData.lockFishId = -_data.lastBigFish
				 		protocalData.lockFishID = _data.lastBigFish
					end
				end
			end
		end
	end
	
	gameData.bulletInfoHash[gameData.bulletID] = {id=gameData.bulletID, kind=protocalData.bulletKind, multiple=protocalData.bulletMultiple}
	
	local respObj = {
		bulletKind = protocalData.bulletKind,
		bulletID = gameData.bulletID,
		chairID = userAttr.chairID,
		angle = protocalData.angle,
		bulletMultiple = protocalData.bulletMultiple,
		lockFishID = protocalData.lockFishID,
	}
	
	local pbParser = resourceResolver.get("pbParser")
	local packetStr = skynet.call(pbParser, "lua", "encode", 0x020000, respObj, true)
	if packetStr then
		if userAttr.isAndroid then
			_data.tableFrame.broadcastTable(packetStr)
		else
			_data.tableFrame.broadcastTableWithExcept(packetStr, userItem)
		end
		
		_data.tableFrame.broadcastLookon(packetStr)
	end
end

local function getfishMultiple(fishKind, fishID)
	if 41<=fishKind and fishKind<=45 then
		return 0
	end
	
	local fishMultiple
	local fishConfigItem = _data.config.fishHash[fishKind]
	if fishKind==20 then
		if not fishID then
			error("打中了李逵，但是没有提供fishID")
		end
		
		local fishTraceInfo = _data.fishTraceHash[fishID]
		if not fishTraceInfo then
			error(string.format("打中了李逵，但是找不到鱼的信息 fishID=%s", tostring(fishID)))
		end
		
		--李逵，根据产生的时间来计算倍数
		fishMultiple = fishConfigItem.multiple[1] + math.floor( (skynet.now()-fishTraceInfo.buildTick)/100 )
		fishMultiple = math.min(fishMultiple, fishConfigItem.multiple[2])
	else
		local multipleType = type(fishConfigItem.multiple)
		if multipleType=="number" then
			fishMultiple = fishConfigItem.multiple
		elseif multipleType=="table" then
			fishMultiple = arc4.random(fishConfigItem.multiple[1], fishConfigItem.multiple[2])
		end
	end
	return fishMultiple
end


local function doCatchFish(userItem, fishID, bulletInfo, catchCount)
	local userAttr = ServerUserItem.getAttribute(userItem, {"userID", "isAndroid", "memberOrder", "chairID", "agent", "nickName", "present"})
	local gameData = getGameDataItem(userAttr.chairID)
	
	local fishTraceInfo = _data.fishTraceHash[fishID]
	local fishConfigItem = _data.config.fishHash[fishTraceInfo.fishKind]
	
	
	local probabilityUpperLimit = fishConfigItem.probability								--fish_probability
	
	if probabilityUpperLimit == nil then
		probabilityUpperLimit = _data.config.probabilityHash[fishTraceInfo.fishKind][userAttr.memberOrder+1]
		if probabilityUpperLimit == nil then
			probabilityUpperLimit = _data.config.probabilityHash[fishTraceInfo.fishKind][1]
		end
		probabilityUpperLimit = probabilityUpperLimit / fishConfigItem.multiple
	end
	
	if userAttr.isAndroid then
		-- 机器人打不中大宝箱，打中小宝箱几率降低
		if fishTraceInfo.fishKind==44 then		--小宝箱
			probabilityUpperLimit = probabilityUpperLimit * 0.2;
		elseif fishTraceInfo.fishKind==45 then	--大宝箱
			probabilityUpperLimit = 0;
		end
	end
	
	probabilityUpperLimit = probabilityUpperLimit / catchCount
	
	--机器人能打中企鹅
	if fishTraceInfo.fishKind==19 and userAttr.isAndroid then
		probabilityUpperLimit = 0.02
	end
	
	local probability = 1 - arc4.random()													-- (0, 1]
	
	if fishTraceInfo.isJihuiyu and gameData.luck.lostGold > -50000000 and bulletInfo.multiple <=3000000 then
		probabilityUpperLimit = probabilityUpperLimit * 2
	end
	--根据好运调整概率
	if (gameData.luck.luckNum == 0 and bulletInfo.multiple <=5000) or 
			(gameData.luck.luckNum == 1 and bulletInfo.multiple <=10000) or 
			(gameData.luck.luckNum == 2 and bulletInfo.multiple <=10000) or 
			(gameData.luck.luckNum > 2 and bulletInfo.multiple <=100000) then
		if gameData.luck.state & (1 << fishTraceInfo.fishKind) ~= 0 then --好运触发
			probabilityUpperLimit = probabilityUpperLimit * 3
			if probability <= probabilityUpperLimit then --打中，好运消失
				gameData.luck.state = (~(1 << fishTraceInfo.fishKind)) & gameData.luck.state
			end
		end
	end
	
	if (fishTraceInfo.fishKind==44 or fishTraceInfo.fishKind==45) and gameData.pay ~= nil then
		local temp = gameData.pay.totalPay - gameData.pay.buyItem - math.floor(userAttr.present * COMMON_CONST.presentToMoney) -- 当前贡献
		local temp1 = 0
		if temp >= 0 then
			temp1 = 1
		elseif temp >= -1000 then
			temp1 = 2
		elseif temp >= -2000 then
			temp1 = 3
		elseif temp >= -3000 then
			temp1 = 4
		elseif temp >= -4000 then
			temp1 = 5
		elseif temp >= -10000 then
			temp1 = 6
		elseif temp >= -20000 then
			temp1 = 7
		elseif temp >= -50000 then
			temp1 = 8
		else
			temp1 = 9
		end
		probabilityUpperLimit = probabilityUpperLimit * (1-_payGongxian[gameData.pay.totalPayType][temp1])
	end
	
	probabilityUpperLimit = probabilityUpperLimit * (1 - gameData.luck.reducePercent/100)
	
	if _data.currentScene == 5 then
		if _data.dragonGrow == 1 then
			return
		end
		xLog("test:当前概率："..probabilityUpperLimit*_data.dragonGrow)
		if probability > probabilityUpperLimit*_data.dragonGrow then
			return
		end
		if not userAttr.isAndroid and _data.isCatch == false and fishTraceInfo.fishKind==46 then
			_data.isCatch = true
			userAttr = ServerUserItem.getAttribute(userItem, {"userID", "gameID", "memberOrder", "nickName", "platformFace"})
			skynet.call(addressResolver.getAddressByServiceName("GS_model_tableManager"), "lua", 
					"catchDragon", {userId=userAttr.userID,gameId=userAttr.gameID,
					name=userAttr.nickName,memberOrder=userAttr.memberOrder, platformFace=userAttr.platformFace}
			)
		end
		return
	end
	
	if probability > probabilityUpperLimit then
		return
	end
	
	
	--计算李逵的倍数的时候需要用到fishTrace
	local fishMultiple = getfishMultiple(fishTraceInfo.fishKind, fishID)
	
	_data.fishTraceHash[fishID] = nil
	
	-- 局部炸弹, 超级炸弹, 鱼王
	if fishTraceInfo.fishKind==22 or fishTraceInfo.fishKind==23 or (30<=fishTraceInfo.fishKind and fishTraceInfo.fishKind<=39) then
		
		skynet.error(string.format("----------userId[%d];fishKind[%d];probability[%f]", 
				userAttr.userID,fishTraceInfo.fishKind,probabilityUpperLimit))
		_data.sweepFishHash[fishID]={
			fishID = fishTraceInfo.fishID,
			fishKind = fishTraceInfo.fishKind,
			bulletKind = bulletInfo.kind,
			bulletMultiple = bulletInfo.multiple,
		}
		
		skynet.send(userAttr.agent, "lua", "forward", 0x020009, {
			chairID=userAttr.chairID,
			fishID=fishTraceInfo.fishID,
		})
		return
	end
	
	local serverConfig = _data.tableFrame.getServerConfig()
	local pbParser = resourceResolver.get("pbParser")
	local fishScore = fishMultiple * bulletInfo.multiple
	
	-- 捕中宝箱，比赛场没有宝箱鱼阵
	if 41<=fishTraceInfo.fishKind and fishTraceInfo.fishKind<=45 then
		local boxMultiple, boxPresent
		local multipleType = type(fishConfigItem.multiple)
		if multipleType=="number" then
			boxMultiple = fishConfigItem.multiple
		elseif multipleType=="table" then
			boxMultiple = arc4.random(fishConfigItem.multiple[1], fishConfigItem.multiple[2])
		end
		boxPresent = math.floor(boxMultiple * bulletInfo.multiple / _data.config.scorePerPresent)
		
		local score = 0
		local present = 0
		
		if (serverConfig.ServerType & GS_CONST.GAME_GENRE.EDUCATE)~=0 then
			score = math.floor(boxPresent * _data.config.scorePerPresentTry)
		else
			present = boxPresent
			changeLuck(userAttr.chairID, present * COMMON_CONST.presentToGold)
		end
		
		if not userAttr.isAndroid then
			if score then
				addSystemScorePool(gameData, -score)
			elseif present then
				addSystemScorePool(gameData, -(present * _data.config.scorePerPresent))
			end
		end
		
		local packetStr = skynet.call(pbParser, "lua", "encode", 0x02000A, {
			fishID=fishTraceInfo.fishID,
			chairID=userAttr.chairID,
			present=present,
			score=score,
		}, true)
		if packetStr then
			_data.tableFrame.broadcastTable(packetStr)
			_data.tableFrame.broadcastLookon(packetStr)
		end
		
		local sql = string.format(
			"insert into `QPRecordDB`.`CatchBox` (`ServerID`, `UserID`, `BoxType`, `Present`, `Score`, `Ctime`) values (%d, %d, '%s', %d, %d, now())",
			serverConfig.ServerID, userAttr.userID, mysqlutil.escapestring(fishConfigItem.name), present, score
		)	
		local mysqlConn = addressResolver.getMysqlConnection()
		skynet.call(mysqlConn, "lua", "query", sql)
		
		gameData.additionalCredit.score = gameData.additionalCredit.score + score
		gameData.additionalCredit.present = gameData.additionalCredit.present + present
			
		if present > _data.config.minBroadCastPresent and (serverConfig.ServerType & GS_CONST.GAME_GENRE.EDUCATE)==0 then
			local msg = string.format("恭喜%s在%s中捕中%s，获得%s%s!", userAttr.nickName, serverConfig.ServerName, fishConfigItem.name, currencyUtility.formatCurrency(present), _data.config.presentName)
			_data.tableFrame.sendSystemMessage(msg, false, true, false, false)
		end
	else
		gameData.fishScore = gameData.fishScore + fishScore
		changeLuck(userAttr.chairID, fishScore)
		_data.tableFrame.onMatchScoreChange(userItem, fishScore)
		if not userAttr.isAndroid then
			addSystemScorePool(gameData, -fishScore)
		end		
		
		if fishScore > _data.config.minBroadCastScore and fishMultiple>=100 and (serverConfig.ServerType & GS_CONST.GAME_GENRE.EDUCATE)==0 then
			local msg
			if fishTraceInfo.fishKind==40 then
				msg = string.format("恭喜%s在%s中捕中%s，获得%s金币!", userAttr.nickName, serverConfig.ServerName, fishConfigItem.name, currencyUtility.formatCurrency(fishScore))
			else
				msg = string.format("恭喜%s在%s中捕中%d倍%s，获得%s金币!", userAttr.nickName, serverConfig.ServerName, fishMultiple, fishConfigItem.name, currencyUtility.formatCurrency(fishScore))
			end
			
			_data.tableFrame.sendSystemMessage(msg, false, true, false, false)
		end
	end
	
	if fishTraceInfo.fishKind==21 then			--如果是定屏炸弹
		_data.timerIDHash.bomb = timerUtility.setTimeout(onTimerLockTimeout, FISH_CONST.TIMER.TICKSPAN_FREEZE_BOMB)
		stopBuildFishTraceTimer()
	end
	
	local packetStr = skynet.call(pbParser, "lua", "encode", 0x02000B, {
		chairID=userAttr.chairID,
		fishID=fishTraceInfo.fishID,
		fishKind=fishTraceInfo.fishKind,
		fishScore=fishScore,
		fishMulti=fishMultiple,
	}, true)
	if packetStr then
		_data.tableFrame.broadcastTable(packetStr)
		_data.tableFrame.broadcastLookon(packetStr)
	end
	
	if fishTraceInfo.fishKind==40 then				--如果是美人鱼
		timerUtility.clearTimer(_data.timerIDHash.switchScene)
		onTimerSwitchScene()
	end
end

local function getRandomFishID()
	local fishIDList = {}
	for fishID, _ in pairs(_data.fishTraceHash) do
		table.insert(fishIDList, fishID)
	end
	
	local length = #fishIDList
	if length>0 then
		return fishIDList[arc4.random(1, length)]
	end
end

local function pbAndroidBigNetCatchFish(userItem, protocalData)
	local userAttr = ServerUserItem.getAttribute(userItem, {"chairID", "isAndroid", "agent", "userID"})
	if not userAttr.isAndroid then
		error(string.format("onAndroidBigNetCatchFish: 非机器人用户发了机器人专用协议 userID=%d", userAttr.userID))
	end
	
	local gameData = getGameDataItem(userAttr.chairID)
	
	local bulletInfo = gameData.bulletInfoHash[protocalData.bulletID]
	if not bulletInfo then
		return
	end
	
	local catchIDList = {}
	if gameData.lockFishId <= 0 and _data.fishTraceHash[-gameData.lockFishId] then
		table.insert(catchIDList, -gameData.lockFishId)
	else
		if protocalData.androidType == FISH_CONST.ANDROID_TYPE.AT_RANDOM then
			--普通随机打鱼的机器人
			local fishID = getRandomFishID()
			if fishID then
				table.insert(catchIDList, fishID)
			end
		else
			for fishID, traceItem in pairs(_data.fishTraceHash) do
				if traceItem.fishKind > 16 and traceItem.fishKind ~= 40 then
					table.insert(catchIDList, fishID)
					break
				end
			end
		end
	end
	
	for _, fishID in ipairs(catchIDList) do
		doCatchFish(userItem, fishID, bulletInfo, #catchIDList)
	end
	
	gameData.bulletInfoHash[protocalData.bulletID] = nil
end

local function pbBigNetCatchFish(userItem, protocalData)
	local userAttr = ServerUserItem.getAttribute(userItem, {"chairID", "isAndroid", "agent"})
	local gameData = getGameDataItem(userAttr.chairID)
	
	local bulletInfo = gameData.bulletInfoHash[protocalData.bulletID]
	if not bulletInfo then
		return
	end
	
	local catchIDList = {}
	for _, fishID in ipairs(protocalData.catchFishIDList) do
		if _data.fishTraceHash[fishID] then
			table.insert(catchIDList, fishID)
		end
	end
	
	if #catchIDList==0 then
		gameData.bulletCompensate = gameData.bulletCompensate + bulletInfo.multiple
		if not userAttr.isAndroid then
			addSystemScorePool(gameData, -bulletInfo.multiple)
		end
	else
		if not userAttr.isAndroid and _data.currentScene ~= 5 then
			addDragonPool(bulletInfo.multiple)
		end
	end
	
	for _, fishID in ipairs(catchIDList) do
		doCatchFish(userItem, fishID, bulletInfo, #catchIDList)
	end
	
	gameData.bulletInfoHash[protocalData.bulletID] = nil
end

local function pbBankOp(userItem, pbObj)
	local re = {}
	local userAttr = ServerUserItem.getAttribute(userItem, {"chairID", "memberOrder", "agent"})
	local gameData = getGameDataItem(userAttr.chairID)
	
	if pbObj.tp == 1 then
		if gameData.fishScore < pbObj.score then -- 存钱 不够
			re.code = "RC_TOHER"
			re.msg = "身上金币不足"
			return re
		end
		local k = math.floor((1000-_data.tableFrame.getMemberOrderBank(userAttr.memberOrder)) * pbObj.score /1000)
		gameData.fishScore = gameData.fishScore - pbObj.score
		gameData.insure = gameData.insure + k
		re.score = -pbObj.score
		re.insure = k
	end
	if pbObj.tp == 2 then
		if gameData.insure < pbObj.score then -- 取钱 不够
			re.code = "RC_TOHER"
			re.msg = "银行金币不足"
			return re
		end
		gameData.insure = gameData.insure - pbObj.score
		gameData.fishScore = gameData.fishScore + pbObj.score
		re.score = pbObj.score
		re.insure = -pbObj.score
	end
	re.code = "RC_OK"
	skynet.send(userAttr.agent, "lua", "forward", 0x020001, re)
	--return re
end

local function pbCatchSweepFish(userItem, protocalData)
	local sweepFishInfo = _data.sweepFishHash[protocalData.sweepID]
	if not sweepFishInfo then
		return
	end
	_data.sweepFishHash[protocalData.sweepID] = nil
	local userAttr = ServerUserItem.getAttribute(userItem, {"chairID", "isAndroid", "agent", "nickName"})
	local gameData = getGameDataItem(userAttr.chairID)	
	
	-- 局部炸弹:22  超级炸弹:23    鱼王:30~39
	if sweepFishInfo.fishKind~=22 and sweepFishInfo.fishKind~=23 and (sweepFishInfo.fishKind<30 or sweepFishInfo.fishKind>39) then
		error(string.format("fishKind=%d, 鱼的种类不属于炸弹", sweepFishInfo.fishKind))
	end
	
	local fishMultiple = getfishMultiple(sweepFishInfo.fishKind)
	skynet.error(string.format("----------fishKind[%d];bulletMultiple[%d];fishMultiple[%d]", 
			sweepFishInfo.fishKind,sweepFishInfo.bulletMultiple,fishMultiple))
			
	for _, fishID in ipairs(protocalData.fishIDList) do
		local fishTraceInfo = _data.fishTraceHash[fishID]
		if fishTraceInfo then
			--if fishTraceInfo.fishKind~=22 and fishTraceInfo.fishKind~=23 then
			--	fishMultiple = fishMultiple + getfishMultiple(fishTraceInfo.fishKind, fishTraceInfo.fishID)
			--end
			_data.fishTraceHash[fishID] = nil
		end
	end
	
	local score = fishMultiple * sweepFishInfo.bulletMultiple
	gameData.fishScore = gameData.fishScore + score
	changeLuck(userAttr.chairID, score)
	_data.tableFrame.onMatchScoreChange(userItem, score)
	if not userAttr.isAndroid then
		addSystemScorePool(gameData, -score)
	end
	
	local serverConfig = _data.tableFrame.getServerConfig()
	local sweepConfigItem = _data.config.fishHash[sweepFishInfo.fishKind]
	local msg=string.format("恭喜%s在%s中捕中%s，获得%s金币!", userAttr.nickName, serverConfig.ServerName, sweepConfigItem.name, currencyUtility.formatCurrency(score))
	
	if score > _data.config.minBroadCastScore and (serverConfig.ServerType & GS_CONST.GAME_GENRE.EDUCATE)==0 then
		_data.tableFrame.sendSystemMessage(msg, false, true, false, false)
	end
	
	local pbParser = resourceResolver.get("pbParser")
	local packetStr = skynet.call(pbParser, "lua", "encode", 0x02000C, {
		chairID=userAttr.chairID,
		sweepID=protocalData.sweepID,
		fishScore=score,
		fishMulti=fishMultiple,
		fishIDList=protocalData.fishIDList,
	}, true)
	if packetStr then
		_data.tableFrame.broadcastTable(packetStr)
		_data.tableFrame.broadcastLookon(packetStr)
	end
end

local function pbChangeBullet(userItem, protocalData)
	local userAttr = ServerUserItem.getAttribute(userItem, {"chairID", "isAndroid", "agent"})
	local gameData = getGameDataItem(userAttr.chairID)
	
	
	local pbParser = resourceResolver.get("pbParser")
	local packetStr = skynet.call(pbParser, "lua", "encode", 0x020002, {
		chairId=userAttr.chairID,
		bulletType=protocalData.bulletType,
		bulletMultiple=protocalData.bulletMultiple,
	}, true)
	if packetStr then
		_data.tableFrame.broadcastTable(packetStr)
		_data.tableFrame.broadcastLookon(packetStr)
	end
	if not userAttr.isAndroid and gameData.changeBullet == 0 then
		gameData.changeBullet = 1
		local sql = string.format("INSERT IGNORE INTO `QPAccountsDB`.`s_user_record` (`id`, `param`) VALUES (%d, 1)", gameData.userId)
		local mysqlConn = addressResolver.getMysqlConnection()
		skynet.call(mysqlConn, "lua", "query", sql)
	end
end

local function pbMessage(userItem, protocalNo, protocalData)
	if protocalNo==0x020000 then
		pbUserFire(userItem, protocalData)
	elseif protocalNo==0x020008 then
		pbBigNetCatchFish(userItem, protocalData)
	elseif protocalNo==0x02000C then
		pbCatchSweepFish(userItem, protocalData)
	elseif protocalNo==0x02000F then
		pbAndroidBigNetCatchFish(userItem, protocalData)
	elseif protocalNo==0x020001 then
		pbBankOp(userItem, protocalData)
	elseif protocalNo==0x020002 then
		pbChangeBullet(userItem, protocalData)
	end
end

local function onEventGameStart()
	_data.isStart = true
	_data.timerIDHash.clearTrace = timerUtility.setInterval(onTimerClearTrace, FISH_CONST.TIMER.TICKSPAN_CLEAR_TRACE)
	_data.timerIDHash.writeScore = timerUtility.setInterval(onTimerWriteScore, FISH_CONST.TIMER.TICKSPAN_WRITE_SCORE)
	if _data.tableFrame.getServerConfig().ServerType & GS_CONST.GAME_GENRE.EDUCATE == 0 then
		_data.timerIDHash.uploadDragonPool = timerUtility.setInterval(onTimerUploadDragonPool, FISH_CONST.TIMER.upload_pool)
	end
	if _data.config.jihuiyuTime then
		local jihuiTemp = arc4.random(_data.config.jihuiyuTime[1],_data.config.jihuiyuTime[2])
		timerUtility.setTimeout(onTimerJihuiyuBegin, jihuiTemp)
	end
	if _data.currentScene ~= 5 then --不是龙宫
		_data.currentScene = 0
		startBuildFishTraceTimer()
		_data.timerIDHash.switchScene = timerUtility.setTimeout(onTimerSwitchScene, FISH_CONST.TIMER.normal_scene)
	else
		_dragonMaxBullet = FISH_CONST.TIMER.upload_pool * FISH_CONST.dragonMaxBullet
		local temp = FISH_CONST.scene[_data.currentScene]
		
		_data.firstSpecialId = 0
		for _,v in ipairs(temp.fishList) do
			for i=1, v[2] do
				local fishTraceItem = createFishTraceItem(v[1], _data.sceneBeginTime)
				if _data.firstSpecialId == 0 then
					_data.firstSpecialId = fishTraceItem.fishID
				end
			end
		end
	end
end

local function calcScoreAndLock(chairID)
	local gameData = getGameDataItem(chairID)
	gameData.isScoreLocked = true
	calcScore(chairID, true)
end

local function releaseScoreLock(chairID)
	local gameData = getGameDataItem(chairID)
	gameData.isScoreLocked = false
end

local function initialize(tableFrame, criticalSection)
	_data.tableFrame = tableFrame
	_criticalSection = criticalSection
	
	_data.config = require(string.format("%s.config.server_%s", _gameName, _configType))
	_data.tableFrame.setStartMode(GS_CONST.START_MODE.TIME_CONTROL)
	_dragonMaxBullet = FISH_CONST.TIMER.upload_pool * FISH_CONST.dragonMaxBullet
	
	if _data.tableFrame.getServerConfig().ServerType & GS_CONST.GAME_GENRE.EDUCATE ~= 0 then --试玩场
		changeLuck = function(chairId, gold)end
		addDragonPool = function()end
	end
	for pathType, pathConfig in pairs(_data.config.pathType) do
		pathUtility.initPathConfig(pathType, pathConfig.min, pathConfig.max, pathConfig.intervalTicks)
	end
	
	local tableFrameSink = {
		addSystemScorePool = addSystemScorePool,
		getGameDataItem = getGameDataItem,
	}
	
	local serverType = _data.tableFrame.getServerConfig().ServerType
end

local function dragonOpen(tp) -- 龙宫开启
	if _data.tableFrame.getServerConfig().ServerType & GS_CONST.GAME_GENRE.EDUCATE ~= 0 then
		return
	end
	if _data.timerIDHash.switchScene then
		timerUtility.clearTimer(_data.timerIDHash.switchScene)
		_data.timerIDHash.switchScene = nil
	end
	if _data.timerIDHash.bomb then
		timerUtility.clearTimer(_data.timerIDHash.bomb)
		_data.timerIDHash.bomb = nil
	end
	_data.dragonUsed = nil
	_data.dragonTp = tp
	_data.dragonGrow = 1
	buildSceneKind(5)
end

local function dragonOver(data)
	if _data.tableFrame.getServerConfig().ServerType & GS_CONST.GAME_GENRE.EDUCATE ~= 0 then
		return
	end
	local pbObj = {}
	if data.winner ~= nil then -- 玩家获奖
		pbObj.winner = data.winner
	end
	pbObj.pool = data.pool
	pbObj.maxPool = data.maxPool
	clearFishTrace(true)
	_data.isCatch = false
	_data.currentScene = 0
	_data.dragonGrow = 1
	_broadcastAll(0x020012, pbObj)
	if _data.isStart then
		for _,v in pairs(_data.chairID2GameData) do
			v.bulletInfoHash = {}
		end
		buildSceneKind(0)
	end
	local re = _data.dragonUsed
	_data.dragonUsed = nil
	return re
end

local function dragonPoolAdd(pool)
	_broadcastAll(0x020011, {pool = pool})
end

local function dragonInit(data)
	_data.pool = data.pool
	_data.maxPool = data.maxPool
	_data.currentScene = 0
	if data.beginTime ~= 0 and  _data.tableFrame.getServerConfig().ServerType & GS_CONST.GAME_GENRE.EDUCATE == 0 then
		_data.currentScene = 5
		_data.dragonTp = data.dragonTp
		_data.sceneBeginTime = data.beginTime
	end
end

local function changeUserFishPercent(chairId, data)
	local gameData = getGameDataItem(chairId)
	gameData.luck.reducePercent = tonumber(data.fishPercent)
end


return {
	initialize = initialize,
	getPlayerTryScore = getPlayerTryScore,
	pbMessage = pbMessage,
	calcScoreAndLock = calcScoreAndLock,
	releaseScoreLock = releaseScoreLock,
	
	onActionUserSitDown = onActionUserSitDown,
	onActionUserStandUp = onActionUserStandUp,
	onActionUserGameOption = onActionUserGameOption,
	onEventGameStart = onEventGameStart,
	onEventGameConclude = onEventGameConclude,
	onUserScoreNotify = onUserScoreNotify,
	changeUserMoney = changeUserMoney,
	changeUserFishPercent = changeUserFishPercent,
	
	dragonOpen = dragonOpen, -- 龙宫开启
	dragonOver = dragonOver, -- 龙宫结束
	dragonPoolAdd = dragonPoolAdd,
	dragonInit = dragonInit, -- 龙宫初始化
}

