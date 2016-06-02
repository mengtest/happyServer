local skynet = require "skynet"
local arc4 = require "arc4random"
local commonServiceHelper = require "serviceHelper.common"
local GS_CONST = require "define.gsConst"
local COMMON_CONST = require "define.commonConst"
local ServerUserItem = require "sui"
local addressResolver = require "addressResolver"
local resourceResolver = require "resourceResolver"
local timerUtility = require "utility.timer"
local queue = require "skynet.queue"
local currencyUtility = require "utility.currency"

local tableFrameSink = require(string.format("%s.lualib.tableFrameSink", skynet.getenv("game")))
local xLog = require "xLog"

local _criticalSection = queue()

local _data = {
	serverConfig = {},
	chairID2UserData = {},	-- index start from 1, [chairID]={item=, isAllowLook=, offlineCount=, offlineTime=}
	
	id = 0,												--桌子号码
	startMode = 0,										-- m_cbStartMode 开始模式 
	drawCount = 0,										-- m_wDrawCount 游戏局数 
	drawStartTime = 0,									-- m_dwDrawStartTime 开始时间
	gameStatus = GS_CONST.GAME_STATUS.FREE,				-- m_cbGameStatus 游戏状态
	isGameStarted = false,								-- m_bGameStarted
	isDrawStarted = false,								-- m_bDrawStarted
	isTableStarted = false,								-- m_bTableStarted
	
	tableOwnerID = 0,									--桌主用户userID m_dwTableOwnerID
	enterPassword = nil,								--进入密码 m_szEnterPassword
	
	offlineCheckTimerID = nil,
	
	drawID = 0,
	gameScoreRecord = {},								-- m_GameScoreRecordActive 游戏记录
	
	packetBuf = {},
	
	isActive = false,
}

local _memberOrderConfig = {}

local function getMemberOrderBank(k)
	return _memberOrderConfig[k]
end

local adjustOfflineTimer, onTimerOfflineWait, concludeGame

local function broadcastTableWithExcept(packetStr, exceptUserItem)
	for _, userData in pairs(_data.chairID2UserData) do
		if userData.item and userData.item ~= exceptUserItem then
			local userAttr = ServerUserItem.getAttribute(userData.item, {"agent"})
			if userAttr.agent ~= 0 then
				skynet.send(userAttr.agent, "lua", "forward", packetStr)
			end
		end
	end
end

local function broadcastTable(packetStr)
	broadcastTableWithExcept(packetStr)
end

local function broadcastLookon(packetStr)
end


local function getBufferedPacket(protocalNo)
	local packet = _data.packetBuf[protocalNo]
	if not packet then
		packet = skynet.call(addressResolver.getAddressByServiceName("simpleProtocalBuffer"), "lua", "get", protocalNo)
		_data.packetBuf[protocalNo] = packet
	end
	return packet
end

local function getOldestOfflineChairID()
	local oldestOfflineTime = math.maxinteger
	local oldestOfflineChairID = GS_CONST.INVALID_CHAIR
	
	for chairID, userData in pairs(_data.chairID2UserData) do
		if userData.offlineTime~=0 and userData.offlineTime < oldestOfflineTime then
			oldestOfflineTime = userData.offlineTime
			oldestOfflineChairID = chairID
		end
	end
	
	return oldestOfflineChairID
end

local function getOfflineUserCount()
	local cnt = 0
	for _, userData in pairs(_data.chairID2UserData) do
		if userData.offlineTime~=0 then
			cnt = cnt + 1
		end
	end
	return cnt;
end

local function createUserDataItem(userItem, userId)
	return {
		userId = userId,
		item = userItem,
		isAllowLook = true,
		offlineCount = 0,
		offlineTime = 0,
	}
end

local function getSitUserCount()
	local cnt = 0
	for _, _ in pairs(_data.chairID2UserData) do
		cnt = cnt + 1
	end
	return cnt
end

local function setStartMode(mode)
	_data.startMode = mode
end

local function getServerConfig()
	return _data.serverConfig
end

local function getGameStatus()
	return _data.gameStatus
end

local function setGameStatus(gameStatus)
	_data.gameStatus = gameStatus
	
	local pbParser = resourceResolver.get("pbParser")
	local packetStr = skynet.call(pbParser, "lua", "encode", 0x010203, {gameStatus=_data.gameStatus}, true)
	if packetStr then
		broadcastTable(packetStr)
		broadcastLookon(packetStr)
	end	
end

local function isDrawStarted()
	return _data.isTableStarted
end

local function startGame()
	if _data.isDrawStarted then
		skynet.error(string.format("%s[%d] 游戏已经开始了", SERVICE_NAME, _data.id))
		return
	end
	local tempCode, tempData = skynet.call(addressResolver.getAddressByServiceName("GS_model_tableManager"),
			"lua", "tableActive", _data.id)
	if tempCode ~= true then
		return
	end
	_data.isActive = true
	if tableFrameSink.dragonInit then
		tableFrameSink.dragonInit(tempData)
	end
	
	local isGameStartedOld = _data.isGameStarted
	local isTableStartedOld = _data.isTableStarted
	
	_data.isGameStarted = true
	_data.isDrawStarted = true
	_data.isTableStarted = true
	_data.gameStatus = GS_CONST.GAME_STATUS.PLAY
	
	_data.drawStartTime = math.floor(skynet.time())
	
	if not isGameStartedOld then
		for chairID, userData in pairs(_data.chairID2UserData) do
			userData.offlineCount = 0
			userData.offlineTime = 0
			
			if _data.serverConfig.ServiceScore > 0 then
				ServerUserItem.freezeScore(userData.item, _data.serverConfig.ServiceScore)
			end
			
			local userAttr =  ServerUserItem.getAttribute(userData.item, {"userStatus", "userID"})
			if userAttr.userStatus ~= GS_CONST.USER_STATUS.US_OFFLINE and userAttr.userStatus ~= GS_CONST.USER_STATUS.US_PLAYING then
				skynet.call(addressResolver.getAddressByServiceName("GS_model_userManager"), "lua", "setUserStatus", userAttr.userID, GS_CONST.USER_STATUS.US_PLAYING, _data.id, chairID)
			end
		end
		
		if not isTableStartedOld then
			skynet.call(addressResolver.getAddressByServiceName("GS_model_tableManager"), "lua", "tableStateChange", _data.id, {
				isLocked = _data.enterPassword~=nil,
				isStarted = _data.isGameStarted,
				sitCount = getSitUserCount(),
			})
		end
	end
	
	local sql = string.format(
		"INSERT INTO `QPRecordDB`.`DrawInfo` (`KindID`, `ServerID`, `TableID`, `StartTime`) VALUES (%d, %d, %d, '%s')",
		_data.serverConfig.KindID, _data.serverConfig.ServerID, _data.id, os.date('%Y-%m-%d %H:%M:%S', _data.drawStartTime)
	)
	
	local mysqlConn = addressResolver.getMysqlConnection()
	_data.drawID = skynet.call(mysqlConn, "lua", "insert", sql)
	
	_data.offlineCheckTimerID = nil
	timerUtility.start(GS_CONST.TIMER.TICK_STEP)
	
	if tableFrameSink.onEventGameStart then
		tableFrameSink.onEventGameStart()
	end
