require "utility.string"
local skynet = require "skynet"
local commonServiceHelper = require "serviceHelper.common"
local addressResolver = require "addressResolver"

local _logonMessageList
local _exchangeMessageList

local function reloadExchangeMessage()
	local sql = "SELECT `MessageString` FROM `QPPlatformDB`.`SystemMessage` WHERE `Type` & 0x01 = 0x01 ORDER BY ID DESC LIMIT 20"
	local dbConn = addressResolver.getMysqlConnection()
	local rows = skynet.call(dbConn, "lua", "query", sql)
	local list = {}	
	if type(rows)=="table" then
		for _, row in ipairs(rows) do
			table.insert(list, row.MessageString)
		end
	end
	_exchangeMessageList = list
end

local function reloadLogonMessage()
	local sql = "SELECT `ID`, `Type`, `ServerRange`, `MessageString`, UNIX_TIMESTAMP(`StartTime`) as \"StartTime\" FROM `QPAccountsDB`.`LogonSystemMessage` WHERE `Type`<>0 AND `StartTime`<NOW() AND NOW()<`EndTime` ORDER BY ID DESC LIMIT 10"
	local dbConn = addressResolver.getMysqlConnection()
	local rows = skynet.call(dbConn, "lua", "query", sql)
	local list = {}
	if type(rows)=="table" then
		for _, row in ipairs(rows) do
			local item = {
				id = tonumber(row.ID),
				type = tonumber(row.Type),
				msg = row.MessageString,
				startTime = tonumber(row.StartTime),
				sendAllServer = false,
				serverIDHash = {}
			}
			
			local tokens = row.ServerRange:split(",")
			for _, v in ipairs(tokens) do
				local serverID = tonumber(v)
				if serverID then
					if serverID==0 then
						item.sendAllServer = true
						break
					else
						item.serverIDHash[serverID] = true
					end
				end
			end
			table.insert(list, item)
		end
	end
	_logonMessageList = list
end

local function sendSystemLogonMessage(agent, kindID)
	local logonMessage = {list={}}
	for _, item in ipairs(_logonMessageList) do
		if item.sendAllServer or item.serverIDHash[kindID] then
			local pbItem = {
				id = item.id,
				type = item.type,
				startTime = item.startTime,
				msg = item.msg
			}
			table.insert(logonMessage.list, pbItem)
		end
	end
	
	if #(logonMessage.list) > 0 then
		skynet.send(agent, "lua", "forward", 0x000300, logonMessage)	
	end
end

local function sendUserLogonMessage(agent, userID)
	local sql = string.format(
		"call QPAccountsDB.sp_load_user_logon_message(%d)",
		userID
	)
	local mysqlConn = addressResolver.getMysqlConnection()
	local msgList = skynet.call(mysqlConn, "lua", "call", sql)
	
	if #(msgList) > 0 then
		skynet.send(agent, "lua", "forward", 0x000301, {list=msgList})
	end
end

local function cmd_onEventLoginSuccess(data)
	sendSystemLogonMessage(data.agent, data.kindID)
	sendUserLogonMessage(data.agent, data.userID)
end

local function cmd_sendExchangeMessage(agent)
	skynet.send(agent, "lua", "forward", 0x000302, {msg=_exchangeMessageList})
end

local conf = {
	methods = {
		["onEventLoginSuccess"] = {["func"]=cmd_onEventLoginSuccess, ["isRet"]=false},
		["sendExchangeMessage"] = {["func"]=cmd_sendExchangeMessage, ["isRet"]=false},
	},
	initFunc = function()
		local eventList = require "define.eventLoginServer"
		skynet.send(addressResolver.getAddressByServiceName("eventDispatcher"), "lua", "addEventListener", eventList.EVT_LS_LOGIN_SUCCESS, skynet.self(), "onEventLoginSuccess")
		
		skynet.fork(function()
			while true do
				reloadExchangeMessage()
				reloadLogonMessage()
				skynet.sleep(60000)
			end
		end)
	end,
}

commonServiceHelper.createService(conf)