local skynet = require "skynet"
local commonServiceHelper = require "serviceHelper.common"
local addressResolver = require "addressResolver"

local _wealthRankingList

local function reloadWealthRankingList()
	local sql = "call QPTreasureDB.sp_load_wealth_ranking_list()"
	local dbConn = addressResolver.getMysqlConnection()
	local rows = skynet.call(dbConn, "lua", "call", sql)
	local list = {}
	if type(rows)=="table" then
		for _, row in ipairs(rows) do
			local item = {
				userID = tonumber(row.UserID),
				faceID = tonumber(row.FaceID),
				gender = tonumber(row.Gender),
				nickName = row.NickName,
				medal = tonumber(row.UserMedal),
				loveLiness = tonumber(row.LoveLiness),
				score = tonumber(row.Score),
				gift = tonumber(row.Gift),
			}
			
			if row.Signature then
				item.signature = row.Signature
			end
			table.insert(list, item)
		end
	end
	_wealthRankingList = list
end

local function cmd_sendWealthRankingList(agent)
	skynet.send(agent, "lua", "forward", 0x000400, {list=_wealthRankingList})
end

local conf = {
	methods = {
		["sendWealthRankingList"] = {["func"]=cmd_sendWealthRankingList, ["isRet"]=false},
	},
	initFunc = function()
		skynet.fork(function()
			while true do
				reloadWealthRankingList()
				skynet.sleep(30000)
			end
		end)
	end,
}

commonServiceHelper.createService(conf)

