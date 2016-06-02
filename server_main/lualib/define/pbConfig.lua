--机器人专用协议不需要配置到这里
local _data = {
	common = {
		s2c = {
			[0xff0000] = "common.misc.s2c.SystemMessage",
		},
		c2s = {},
		files = {
			"common.misc.s2c.pb",
		},		
	},
	loginServer = {
		s2c = {
			[0x000000] = "loginServer.heartBeat.s2c.HeartBeat",
			[0x000100] = "login_s.BackLogin",
			[0x000101] = "loginServer.login.s2c.Logout",
			[0x000102] = "loginServer.login.s2c.ScoreInfo",
			[0x000200] = "loginServer.server.s2c.NodeList",
			[0x000201] = "loginServer.server.s2c.MatchConfigList",
			[0x000202] = "loginServer.server.s2c.ServerOnline",
			[0x000299] = "loginServer.server.s2c.DefenseList",
			[0x000300] = "loginServer.message.s2c.SystemLogonMessage",
			[0x000301] = "loginServer.message.s2c.UserLogonMessage",
			[0x000302] = "loginServer.message.s2c.ExchangeMessage",
			[0x000400] = "loginServer.ranking.s2c.WealthRanking",
			[0x000500] = "loginServer.pay.s2c.QueryPayOrderItem",
			[0x000501] = "loginServer.pay.s2c.PaymentNotify",
			[0x000502] = "loginServer.pay.s2c.BackQueryFreeScore",
			[0x000503] = "loginServer.pay.s2c.BackGetFreeScore",
			[0x000504] = "loginServer.pay.s2c.BackQueryVipFreeScore",
			[0x000505] = "loginServer.pay.s2c.BackGetVipFreeScore",
			[0x000506] = "loginServer.pay.s2c.BackGetGiftScore",
			[0x000507] = "loginServer.pay.s2c.BackQueryVipInfo",
			[0x000508] = "loginServer.pay.s2c.RefreshGift",
			[0x000509] = "loginServer.pay.s2c.RefreshLoveliness",
			[0x00050A] = "loginServer.pay.s2c.RefreshUserInfo",
			
			[0x000600] = "loginServer.account.s2c.ChangeFaceID",
			[0x000601] = "loginServer.account.s2c.ChangeSignature",
			[0x000602] = "loginServer.account.s2c.ChangeNickname",
			[0x000603] = "loginServer.account.s2c.CheckNickname",
			[0x000604] = "loginServer.account.s2c.ChangeGender",
			[0x000605] = "loginServer.account.s2c.SetPlatformFace",
			
			[0x000700] = "loginServer.bank.s2c.Deposit",
			[0x000701] = "loginServer.bank.s2c.Withdraw",
			[0x000702] = "loginServer.bank.s2c.Query",
			
			[0x000800] = "loginServer.ping.s2c.Ping",	
			
			[0x000A00] = "loginServer.tuijianren.s2c.BackUpTuijianren",
			[0x000A01] = "loginServer.tuijianren.s2c.BackIntoTuijianren",
			[0x000A02] = "loginServer.tuijianren.s2c.BackRecvBox",
			[0x000A03] = "loginServer.tuijianren.s2c.BackRecvScore",
			
			[0x000B00] = "loginServer.duobao.s2c.BackIntoDuobao",
			[0x000B01] = "loginServer.duobao.s2c.BackChip",
			
			[0x000C00] = "loginServer.activity.s2c.BackIntoDragon",
			[0x000C01] = "loginServer.activity.s2c.BackIntoLoginReward",
			[0x000C02] = "loginServer.activity.s2c.BackGetLoginOne",
			[0x000C03] = "loginServer.activity.s2c.BackGetLoginMore",
			[0x000C04] = "loginServer.activity.s2c.BackGetDragonRecord",
			[0x000C05] = "loginServer.activity.s2c.BackGetSkin",
			[0x000C06] = "loginServer.activity.s2c.BackBuySkin",
			[0x000C07] = "loginServer.activity.s2c.BackSetSkin",
			[0x000C08] = "loginServer.activity.s2c.BackGetLoginEgg",
		},
		c2s = {
			[0x000000] = "loginServer.heartBeat.c2s.HeartBeat",
			[0x000100] = "login_c.Login",
			[0x000202] = "loginServer.server.c2s.QueryServerOnline",
			[0x000302] = "loginServer.message.c2s.QueryExchangeMessage",
			[0x000400] = "loginServer.ranking.c2s.QueryWealthRanking",
			[0x000500] = "loginServer.pay.c2s.QueryPayOrderItem",
			[0x000501] = "loginServer.pay.c2s.QueryFreeScore",
			[0x000502] = "loginServer.pay.c2s.GetFreeScore",
			[0x000503] = "loginServer.pay.c2s.QueryVipFreeScore",
			[0x000504] = "loginServer.pay.c2s.GetVipFreeScore",
			[0x000505] = "loginServer.pay.c2s.GetGiftScore",
			[0x000506] = "loginServer.pay.c2s.QueryVipInfo",
			
			[0x000600] = "loginServer.account.c2s.ChangeFaceID",
			[0x000601] = "loginServer.account.c2s.ChangeSignature",
			[0x000602] = "loginServer.account.c2s.ChangeNickname",
			[0x000603] = "loginServer.account.c2s.CheckNickname",
			[0x000604] = "loginServer.account.c2s.ChangeGender",
			[0x000605] = "loginServer.account.c2s.SetPlatformFace",
			
			[0x000700] = "loginServer.bank.c2s.Deposit",
			[0x000701] = "loginServer.bank.c2s.Withdraw",
			[0x000702] = "loginServer.bank.c2s.Query",
			
			[0x000800] = "loginServer.ping.c2s.Ping",
			
			[0x000A00] = "loginServer.tuijianren.c2s.UpTuijianren",
			[0x000A01] = "loginServer.tuijianren.c2s.IntoTuijianren",
			[0x000A02] = "loginServer.tuijianren.c2s.RecvBox",
			[0x000A03] = "loginServer.tuijianren.c2s.RecvScore",
			
			[0x000B00] = "loginServer.duobao.c2s.IntoDuobao",
			[0x000B01] = "loginServer.duobao.c2s.chip",
			
			[0x000C00] = "loginServer.activity.c2s.IntoDragon",
			[0x000C01] = "loginServer.activity.c2s.IntoLoginReward",
			[0x000C02] = "loginServer.activity.c2s.GetLoginone",
			[0x000C03] = "loginServer.activity.c2s.GetLoginMore",
			[0x000C04] = "loginServer.activity.c2s.GetDragonRecord",
			[0x000C05] = "loginServer.activity.c2s.GetSkin",
			[0x000C06] = "loginServer.activity.c2s.BuySkin",
			[0x000C07] = "loginServer.activity.c2s.SetSkin",
			[0x000C08] = "loginServer.activity.c2s.GetLoginEgg",
		},
		files = {
		"login_c.pb",
		"login_s.pb",
			"loginServer.heartBeat.c2s.pb",
			"loginServer.heartBeat.s2c.pb",
			"loginServer.login.c2s.pb",
			"loginServer.login.s2c.pb",
			"loginServer.server.c2s.pb",
			"loginServer.server.s2c.pb",
			"loginServer.message.c2s.pb",
			"loginServer.message.s2c.pb",
			"loginServer.ranking.c2s.pb",
			"loginServer.ranking.s2c.pb",		
			"loginServer.pay.c2s.pb",
			"loginServer.pay.s2c.pb",
			"loginServer.account.c2s.pb",
			"loginServer.account.s2c.pb",
			"loginServer.bank.c2s.pb",
			"loginServer.bank.s2c.pb",
			"loginServer.ping.c2s.pb",
			"loginServer.ping.s2c.pb",	
			"loginServer.tuijianren.c2s.pb",
			"loginServer.tuijianren.s2c.pb",
			"loginServer.duobao.c2s.pb",
			"loginServer.duobao.s2c.pb",
			"loginServer.activity.c2s.pb",
			"loginServer.activity.s2c.pb",
		},
	},
	gameServer = {
		s2c = {
			[0x010000] = "gameServer.heartBeat.s2c.HeartBeat",
			
			[0x010100] = "gameServer.login.s2c.Login",
			[0x010102] = "gameServer.login.s2c.ServerConfig",
			[0x010104] = "gameServer.login.s2c.TableStatus",
			[0x010105] = "gameServer.login.s2c.TableStatusList",
			[0x010106] = "gameServer.login.s2c.UserInfo",
			[0x010107] = "gameServer.login.s2c.UserInfoViewPort",
			[0x010109] = "gameServer.login.s2c.Logout",
			[0x01010A] = "gameServer.login.s2c.ChangeUserInfo",
			
			[0x010200] = "gameServer.table.s2c.UserSitDown",
			[0x010201] = "gameServer.table.s2c.UserStatus",
			[0x010203] = "gameServer.table.s2c.GameStatus",
			[0x010204] = "gameServer.table.s2c.UserStandUp",
			[0x010205] = "gameServer.table.s2c.AllPlayerLeft",
			
			[0x010300] = "gameServer.property.s2c.PropertyConfig",
			[0x010301] = "gameServer.property.s2c.PropertyRepository",
			[0x010302] = "gameServer.property.s2c.BuyProperty",
			[0x010303] = "gameServer.property.s2c.TrumpetScore",
			[0x010304] = "gameServer.property.s2c.UseProperty",
			[0x010305] = "gameServer.property.s2c.UsePropertyBroadcast",
			[0x010306] = "gameServer.property.s2c.PropertyRepositoryUpdate",
			[0x010307] = "gameServer.property.s2c.SendTrumpet",
			[0x010308] = "gameServer.property.s2c.TrumpetMsg",
			
			[0x010400] = "gameServer.chat.s2c.UserChat",
			[0x010401] = "gameServer.chat.s2c.UserExpression",
			[0x010402] = "gameServer.chat.s2c.UserMultimedia",
			
			[0x010500] = "gameServer.ping.s2c.Ping",
			
			[0x01ff01] = "gameServer.misc.s2c.UserScore",
			[0x01ff02] = "gameServer.misc.s2c.PaymentNotify",
		},
		c2s = {
			[0x010000] = "gameServer.heartBeat.c2s.HeartBeat",
			[0x010100] = "gameServer.login.c2s.Login",
			[0x010109] = "gameServer.login.c2s.Logout",
			[0x010200] = "gameServer.table.c2s.UserSitDown",
			[0x010202] = "gameServer.table.c2s.GameOption",
			[0x010204] = "gameServer.table.c2s.UserStandUp",
			
			[0x010302] = "gameServer.property.c2s.BuyProperty",
			[0x010304] = "gameServer.property.c2s.UseProperty",
			[0x010307] = "gameServer.property.c2s.SendTrumpet",
			
			[0x010400] = "gameServer.chat.c2s.UserChat",
			[0x010401] = "gameServer.chat.c2s.UserExpression",
			[0x010402] = "gameServer.chat.c2s.UserMultimedia",
			
			[0x010500] = "gameServer.ping.c2s.Ping",
		},
		files = {
			"gameServer.heartBeat.c2s.pb",
			"gameServer.heartBeat.s2c.pb",
			"gameServer.login.c2s.pb",
			"gameServer.login.s2c.pb",
			"gameServer.table.c2s.pb",
			"gameServer.table.s2c.pb",
			"gameServer.property.c2s.pb",
			"gameServer.property.s2c.pb",			
			"gameServer.chat.c2s.pb",
			"gameServer.chat.s2c.pb",
			"gameServer.ping.c2s.pb",
			"gameServer.ping.s2c.pb",	
			"gameServer.misc.s2c.pb",
		},
	},
	fish = {
		s2c = {
			[0x020000] = "fish.s2c.UserFire",
			[0x020001] = "fish.s2c.BackBankOp",
			[0x020002] = "fish.s2c.BackChangeBullet",
			[0x020003] = "fish.s2c.SwitchScene",
			[0x020005] = "fish.s2c.GameConfig",
			[0x020006] = "fish.s2c.GameScene",
			[0x020007] = "fish.s2c.ExchangeFishScore",
			[0x020009] = "fish.s2c.CatchSweepFish",
			[0x02000A] = "fish.s2c.TreasureBox",
			[0x02000B] = "fish.s2c.CatchFish",
			[0x02000C] = "fish.s2c.CatchSweepFishResult",
			[0x02000D] = "fish.s2c.LockTimeout",
			[0x02000E] = "fish.s2c.BulletCompensate",
			[0x020010] = "fish.s2c.FishSpawn",
			[0x020011] = "fish.s2c.DragonPool",
			[0x020012] = "fish.s2c.DragonOver",
			
			
			[0x020200] = "fish.volcano.s2c.PoolStatus",
			[0x020201] = "fish.volcano.s2c.VolcanoOpen",
		},
		c2s = {
			[0x020000] = "fish.c2s.UserFire",
			[0x020001] = "fish.c2s.BankOp",
			[0x020002] = "fish.c2s.ChangeBullet",
			[0x020008] = "fish.c2s.BigNetCatchFish",
			[0x02000C] = "fish.c2s.CatchSweepFish",
		},
		files = {
			"fish.c2s.pb",
			"fish.s2c.pb",
			"fish.volcano.s2c.pb",
		},
	},
	baccarat = {
		s2c = {
			[0x030000] = "baccarat.s2c.GameConfig",
			[0x030001] = "baccarat.s2c.GameScene",
			[0x030002] = "baccarat.s2c.BackBet",
			[0x030003] = "baccarat.s2c.BackCancelBet",
			[0x030004] = "baccarat.s2c.BetBegin",
			[0x030005] = "baccarat.s2c.BetEnd",
			[0x030006] = "baccarat.s2c.NewPlayerChip",
			[0x030007] = "baccarat.s2c.ApplyBanker",
			[0x030008] = "baccarat.s2c.CancelBanker",
			[0x030009] = "baccarat.s2c.BetFree",
			[0x03000A] = "baccarat.s2c.NowBanker",
		},
		c2s = {
			[0x030000] = "baccarat.c2s.Bet",	
			[0x030001] = "baccarat.c2s.ApplyBanker",	
			[0x030002] = "baccarat.c2s.CancelBanker",	
		},
		files = {
			"baccarat.c2s.pb",
			"baccarat.s2c.pb",
		},
	},
	paijiu = {
		s2c = {
			[0x040000] = "paijiu.s2c.GameConfig",
			[0x040001] = "paijiu.s2c.GameScene",
			[0x040002] = "paijiu.s2c.ChipInfo",
			[0x040003] = "paijiu.s2c.BackBet",
			[0x040004] = "paijiu.s2c.BetBegin",
			[0x040005] = "paijiu.s2c.BetEnd",
			[0x040006] = "paijiu.s2c.BetFree",
			[0x040007] = "paijiu.s2c.ApplyBanker",
			[0x040008] = "paijiu.s2c.CancelBanker",
			[0x04000A] = "paijiu.s2c.NowBanker",
		},
		c2s = {
			[0x040000] = "paijiu.c2s.Bet",
			[0x040001] = "paijiu.c2s.ApplyBanker",
			[0x040002] = "paijiu.c2s.CancelBanker",
		},
		files = {
			"paijiu.c2s.pb",
			"paijiu.s2c.pb",
		},
	},	
	
}

local function mergeConfig(...)
	local config = {
		s2c = {},
		c2s = {},
		files = {},
	}
	
	for _, sectionName in ipairs{...} do
		local c = _data[sectionName]
		if c then
			for k, v in pairs(c.s2c) do
				config.s2c[k] = v
			end
			
			for k, v in pairs(c.c2s) do
				config.c2s[k] = v
			end
			
			for _, v in ipairs(c.files) do
				table.insert(config.files, v)
			end
		end
	end
	
	return config
end

local function getConfig(type)
	if type=="loginServer" then
		return mergeConfig("loginServer", "common")
	elseif type=="fish" then
		return mergeConfig("gameServer", "fish", "common")
	elseif type=="baccarat" then
		return mergeConfig("gameServer", "baccarat", "common")
	elseif type=="paijiu" then
		return mergeConfig("gameServer", "paijiu", "common")
	else
		error(string.format("invalid type \"%s\"", type), 2)
	end
end

return {
	getConfig = getConfig,
}
