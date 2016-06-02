package.path = package.path .. ";../lualib/?.lua"
package.cpath = package.cpath .. ";../luaclib/?.so"
local luasql = require "luasql.mysql"
local util = require "cjson.util"

local _env = luasql.mysql()
local _db = assert(_env:connect("test", "root", "qpserverdev", "127.0.0.1"))

--[[
local cursor = assert(_db:execute("select user, host from mysql.user"))
while true do
  local row = cursor:fetch({}, 'a')
  if not row then
    break;
  end
  print(string.format("user: %s\thost: %s", row.user, row.host))
end
--]]


local function cmd_query(_db, sql)
	local cursor = assert(_db:execute(sql))
	if type(cursor)=='number' then
		return cursor
	end

	local rows = {}
	while true do
		local row = cursor:fetch({}, 'a')
		if row then
			table.insert(rows, row)
		else
			break;
		end
	end
	cursor:close()
	return rows
end

_db:execute("set names 'utf8'")
local rows = cmd_query(_db, "select * from test1")
print(util.serialise_value(rows))
rows = cmd_query(_db, "select * from bitTest")
print(util.serialise_value(rows))