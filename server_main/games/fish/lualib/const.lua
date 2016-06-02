
local TIMER  = {
	build_fish = 1,		-- 创建鱼
	normal_scene = 250,	-- 普通场景持续时间
	TICKSPAN_CLEAR_TRACE = 60,
	TICKSPAN_WRITE_SCORE = 66,
	scene_over = 6,		-- 龙宫结束
	upload_pool = 2,	-- 龙宫结束
	TICKSPAN_FREEZE_BOMB = 10,
	TICKSPAN_VOLCANO_STORE_NET_WIN = 120,
}

local ANDROID_TIMER = {
	TICK_STEP = 25,
	TICKSPAN_SWITCH_SCENE_WAIT = 32,
}

local scene = {
	[1] = {--宝箱
		fishList = {{45,4},{44,30}},	--鱼列表
		duration = 50,					--持续时间(秒)
	},
	[2] = {
		fishList = {{17,8},{18,1}},		--鱼列表
		duration = 50,					--持续时间(秒)
	},
	[3] = {
		fishList = {{17,1},{18,1},{19,1},{20,1}},	--鱼列表
		duration = 50,					--持续时间(秒)
	},
	[4] = {
		fishList = {{40,1}},			--鱼列表
		duration = 50,					--持续时间(秒)
	},
	[5] = {--龙宫
		fishList = {{46,1}},			--鱼列表
		duration = 68,					--持续时间(秒)/后30秒有效（程序里配置）
	},
}
local sceneList = {2,3,4}		--循环场景id

local SYSTEM_SCORE_POOL_OPERATION = {
	SSPO_DO_NOT_CHANGE_VOLCANO = 0x01,
}

local PATH_TYPE = {
	PT_SINGLE = "pt_single",
	PT_PIPELINE = "pt_pipeline",
}

local ANDROID_TYPE = {
	AT_RANDOM = 0,
	AT_BIGTARGET = 1,
}

local android = {
	speed = { --子弹速度(每秒发射数量)
		[0] = 4,
		[1] = 5,
		[2] = 6,
		[3] = 7,
		[4] = 8,
		[5] = 10,
	},
	angleType = {
		[1] = {20,45},
		[2] = {18,56},
		[3] = {6,28},
		[4] = {4,20},
		[5] = {24,60},
	}
}

return {
	TIMER = TIMER,
	ANDROID_TIMER = ANDROID_TIMER,
	ANDROID_TYPE = ANDROID_TYPE,
	scene = scene,
	sceneList = sceneList,
	SYSTEM_SCORE_POOL_OPERATION = SYSTEM_SCORE_POOL_OPERATION,
	PATH_TYPE = PATH_TYPE,
	
	fishLiveTime = 9000,			--鱼存活时间(1/100秒)
	luck_init = 0x1003f3fffff,		--好运鱼初始化，按位
	android = android,
	dragonMaxBullet = 4,			--龙宫每秒最大子弹数量
	dragonGrow = 1.5,				--龙宫概率增长系数（2秒一次）
}

