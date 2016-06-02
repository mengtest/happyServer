local skynet = require "skynet"
local commonServiceHelper = require "serviceHelper.common"
local addressResolver = require "addressResolver"
local timerUtility = require "utility.timer"
local signUtility = require "utility.sign"
local LS_EVENT = require "define.eventLoginServer"

local _timeoutThresholdTick
local _kindHash = {}
local _nodeHash = {}
local _serverHash = {}
local _serverMatchOption = {}
local defenseList = nil

local function sortIDComparer(a, b)
	return a.sortID < b.sortID;
end

local function sortBySortID(idList, id2Item)
	--用户处理idList中可能的重复
	local idHash = {}
	
	local itemList = {}
	for _, id in ipairs(idList) do
		if id2Item[id] and not idHash[id] then
			idHash[id] = true
			table.insert(itemList, id2Item[id])
		end
	end
	table.sort(itemList, sortIDComparer)
	local dstIDList = {}
	for _, item in ipairs(itemList) do
		table.insert(dstIDList, item.id)
	end
	return dstIDList
end

local function deleteServer(serverItem)
	local shallDeleteNode = false
	local shallDeleteKind = false

	local nodeItem = _nodeHash[serverItem.nodeID]
	if #(nodeItem.serverIDList) == 1 and nodeItem.serverIDList[1] == serverItem.id then
		shallDeleteNode = true
	end
	
	local kindItem = _kindHash[serverItem.kindID]
	if shallDeleteNode then
		if #(kindItem.nodeIDList) == 1 and kindItem.nodeIDList[1] == serverItem.nodeID then
			shallDeleteKind = true
		end
	end
	
	skynet.error(string.format("delete server %s", _serverHash[serverItem.id].name))
	_serverMatchOption[serverItem.id] = nil
	_serverHash[serverItem.id] = nil
	
	if shallDeleteNode then
		skynet.error(string.format("delete node %s", nodeItem.name))
		_nodeHash[serverItem.nodeID] = nil
	else
		nodeItem.onlineCount = nodeItem.onlineCount - serverItem.onlineCount
		nodeItem.fullCount = nodeItem.fullCount - serverItem.fullCount
		nodeItem.serverIDList = sortBySortID(nodeItem.serverIDList, _serverHash)	
	end	
	
	
	if shallDeleteKind then
		skynet.error(string.format("delete kind %s", kindItem.name))
		_kindHash[serverItem.kindID] = nil
	else
		kindItem.onlineCount = kindItem.onlineCount - serverItem.onlineCount
		kindItem.fullCount = kindItem.fullCount - serverItem.fullCount
		kindItem.nodeIDList = sortBySortID(kindItem.nodeIDList, _nodeHash)
	end
	skynet.send(addressResolver.getAddressByServiceName("eventDispatcher"), "lua", "dispatch", LS_EVENT.EVT_LS_GAMESERVER_DISCONNECT, {serverID=serverItem.id})
end

local function checkServerTick()
	local nowTick = skynet.now()
	for serverID, serverItem in pairs(_serverHash) do
		if nowTick - serverItem.tick > _timeoutThresholdTick then
			deleteServer(serverItem)
		end
	end
end

local function sendNodeServerList(kindID, agent)
	local nodeList = {list={}}

	local kindItem = _kindHash[kindID] 
	if kindItem then
		for _, nodeID in ipairs(kindItem.nodeIDList) do		
			local nodeItem = _nodeHash[nodeID]
			
			local pbListItem={
				nodeID=nodeItem.id,
				kindID=nodeItem.kindID,
				name=nodeItem.name,
				onlineCount=nodeItem.onlineCount,
				fullCount=nodeItem.fullCount,
				serverList={}
			}
			
			for _, serverID in ipairs(nodeItem.serverIDList) do
				local serverItem = _serverHash[serverID]
				if serverItem then
					table.insert(pbListItem.serverList, {
						serverID=serverItem.id,
						serverType=serverItem.type,
						serverAddr=serverItem.ip,
						serverPort=serverItem.port,
						serverName=serverItem.name,
						cellScore=serverItem.cellScore,
						maxEnterScore=serverItem.maxEnterScore,
						minEnterScore=serverItem.minEnterScore,
						minEnterMember=serverItem.minEnterMember,
						maxEnterMember=serverItem.maxEnterMember,
						onlineCount = serverItem.onlineCount,
						fullCount = serverItem.fullCount,
					})
				end
			end
			table.insert(nodeList.list, pbListItem)			
		end
	end

	skynet.send(agent, "lua", "forward", 0x000200, nodeList)
