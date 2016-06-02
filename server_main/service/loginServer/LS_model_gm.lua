local skynet = require "skynet"
local commonServiceHelper = require "serviceHelper.common"
local addressResolver = require "addressResolver"
local resourceResolver = require "resourceResolver"
local timerUtility = require "utility.timer"
local mysqlutil = require "mysqlutil"
local COMMON_CONST = require "define.commonConst"
local ServerUserItem = require "sui"
local lsConst = require "define.lsConst"
local currencyUtility = require "utility.currency"

local _data = {
}

local function cmd_setDragonType(data)
	skynet.call(addressResolver.getAddressByServiceName("LS_model_dragon"), "lua", "setGmControl", 0,data.tp)
	local re = string.format("已设置龙宫状态：%d", data.tp)
	skynet.error(re)
	return re
end

local function cmd_setSmallType(data)
	skynet.call(addressResolver.getAddressByServiceName("LS_model_dragon"), "lua", "setGmControl", 1,data.tp)
	local re = string.format("已设置宝箱状态：%d", data.tp)
	skynet.error(re)
	return re
end

local function cmd_addDragonBlack(data)
	local re = skynet.call(addressResolver.getAddressByServiceName("LS_model_dragon"), "lua", "setGmControl", 2,data.userId)
	skynet.error(string.format("加入龙宫黑名单：%d", data.userId))
	return re
end

local function cmd_clearDragonBlack(data)
	skynet.call(addressResolver.getAddressByServiceName("LS_model_dragon"), "lua", "setGmControl", 3)
	skynet.error("清除龙宫黑名单")
	return re
end

local function cmd_reloadDefense()
	skynet.call(addressResolver.getAddressByServiceName("LS_model_serverManager"), "lua", "reloadDefenseList")
	skynet.error("重载防御配置")
	return re
end

local conf = {
	methods = {
		["setDragonType"] = {["func"]=cmd_setDragonType, ["isRet"]=true},
		["setSmallType"] = {["func"]=cmd_setSmallType, ["isRet"]=true},
		["addDragonBlack"] = {["func"]=cmd_addDragonBlack, ["isRet"]=true},
		["clearDragonBlack"] = {["func"]=cmd_clearDragonBlack, ["isRet"]=true},
		["reloadDefense"] = {["func"]=cmd_reloadDefense, ["isRet"]=true},
	},
	initFunc = function()
		resourceResolver.init()
	end,
}

commonServiceHelper.createService(conf)