end

local function storeGameRecord()	
	local sql = string.format(
		"UPDATE `QPRecordDB`.`DrawInfo` SET `ConcludeTime`='%s' WHERE `DrawID`=%d",
		os.date('%Y-%m-%d %H:%M:%S', math.floor(skynet.time())), _data.drawID
	)
	
	local mysqlConn = addressResolver.getMysqlConnection()
	skynet.send(mysqlConn, "lua", "execute", sql)
	
	if #(_data.gameScoreRecord) == 0 then
		return 
	end	
	
	for _, item in ipairs(_data.gameScoreRecord) do
		if item.isAndroid then
			item.isAndroid = 1
		else
			item.isAndroid = 0
		end
		
		if item.grade==nil then
			item.grade = 0
		end
		
		if item.gift==nil then
			item.gift = 0
		end
		
		if item.present==nil then
			item.present = 0
		end
		
		if item.loveliness==nil then
			item.loveliness = 0
		end
		
		if item.loveliness==nil then
			item.loveliness = 0
		end		
		
		
		sql = string.format(
			"INSERT INTO `QPRecordDB`.`DrawScore` (`DrawID`, `UserID`, `ChairID`, `isAndroid`, `Score`, `Grade`, `Revenue`, `Medal`, `Gift`, `Present`, `Loveliness`, `PlayTimeCount`, `InoutIndex`, `InsertTime`) VALUES (%d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, '%s')",
			_data.drawID, item.userID, item.chairID, item.isAndroid, item.score, item.grade, item.revenue, item.medal, item.gift, item.present, item.loveliness, item.gamePlayTime, item.inoutIndex, os.date('%Y-%m-%d %H:%M:%S', item.insertTime)
		)
		skynet.send(mysqlConn, "lua", "execute", sql)
	end
	
	_data.gameScoreRecord = {}
end

--[[
tagScoreInfo: {
	type=GS_CONST.SCORE_TYPE, 			--积分类型
	score=, 							--用户分数
	insure=,							--用户银行（这个基本不会用）
	grade=, 							--用户成绩
	revenue=, 							--游戏税收
	medal=,								--奖牌
	gift=,								--礼券
	present=,							--UU游戏的用户的奖牌数
	loveliness=,						--魅力
}
--]]
local function writeUserScore(chairID, tagScoreInfo, gamePlayTime, ignoreGameRecord)
	if _data.serverConfig.ServerType==GS_CONST.GAME_GENRE.MATCH then
		return
	end
	
	local userData = _data.chairID2UserData[chairID]
	if not userData then
		error(string.format("%s[%d] writeUserScore 找不到用户信息 chairID=%d", SERVICE_NAME, _data.id, chairID))
	end
	
	if tagScoreInfo.type==nil then
		error(string.format("%s[%d] writeUserScore 缺少积分类型 chairID=%d", SERVICE_NAME, _data.id, chairID))
	end
	
	if tagScoreInfo.score==nil then
		tagScoreInfo.score = 0
	end
	
	if tagScoreInfo.revenue==nil then
		tagScoreInfo.revenue = 0
	end
	
	if tagScoreInfo.medal==nil then
		tagScoreInfo.medal = 0
	end	
	
	--游戏时间
	if gamePlayTime==nil then
		if _data.isDrawStarted then
			gamePlayTime = math.floor(skynet.time()) - _data.drawStartTime
		else
			gamePlayTime = 0
		end
	end	
	
	if GS_CONST.SCORE_TYPE.ST_WIN<=tagScoreInfo.type and tagScoreInfo.type<=GS_CONST.SCORE_TYPE.ST_FLEE then
		--扣服务费
		if _data.serverConfig.ServiceScore>0 and _data.serverConfig.ServerType==GS_CONST.GAME_GENRE.GOLD then
			tagScoreInfo.score = tagScoreInfo.score - _data.serverConfig.ServiceScore
			tagScoreInfo.revenue = tagScoreInfo.revenue + _data.serverConfig.ServiceScore
			
			local userAttr = ServerUserItem.getAttribute(userData.item, {"frozenedScore"})
			ServerUserItem.unfreezeScore(userData.item, math.min(userAttr.frozenedScore, _data.serverConfig.ServiceScore))
		end
	end

	
	--道具判断(更像是buff效果，由于没用，拿掉)
	
	ServerUserItem.writeUserScore(userData.item, {
		score=tagScoreInfo.score,
		insure=tagScoreInfo.insure,
		grade=tagScoreInfo.grade,
		revenue=tagScoreInfo.revenue,
		medal=tagScoreInfo.medal,
		gift=tagScoreInfo.gift,
		present=tagScoreInfo.present,
		loveliness=tagScoreInfo.loveliness,
	}, tagScoreInfo.type, gamePlayTime)
	if _data.serverConfig.ServerType~=GS_CONST.GAME_GENRE.EDUCATE then
		skynet.call(addressResolver.getAddressByServiceName("GS_model_attemperEngine"), "lua", "writeVariation", userData.item)
	end
	
	--游戏记录
	if not ignoreGameRecord and (_data.serverConfig.ServerRule & GS_CONST.SERVER_RULE.SR_RECORD_GAME_SCORE) ~= 0 then
		local userAttr = ServerUserItem.getAttribute(userData.item, {"userID", "isAndroid", "inoutIndex"})
		table.insert(_data.gameScoreRecord, {
			userID = userAttr.userID,
			chairID = chairID,
			isAndroid = userAttr.isAndroid,
			score = tagScoreInfo.score,
			grade = tagScoreInfo.grade,
			revenue = tagScoreInfo.revenue,
			medal = tagScoreInfo.medal,
			gift = tagScoreInfo.gift,
			present = tagScoreInfo.present,
			loveliness = tagScoreInfo.loveliness,
			gamePlayTime = gamePlayTime,
			inoutIndex = userAttr.inoutIndex,
			insertTime = math.floor(skynet.time()),
		})
	
		if #(_data.gameScoreRecord) > 100 then
			storeGameRecord()
		end
	end
