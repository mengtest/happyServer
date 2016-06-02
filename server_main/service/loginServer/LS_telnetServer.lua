--debug_console
local skynet = require "skynet"
require "skynet.manager"
local codecache = require "skynet.codecache"
local core = require "skynet.core"
local socket = require "socket"
local snax = require "snax"
local addressResolver = require "addressResolver"
local xpcallUtility = require "utility.xpcall"
local memory = require "memory"

local port = tonumber(...)
local COMMAND = {}

local function format_table(t)
	local index = {}
	for k in pairs(t) do
		table.insert(index, k)
	end
	table.sort(index)
	local result = {}
	for _,v in ipairs(index) do
		table.insert(result, string.format("%s:%s",v,tostring(t[v])))
	end
	return table.concat(result,"\t")
end

local function dump_line(print, key, value)
	if type(value) == "table" then
		print(string.format("%-16s", tostring(key)), format_table(value))
	else
		print(string.format("%-16s", tostring(key)), tostring(value))
	end
end

local function dump_list(print, list)
	local index = {}
	for k in pairs(list) do
		table.insert(index, k)
	end
	table.sort(index)
	for _,v in ipairs(index) do
		dump_line(print, v, list[v])
	end
	print("OK")
end

local function split_cmdline(cmdline)
	local split = {}
	for i in string.gmatch(cmdline, "%S+") do
		table.insert(split,i)
	end
	return split
end

local function docmd(cmdline, print, fd)
	local split = split_cmdline(cmdline)
	local command = split[1]
	if command == "debug" then
		table.insert(split, fd)
	end
	local cmd = COMMAND[command]
	local ok, list
	if cmd then
		ok, list = xpcall(cmd, xpcallUtility.errorMessageSaver, select(2,table.unpack(split)))
	else
		print("Invalid command, type help for command list")
	end

	if ok then
		if list then
			if type(list) == "string" then
				print(list)
			else
				dump_list(print, list)
			end
		else
			print("OK")
		end
	else
		print("Error:", xpcallUtility.getErrorMessage())
	end
end

local function console_main_loop(stdin, print)
	socket.lock(stdin)
	print("欢迎登录管理后台")
	while true do
		local cmdline = socket.readline(stdin, "\n")
		if not cmdline then
			break
		end
		if cmdline ~= "" then
			docmd(cmdline, print, stdin)
		end
	end
	socket.unlock(stdin)
end

skynet.start(function()
	local listen_socket = socket.listen ("127.0.0.1", port)
	skynet.error("Start debug console at 127.0.0.1 " .. port)
	socket.start(listen_socket , function(id, addr)
		local function print(...)
			local t = { ... }
			for k,v in ipairs(t) do
				t[k] = tostring(v)
			end
			socket.write(id, table.concat(t,"\t"))
			socket.write(id, "\n")
		end
		socket.start(id)
		skynet.fork(console_main_loop, id , print)
	end)
end)

function COMMAND.help()
	return {
	}
end

function COMMAND.setDragonType(tp) -- xxxxxx对应每个vip（普通-皇冠）是否可以打中(0不行，1可以)
	if tonumber(tp) == nil then
		return "输入有误"
	end
	return skynet.call(addressResolver.getAddressByServiceName("LS_model_gm"), "lua", "setDragonType", 
			{tp = tonumber(tp)})
end

function COMMAND.setSmallType(tp) -- xxxxxx对应每个vip（普通-皇冠）是否可以打中(0不行，1可以)
	if tonumber(tp) == nil then
		return "输入有误"
	end
	return skynet.call(addressResolver.getAddressByServiceName("LS_model_gm"), "lua", "setSmallType", 
			{tp = tonumber(tp)})
end

function COMMAND.addDragonBlack(tp)
	if tonumber(tp) == nil then
		return "输入有误"
	end
	return skynet.call(addressResolver.getAddressByServiceName("LS_model_gm"), "lua", "addDragonBlack", 
			{userId = tonumber(tp)})
end

function COMMAND.clearDragonBlack()
	return skynet.call(addressResolver.getAddressByServiceName("LS_model_gm"), "lua", "clearDragonBlack")
end

function COMMAND.reloadDefense()
	return skynet.call(addressResolver.getAddressByServiceName("LS_model_gm"), "lua", "reloadDefense")
end
