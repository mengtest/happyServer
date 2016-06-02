local GS_LOGIN_CODE = {
	GLC_SUCCESS = 0,
	GLC_INVALID_SESSION = 1,
	GLC_LS_LOGIN_FIRST = 2,
	GLC_RETRY = 3,
}

local RELAY_MESSAGE_TYPE = {
	RMT_SYSTEM_MESSAGE = 0x20000000,
	RMT_BIG_TRUMPET = 0x20000001,
}

local LSNOTIFY_EVENT = {
	EVT_LSNOTIFY_USER_LOGIN_OTHER_SERVER = 0x10000000,
	EVT_LSNOTIFY_PAY_ORDER_CONFIRM = 0x10000001,
	dragonInfo = 0x10000002,		-- 龙宫开启
	dragonPoolAdd = 0x10000003,		-- 
	changeUserScore = 0x10000004,		-- 货币变更
}


local SYSTEM_MESSAGE_TYPE = {
	--类型掩码
	SMT_NORMAL 				= 0x0001,				--普通消息
	SMT_SYSTEM 				= 0x0002,				--系统消息
	SMT_POPUP 				= 0x0004,				--弹窗消息
	SMT_DRAGON_OPEN			= 0x0008,				--龙宫开启消息
	SMT_MIDDLE				= 0x0010,				--特殊消息
	
	--控制掩码
	SMT_CLOSE_ROOM 			= 0x0100,				--关闭房间
	SMT_CLOSE_GAME 			= 0x0200,				--关闭游戏
	SMT_CLOSE_LINK 			= 0x0400,				--中断连接
}

local DB_STATUS_MASK = {
	DSM_NULLITY						= 0x01,
	DSM_STUNDOWN					= 0x02,
	DSM_ISANDROID					= 0x04,
	DSM_MOORMACHINE					= 0x08,
	DSM_NOTFREESCORE				= 0x10,
}

local RELAY_MESSAG_MASK = 0x20000000
local LSNOTIFY_EVENT_MASK = 0x10000000

local message = {
	dragonOpen = "小金龙已经现身，请立即进入普通/豪华房间，当前宝藏已达%s",
	dragonOver = "恭喜 %s 玩家 %s 成功开启龙宫，夺得了 %s 大奖！",
	smallOpen = "龙宝箱已经出现，请立即进入普通/豪华房间，当前宝藏为%s",
	smallOver = "恭喜 %s 玩家 %s 成功开启龙宝箱，夺得了 %s 大奖！",
}

return {
	RELAY_MESSAGE_TYPE = RELAY_MESSAGE_TYPE,
	GS_LOGIN_CODE = GS_LOGIN_CODE,
	LSNOTIFY_EVENT = LSNOTIFY_EVENT,
	SYSTEM_MESSAGE_TYPE = SYSTEM_MESSAGE_TYPE,
	
	RELAY_MESSAG_MASK = RELAY_MESSAG_MASK,
	LSNOTIFY_EVENT_MASK = LSNOTIFY_EVENT_MASK,
	DB_STATUS_MASK = DB_STATUS_MASK,
	
	presentToMoney = 0.01,	-- 礼券换rmb(分)
	presentToGold = 20,	-- 礼券换金币
	message = message,
}

