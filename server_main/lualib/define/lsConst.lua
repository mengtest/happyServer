local LOGIN_CONTROL = {
	RETRY_INTERVAL_TICK = 30,
	RETRY_COUNT = 3,
	TIMEOUT_THRESHOLD_TICK=200,
	TIMEOUT_CHECK_INTERVAL_TICK = 100,
}
local timer  = {
	secondTick = 100,
}

local SESSION_CONTROL = {
	USER_ITEM_LIFE_TIME = 300,			-- 5 minute
	SESSION_LIFE_TIME = 10800,			-- 3 hours
	CHECK_INTERVAL = 600,				-- 10 minute
}

local USER_STATUS = {
	US_NULL 			= 0x00,								--没有状态
	US_LS 				= 0x01,								--登录服务器
	US_GS 				= 0x02,								--游戏服务器
	US_GS_OFFLINE 		= 0x03,								--游戏掉线
	US_LS_GS 			= 0x04,								--登录在线，游戏在线
	US_LS_GS_OFFLINE 	= 0x05,								--登录在线，游戏掉线
}

local freeScore = {
	limit = 5000,	--能够领取免费金币的条件<limit
	gold = 50000,	--每次领取获得的金币
	num = 1, 		--非vip可领次数
	vipNum = 3, 	-- vip可领次数
}

local dragonInfo = {
	state = 1,					-- 是否开启(0不开启，1开启)
	lastTime = 68,
	firstPool = 1000000000,			-- 初始奖池
	addPool = 100000000,			-- 每次结束增加
	
	smallPool = 50000000,		--小奖池每次金额
	smallPoolCondition = 100000000, --小奖池触发条件（<firstPool）
}

return {
	SESSION_CONTROL = SESSION_CONTROL,
	LOGIN_CONTROL = LOGIN_CONTROL,
	USER_STATUS = USER_STATUS,
	freeScore = freeScore,
	LOVELINESS_SCORE = 1000000, -- 1魅力所换金币的数量
	LOVELINESS_MEMBER = {0.01,0.01,0.005,0.005,0}, -- 会员对应的手续费
	dragonTickLater = 10, -- 龙宫开启前置时间（秒）
	dragonTickNow = 30, -- 龙宫开启持续时间（秒）
	dragonInfo = dragonInfo,
	timer = timer,
}