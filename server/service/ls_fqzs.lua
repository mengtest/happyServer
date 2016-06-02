local skynet = require "skynet"
local serviceHelper = require "serviceHelper"
local xLog = require "xLog"

local mysqlService = nil
local _data = {
	info = nil,
	ranNum = 0,
	gameInfo = {}
}
local _config = {
	muti = 1,	--每注倍数
	gbs = 48,	--最小公倍数
}

local REQUEST = {
	[0x020100] = function(agent, pbObj, attr)
		local re = {}
		xLog("into ls_login")
		local chipInfo = pbObj.chipInfo
		if chipInfo == nil then
			re.code = -1
			re.msg = "当前没有下注"
			return 0x020100, re
		end
		local usedGold = 0
		for _,v in pairs(chipInfo) do
			usedGold = usedGold + v.num*_config.muti
		end
		if usedGold > attr.gold then
			re.code = -1
			re.msg = "金币不足"
			return 0x020100, re
		end
		
		local ran = math.random(_data.ranNum)
		
		for _,v in pairs(_data.info) do
			if v.gl then
				if ran <=v.gl then -- 中
					re.id = v.id
					re.no = math.random(v.num)
					break
				else
					ran = ran - v.gl
				end
			end
		end
		skynet.call(mysqlService, "lua", "query", 
			string.format("insert into r_fqzs (userId,fqzsId,beginTime) values(%d,%d,NOW())", attr.userId, re.id))
		
		local winGold = 0
		for _,v in pairs(chipInfo) do
			if v.num ~= 0 and v.id == re.id then
				winGold = winGold + _data.info[v.id].mutiple * v.num * _config.muti
				break
			end
		end
		
		local tp = _data.info[re.id].tp --1飞，2走
		for _,v in pairs(chipInfo) do
			if v.id == 109+tp then
				winGold = winGold + _data.info[v.id].mutiple * v.num * _config.muti
				break
			end
		end
		xLog("into:::"..usedGold..","..winGold..","..re.id)
		
		attr.gold = attr.gold - usedGold + winGold
		
		_data.gameInfo[attr.userId] = {winGold, 5} -- 可以比倍的金币
		skynet.call(mysqlService, "lua", "query", 
			string.format("update s_user_score set gold=gold+%d where id=%d", winGold-usedGold, attr.userId))
		skynet.call(agent, "lua", "setAttr", {gold = attr.gold})
		re.gold = attr.gold
		
		return 0x020100, re
	end,
	[0x020101] = function(agent, pbObj, attr)
		local re = {}
		if _data.gameInfo[attr.userId] == nil then
			re.code = -1
			re.msg = "无法猜大小"
			return 0x020101, re
		end
		local beginNum = _data.gameInfo[attr.userId][1]
		if beginNum and beginNum >= pbObj.useGold then
			if _data.gameInfo[attr.userId][2]<=0 then
				re.code = -1
				re.msg = "次数不足"
				return 0x020101, re
			end
			_data.gameInfo[attr.userId][2] = _data.gameInfo[attr.userId][2] - 1
			local ran = math.random(12)
			re.num = ran
			if (ran <=6 and pbObj.tp == 1) or (ran>7 and pbObj.tp ==2) then -- 猜对
				attr.gold = attr.gold + pbObj.useGold
				skynet.call(mysqlService, "lua", "query", 
					string.format("update s_user_score set gold=gold+%d where id=%d", pbObj.useGold, attr.userId))
				skynet.call(agent, "lua", "setAttr", {gold = attr.gold})
				re.gold = pbObj.useGold * 2
				_data.gameInfo[attr.userId][2] = pbObj.useGold * 2
			else
				attr.gold = attr.gold - pbObj.useGold
				skynet.call(mysqlService, "lua", "query", 
					string.format("update s_user_score set gold=gold+%d where id=%d", -pbObj.useGold, attr.userId))
				skynet.call(agent, "lua", "setAttr", {gold = attr.gold})
				re.gold = 0
				_data.gameInfo[attr.userId] = nil
			end
		else
			re.code = -1
			re.msg = "比倍金币非法"
		end
		return 0x020101, re
	end,
}

local conf = {
	loginCheck = true,
	protocalHandlers = REQUEST,
	initFunc = function()
		mysqlService = skynet.queryservice("mysqlConnect")
		
		local rows = skynet.call(mysqlService, "lua", "query", "select * from d_fqzs")
		_data.info = {}
		local temp = {}
		for _,v in pairs(rows) do
			temp = {}
			temp.id = tonumber(v.id)
			temp.tp = tonumber(v.tp)
			temp.mutiple = tonumber(v.mutiple)
			temp.num = tonumber(v.num)
			if temp.num ~= 0 then
				temp.gl = _config.gbs/tonumber(v.mutiple)
				_data.ranNum = _data.ranNum + temp.gl
			end
			_data.info[temp.id] = temp
		end
		
		math.randomseed(tostring(os.time()):reverse():sub(1, 6))
		math.random()
	end,
}

serviceHelper.create(conf)