end

local function getTableID()
	return _data.id
end

-- 结束桌子
local function concludeTable()
	if not _data.isGameStarted and _data.isTableStarted then
		if _data.startMode==GS_CONST.START_MODE.ALL_READY or _data.startMode==GS_CONST.START_MODE.PAIR_READY or _data.startMode==GS_CONST.START_MODE.FULL_READY or
				_data.serverConfig.ChairPerTable==GS_CONST.MAX_CHAIR or getSitUserCount()==0 then
					
			_data.isTableStarted = false
		end
	end
end

-- 判断 ALL_READY|FULL_READY|PAIR_READY 3种模式是否可以开始游戏
local function efficacyStartGame(chairID)
	if _data.isGameStarted then
		return false
	end
	
	--模式过滤
	if _data.startMode==GS_CONST.START_MODE.TIME_CONTROL or _data.startMode==GS_CONST.START_MODE.MASTER_CONTROL then
		return false
	end
	
	local readyUserCount = 0
	for cid, userData in pairs(_data.chairID2UserData) do
		local userAttr = ServerUserItem.getAttribute(userData.item, {"isClientReady", "userStatus"})
		if not userAttr.isClientReady or (chairID~=cid and userAttr.userStatus~=GS_CONST.USER_STATUS.US_READY) then
			return false
		end
		readyUserCount = readyUserCount + 1
	end
	
	if _data.startMode==GS_CONST.START_MODE.ALL_READY then
		--所有准备
		if readyUserCount >= 2 then
			return true
		else
			return false
		end
		
	elseif _data.startMode==GS_CONST.START_MODE.FULL_READY then
		--满人开始
		if readyUserCount==_data.serverConfig.ChairPerTable then
			return true
		else
			return false
		end
		
	elseif _data.startMode==GS_CONST.START_MODE.PAIR_READY then
		--配对开始
		
		--数目判断
		if readyUserCount==_data.serverConfig.ChairPerTable then
			return true
		end
		
		if readyUserCount<2 or readyUserCount%2~=0 then
			return false
		end
		
		local halfTableNum = math.floor(_data.serverConfig.ChairPerTable/2)
		for i=1, halfTableNum do
			local ud1 = _data.chairID2UserData[i]
			local ud2 = _data.chairID2UserData[i+halfTableNum]
			
			if (ud1==nil and ud2~=nil) or (ud1~=nil and ud2==nil) then
				return false
			end
		end
		
		return true
	else
		return false
	end
end

local function standUp(userItem, doNotSendTableState)
	local userAttr = ServerUserItem.getAttribute(userItem, {"userStatus", "tableID", "chairID", "userID", "siteDownScore", "isAndroid", "agent", "frozenedScore"})
	local userData = _data.chairID2UserData[userAttr.chairID]
	
	if not userData or userData.item~=userItem then
		if not userData then
			skynet.error(string.format("%s[%d] standUP 桌子用户信息冲突 chairID=%d userItem=%s userData=nil", SERVICE_NAME, _data.id, userAttr.chairID, tostring(userItem)))
			
			for k, v in pairs(_data.chairID2UserData) do
				if v.userId == userAttr.userID then
					_data.chairID2UserData[k] = nil
					break
				end
			end
		else
			skynet.error(string.format("%s[%d] standUP 桌子用户信息冲突 chairID=%d userItem=%s userData.item=%s", SERVICE_NAME, _data.id, userAttr.chairID, tostring(userItem), tostring(userData.item)))
		end
		return
	end
	
	--解锁游戏币
	if userAttr.frozenedScore > 0 then
		ServerUserItem.unfreezeScore(userItem, userAttr.frozenedScore)
	end
	
	if tableFrameSink.onActionUserStandUp then
		tableFrameSink.onActionUserStandUp(userAttr.chairID)
	end
	
	--如果是练习场
	if _data.serverConfig.ServerType==GS_CONST.GAME_GENRE.EDUCATE then
		ServerUserItem.setAttribute(userItem, {score=userAttr.siteDownScore})
		--推送玩家积分信息
		skynet.call(addressResolver.getAddressByServiceName("GS_model_attemperEngine"), "lua", "broadcastUserScore", userItem)
	end
	
	ServerUserItem.setAttribute(userItem, {isClientReady=false})
	
	local us
	if userAttr.userStatus==GS_CONST.USER_STATUS.US_OFFLINE then
		us = GS_CONST.USER_STATUS.US_NULL
	else
		us = GS_CONST.USER_STATUS.US_FREE
	end
	_data.chairID2UserData[userAttr.chairID] = nil
--[[	
	if us == GS_CONST.USER_STATUS.US_NULL then
		skynet.error(string.format("%s[%d] standUp 清除离线用户数据 chairID=%d userItem=%s userID=%d", SERVICE_NAME, _data.id, userAttr.chairID, tostring(userItem), userAttr.userID))
	else
		skynet.error(string.format("%s[%d] standUp 用户从桌子站起 chairID=%d userItem=%s userID=%d", SERVICE_NAME, _data.id, userAttr.chairID, tostring(userItem), userAttr.userID))
	end
--]]
	skynet.call(addressResolver.getAddressByServiceName("GS_model_userManager"), "lua", "setUserStatus", userAttr.userID, us, GS_CONST.INVALID_TABLE, GS_CONST.INVALID_CHAIR)
	
	if _data.tableOwnerID == userAttr.userID then
		local firstRemainUserData
		for _, _ud in pairs(_data.chairID2UserData) do
			firstRemainUserData = _ud
			break
		end
		if firstRemainUserData~=nil then
			local firstRemainUserAttr = ServerUserItem.getAttribute(firstRemainUserData.item, {"userID"})
			_data.tableOwnerID = firstRemainUserAttr.userID
		else
			_data.tableOwnerID = 0
			_data.enterPassword = nil
		end
	end
	
	if _data.tableOwnerID == 0 then
		--踢走旁观
		local packetStr = getBufferedPacket(0x010205)
		broadcastLookon(packetStr)
		
		--结束桌子
		timerUtility.stop()
		concludeGame(GS_CONST.GAME_STATUS.FREE)
	end	
	
	--开始判断
	if efficacyStartGame(GS_CONST.INVALID_CHAIR) then
		startGame()
	end
	
	if not doNotSendTableState then
		skynet.call(addressResolver.getAddressByServiceName("GS_model_tableManager"), "lua", "tableStateChange", _data.id, {
			isLocked = _data.enterPassword~=nil,
			isStarted = _data.isGameStarted,
			sitCount = getSitUserCount(),
		})
	end

	--[[
	--换一个机器人(原来也没用，未实现)
	if userAttr.isAndroid then
		skynet.call(addressResolver.getAddressByServiceName("GS_model_attemperEngine"), "lua", "refushAndroidPlayer", userItem)
	end
	--]]
