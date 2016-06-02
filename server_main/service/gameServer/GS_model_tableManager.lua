local skynet = require "skynet"
local cluster = require "cluster"
local commonServiceHelper = require "serviceHelper.common"
local COMMON_CONST = require "define.commonConst"
local GS_CONST = require "define.gsConst"
local addressResolver = require "addressResolver"
local resourceResolver = require "resourceResolver"
local timerUtility = require "utility.timer"
local currencyUtility = require "utility.currency"

local _serverConfig
local _tableHash = {}
local _activeTable = {} -- 开启的桌子号
local _data = {
	pool = 0,
	maxPool = 0,
	status = 0,
	localPool = 0,
	dragonUsed = {},
	beginTime = 0,
	dragonTp = 0,
}
local _LS_dragonAddress

local function cmd_onEventLoginSuccess(data)
	if not data.isAndroid then	
		local list = {}
		for tableID, item in ipairs(_tableHash) do
			table.insert(list, {tableID=tableID, isLocked=item.state.isLocked, isStarted=item.state.isStarted, sitCount=item.state.sitCount})
		end
		
		skynet.send(data.agent, "lua", "forward", 0x010105, {list=list})
	end
end

local function cmd_masterInit()
	for _, item in ipairs(_tableHash) do
		skynet.call(item.addr, "lua", "masterInit")
	end
end

local function cmd_tableActive(tableId)
	_activeTable[tableId] = true
	return true, {
		beginTime = _data.beginTime,
		pool = _data.pool,
		maxPool = _data.maxPool,
		dragonTp = _data.dragonTp,
	}
end

local function cmd_tableNotActive(tableId)
	_activeTable[tableId] = nil
end

local function cmd_dragonInfo(data)--登陆服务器推送
	if data.tp == 2 then -- 龙宫开启
		_data.status = 1
		_data.beginTime = data.info.beginTime
		local msgBody = {
			type = COMMON_CONST.SYSTEM_MESSAGE_TYPE.SMT_DRAGON_OPEN,
		}
		if data.info.isSmallPool == nil then
			_data.dragonTp = 1
			_data.maxPool = data.info.maxPool
			msgBody.msg = string.format(COMMON_CONST.message.dragonOpen,
					currencyUtility.formatCurrency(_data.maxPool))
		else
			_data.dragonTp = 2
			msgBody.msg = string.format(COMMON_CONST.message.smallOpen,
					currencyUtility.formatCurrency(data.info.maxPool))
		end
		_data.dragonUsed = {}
		for tableId,_ in pairs(_activeTable) do
			skynet.send(_tableHash[tableId].addr, "lua", "dragonOpen", _data.dragonTp)
		end
		local pbParser = resourceResolver.get("pbParser")
		local packetStr = skynet.call(pbParser, "lua", "encode", 0xff0000, msgBody, true)
		if packetStr then
			skynet.call(addressResolver.getAddressByServiceName("GS_model_userManager"), "lua", "broadcast", packetStr)
		end	
	elseif data.tp == 3 then -- 龙宫结束
		_data.dragonTp = 0
		_data.status = 0
		_data.beginTime = 0
		_data.pool = data.info.pool
		if data.info.isSmallPool == nil then
			_data.maxPool = data.info.maxPool
		end
		for tableId,_ in pairs(_tableHash) do
			local temp = skynet.call(_tableHash[tableId].addr, "lua", "dragonOver", data.info)
			if temp ~= nil then
				for k,v in pairs(temp) do
					if _data.dragonUsed[k] == nil then
						_data.dragonUsed[k] = v
					else
						_data.dragonUsed[k] = _data.dragonUsed[k] + v
					end
				end
			end
		end
		local winner = data.info.winner
		if winner ~= nil then
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
			}
		if data.info.isSmallPool ~= nil then
			_data.maxPool = data.info.maxPool
			msgBody.msg = string.format(COMMON_CONST.message.smallOver, temp[winner.memberOrder],
						winner.name, currencyUtility.formatCurrency(winner.score))
		else
			msgBody.msg = string.format(COMMON_CONST.message.smallOver, temp[winner.memberOrder],
						winner.name, currencyUtility.formatCurrency(winner.score))
		end
			local pbParser = resourceResolver.get("pbParser")
			local packetStr = skynet.call(pbParser, "lua", "encode", 0xff0000, msgBody, true)
			if packetStr then
				skynet.call(addressResolver.getAddressByServiceName("GS_model_userManager"), "lua", "broadcast", packetStr)
			end
		end
		cluster.call("loginServer", _LS_dragonAddress, "dragonOverCal", _data.dragonUsed)
	end
end

local function cmd_addLocalPool(num) -- 每个房间上传奖池
	_data.localPool = _data.localPool + num
end

local function uploadDragonPoolAdd() -- 每5s上传同步一次
	local temp = _data.localPool
	_data.localPool = 0
	_data.pool = cluster.call("loginServer", _LS_dragonAddress, "addPool", temp)
	
	for _, item in ipairs(_tableHash) do -- 通知所有有人的桌子，更新龙宫奖池
		skynet.call(item.addr, "lua", "dragonPoolAdd", _data.pool)
	end
end

local function cmd_catchDragon(data)
	if _data.status == 1 then
		cluster.call("loginServer", _LS_dragonAddress, "dragonOver", data)
	end
end

local function cmd_getTableFrame(tableID)
	local item = _tableHash[tableID]
	if item then
		return item.addr
	end
end

