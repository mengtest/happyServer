return {
	betTime = 10, -- 下注时间/秒
	payOffTime = 15, -- 结算时间
	freeTime = 10, -- 空闲时间/秒
	
	odds = {1,8,0.95,11,11},
	chip = {10000,20000,50000,100000},
	
	bankerChip = 10000000,--申请上庄金额
	bankerNum = 5, -- 上庄次数
	areaLimitChip = 5000000,--每个区域下注限制
	userLimitChip = 5000000,--每个玩家下注限制
	
	rewardSize = -1, --奖池下限
	rewardReduce = 0, -- 奖池每局扣除(千分比)
}