end


--插入两个函数drawStart,drawStop，用于百家乐形式的每局开始和结束
local function drawStart()
	if _data.serverConfig.ServiceScore > 0 then -- 每一局冻结服务费
		for chairID, userData in pairs(_data.chairID2UserData) do
			ServerUserItem.freezeScore(userData.item, _data.serverConfig.ServiceScore)
		end
	end
	
	_data.drawStartTime = math.floor(skynet.time())
	--写开始记录
	local sql = string.format(
		"INSERT INTO `QPRecordDB`.`DrawInfo` (`KindID`, `ServerID`, `TableID`, `StartTime`) VALUES (%d, %d, %d, '%s')",
		_data.serverConfig.KindID, _data.serverConfig.ServerID, _data.id, os.date('%Y-%m-%d %H:%M:%S', _data.drawStartTime)
	)
	
	local mysqlConn = addressResolver.getMysqlConnection()
	_data.drawID = skynet.call(mysqlConn, "lua", "insert", sql)
end

local function drawStop()
	if not _data.isGameStarted then
		return
	end
	storeGameRecord()
	
	_data.drawCount = _data.drawCount + 1
	
	for chairID, userData in pairs(_data.chairID2UserData) do
		local userAttr = ServerUserItem.getAttribute(userData.item, {"userStatus", "userID", "isAndroid", "score", "masterOrder", "agent", "frozenedScore"})
		
		if userAttr.frozenedScore > 0 then
			ServerUserItem.unfreezeScore(userData.item, userAttr.frozenedScore)
		end
		
		if userAttr.userStatus==GS_CONST.USER_STATUS.US_OFFLINE then
			standUp(userData.item, true)
		else
			local kickMsg = nil
			--积分限制
			if _data.serverConfig.MinTableScore > 0 and userAttr.score < _data.serverConfig.MinTableScore then
				if (_data.serverConfig.ServerType & GS_CONST.GAME_GENRE.GOLD)~= 0 then
					kickMsg = string.format("您的游戏筹码少于%s，不能继续游戏！", currencyUtility.formatCurrency(_data.serverConfig.MinTableScore))
				else
					kickMsg = string.format("您的游戏积分少于%s，不能继续游戏！", currencyUtility.formatCurrency(_data.serverConfig.MinTableScore))
				end
			end
			
			if _data.serverConfig.MinEnterScore > 0 and userAttr.score < _data.serverConfig.MinEnterScore then
				if (_data.serverConfig.ServerType & GS_CONST.GAME_GENRE.GOLD)~= 0 then
					kickMsg = string.format("您的游戏筹码少于%s，不能继续游戏！", currencyUtility.formatCurrency(_data.serverConfig.MinEnterScore))
				else
					kickMsg = string.format("您的游戏积分少于%s，不能继续游戏！", currencyUtility.formatCurrency(_data.serverConfig.MinEnterScore))
				end
			end
			
			if _data.serverConfig.MaxEnterScore > 0 and userAttr.score > _data.serverConfig.MaxEnterScore then
				if (_data.serverConfig.ServerType & GS_CONST.GAME_GENRE.GOLD)~= 0 then
					kickMsg = string.format("您的游戏筹码高于%s，不能继续游戏！", currencyUtility.formatCurrency(_data.serverConfig.MaxEnterScore))
				else
					kickMsg = string.format("您的游戏积分高于%s，不能继续游戏！", currencyUtility.formatCurrency(_data.serverConfig.MaxEnterScore))
				end
			end
			
			if (_data.serverConfig.ServerRule & GS_CONST.SERVER_RULE.SR_FORFEND_GAME_ENTER)~=0 and userAttr.masterOrder==0 then
				kickMsg = "由于系统维护，当前游戏桌子禁止用户继续游戏！"
			end
			
			if kickMsg then
				standUp(userData.item, true)
				
				skynet.send(userAttr.agent, "lua", "forward", 0xff0000, {
					msg = kickMsg,
					type = COMMON_CONST.SYSTEM_MESSAGE_TYPE.SMT_POPUP,
				})
			end
		end
	end
end

