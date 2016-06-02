local json = require "cjson"
local util = require "cjson.util"

local jsonEvent = [=[{"TYPE":"EVENT_PAY_ORDER_CONFIRM","DATA":{"OrderID":"PG2014040114173179CGZZXZ88","PayChannel":4,"UserID":2700777,"AppID":1009,"ServerID":10001,"CurrencyType":"CNY","CurrencyAmount":68,"Gift":0,"GameGift":680,"SubmitTime":"2014-04-01 14:17:31","Source":"a_01","OS":"IOS","Version":"1.0","FinishTime":"2014-04-01 14:17:31","isFirstPay":false,"isAppFirstPay":false}}]=]
print(jsonEvent)

local isOK, t = pcall(json.decode, jsonEvent)
if isOK then
  print(util.serialise_value(t))
else
  print(t)
end


