local data = {
	loginServer = {
		[0x000100] = "LS_controller_login",
		[0x000200] = "LS_controller_server",
		[0x000300] = "LS_controller_message",
		[0x000400] = "LS_controller_ranking",
		[0x000500] = "LS_controller_pay",
		[0x000600] = "LS_controller_account",
		[0x000700] = "LS_controller_bank",
		[0x000800] = "LS_controller_ping",
		[0x000A00] = "LS_controller_tuijianren",
		[0x000B00] = "LS_controller_duobao",
		[0x000C00] = "LS_controller_activity",
	},
	gameServer = {
		[0x010100] = "GS_controller_login",
		[0x010200] = "GS_controller_table",
		[0x010300] = "GS_controller_property",
		[0x010400] = "GS_controller_chat",
		[0x010500] = "GS_controller_ping",
	},
	web = {
		["uniformpay"] = "LS_webController_uniformPlatform",
		["uniformother"] = "LS_webController_uniformPlatform",
		["interface"] = "LS_webController_interface",
	},
	fish = {
		[0x020000] = "fish_controller",
	},
	baccarat = {
		[0x030000] = "baccarat_controller",
	},
	paijiu = {
		[0x040000] = "paijiu_controller",
	},
}

local function getConfig(type)
	local c = data[type]
	if c then
		return data[type]
	else
		error(string.format("controller resolve config not found for \"%s\"", tostring(type)), 2)
	end
end

return {
	getConfig = getConfig,
}