concludeGame = function(gameStatus)	
	if not _data.isGameStarted then
		return
	end
	
	_data.isActive = false
	skynet.send(addressResolver.getAddressByServiceName("GS_model_tableManager"),
			"lua", "tableNotActive", _data.id)
	
	_data.offlineCheckTimerID = nil
	tableFrameSink.onEventGameConclude()
	storeGameRecord()	
	
	_data.isDrawStarted = false
	setGameStatus(gameStatus)
	if _data.gameStatus>=GS_CONST.GAME_STATUS.PLAY then
		_data.isGameStarted = true
	else
		_data.isGameStarted = false
	end
	_data.drawCount = _data.drawCount + 1
	
	if not _data.isGameStarted then
		for chairID, userData in pairs(_data.chairID2UserData) do
			local userAttr = ServerUserItem.getAttribute(userData.item, {"userStatus", "userID", "isAndroid", "score", "masterOrder", "agent", "frozenedScore"})
			
			if userAttr.frozenedScore > 0 then
				ServerUserItem.unfreezeScore(userData.item, userAttr.frozenedScore)
			end
			
			if userAttr.userStatus==GS_CONST.USER_STATUS.US_OFFLINE then
				standUp(userData.item, true)
			else
				if userAttr.userStatus==GS_CONST.USER_STATUS.US_PLAYING then
					skynet.call(addressResolver.getAddressByServiceName("GS_model_userManager"), "lua", "setUserStatus", userAttr.userID, GS_CONST.USER_STATUS.US_SIT, _data.id, chairID)
				end
				
				if (_data.serverConfig.ServerType & GS_CONST.GAME_GENRE.MATCH)==0 and userAttr.isAndroid then
					--TODO CTableFrame::ConcludeGame 机器人局数，时间限制的检查，不符合条件就站起
				end
				
				local kickMsg = nil
				--积分限制
				if _data.serverConfig.MinTableScore > 0 and userAttr.score < _data.serverConfig.MinTableScore then
					if (_data.serverConfig.ServerType & GS_CONST.GAME_GENRE.GOLD)~= 0 then
						kickMsg = string.format("您的游戏筹码少于%s，不能继续游戏！", currencyUtility.formatCurrency(_data.serverConfig.MinTableScore))
					else
						kickMsg = string.format("您的游戏积分少于%s，不能继续游戏！", currencyUtility.formatCurrency(_data.serverConfig.MinTableScore))
					end
				end
				
				if _data.serverConfig.MinEnterScore > 0 and userAttr.score < _data.serverConfig.MinEnterScore then
					if (_data.serverConfig.ServerType & GS_CONST.GAME_GENRE.GOLD)~= 0 then
						kickMsg = string.format("您的游戏筹码少于%s，不能继续游戏！", currencyUtility.formatCurrency(_data.serverConfig.MinEnterScore))
					else
						kickMsg = string.format("您的游戏积分少于%s，不能继续游戏！", currencyUtility.formatCurrency(_data.serverConfig.MinEnterScore))
					end
				end
				
				if _data.serverConfig.MaxEnterScore > 0 and userAttr.score > _data.serverConfig.MaxEnterScore then
					if (_data.serverConfig.ServerType & GS_CONST.GAME_GENRE.GOLD)~= 0 then
						kickMsg = string.format("您的游戏筹码高于%s，不能继续游戏！", currencyUtility.formatCurrency(_data.serverConfig.MaxEnterScore))
					else
						kickMsg = string.format("您的游戏积分高于%s，不能继续游戏！", currencyUtility.formatCurrency(_data.serverConfig.MaxEnterScore))
					end
				end
				
				if (_data.serverConfig.ServerRule & GS_CONST.SERVER_RULE.SR_FORFEND_GAME_ENTER)~=0 and userAttr.masterOrder==0 then
					kickMsg = "由于系统维护，当前游戏桌子禁止用户继续游戏！"
				end
				
				if kickMsg then
					standUp(userData.item, true)
					
					skynet.send(userAttr.agent, "lua", "forward", 0xff0000, {
						msg = kickMsg,
						type = COMMON_CONST.SYSTEM_MESSAGE_TYPE.SMT_POPUP,
					})
				end
			end
		end
	end
	
	if tableFrameSink and tableFrameSink.reset then
		--原来的TableFrameSink::RepositionSink
		tableFrameSink.reset()
	end
	
	concludeTable();
	
	skynet.call(addressResolver.getAddressByServiceName("GS_model_tableManager"), "lua", "tableStateChange", _data.id, {
		isLocked = _data.enterPassword~=nil,
		isStarted = _data.isGameStarted,
		sitCount = getSitUserCount(),
	})
end

-- CTableFrame::OnMatchScoreChange CAttemperEngineSink::OnMatchScoreChange
local function onMatchScoreChange(userItem, scoreDelt)
	if (_data.serverConfig.ServerType & GS_CONST.GAME_GENRE.MATCH)~=0 then
		skynet.call(addressResolver.getAddressByServiceName("GS_model_matchManager"), "lua", "onMatchScoreChange", userItem, scoreDelt)
	end
end

local function sendSystemMessage(msg, isAll, isKind, isNode, isServer)
	local msgBody = {
		msg=msg,
		type=COMMON_CONST.SYSTEM_MESSAGE_TYPE.SMT_NORMAL,
	}
	
	local kid, nid, sid, sendRemote
	if isAll then
		kid = nil
		nid = nil
		sid = nil
		sendRemote = true
	elseif isKind then
		kid = _data.serverConfig.KindID
		nid = nil
		sid = nil
		sendRemote = true
	elseif isNode then
		kid = nil
		nid = _data.serverConfig.NodeID
		sid = nil
		sendRemote = true
	elseif isServer then
		sendRemote = false
	else
		error(string.format("%s[%d] sendSystemMessage 系统消息目标错误", SERVICE_NAME, _data.id))
	end
	
	if sendRemote then
		skynet.send(
			addressResolver.getAddressByServiceName("GS_model_serverStatus"), "lua", "serverBroadCast",
			kid, nid, sid, COMMON_CONST.RELAY_MESSAGE_TYPE.RMT_SYSTEM_MESSAGE, msgBody
		)
	else
		local pbParser = resourceResolver.get("pbParser")
		local packetStr = skynet.call(pbParser, "lua", "encode", 0xff0000, msgBody, true)
		if packetStr then
			skynet.call(addressResolver.getAddressByServiceName("GS_model_userManager"), "lua", "broadcast", packetStr)
		end	
	end
end

adjustOfflineTimer = function(oldestOfflineChairID)
	local oldestOfflineUserData = _data.chairID2UserData[oldestOfflineChairID]
	local lapseSecond = math.floor(skynet.time()) - oldestOfflineUserData.offlineTime
	local timeoutTick = GS_CONST.TIMER.TICKSPAN_TABLE_OFFLINE_WAIT * GS_CONST.TIMER.TICK_STEP - (lapseSecond * 100)
	if timeoutTick < 0 then
		timeoutTick = 0
	end

	_data.offlineCheckTimerID = timerUtility.setTimeout(onTimerOfflineWait, math.ceil(timeoutTick / GS_CONST.TIMER.TICK_STEP), oldestOfflineChairID)
end

onTimerOfflineWait = function(offlineChairID)
	_criticalSection(function()
		if _data.offlineCheckTimerID~=nil then
			_data.offlineCheckTimerID = nil
			
			-- 不需要寻找最老的断线用户，实现保证了offlineChairID就是最老的断线用户
			local offlineUserData = _data.chairID2UserData[offlineChairID]
			if offlineUserData then
				standUp(offlineUserData.item)
			else
				error(string.format("%s[%d]: onTimerOfflineWait 找不到断线用户 chairID=%d", SERVICE_NAME, _data.id, offlineChairID))
			end
			
			if _data.isGameStarted then
				local oldestOfflineChairID = getOldestOfflineChairID()
				if oldestOfflineChairID~=GS_CONST.INVALID_CHAIR then
					--调整定时器
					adjustOfflineTimer(oldestOfflineChairID)
				end
			end
		end
	end)
end