end

local function sendMatchOption(kindID, agent)
	local configList={list={}}
	for serverID, item in pairs(_serverMatchOption) do
		if item.kindID == kindID then
			table.insert(configList.list, item.data)
		end
	end
	
	if #(configList.list) > 0 then
		skynet.send(agent, "lua", "forward", 0x000201, configList)
	end
end

local function getServerIDListByNodeID(nodeID)
	local nodeItem = _nodeHash[nodeID]
	if nodeItem then
		if #(nodeItem.serverIDList) > 0 then
			return nodeItem.serverIDList
		end
	end
end

local function getServerIDListByKindID(kindID)
	local kindItem = _kindHash[kindID]
	if kindItem then
		local list = {}
		for _, nodeID in ipairs(kindItem.nodeIDList) do
			local nodeServerIDList = getServerIDListByNodeID(nodeID)
			if nodeServerIDList then
				for _, serverID in ipairs(nodeServerIDList) do
					table.insert(list, serverID)
				end
			end
		end
		
		if #list > 0 then
			return list
		end
	end
end


local function cmd_gs_registerServer(data)
--[[
data={
	kindID=,
	nodeID=,
	sortID=,
	serverID=,
	serverIP=,
	serverPort=,
	serverType=,
	serverName=,
	onlineCount=,
	fullCount=,
	cellScore=,
	maxEnterScore=,
	minEnterScore=,
	minEnterMember=,
	maxEnterMember=,
}
--]]
	if _serverHash[data.serverID] then
		error(string.format("服务器已经注册 serverID=%d", data.serverID))
	end

	local kindItem = _kindHash[data.kindID]
	local nodeItem = _nodeHash[data.nodeID]
	if not kindItem then
		local sql = string.format("select * from `QPPlatformDB`.`GameKindItem` where KindID=%d", data.kindID)
		local dbConn = addressResolver.getMysqlConnection()
		local rows = skynet.call(dbConn, "lua", "query", sql)
		if #rows ~= 1 then
			error(string.format("kindID=%d not found", data.kindID))
		end
		local row=rows[1]
		kindItem = {
			id = tonumber(row.KindID),
			name = row.KindName,
			onlineCount = 0,
			fullCount = 0,
			nodeIDList = {}
		}
	end
	
	if not nodeItem then
		local sql = string.format("select * from `QPPlatformDB`.`GameNodeItem` where NodeID=%d", data.nodeID)
		local dbConn = addressResolver.getMysqlConnection()
		local rows = skynet.call(dbConn, "lua", "query", sql)
		if #rows ~= 1 then
			error(string.format("nodeID=%d not found", data.nodeID))
		end
		local row=rows[1]
		nodeItem = {
			kindID = tonumber(row.KindID),
			id = tonumber(row.NodeID),
			name = row.NodeName,
			onlineCount = 0,
			fullCount = 0,
			sortID = tonumber(row.SortID),
			serverIDList = {}
		}
		_nodeHash[data.nodeID] = nodeItem
	end
	
	if not _kindHash[data.kindID] then
		_kindHash[data.kindID] = kindItem
	end
	
	local serverItem = {
		kindID = data.kindID,
		nodeID = data.nodeID,
		sortID = data.sortID,
		id = data.serverID,
		ip = data.serverIP,
		port = data.serverPort,
		name = data.serverName,
		type = data.serverType,
		cellScore = data.cellScore,
		maxEnterScore = data.maxEnterScore,
		minEnterScore = data.minEnterScore,
		minEnterMember = data.minEnterMember,
		maxEnterMember = data.maxEnterMember,
		onlineCount = data.onlineCount,
		fullCount = data.fullCount,
		tick = skynet.now(),
		sign = signUtility.getSign(),
	}
	_serverHash[data.serverID] = serverItem

	kindItem.onlineCount = kindItem.onlineCount + serverItem.onlineCount
	kindItem.fullCount = kindItem.fullCount + serverItem.fullCount
	nodeItem.onlineCount = nodeItem.onlineCount + serverItem.onlineCount
	nodeItem.fullCount = nodeItem.fullCount + serverItem.fullCount
	
	table.insert(kindItem.nodeIDList, data.nodeID)
	kindItem.nodeIDList = sortBySortID(kindItem.nodeIDList, _nodeHash)
	table.insert(nodeItem.serverIDList, data.serverID)
	nodeItem.serverIDList = sortBySortID(nodeItem.serverIDList, _serverHash)
	
	skynet.send(addressResolver.getAddressByServiceName("eventDispatcher"), "lua", "dispatch", LS_EVENT.EVT_LS_GAMESERVER_CONNECT, {serverID=serverItem.id, sign=serverItem.sign})
	return serverItem.sign
