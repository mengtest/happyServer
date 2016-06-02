local skynet = require "skynet"
local serviceHelper = require "serviceHelper"
local xLog = require "xLog"


local mysqlService = nil

local _data = 
{
	reward = {50,100,150,200,250,300}
}
local function loginReward(agent, userId)
	local temp = math.random(#_data.reward)
	skynet.call(mysqlService, "lua", "query", string.format("update s_user_score set gold=gold+%d where id=%d", _data.reward[temp], userId))
	skynet.call(agent, "lua", "forward", 0x000101, {gold=_data.reward[temp]})
end

local REQUEST = {
	[0x000100] = function(agent, pbObj, attr)
		xLog("into ls_login")
		local re = {}
		local account = pbObj.account
		local password = pbObj.password
		local aid = 0
		local userId = 0
		local backAccount = nil
		local name = nil
		local lastLoginTime = 0
		if password then -- 账号登录
			local sql = string.format("select id from s_account where account='%s' and password='%s'", account, password)
			local rows = skynet.call(mysqlService, "lua", "query", sql)
			if rows[1] == nil then -- 已存在
				re.code = 1
				re.msg = "用户名或密码错误"
				return 0x000100, re
			end
			backAccount = account
			aid = tonumber(rows[1].id)
			rows = skynet.call(mysqlService, "lua", "query", string.format("select id,name,UNIX_TIMESTAMP(loginTime) as loginTime from s_user where accountId=%d", aid))
			userId = tonumber(rows[1].id)
			name = rows[1].name
			lastLoginTime = tonumber(rows[1].loginTime)
		else
			local rows = skynet.call(mysqlService, "lua", "query", string.format("select id,account from s_account where uuid='%s'", account))
			if rows[1] == nil then -- 新玩家
				rows = skynet.call(mysqlService, "lua", "query", string.format("insert into s_account set uuid='%s',registerUuid='%s',registerTime=NOW(),lastLoginTime=NOW()", account, account))
				aid = tonumber(rows.insert_id)
				
				rows = skynet.call(mysqlService, "lua", "query", string.format("insert into s_user set accountId=%d,name='%s',loginTime=NOW()", aid, account))
				userId = tonumber(rows.insert_id)
				name = account
				skynet.call(mysqlService, "lua", "query", string.format("insert into s_user_score set id=%d,gold=300", userId))
			else
				aid = tonumber(rows[1].id)
				backAccount = rows[1].account
				
				rows = skynet.call(mysqlService, "lua", "query", string.format("select id,name,UNIX_TIMESTAMP(loginTime) as loginTime from s_user where accountId=%d", aid))
			
				userId = tonumber(rows[1].id)
				name = rows[1].name
			lastLoginTime = tonumber(rows[1].loginTime)
			end
		end
		local lastDate = os.date("%Y%m%d", lastLoginTime)
		local nowDate = os.date("%Y%m%d", os.time())
		skynet.call(mysqlService, "lua", "query", string.format("update s_user set loginTime=NOW() where id=%d", userId))
		rows = skynet.call(mysqlService, "lua", "query", string.format("select gold from s_user_score where id=%d", userId))
		skynet.call(agent, "lua", "setAttr", {aid = aid, userId = userId, gold = tonumber(rows[1].gold)})
		re.userId = userId
		re.name = name
		re.gold = tonumber(rows[1].gold)
		re.account = backAccount 
		
		skynet.call(agent, "lua", "forward", 0x000100, re)
		if lastDate ~= nowDate then
			loginReward(agent, userId)
		end
		return
	end,
	[0x000101] = function(agent, pbObj, attr)
		local rows = skynet.call(mysqlService, "lua", "query", string.format("select fqzsId from r_fqzs where userId = %d order by beginTime desc limit 8", attr.userId))
		
		local re = {}
		if rows[1] then
			for _,v in pairs(rows) do
				table.insert(re, tonumber(v.fqzsId))
			end
		end
		
		return 0x020102, {history = re}
	end,
	[0x000102] = function(agent, pbObj, attr) -- 账号注册
		local re = {}
		local account = pbObj.account
		local password = pbObj.password
		if string.len(account)<3 or string.len(account)>30 then
			re.code = 1
			re.msg = "账号过长或过短"
			return 0x000102, re
		end
		if string.len(password)<3 or string.len(password)>30 then
			re.code = 1
			re.msg = "密码过长或过短"
			return 0x000102, re
		end
		local name = pbObj.name
		if pbObj.uuid == nil then
			re.code = 1
			re.msg = "设备号错误"
			return 0x000102, re
		end
		
		local sql = string.format("select num from s_uuid_num where uuid='%s'", pbObj.uuid)
		local rows = skynet.call(mysqlService, "lua", "query", sql)
		if rows[1] ~= nil and tonumber(rows[1].num) >= 5 then -- 已存在
			re.code = 1
			re.msg = "该设备注册数量已达上限"
			return 0x000102, re
		end
		
		local sql = string.format("select id from s_account where account='%s'", account)
		local rows = skynet.call(mysqlService, "lua", "query", sql)
		if rows[1] ~= nil then -- 已存在
			re.code = 1
			re.msg = "该账号已被注册"
			return 0x000102, re
		end
		
		rows = skynet.call(mysqlService, "lua", "query", string.format("select id from s_user where name='%s'", name))
		if rows[1] ~= nil then -- 已存在
			re.code = 1
			re.msg = "该昵称已被注册"
			return 0x000102, re
		end
		
		
		sql = string.format("insert into s_account (account,password,registerUuid,registerTime,lastLoginTime) values ('%s','%s','%s',NOW(),NOW())"
				, account, password, pbObj.uuid)
		rows = skynet.call(mysqlService, "lua", "query", sql)
		
		local aid = tonumber(rows.insert_id)
		if not aid then
			re.code = 1
			re.msg = "注册失败"
			return 0x000102, re
		end 
		local userId = 0
		
		rows = skynet.call(mysqlService, "lua", "query", string.format("insert into s_user set accountId=%d,name='%s',loginTime=NOW()", aid, name))
		userId = tonumber(rows.insert_id)
		skynet.call(mysqlService, "lua", "query", string.format("insert into s_user_score set id=%d,gold=300", userId))
		
		
		sql = string.format("insert into s_uuid_num values('%s',1) on duplicate key update num=num+1", pbObj.uuid)
		skynet.call(mysqlService, "lua", "query", sql)
		rows = skynet.call(mysqlService, "lua", "query", string.format("select gold from s_user_score where id=%d", userId))
		skynet.call(agent, "lua", "setAttr", {aid = aid, userId = userId, gold = tonumber(rows[1].gold)})
		re.code = 0
		re.backLogin = {}
		re.backLogin.userId = userId
		re.backLogin.name = pbObj.name
		re.backLogin.gold = tonumber(rows[1].gold)
		re.backLogin.account = account
		
		skynet.call(agent, "lua", "forward", 0x000102, re)
		loginReward(agent, userId)
		return
	end,
	[0x000103] = function(agent, pbObj, attr) -- 绑定账号
		local re = {}
		local account = pbObj.account
		local password = pbObj.password
		if string.len(account)<3 or string.len(account)>30 then
			re.code = 1
			re.msg = "账号过长或过短"
			return 0x000103, re
		end
		if string.len(password)<3 or string.len(password)>30 then
			re.code = 1
			re.msg = "密码过长或过短"
			return 0x000103, re
		end
		local name = pbObj.name
		
		local sql = string.format("select id from s_account where account='%s'", account)
		local rows = skynet.call(mysqlService, "lua", "query", sql)
		if rows[1] ~= nil then -- 已存在
			re.code = 1
			re.msg = "该账号已被注册"
			return 0x000103, re
		end
	
		local aid = attr.aid
		
		sql = string.format("select account from s_account where id=%d", aid)
		rows = skynet.call(mysqlService, "lua", "query", sql)
		if rows[1] == nil or rows[1].account ~= nil then -- 已存在
			re.code = 1
			re.msg = "该账号已被绑定"
			return 0x000103, re
		end
		
		sql = string.format("update s_account set account='%s',password='%s' where id=%d", account, password, aid)
		skynet.call(mysqlService, "lua", "query", sql)
		re.code = 0
		
		return 0x000103, re
	end,
}

local conf = {
	loginCheck = false,
	protocalHandlers = REQUEST,
	initFunc = function()
		mysqlService = skynet.queryservice("mysqlConnect")
		math.randomseed(tostring(os.time()):reverse():sub(1, 6))
		math.random()
	end,
}

serviceHelper.create(conf)