local function findRandomEmptyChairID()
	local temp = arc4.random(0, _data.serverConfig.ChairPerTable-1)
	for i=temp, temp+_data.serverConfig.ChairPerTable-1 do
		local index = i % _data.serverConfig.ChairPerTable + 1
		if _data.chairID2UserData[index] == nil then
			return index
		end
	end
end

local function getUserItem(chairID)
	local userData = _data.chairID2UserData[chairID]
	if userData then
		return userData.item
	end	
end

local function cmd_getUserItem(chairID)
	local userItem
	_criticalSection(function()
		userItem = getUserItem(chairID)
	end)
	return userItem 
end

-- performSitDownAction
local function cmd_sitDown(userItem, chairID, password)
	
	local isSuccess, retCode, msg
	
	_criticalSection(function()

		local userAttr = ServerUserItem.getAttribute(userItem, {"userID", "tableID", "chairID", "score", "agent"})
		assert(userAttr.tableID==GS_CONST.INVALID_TABLE and userAttr.chairID==GS_CONST.INVALID_CHAIR, "用户状态错误")
		
		if _data.isGameStarted and (_data.serverConfig.ServerRule & GS_CONST.SERVER_RULE.SR_ALLOW_DYNAMIC_JOIN) == 0 then
			isSuccess, retCode, msg = false, "RC_TABLE_GAME_STARTED"
			return
		end
		if chairID == GS_CONST.INVALID_CHAIR then
			chairID = findRandomEmptyChairID()
			if chairID == nil then
				isSuccess, retCode, msg = false, "RC_CHAIR_ALREADY_TAKEN", "找不到空位置，请稍后再试！"
				return
			end
		else
			local tableUserData = _data.chairID2UserData[chairID]
			if tableUserData ~= nil then
				local tableUserAttr = ServerUserItem.getAttribute(tableUserData.item, {"nickName"})
				isSuccess, retCode, msg = false, "RC_CHAIR_ALREADY_TAKEN", string.format("椅子已经被 [%s] 捷足先登了，下次动作要快点了！", tableUserAttr.nickName)
				return
			end
		end
		
		if _data.enterPassword and _data.enterPassword~=password then
			isSuccess, retCode, msg = false, "RC_PASSWORD_ERROR"
			return
		end
		
		_data.chairID2UserData[chairID] = createUserDataItem(userItem, userAttr.userID)
		_data.drawCount = 0	
		
		if (_data.serverConfig.ServerType & GS_CONST.GAME_GENRE.EDUCATE) ~= 0 then
			-- 默认试玩场给的钱
			local tryScore = 100000
			
			if tableFrameSink.getPlayerTryScore then
				tryScore = tableFrameSink.getPlayerTryScore()
			end
			
			ServerUserItem.setAttribute(userItem, {siteDownScore=userAttr.score, score=tryScore})
		end

		ServerUserItem.setAttribute(userItem, {isClientReady=false})
		
		local us
		if not _data.isGameStarted then
			us = GS_CONST.USER_STATUS.US_SIT
		else
			if _data.serverConfig.ServiceScore > 0 then
				ServerUserItem.freezeScore(userItem, _data.serverConfig.ServiceScore)
			end
			us = GS_CONST.USER_STATUS.US_PLAYING
		end
		
		local backTemp = skynet.call(addressResolver.getAddressByServiceName("GS_model_userManager"), "lua", "setUserStatus", userAttr.userID, us, _data.id, chairID)
		if backTemp == false then -- userItem找不到，已被清除
			_data.chairID2UserData[chairID] = nil
			isSuccess, retCode, msg = false, "RC_CHAIR_ALREADY_TAKEN"
			return
		end
		if getSitUserCount()==1 and _data.startMode ~= GS_CONST.START_MODE.MASTER_CONTROL then
			_data.tableOwnerID = userAttr.userID
			if password ~= nil then
				_data.enterPassword = password
			end
		end	
		
		skynet.call(addressResolver.getAddressByServiceName("GS_model_tableManager"), "lua", "tableStateChange", _data.id, {
			isLocked = _data.enterPassword~=nil,
			isStarted = _data.isGameStarted,
			sitCount = getSitUserCount(),
		})
		
		if tableFrameSink.onActionUserSitDown then
			tableFrameSink.onActionUserSitDown(chairID, userItem, false)
		end
		
		isSuccess, retCode, msg = true
	end)
	
	return isSuccess, retCode, msg
end

local function cmd_gameOption(userItem, isAllowLookon)
	_criticalSection(function()
		local userAttr = ServerUserItem.getAttribute(userItem, {"chairID", "userStatus", "agent"})
		--skynet.error(string.format("gameOption received from [:%08x]", userAttr.agent))
		local userData = _data.chairID2UserData[userAttr.chairID]
		if not userData or userData.item~=userItem then
			error(string.format("%s[%d] cmd_gameOption 用户信息冲突 chairID=%d", SERVICE_NAME, _data.id, userAttr.chairID))
		end
		
		-- 断线清理
		if userAttr.userStatus~=GS_CONST.USER_STATUS.US_LOOKON and userData.offlineTime~=0 then
			userData.offlineTime=0
			
			if _data.offlineCheckTimerID then
				timerUtility.clearTimer(_data.offlineCheckTimerID)
				_data.offlineCheckTimerID = nil
				
				local oldestOfflineChairID = getOldestOfflineChairID()
				if oldestOfflineChairID~=GS_CONST.INVALID_CHAIR then
					--调整定时器
					adjustOfflineTimer(oldestOfflineChairID)
				end
			end
		end
		
		ServerUserItem.setAttribute(userItem, {isClientReady=true})
		if userAttr.userStatus~=GS_CONST.USER_STATUS.US_LOOKON then
			userData.isAllowLook = isAllowLookon
		end
		
		skynet.send(userAttr.agent, "lua", "forward", 0x010203, {gameStatus=_data.gameStatus})
		
		skynet.send(userAttr.agent, "lua", "forward", 0xff0000, {
			type = COMMON_CONST.SYSTEM_MESSAGE_TYPE.SMT_NORMAL,
			msg = string.format("欢迎您进入“%s”游戏，祝您游戏愉快！", _data.serverConfig.KindName),
		})
		
		local sendSecret = userAttr.userStatus~=GS_CONST.USER_STATUS.US_LOOKON or userData.isAllowLook
		tableFrameSink.onActionUserGameOption(userAttr.chairID, userItem, _data.gameStatus, sendSecret)
		
		-- 开始判断
		if userAttr.userStatus==GS_CONST.USER_STATUS.US_READY and efficacyStartGame(userAttr.chairID) then
			startGame()
		end
	end)