end

local function cmd_gs_registerMatch(sign, kindID, data)
	local serverItem = _serverHash[data.serverID]
	if serverItem and serverItem.sign==sign then
		_serverMatchOption[data.serverID] = {kindID=kindID, data=data}
	else
		error(string.format("注册比赛信息失败 serverID=%s", tostring(data.serverID)))
	end
end

local function cmd_gs_reportOnline(sign, serverID, onlineCount)
	--skynet.error("reprotOnline", serverID, onlineCount)
	local serverItem = _serverHash[serverID]
	if serverItem and serverItem.sign==sign then
		local oldServerOnlineCount = serverItem.onlineCount
		serverItem.onlineCount = onlineCount
		serverItem.tick = skynet.now()
		
		local nodeItem = _nodeHash[serverItem.nodeID]
		if nodeItem then
			nodeItem.onlineCount = nodeItem.onlineCount - oldServerOnlineCount + onlineCount
		end
		
		local kindItem = _kindHash[serverItem.kindID]
		if kindItem then
			kindItem.onlineCount = kindItem.onlineCount - oldServerOnlineCount + onlineCount
		end
		
		return true
	else
		return false
	end
end

local function cmd_gs_relay(sourceServerID, sign, targetKindID, targetNodeID, targetServerID, msgNo, msgBody)
	local sourceServerItem = _serverHash[sourceServerID]
	if not sourceServerItem or sourceServerItem.sign~=sign then
		error("服务器还没有注册")
	end
	
	
	if targetServerID then							--指定服务器
		if _serverHash[targetServerID] then
			skynet.send(addressResolver.getAddressByServiceName("LS_model_GSProxy"), "lua", "send", {targetServerID}, msgNo, msgBody)
		else
			skynet.error(string.format("找不到指定的服务器: targetServerID=%s, sourceServerID=%s", tostring(targetServerID), tostring(sourceServerID)))
		end
	elseif targetNodeID then						--指定节点
		local sidList = getServerIDListByNodeID(targetNodeID)
		if sidList then
			skynet.send(addressResolver.getAddressByServiceName("LS_model_GSProxy"), "lua", "send", sidList, msgNo, msgBody)
		else
			skynet.error(string.format("找不到指定的服务器: targetNodeID=%s, sourceServerID=%s", tostring(targetNodeID), tostring(sourceServerID)))
		end
		
	elseif targetKindID then						--指定游戏
		local sidList = getServerIDListByKindID(targetKindID)
		if sidList then
			skynet.send(addressResolver.getAddressByServiceName("LS_model_GSProxy"), "lua", "send", sidList, msgNo, msgBody)
		else
			skynet.error(string.format("找不到指定的服务器: targetKindID=%s, sourceServerID=%s", tostring(targetKindID), tostring(sourceServerID)))
		end
	else											--全部服务器
		local sidList = {}
		for serverID, _ in pairs(_serverHash) do
			table.insert(sidList, serverID)
		end
		
		if #sidList> 0 then
			skynet.send(addressResolver.getAddressByServiceName("LS_model_GSProxy"), "lua", "send", sidList, msgNo, msgBody)
		end
	end
end

local function cmd_reloadDefenseList()
	local t = skynet.getenv("defenseList")
	if t == nil then
		return
	end
	local f = io.open(skynet.getenv("defenseList"), "rb")
	if not f then
		return
	end
	local source = f:read "*a"
	f:close()
	defenseList = load(source)()
end

