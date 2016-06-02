return {
	volcano = {
        isEnable = false,
        activePoolThreshold = 20000000,
        activeFishMultiple = 20,
        giveRate = 0.4,
    },
    dragonPermillage = 2,
    jihuiyuTime = {180, 240},						--机会鱼每隔出现的秒数(出现之后才重新计时), nil表示不出
    boxSceneInterval = 1,                                                   -- 每多少次鱼阵有一次宝箱鱼阵, nil不出宝箱鱼阵
    tryScore = 1000000,                                                             -- 试玩场坐下给多少钱
    minBroadCastScore = 10000000,
    minBroadCastPresent = 100000,                                    -- 播报最低牌子数
    scorePerPresent = 10,                                                   -- 奖牌价值
    scorePerPresentTry = 0.1,                                                       -- 试玩场牌子转换为金币系数
    presentName = "礼券",
    cannonMultiple = {
        min = 10000,
        max = 5000000,
    },
    bombRange = {                                                                   -- 局部炸弹的范围
        width = 400,
        height = 400,
    },
    fishHash = {
        [0]={name="fish1", speed=9, multiple=2, boundingBox={55,15}, probability=0.49},
        [1]={name="fish2", speed=9, multiple=2, boundingBox={60,25}, probability=0.49},
        [2]={name="fish3", speed=9, multiple=3, boundingBox={80,32}, probability=0.3266667},
        [3]={name="fish4", speed=7, multiple=4, boundingBox={70,43}, probability=0.245},
        [4]={name="fish5", speed=7, multiple=5, boundingBox={80,54}, probability=0.196},
        [5]={name="fish6", speed=6, multiple=6, boundingBox={90,70}, probability=0.16333333},
        [6]={name="fish7", speed=6, multiple=7, boundingBox={90,40}, probability=0.14},
        [7]={name="fish8", speed=5, multiple=8, boundingBox={120,55}, probability=0.1225},
        [8]={name="fish9", speed=5, multiple=9, boundingBox={150,47}, probability=0.108889},

        [9]={name="fish10", speed=5, multiple=10, boundingBox={110,112}, probability=0.098},
        [10]={name="fish11", speed=4, multiple=12, boundingBox={145,80}, probability=0.0816667},
        [11]={name="fish12", speed=4, multiple=15, boundingBox={120,150}, probability=0.06533333},
        [12]={name="fish13", speed=4, multiple=18, boundingBox={180,70}, probability=0.0544444},
        [13]={name="fish14", speed=4, multiple=20, boundingBox={255,88}, probability=0.049},

        [14]={name="fish15", speed=4, multiple=25, boundingBox={180,180}, probability=0.0392},
        [15]={name="fish16", speed=4, multiple=30, boundingBox={270,80}, probability=0.03266667},
        [16]={name="fish17", speed=4, multiple=35, boundingBox={290,90}, probability=0.0280},
        [17]={name="鲨鱼", speed=4, multiple={40,120}, boundingBox={500,170}, probability=0.0115294117647},
        [18]={name="大龙虾", speed=3, multiple={120,500}, boundingBox={400,100}, probability=0.0025789},

        [19]={name="富贵猪", speed=2, multiple=320, boundingBox={404,100}, probability=0.0030625},
        [20]={name="大眼鱼", speed=2, multiple={40,300}, boundingBox={200,245}, probability=0.00576471},
        [21]={name="定屏炸弹", speed=3, multiple=20, boundingBox={180,100}, probability=0.049},
        --[22]={name="局部炸弹", speed=3, multiple=250, boundingBox={140,140}, probability=0.00392},
        [23]={name="超级炸弹", speed=2, multiple={1000,2000}, boundingBox={130,130}, probability=0.00063225806},

        [24]={name="大三元1", speed=4, multiple=22, boundingBox={340,130}, probability=0.04454545},
        [25]={name="大三元2", speed=4, multiple=32, boundingBox={340,130}, probability=0.030625},
        [26]={name="大三元3", speed=4, multiple=32, boundingBox={340,130}, probability=0.030625},
        [27]={name="大四喜1", speed=4, multiple=20, boundingBox={460,130}, probability=0.049},
        [28]={name="大四喜2", speed=4, multiple=20, boundingBox={460,130}, probability=0.049},

        [29]={name="大四喜3", speed=4, multiple=40, boundingBox={460,130}, probability=0.0245},
        [40]={name="美人鱼", speed=1, multiple=200, boundingBox={150,150}, probability=0.0049},
        --[41]={name="金宝箱", speed=2, multiple={40,60}, boundingBox={150,150}, probability=0.006},
        --[42]={name="银宝箱", speed=2, multiple={10,30}, boundingBox={150,150}, probability=0.015},
        --[43]={name="铜宝箱", speed=2, multiple=10, boundingBox={150,150}, probability=0.03},

        [44]={name="小宝箱", speed=2, multiple=5, boundingBox={150,150}, probability=nil},
        [45]={name="大宝箱", speed=2, multiple=20, boundingBox={150,150}, probability=nil},
        
        [46]={name="小金龙", speed=9, multiple=1, boundingBox={150,150}, probability=nil},
        [47]={name="急速龟", speed=3, multiple=20, boundingBox={180,100}, probability=0.049},
    },
    probabilityHash = {
    	--    probability*multiple
    	--   普通，绿钻，蓝钻，紫钻，金钻，皇冠
        [44]={0.3, 0.33, 0.36, 0.39, 0.42, 0.45},
        [45]={0.3, 0.33, 0.36, 0.39, 0.42, 0.45},
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
        smallFish={4000,4000,4000,3000,3000,3000,3000,3000},                                                    -- 0-9
        mediumFish={2,2,2,2,2,2,2,2},                                                   -- 10-16
        fish17={7,7,7,7,7,7,7,7},                                               -- 17
        fish18={39,39,39,39,39,39,39,39},                                       -- 18
        fish19={69,69,69,69,69,69,69,69},                               -- 19
        fish20={93,93,93,93,93,93,93,93},                                               -- 20
        --bomb={143,143,139,139,139,139,131,131},
        superBomb={153,153,151,151,151,151,149,149},
        lockBomb={44,44,44,44,44,44,44,44},
        tripleDouble={1480,1480,1380,1380,1280,1280,1280,1280},	-- 24-26
        big4={1970,1970,1870,1870,1770,1770,1770,1770},			-- 27-29
        --fishKing={3400,3400,2900,2900,2300,2300,2300,2300},	-- 30-39
        --goldBox={2110,2110,2110,2110,2110,2110,2110,2110},	-- 41
        --silverBox={990,990,990,990,990,990,990,990},			-- 42
        --copperBox={430,430,430,430,430,430,430,430},			-- 43
		smallBox={60,60,60,60,60,60,60,60},						-- 44
		bigBox={180,180,180,180,180,180,180,180},				-- 45
		jisu={41,41,41,41,41,41,41,41},				-- 47
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