end

local function cmd_standUp(userItem)
	_criticalSection(function()
		standUp(userItem)
	end)
end

--用户积分变动
local function cmd_onUserScoreNotify(userItem)
	_criticalSection(function()
		local userAttr = ServerUserItem.getAttribute(userItem, {"chairID"})
		local userData = _data.chairID2UserData[userAttr.chairID]			
		if not userData or userData.item~=userItem then
			error(string.format("%s[%d] cmd_onUserScoreNotify 用户信息冲突 chairID=%d", SERVICE_NAME, _data.id, userAttr.chairID))
		end			
			
		if (_data.serverConfig.ServerType & GS_CONST.GAME_GENRE.EDUCATE)==0 and (_data.serverConfig.ServerType & GS_CONST.GAME_GENRE.MATCH)==0 and tableFrameSink.onUserScoreNotify then
			tableFrameSink.onUserScoreNotify(userAttr.chairID, userItem)
		end	
	end)
end

--用户积分变动(新)
local function cmd_changeUserMoney(data)
	_criticalSection(function()
		local chairId = 0
		for k, userData in pairs(_data.chairID2UserData) do
			if userData.userId == data.userId then
				chairId = k
				break
			end
		end
		if chairId == 0 then
			return
		end
			
		if data.score ~= 0 and (_data.serverConfig.ServerType & GS_CONST.GAME_GENRE.EDUCATE)==0 and (_data.serverConfig.ServerType & GS_CONST.GAME_GENRE.MATCH)==0 and tableFrameSink.changeUserMoney then
			tableFrameSink.changeUserMoney(chairId, data.score)
		end	
	end)
end

local function cmd_calcScoreAndLock(userItem)
	_criticalSection(function()
		local userAttr = ServerUserItem.getAttribute(userItem, {"chairID"})
		local userData = _data.chairID2UserData[userAttr.chairID]
		if not userData or userData.item~=userItem then
			error(string.format("%s[%d] cmd_calcScoreAndLock 用户信息冲突 chairID=%d", SERVICE_NAME, _data.id, userAttr.chairID))
		end
		
		if tableFrameSink.calcScoreAndLock then
			-- 捕鱼这类没有锁定金币，不是一局一结算的游戏，需要先通知锁定
			tableFrameSink.calcScoreAndLock(userAttr.chairID)
		end
	end)
end

local function cmd_releaseScoreLock(userItem)
	_criticalSection(function()
		local userAttr = ServerUserItem.getAttribute(userItem, {"chairID"})
		local userData = _data.chairID2UserData[userAttr.chairID]
		if not userData or userData.item~=userItem then
			error(string.format("%s[%d] cmd_releaseScoreLock 用户信息冲突 chairID=%d", SERVICE_NAME, _data.id, userAttr.chairID))
		end
		
		if tableFrameSink.releaseScoreLock then
			tableFrameSink.releaseScoreLock(userAttr.chairID)
		end
	end)
end



--CTableFrame::OnEventUserOffLine
local function cmd_userOffLine(userItem)
	_criticalSection(function()
		local userAttr = ServerUserItem.getAttribute(userItem, {"chairID", "userStatus", "agent", "userID"})
		local userData = _data.chairID2UserData[userAttr.chairID]
		
		if not userData or userData.item~=userItem then
			skynet.call(addressResolver.getAddressByServiceName("GS_model_userManager"), "lua", "setUserStatus", userAttr.userID, GS_CONST.USER_STATUS.US_NULL, GS_CONST.INVALID_TABLE, GS_CONST.INVALID_CHAIR)
			if not userData then
				skynet.error(string.format("%s[%d] cmd_userOffLine 桌子用户信息冲突 chairID=%d userItem=%s userData=nil", SERVICE_NAME, _data.id, userAttr.chairID, tostring(userItem)))
			else
				skynet.error(string.format("%s[%d] cmd_userOffLine 桌子用户信息冲突 chairID=%d userItem=%s userData.item=%s", SERVICE_NAME, _data.id, userAttr.chairID, tostring(userItem), tostring(userData.item)))
			end
			return
		end
		
		if userAttr.userStatus==GS_CONST.USER_STATUS.US_PLAYING then
			ServerUserItem.setAttribute(userItem, {isClientReady=false, })
			skynet.call(addressResolver.getAddressByServiceName("GS_model_userManager"), "lua", "setUserStatus", userAttr.userID, GS_CONST.USER_STATUS.US_OFFLINE, _data.id, userAttr.chairID)
			userData.offlineCount = userData.offlineCount + 1
			userData.offlineTime = math.floor(skynet.time())
			
			if _data.offlineCheckTimerID==nil then
				_data.offlineCheckTimerID = timerUtility.setTimeout(onTimerOfflineWait, GS_CONST.TIMER.TICKSPAN_TABLE_OFFLINE_WAIT, userAttr.chairID)
			end
		else
			--skynet.error(string.format("%s[%d]: cmd_userOffLine 用户起立 userID=%d", SERVICE_NAME, _data.id, userAttr.userID))
			--用户起立
			standUp(userItem)
			--skynet.error(string.format("%s.cmd_userOffLine 清除用户数据 userID=%d tableID=%d", SERVICE_NAME, userAttr.userID, _data.id))
			skynet.call(addressResolver.getAddressByServiceName("GS_model_userManager"), "lua", "setUserStatus", userAttr.userID, GS_CONST.USER_STATUS.US_NULL, GS_CONST.INVALID_TABLE, GS_CONST.INVALID_CHAIR)
		end	
	end)
end

-- 游戏事件 CTableFrame::OnEventSocketGame
local function cmd_onGameMessage(chairID, userItem, protocalNo, data)
	_criticalSection(function()
		local userData = _data.chairID2UserData[chairID]
		if not userData or userData.item~=userItem then
--[[			
			if not userData then
				skynet.error(string.format("%s[%d] cmd_onGameMessage 桌子用户信息冲突 chairID=%d userItem=%s userData=nil", SERVICE_NAME, _data.id, chairID, tostring(userItem)))
			else
				skynet.error(string.format("%s[%d] cmd_onGameMessage 桌子用户信息冲突 chairID=%d userItem=%s userData.item=%s", SERVICE_NAME, _data.id, chairID, tostring(userItem), tostring(userData.item)))
			end
--]]
			return 
		end
		
		tableFrameSink.pbMessage(userItem, protocalNo, data)
	end)
