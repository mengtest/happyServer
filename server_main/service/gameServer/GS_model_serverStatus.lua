local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local GS_CONST = require "define.gsConst"
local GS_EVENT = require "define.eventGameServer"
local commonServiceHelper = require "serviceHelper.common"
local addressResolver = require "addressResolver"
local timerUtility = require "utility.timer"

local _sign
local _data
local _matchOption
local _LS_serverManagerAddress

local function populateMatchOption(serverID)

	local sql = string.format("call QPPlatformDB.sp_load_match_option(%d)", serverID)
	local dbConn = addressResolver.getMysqlConnection()
	local rows = skynet.call(dbConn, "lua", "call", sql)
	local row = rows[1]
	
	if not row then
		error(string.format("error loading match option for serverID=%d", serverID))
	end
	
	_matchOption = {
		serverID = tonumber(row.ServerID),
		name = row.MatchName,
		startHour = tonumber(row.MatchStartHour),
		startMinute = tonumber(row.MatchStartMinute),
		endHour = tonumber(row.MatchEndHour),
		endMinute = tonumber(row.MatchEndMinute),
		firstHour = tonumber(row.FirstMatchHour),
		firstMinute = tonumber(row.FirstMatchMinute),
		duration = tonumber(row.MatchDuration),
		interval = tonumber(row.MatchInterval),
		fee = tonumber(row.MatchFee),
		initScore = tonumber(row.MatchInitScore),
		awardMinScore = tonumber(row.MatchAwardMinScore),
		awardList = {}
	}

	for i=1,1000 do
		local rankColumn = string.format("Rank%d", i)
		local goldColumn = string.format("Gold%d", i)
		local medalColumn = string.format("Medal%d", i)
		local expColumn = string.format("Exp%d", i)
		
		if row[rankColumn]==nil then
			break
		end
		
		table.insert(_matchOption.awardList, {
			rank = row[rankColumn],
			gold = row[goldColumn],
			medal = row[medalColumn],
			exp = row[expColumn],
		})
	end
end

-- CServiceUnits::RectifyServiceParameter
local function rectifyServiceParameter()
	--占位调整
	if _data.ChairPerTable == GS_CONST.MAX_CHAIR then
		_data.ServerRule = _data.ServerRule | GS_CONST.SERVER_RULE.SR_ALLOW_ANDROID_SIMULATE
	end
	
	--作弊模式
	if (_data.DistributeRule & GS_CONST.DISTRIBUTE.ALLOW)~=0 then
		--设置反作弊
		_data.ServerRule = _data.ServerRule | GS_CONST.SERVER_RULE.SR_ALLOW_AVERT_CHEAT_MODE
		
		_data.MinDistributeUser = math.max(_data.MinDistributeUser, _data.ChairPerTable)
		if _data.MaxDistributeUser ~= 0 then
			_data.MaxDistributeUser = math.max(_data.MaxDistributeUser, _data.MinDistributeUser)
		end
	end
	
	
	if (_data.ServerType & GS_CONST.GAME_GENRE.GOLD) ~= 0 then
		--游戏记录
		_data.ServerRule = _data.ServerRule | GS_CONST.SERVER_RULE.SR_RECORD_GAME_SCORE
		_data.ServerRule = _data.ServerRule | GS_CONST.SERVER_RULE.SR_IMMEDIATE_WRITE_SCORE
		
		--最小积分
		_data.MinTableScore = _data.MinTableScore + _data.ServiceScore
	end
	
	--限制调整
	if _data.MaxEnterScore ~= 0 then
		_data.MaxEnterScore = math.max(_data.MaxEnterScore, _data.MinTableScore)
	end
	
	--挂接设置
	if _data.SortID == 0 then
		_data.SortID = 500
	end
	
	_data.MaxPlayer = _data.TableCount * _data.ChairPerTable
	
	-- TODO
	--_data = skynet.call(addressResolver.getAddressByServiceName("GS_model_matchManager"), "lua", "rectifyServiceOption", _data)
end

