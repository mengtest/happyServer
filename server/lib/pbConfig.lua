return {
	client = {
		--[0x000000] = "loginServer.heartBeat.c2s.HeartBeat",
		
		[0x000100] = "login_c.Login",
		[0x000101] = "login_c.FqzsLogin",
		[0x000102] = "login_c.Register",
		[0x000103] = "login_c.Bind",
		
		[0x020100] = "fqzs_c.GameStart",
		[0x020101] = "fqzs_c.GameGuess",
		
	},
	server = {
		[0x000100] = "login_s.BackLogin",
		[0x000101] = "login_s.LoginReward",
		[0x000102] = "login_s.BackRegister",
		[0x000103] = "login_s.BackBind",
		
		[0x020100] = "fqzs_s.BackGameStart",
		[0x020101] = "fqzs_s.BackGameGuess",
		[0x020102] = "fqzs_s.GameHistory",
	},
	file = {
		"login_c.pb",
		"login_s.pb",
		"fqzs_c.pb",
		"fqzs_s.pb",
	},
	deal = {
		[0x000100] = "ls_login",
		[0x020100] = "ls_fqzs",
	}
}