local function sendDefenseList(userId, pid, agent)
	local re = {}
	if defenseList then
		local sql = string.format("select totalPay from `QPTreasureDB`.`s_pay` where id=%d", userId)
		local dbConn = addressResolver.getMysqlConnection()
		local rows = skynet.call(dbConn, "lua", "query", sql)
		if rows[1] ~= nil then -- 充值玩家
			local pay = tonumber(rows[1].totalPay)
			for _,v in ipairs(defenseList.vipList) do
				if pay >= v[1] then
					re.ip = v[2]
					skynet.send(agent, "lua", "forward", 0x000299, re)
					return
				end
			end
		end
		for _,v in ipairs(defenseList.oldList) do -- 老玩家
			if pid <= v[1] then
				re.ip = v[2]
				skynet.send(agent, "lua", "forward", 0x000299, re)
				return
			end
		end
		
		sql = string.format("select param from `QPAccountsDB`.`s_user_record` where id=%d", userId)
		rows = skynet.call(dbConn, "lua", "query", sql)
		if rows[1] == nil or rows[1].param == 0 then -- 新玩家没有改炮和银行操作
			return
		end
		re.ip = defenseList.newList[tonumber(rows[1].param)]
		
		skynet.send(agent, "lua", "forward", 0x000299, re)
	end
end

local function cmd_onEventLoginSuccess(data)
	sendNodeServerList(data.kindID, data.agent)
	sendMatchOption(data.kindID, data.agent)
	sendDefenseList(data.userID,data.platformID,data.agent)
end

local function cmd_sendServerOnline(agent, serverIDList)
	local list = {}
	for _, serverID in ipairs(serverIDList) do
		local item = {serverID=serverID, onLineCount=0}
		local serverItem = _serverHash[serverID]
		if serverItem then
			item.onLineCount = serverItem.onlineCount
		end
		table.insert(list, item)
	end
	
	skynet.send(agent, "lua", "forward", 0x000202, {list=list})
end

local function cmd_getServerName(serverID)
	local item = _serverHash[serverID]
	if item then
		return string.format("%s-%s", _kindHash[item.kindID].name, _nodeHash[item.nodeID].name)
	else
		return "其他游戏"
	end
end

local conf = {
	methods = {
		["gs_registerServer"] = {["func"]=cmd_gs_registerServer, ["isRet"]=true},
		["gs_registerMatch"] = {["func"]=cmd_gs_registerMatch, ["isRet"]=true},
		["gs_onlineReport"] = {["func"]=cmd_gs_reportOnline, ["isRet"]=true},
		["gs_relay"] = {["func"]=cmd_gs_relay, ["isRet"]=true},
		
		["getServerName"] = {["func"]=cmd_getServerName, ["isRet"]=true},
		["sendServerOnline"] = {["func"]=cmd_sendServerOnline, ["isRet"]=false},
		["onEventLoginSuccess"] = {["func"]=cmd_onEventLoginSuccess, ["isRet"]=false},
		
		["getServerIDListByKindID"] = {["func"]=getServerIDListByKindID, ["isRet"]=true},
		["reloadDefenseList"] = {["func"]=cmd_reloadDefenseList, ["isRet"]=true},
		["sendDefenseList"] = {["func"]=sendDefenseList, ["isRet"]=false},
	},
	initFunc = function()		
		local tickerStep = tonumber(skynet.getenv("serverManagerTickerStep"))
		if not tickerStep or tickerStep<=0 then
			error(string.format("invalid tickerStep: %s", tostring(tickerStep)))
		end
		
		local timerInterval = tonumber(skynet.getenv("serverManagerTimerInterval"))	
		if not timerInterval or timerInterval<=0 then
			error(string.format("invalid timerInterval: %s", tostring(timerInterval)))
		end
		
		local timeoutThreshold = tonumber(skynet.getenv("serverManagerTimeoutThreshold"))	
		if not timeoutThreshold or timeoutThreshold<=0 then
			error(string.format("invalid timeoutThreshold: %s", tostring(timeoutThreshold)))
		end
		_timeoutThresholdTick = timeoutThreshold * 100
		
		skynet.send(addressResolver.getAddressByServiceName("eventDispatcher"), "lua", "addEventListener", LS_EVENT.EVT_LS_LOGIN_SUCCESS, skynet.self(), "onEventLoginSuccess")
		cmd_reloadDefenseList()
		timerUtility.start(tickerStep)
		timerUtility.setInterval(checkServerTick, timerInterval)
	end,
}

commonServiceHelper.createService(conf)
