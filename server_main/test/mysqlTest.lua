package.path = package.path .. ";../lualib/?.lua"
package.cpath = package.cpath .. ";../luaclib/?.so"
local luasql = require "luasql.mysql"
local util = require "cjson.util"

local _env = luasql.mysql()
local _db = assert(_env:connect("newServer", "root", "qpserverdev", "127.0.0.1"))

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

_db:execute("set names 'utf8'")
local cursor = assert(_db:execute("call dummy()"))
local row = cursor:fetch({}, 'a')
print(util.serialise_value(row))