local function doRegister(onlineCount)
	_sign = cluster.call("loginServer", _LS_serverManagerAddress, "gs_registerServer", {
		kindID = _data.KindID,
		nodeID = _data.NodeID,
		sortID = _data.SortID,
		serverID = _data.ServerID,
		serverIP = _data.ServerAddr,
		serverPort = _data.ServerPort,
		serverType = _data.ServerType,
		serverName = _data.ServerName,
		onlineCount = onlineCount,
		fullCount = _data.ChairPerTable * _data.TableCount,
		cellScore = _data.CellScore,
		maxEnterScore = _data.MaxEnterScore,
		minEnterScore = _data.MinEnterScore,
		minEnterMember = _data.MinEnterMember,
		maxEnterMember = _data.MaxEnterMember,
	})
	
	if _matchOption then
		cluster.call("loginServer", _LS_serverManagerAddress, "gs_registerMatch", _sign, _data.KindID, _matchOption)
	end	
	
	skynet.send(addressResolver.getAddressByServiceName("eventDispatcher"), "lua", "dispatch", GS_EVENT.EVT_GS_SERVER_REGISTER_SUCCESS, {serverID=_data.ServerID, sign=_sign})
end


local function registerServer(onlineCount)
	local isSuccess, errMsg = pcall(doRegister, onlineCount)
	if not isSuccess then
		skynet.error(string.format("%s: 注册游戏服务器失败, 退出, %s", SERVICE_NAME, tostring(errMsg)))
		skynet.yield()
		skynet.abort()
	end
end

local function reportToLoginServer()
	local onlineCount = skynet.call(addressResolver.getAddressByServiceName("GS_model_userManager"), "lua", "getUserItemCount")
	if _sign==nil then
		registerServer(onlineCount)
	else
		local isSuccess, isServerExist = pcall(cluster.call, "loginServer", _LS_serverManagerAddress, "gs_onlineReport", _sign, _data.ServerID, onlineCount)
		if isSuccess then
			if not isServerExist then
				registerServer(onlineCount)
			end
		else
			skynet.error(string.format("%s: 与登录服务器失去连接", SERVICE_NAME))
		end
	end
end

local function cmd_getServerData()
	return _data
end

local function cmd_start(serverID)
	local sql = string.format("call QPPlatformDB.sp_load_server_config(%d)", serverID)
	local mysqlConn = addressResolver.getMysqlConnection()
	local rows = skynet.call(mysqlConn, "lua", "call", sql)	
	
	if type(rows)=="table" and #rows == 1 then
		if tonumber(rows[1].retCode)==0 then
			_data=rows[1]
			_data.retCode = nil
			_data.retMsg = nil
		else
			skynet.error(string.format("%s: 加载游戏房间配置失败, 退出: %s", SERVICE_NAME, rows[1].retMsg))
			skynet.yield()
			skynet.abort()
		end
	end
	
	
	for k, v in pairs(_data) do
		if k ~= "ServerName" and k ~= "ServerAddr" and k~="KindName" and k~="NodeName" then
			_data[k] = tonumber(v)
		end
	end

	rectifyServiceParameter()
	
	if (_data.ServerType & GS_CONST.GAME_GENRE.MATCH) ~= 0 then
		populateMatchOption(serverID)
	end
	
	local notifyInterval, notifyIntervalTick
	notifyInterval = tonumber(skynet.getenv("serverStatusNotifyInterval"))
	if not notifyInterval or notifyInterval<=0 then
		error(string.format("invalid notifyInterval: %s", tostring(notifyInterval)))
	end
	notifyIntervalTick = notifyInterval * 100

	timerUtility.start(notifyIntervalTick)
	timerUtility.setInterval(reportToLoginServer, 1)
end

local function cmd_serverBroadCast(targetKindID, targetNodeID, targetServerID, msgNo, msgBody)
	cluster.call("loginServer", _LS_serverManagerAddress, "gs_relay", _data.ServerID, _sign, targetKindID, targetNodeID, targetServerID, msgNo, msgBody)
end

local conf = {
	methods = {
		["getServerData"] = {["func"]=cmd_getServerData, ["isRet"]=true},
		["start"] = {["func"]=cmd_start, ["isRet"]=true},
		["serverBroadCast"] = {["func"]=cmd_serverBroadCast, ["isRet"]=false},
	},
	initFunc = function()
		_LS_serverManagerAddress = cluster.query("loginServer", "LS_model_serverManager")
	end,
}

commonServiceHelper.createService(conf)


