local jsonUtil = require "cjson.util"
print(jsonUtil.serialise_value(arg))
print(string.format("arg[1]=%s arg[2]=%s", arg[1], arg[2]))