end

local interface4sink = {
	getTableID = getTableID,
	getGameStatus = getGameStatus,
	setGameStatus = setGameStatus,
	setStartMode = setStartMode,
	getServerConfig = getServerConfig,
	startGame = startGame,
	broadcastTable = broadcastTable,
	broadcastTableWithExcept = broadcastTableWithExcept,
	broadcastLookon = broadcastLookon,
	writeUserScore = writeUserScore,
	getBufferedPacket = getBufferedPacket,
	concludeGame = concludeGame,
	standUp = standUp,
	onMatchScoreChange = onMatchScoreChange,
	sendSystemMessage = sendSystemMessage,
	isDrawStarted = isDrawStarted,
	getUserItem = getUserItem,
	
	drawStart = drawStart,
	drawStop = drawStop,
	
	getMemberOrderBank = getMemberOrderBank,
}

local function cmd_initialize(tableID, serverConfig, memberOrderConfig)
	_data.serverConfig = serverConfig
	_data.id = tableID
	_memberOrderConfig = memberOrderConfig

	tableFrameSink.initialize(interface4sink, _criticalSection)
end

--CTableFrame::GetTableUserInfo
local function cmd_getUserCount()
	local count = {
		minUser = 0,
		user = 0,
		android = 0,
		ready = 0,
		total = 0,
	}
	
	_criticalSection(function()
		--用户分析
		for _, userData in pairs(_data.chairID2UserData) do
			local userAttr =  ServerUserItem.getAttribute(userData.item, {"userStatus", "isAndroid"})
			if userAttr.isAndroid then
				count.android = count.android + 1
			else
				count.user = count.user + 1
			end
			
			if userAttr.userStatus == GS_CONST.USER_STATUS.US_READY then
				count.ready = count.ready + 1
			end
			
			count.total = count.total + 1
		end
		
		--最少数目
		if _data.startMode == GS_CONST.START_MODE.ALL_READY then			--所有准备
			count.minUser = 2
		elseif _data.startMode == GS_CONST.START_MODE.PAIR_READY then		--配对开始
			count.minUser = 2
		elseif _data.startMode == GS_CONST.START_MODE.TIME_CONTROL then		--时间控制
			count.minUser = 1
		elseif _data.startMode == GS_CONST.START_MODE.MASTER_CONTROL then		--时间控制
			count.minUser = 1
		else																--默认模式
			count.minUser = _data.serverConfig.ChairPerTable
		end	
	end)

	return count
end

local function cmd_getState()
	local ret 
	_criticalSection(function()
		ret = {isGameStarted = _data.isGameStarted, isLocked = _data.enterPassword~=nil}
	end)
	return ret
end

local function cmd_enumerateUserItem()
	local list = {}
	_criticalSection(function()
		for _, userData in pairs(_data.chairID2UserData) do
			table.insert(list, userData.item)
		end
	end)

	return list
end

local function cmd_broadcastTable(packetStr)
	broadcastTable(packetStr)
end

local function cmd_broadcastLookon(packetStr)
	broadcastLookon(packetStr)
end


local function cmd_masterInit()
	if _data.startMode == GS_CONST.START_MODE.MASTER_CONTROL then
		_data.tableOwnerID = -1
		if _data.gameStatus == GS_CONST.GAME_STATUS.FREE then
			startGame()
		end	
	end
end

local function cmd_dragonOpen(tp)
	if _data.isActive then
		tableFrameSink.dragonOpen(tp)
	end
end

local function cmd_dragonOver(data)
	return tableFrameSink.dragonOver(data)
end

local function cmd_dragonPoolAdd(pool)
	if _data.isActive then
		tableFrameSink.dragonPoolAdd(pool)
	end
end

local function cmd_changeUserFishPercent(data)
	if tableFrameSink.changeUserFishPercent then
		local chairId = 0
		for k, userData in pairs(_data.chairID2UserData) do
			if userData.userId == data.userId then
				chairId = k
				break
			end
		end
		if chairId == 0 then
			return
		end
		tableFrameSink.changeUserFishPercent(chairId, data)
	end
end

local conf = {
	methods = {
		["initialize"] = {["func"]=cmd_initialize, ["isRet"]=true},
		["masterInit"] = {["func"]=cmd_masterInit, ["isRet"]=true},
		["getState"] = {["func"]=cmd_getState, ["isRet"]=true},
		["getUserItem"] = {["func"]=cmd_getUserItem, ["isRet"]=true},
		["getUserCount"] = {["func"]=cmd_getUserCount, ["isRet"]=true},
		["sitDown"] = {["func"]=cmd_sitDown, ["isRet"]=true},
		["gameOption"] = {["func"]=cmd_gameOption, ["isRet"]=true},
		["standUp"] = {["func"]=cmd_standUp, ["isRet"]=true},
		["performStandUp"] = {["func"]=cmd_performStandUp, ["isRet"]=true},
		["userOffLine"] = {["func"]=cmd_userOffLine, ["isRet"]=true},
		["gameMessage"] = {["func"]=cmd_onGameMessage, ["isRet"]=true},
		["calcScoreAndLock"] = {["func"]=cmd_calcScoreAndLock, ["isRet"]=true},
		["releaseScoreLock"] = {["func"]=cmd_releaseScoreLock, ["isRet"]=true},
		["enumerateUserItem"] = {["func"]=cmd_enumerateUserItem, ["isRet"]=true},
		["broadcastTable"] = {["func"]=cmd_broadcastTable, ["isRet"]=false},
		["broadcastLookon"] = {["func"]=cmd_broadcastLookon, ["isRet"]=false},
		
		["onUserScoreNotify"] = {["func"]=cmd_onUserScoreNotify, ["isRet"]=true},
		["changeUserMoney"] = {["func"]=cmd_changeUserMoney, ["isRet"]=true},
		["changeUserFishPercent"] = {["func"]=cmd_changeUserFishPercent, ["isRet"]=true},
		
		["dragonOpen"] = {["func"]=cmd_dragonOpen, ["isRet"]=false},
		["dragonOver"] = {["func"]=cmd_dragonOver, ["isRet"]=true},
		["dragonPoolAdd"] = {["func"]=cmd_dragonPoolAdd, ["isRet"]=true},
	},
	initFunc = function()
		resourceResolver.init()
	end,
}

commonServiceHelper.createService(conf)