local function cmd_findAvailableTable()
	local allowDynamicJoin = (_serverConfig.ServerRule & GS_CONST.SERVER_RULE.SR_ALLOW_DYNAMIC_JOIN) ~= 0
	
	for _, v in ipairs(_tableHash) do
		if (not v.state.isStarted or allowDynamicJoin) and v.state.sitCount < _serverConfig.ChairPerTable then
			return v.addr
		end
	end
end

local function cmd_tableStateChange(tableID, stateObj)
	local item = _tableHash[tableID]
	if item then
		if stateObj.isLocked ~= nil then
			item.state.isLocked = stateObj.isLocked
		end
		
		if stateObj.isStarted ~= nil then
			item.state.isStarted = stateObj.isStarted
		end
		
		if stateObj.sitCount ~= nil then
			item.state.sitCount = stateObj.sitCount
		end	
		
		local pbParser = resourceResolver.get("pbParser")
		local packetStr = skynet.call(pbParser, "lua", "encode", 0x010104, {
			tableID=tableID,
			isLocked=item.state.isLocked,
			isStarted=item.state.isStarted,
			sitCount=item.state.sitCount,	
		}, true)
		if packetStr then
			skynet.call(addressResolver.getAddressByServiceName("GS_model_userManager"), "lua", "broadcast", packetStr)
		end		
	end
end

local conf = {
	methods = {
		["getTableFrame"] = {["func"]=cmd_getTableFrame, ["isRet"]=true},
		["masterInit"] = {["func"]=cmd_masterInit, ["isRet"]=true},
		["findAvailableTable"] = {["func"]=cmd_findAvailableTable, ["isRet"]=true},
		["tableStateChange"] = {["func"]=cmd_tableStateChange, ["isRet"]=true},
		
		["onEventLoginSuccess"] = {["func"]=cmd_onEventLoginSuccess, ["isRet"]=false},
		
		["addLocalPool"] = {["func"]=cmd_addLocalPool, ["isRet"]=false},
		["catchDragon"] = {["func"]=cmd_catchDragon, ["isRet"]=true},
		["dragonInfo"] = {["func"]=cmd_dragonInfo, ["isRet"]=true},
		
		["tableActive"] = {["func"]=cmd_tableActive, ["isRet"]=true},
		["tableNotActive"] = {["func"]=cmd_tableNotActive, ["isRet"]=false},
		
	},
	-- CAttemperEngineSink::OnAttemperEngineStart
	initFunc = function()
		resourceResolver.init()
		
		_LS_dragonAddress = cluster.query("loginServer", "LS_model_dragon")
		local temp = cluster.call("loginServer", _LS_dragonAddress, "getPoolInfo")
		_data.status = temp.status
		_data.pool = temp.pool
		_data.maxPool = temp.maxPool
		_data.localPool = 0
		_serverConfig = skynet.call(addressResolver.getAddressByServiceName("GS_model_serverStatus"), "lua", "getServerData")
		if not _serverConfig then
			error("server config not initialized")
		end
		
		local mysqlConn = addressResolver.getMysqlConnection()
		local sql = "select * from `QPAccountsDB`.`SystemStatusInfo` where StatusName='RevenueRateSave'"
		local rows = skynet.call(mysqlConn, "lua", "query", sql)
		local _memberOrderConfig = {}
		_memberOrderConfig[0] = tonumber(rows[1].StatusValue)
		sql = "select * from `QPAccountsDB`.`SystemStatusInfo` where StatusName='RevenueRateSaveMember1'"
		rows = skynet.call(mysqlConn, "lua", "query", sql)
		_memberOrderConfig[1] = tonumber(rows[1].StatusValue)
		sql = "select * from `QPAccountsDB`.`SystemStatusInfo` where StatusName='RevenueRateSaveMember2'"
		rows = skynet.call(mysqlConn, "lua", "query", sql)
		_memberOrderConfig[2] = tonumber(rows[1].StatusValue)
		sql = "select * from `QPAccountsDB`.`SystemStatusInfo` where StatusName='RevenueRateSaveMember3'"
		rows = skynet.call(mysqlConn, "lua", "query", sql)
		_memberOrderConfig[3] = tonumber(rows[1].StatusValue)
		sql = "select * from `QPAccountsDB`.`SystemStatusInfo` where StatusName='RevenueRateSaveMember4'"
		rows = skynet.call(mysqlConn, "lua", "query", sql)
		_memberOrderConfig[4] = tonumber(rows[1].StatusValue)
		sql = "select * from `QPAccountsDB`.`SystemStatusInfo` where StatusName='RevenueRateSaveMember5'"
		rows = skynet.call(mysqlConn, "lua", "query", sql)
		_memberOrderConfig[5] = tonumber(rows[1].StatusValue)
		
		for i=1, _serverConfig.TableCount do
			local tbAddr = skynet.newservice("GS_model_tableFrame")
			skynet.call(tbAddr, "lua", "initialize", i, _serverConfig, _memberOrderConfig)
			_tableHash[i] = {addr=tbAddr, state={isLocked=false, isStarted=false, sitCount=0}}
		end		
	
		local GS_EVENT = require "define.eventGameServer"
		skynet.send(addressResolver.getAddressByServiceName("eventDispatcher"), "lua", "addEventListener", GS_EVENT.EVT_GS_LOGIN_SUCCESS, skynet.self(), "onEventLoginSuccess")
		
		timerUtility.start(GS_CONST.TIMER.TICK_STEP)
		timerUtility.setInterval(uploadDragonPoolAdd, 5)
	end,
}

commonServiceHelper.createService(conf)

