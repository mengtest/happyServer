package.path = package.path .. ";../lualib/?.lua"
package.cpath = package.cpath .. ";../luaclib/?.so"

local protobuf = require "protobuf"
local util = require "cjson.util"
--[[
addr = io.open("../../build/addressbook.pb","rb")
buffer = addr:read "*a"
addr:close()
protobuf.register(buffer)
--]]
protobuf.register_file("../protocals/pbs/s2c.role.pb")

local accountData = {
  money = 0,
}

local buffer = protobuf.encode("protocals.s2c.role.AccountData", accountData)
local o = assert(io.open("accountData.bin", "wb"))
o:write(buffer)
o:close()
local t = protobuf.decode("protocals.s2c.role.AccountData", buffer)
print(t)
print(util.serialise_value(t))

