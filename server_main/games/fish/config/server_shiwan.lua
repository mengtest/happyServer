return {
	volcano = {
        isEnable = false,
        activePoolThreshold = 20000000,
        activeFishMultiple = 20,
        giveRate = 0.4,
    },
    dragonPermillage = 0,
    jihuiyuTime = nil,						--机会鱼每隔出现的秒数(出现之后才重新计时)
    boxSceneInterval = 4,                                                 -- 每多少次鱼阵有一次宝箱鱼阵, nil不出宝箱鱼阵
    tryScore = 1000000,                                                             -- 试玩场坐下给多少钱
    minBroadCastScore = 10000000,
    minBroadCastPresent = 100000,                                      -- 播报最低牌子数
    scorePerPresent = 10,                                                   -- 奖牌价值
    scorePerPresentTry = 0.1,                                                       -- 试玩场牌子转换为金币系数
    presentName = "礼券",
    cannonMultiple = {
        min = 1000,
        max = 1000000,
    },
    bombRange = {                                                                   -- 局部炸弹的范围
        width = 400,
        height = 400,
    },
    fishHash = {
		[0]={name="fish1", speed=9, multiple=2, boundingBox={55,15}, probability=0.5},
		[1]={name="fish2", speed=9, multiple=2, boundingBox={60,25}, probability=0.5},
		[2]={name="fish3", speed=9, multiple=3, boundingBox={80,32}, probability=0.33333},
		[3]={name="fish4", speed=7, multiple=4, boundingBox={70,43}, probability=0.25},
		[4]={name="fish5", speed=7, multiple=5, boundingBox={80,54}, probability=0.2},
		[5]={name="fish6", speed=6, multiple=6, boundingBox={90,70}, probability=0.16666},
		[6]={name="fish7", speed=6, multiple=7, boundingBox={90,40}, probability=0.14285},
		[7]={name="fish8", speed=5, multiple=8, boundingBox={120,55}, probability=0.125},
		[8]={name="fish9", speed=5, multiple=9, boundingBox={150,47}, probability=0.11111},

		[9]={name="fish10", speed=5, multiple=10, boundingBox={110,112}, probability=0.1},
		[10]={name="fish11", speed=4, multiple=12, boundingBox={145,80}, probability=0.08333},
		[11]={name="fish12", speed=4, multiple=15, boundingBox={120,150}, probability=0.06666},
		[12]={name="fish13", speed=4, multiple=18, boundingBox={180,70}, probability=0.05555},
		[13]={name="fish14", speed=4, multiple=20, boundingBox={255,88}, probability=0.05},

		[14]={name="fish15", speed=4, multiple=25, boundingBox={180,180}, probability=0.04},
		[15]={name="fish16", speed=4, multiple=30, boundingBox={270,80}, probability=0.03333},
		[16]={name="fish17", speed=4, multiple=35, boundingBox={290,90}, probability=0.02857},
		[17]={name="鲨鱼", speed=4, multiple={40,120}, boundingBox={500,170}, probability=0.0125},
		[18]={name="大龙虾", speed=3, multiple={120,500}, boundingBox={400,100}, probability=0.002727777},

		[19]={name="富贵猪", speed=2, multiple=320, boundingBox={404,100}, probability=0.003125},
		[20]={name="大眼鱼", speed=2, multiple={40,300}, boundingBox={200,245}, probability=0.00588},
		[21]={name="定屏炸弹", speed=3, multiple=20, boundingBox={180,100}, probability=0.05},
		--[22]={name="局部炸弹", speed=3, multiple=250, boundingBox={140,140}, probability=0.004},
		[23]={name="超级炸弹", speed=1, multiple={1000,2000}, boundingBox={130,130}, probability=0.000667},

		[24]={name="大三元1", speed=4, multiple=22, boundingBox={340,130}, probability=0.04545},
		[25]={name="大三元2", speed=4, multiple=32, boundingBox={340,130}, probability=0.03125},
		[26]={name="大三元3", speed=4, multiple=32, boundingBox={340,130}, probability=0.03125},
		[27]={name="大四喜1", speed=4, multiple=20, boundingBox={460,130}, probability=0.05},
		[28]={name="大四喜2", speed=4, multiple=20, boundingBox={460,130}, probability=0.05},

		[29]={name="大四喜3", speed=4, multiple=40, boundingBox={460,130}, probability=0.025},
		[40]={name="美人鱼", speed=1, multiple=200, boundingBox={150,150}, probability=0.005},
		--[41]={name="金宝箱", speed=2, multiple={40,60}, boundingBox={150,150}, probability=0.006},
		--[42]={name="银宝箱", speed=2, multiple={10,30}, boundingBox={150,150}, probability=0.015},
		--[43]={name="铜宝箱", speed=2, multiple=10, boundingBox={150,150}, probability=0.03},

		[44]={name="小宝箱", speed=2, multiple=1, boundingBox={150,150}, probability=0.09},
		[45]={name="大宝箱", speed=2, multiple=5, boundingBox={150,150}, probability=0.0225},
        
        [46]={name="小金龙", speed=9, multiple=1, boundingBox={150,150}, probability=nil},
    },
    probabilityHash = {
    	--    probability*multiple
    	--   普通，绿钻，蓝钻，紫钻，金钻，皇冠
        [46]={0.00001, 0.000011, 0.000015, 0.00002, 0.00003, 0.00005},
    },
	bulletHash = {								-- kind:对应BulletKind name:描述 speed:子弹速度 netRadius:渔网的半径
		[0]={name="1炮筒", speed=20},
		[1]={name="2炮筒", speed=20},
		[2]={name="3炮筒", speed=20},
		[3]={name="4炮筒", speed=20},
		[4]={name="1炮筒能量炮", speed=30},
		[5]={name="2炮筒能量炮", speed=30},
		[6]={name="3炮筒能量炮", speed=30},
		[7]={name="4炮筒能量炮", speed=30},
	},
	
	-- 游戏人数对应的生成时间间隔(秒)
	singleBuildInterval = {
		smallFish={3,3,3,2,2,2,2,2},							-- 0-9
		mediumFish={4,4,4,3,3,3,3,3},							-- 10-16
		fish17={63,63,53,53,43,43,43,43},						-- 17
		fish18={113,113,103,103,93,93,93,93},					-- 18
		fish19={201,201,191,191,181,181,181,181},				-- 19
		fish20={107,107,97,97,91,91,91,91},						-- 20
		--bomb={143,143,139,139,139,139,131,131},
		superBomb={153,153,151,151,151,151,149,149},
		lockBomb={134,134,124,124,114,114,114,114},
		tripleDouble={148,148,138,138,128,128,128,128},			-- 24-26
		big4={197,197,187,187,177,177,177,177},					-- 27-29
		--fishKing={3400,3400,2900,2900,2300,2300,2300,2300},	-- 30-39
		--goldBox={2110,2110,2110,2110,2110,2110,2110,2110},	-- 41
		--silverBox={990,990,990,990,990,990,990,990},			-- 42
		--copperBox={430,430,430,430,430,430,430,430},			-- 43
		smallBox={60,60,60,60,60,60,60,60},						-- 44
		bigBox={180,180,180,180,180,180,180,180},				-- 45
	},
	pipelineBuildInterval = {
		pipeline1={63,63,53,53,43,43,43,43},
		pipeline2={107,107,97,97,91,91,91,91},
	},
	contributionRatio = {										-- 贡献度控制概率
		{value=-500, ratio=0.5},
		{value=-400, ratio=0.6},
		{value=-300, ratio=0.7},
		{value=-200, ratio=0.8},
		{value=-100, ratio=0.9},
		{value=-50, ratio=0.95},
	},
	pathType = {
		pt_single={min=1, max=80, intervalTicks=100},
		pt_pipeline={min=1, max=80, intervalTicks=2000},
	},
}
