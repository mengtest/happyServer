package.path = package.path .. ";../lualib/?.lua"
package.cpath = package.cpath .. ";../luaclib/?.so"
local luasql = require "luasql.sqlite3"
local util = require "cjson.util"

local _env = luasql.sqlite3()
local _db = assert(_env:connect_memory("/root/github/skynet/server/hiwan.db"))

local cursor = assert(_db:execute("select * from Item where id like 'cwd%'"))
while true do
  local row = cursor:fetch({}, 'a')
  if not row then
    break;
  end
  print(util.serialise_value(row))
end
