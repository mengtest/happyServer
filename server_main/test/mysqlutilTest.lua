package.cpath = package.cpath .. ";../luaclib/?.so"
local mysqlutil = require "mysqlutil"

print(mysqlutil.escapestring("\"\'\0\x1a斯大林看abdlk\\"))
