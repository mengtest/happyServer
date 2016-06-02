local ServerUserItem = require "sui"
local jsonUtil = require "cjson.util"
local lunatest = require "lunatest"


local icp1 = {
	userID=8888,
	gameID=6666,
	platformID=1,
	nickName="恭喜发财",
	gender=0,
	faceID=1,
	memberOrder=3,
	masterOrder=1,
	userRight=32,
	masterRight=64,	
	score=8887850,
	insure=7990,
	medal=9550,
	gift=9800,
	present=8600,
	experience=8800,
	loveliness=260,
	winCount=1,
	lostCount=2,
	drawCount=3,
	fleeCount=4,
	contribution=5,
}
local icp2 = {
	tableID=21,
	chairID=1,
	userStatus=0x01,
	enListStatus=0x02,

	restrictScore=1000000,
	isAndroid=false,
	agent=1234,
	ipAddr="127.0.0.1",
	machineID="0cc175b9c0f1b6a831c399e269772661",
	deskCount=12,
	mobileUserRule=0x100,
	logonTime=os.time(),
	inoutIndex=1,
}
---[[

--测试比较
function test_equality()
	local userItem1 = ServerUserItem.new()
	ServerUserItem.initialize(userItem1, icp1, icp2)
	lunatest.assert_userdata(userItem1)
	
	local userItem2 = ServerUserItem.new()
	ServerUserItem.initialize(userItem2, icp1, icp2)
	lunatest.assert_userdata(userItem2)	

	lunatest.assert_equal(userItem1, userItem1);
	lunatest.assert_not_equal(userItem1, userItem2);
	
	ServerUserItem.destroy(userItem1)
	ServerUserItem.destroy(userItem2)
end

--测试获取全部数据
function test_attribute_get()
	local userItem1 = ServerUserItem.new()
	ServerUserItem.initialize(userItem1, icp1, icp2)
	lunatest.assert_userdata(userItem1)	
	
	local attr = ServerUserItem.getAttribute(userItem1, {
		"userID", "gameID", "platformID", "nickName", "gender", "faceID", "score", "insure", "grade", "medal", "gift", "present", "experience",
		"loveliness", "winCount", "lostCount", "drawCount", "fleeCount", "contribution", "siteDownScore", "memberOrder", "masterOrder",
		"userRight", "masterRight", "tableID", "chairID", "userStatus", "enListStatus", "userRule", "variationInfo", "trusteeScore", "restrictScore",
		"frozenedScore", "logonTime", "inoutIndex", "isAndroid", "isClientReady", "agent", "ipAddr", "machineID", "deskPos",
		"deskCount", "mobileUserRule",
	})

	--print(string.format("%s\n%s", tostring(userItem1), jsonUtil.serialise_value(attr)))
	
	lunatest.assert_equal(attr.userID, icp1.userID)
	lunatest.assert_equal(attr.gameID, icp1.gameID)
	lunatest.assert_equal(attr.platformID, icp1.platformID)
	lunatest.assert_equal(attr.nickName, icp1.nickName)
	lunatest.assert_equal(attr.gender, icp1.gender)
	lunatest.assert_equal(attr.faceID, icp1.faceID)
	lunatest.assert_equal(attr.memberOrder, icp1.memberOrder)
	lunatest.assert_equal(attr.masterOrder, icp1.masterOrder)
	lunatest.assert_equal(attr.userRight, icp1.userRight)
	lunatest.assert_equal(attr.masterRight, icp1.masterRight)
	if attr.trusteeScore > 0 then
		lunatest.assert_equal(attr.score+attr.trusteeScore, icp1.score)
	else
		lunatest.assert_equal(attr.score, icp1.score)
	end
	lunatest.assert_equal(attr.insure, icp1.insure)
	lunatest.assert_equal(attr.medal, icp1.medal)
	lunatest.assert_equal(attr.gift, icp1.gift)
	lunatest.assert_equal(attr.present, icp1.present)
	lunatest.assert_equal(attr.experience, icp1.experience)
	lunatest.assert_equal(attr.loveliness, icp1.loveliness)
	lunatest.assert_equal(attr.winCount, icp1.winCount)
	lunatest.assert_equal(attr.lostCount, icp1.lostCount)
	lunatest.assert_equal(attr.drawCount, icp1.drawCount)
	lunatest.assert_equal(attr.fleeCount, icp1.fleeCount)
	lunatest.assert_equal(attr.contribution, icp1.contribution)
	
	lunatest.assert_equal(attr.tableID, icp2.tableID)
	lunatest.assert_equal(attr.chairID, icp2.chairID)
	lunatest.assert_equal(attr.userStatus, icp2.userStatus)
	lunatest.assert_equal(attr.enListStatus, icp2.enListStatus)

	lunatest.assert_equal(attr.isAndroid, icp2.isAndroid)
	lunatest.assert_equal(attr.agent, icp2.agent)
	lunatest.assert_equal(attr.ipAddr, icp2.ipAddr)
	lunatest.assert_equal(attr.machineID, icp2.machineID)
	
	lunatest.assert_equal(attr.deskCount, icp2.deskCount)
	lunatest.assert_equal(attr.mobileUserRule, icp2.mobileUserRule)
	lunatest.assert_equal(attr.logonTime, icp2.logonTime)
	lunatest.assert_equal(attr.inoutIndex, icp2.inoutIndex)
	
	lunatest.assert_equal(attr.grade, 0)
	lunatest.assert_equal(attr.siteDownScore, 0)
	if attr.score < icp1.score then
		lunatest.assert_equal(attr.trusteeScore, icp1.score-attr.score)
	else
		lunatest.assert_equal(attr.trusteeScore, 0)
	end
	lunatest.assert_equal(attr.frozenedScore, 0)
	lunatest.assert_false(attr.isClientReady)
	lunatest.assert_equal(attr.deskPos, 1)
	
	ServerUserItem.destroy(userItem1)
end

--测试scale value
function test_attribute_set()
	local userItem1 = ServerUserItem.new()
	ServerUserItem.initialize(userItem1, icp1, icp2)
	lunatest.assert_userdata(userItem1)	
	
	local orignalAttr = ServerUserItem.getAttribute(userItem1, {
		"userID", "gameID", "platformID", "nickName", "gender", "faceID", "score", "insure", "grade", "medal", "gift", "present", "experience",
		"loveliness", "winCount", "lostCount", "drawCount", "fleeCount", "contribution", "siteDownScore", "memberOrder", "masterOrder",
		"userRight", "masterRight", "tableID", "chairID", "userStatus", "enListStatus", "userRule", "variationInfo", "trusteeScore", "restrictScore",
		"frozenedScore", "logonTime", "inoutIndex", "isAndroid", "isClientReady", "agent", "ipAddr", "machineID", "deskPos",
		"deskCount", "mobileUserRule",
	})

	local setAttr = {
		userID=9999,
		gameID=1290342,
		platformID=23,
		nickName="时大鲲",
		gender=1,
		faceID=18,
		memberOrder=7,
		masterOrder=0,
		score=50,
		insure=10,
		medal=1,
		gift=2,
		present=3,
		experience=4,
		loveliness=5,
		winCount=6,
		lostCount=7,
		drawCount=8,
		fleeCount=9,
		contribution=10,
	}
	
	ServerUserItem.setAttribute(userItem1, setAttr)
	local attr = ServerUserItem.getAttribute(userItem1, {
		"userID", "gameID", "platformID", "nickName", "gender", "faceID", "score", "insure", "grade", "medal", "gift", "present", "experience",
		"loveliness", "winCount", "lostCount", "drawCount", "fleeCount", "contribution", "siteDownScore", "memberOrder", "masterOrder",
		"userRight", "masterRight", "tableID", "chairID", "userStatus", "enListStatus", "userRule", "variationInfo", "trusteeScore", "restrictScore",
		"frozenedScore", "logonTime", "inoutIndex", "isAndroid", "isClientReady", "agent", "ipAddr", "machineID", "deskPos",
		"deskCount", "mobileUserRule",
	})
	
	lunatest.assert_equal(attr.userID, setAttr.userID)
	lunatest.assert_equal(attr.gameID, setAttr.gameID)
	lunatest.assert_equal(attr.platformID, setAttr.platformID)
	lunatest.assert_equal(attr.nickName, setAttr.nickName)
	lunatest.assert_equal(attr.gender, setAttr.gender)
	lunatest.assert_equal(attr.faceID, setAttr.faceID)
	lunatest.assert_equal(attr.memberOrder, setAttr.memberOrder)
	lunatest.assert_equal(attr.masterOrder, setAttr.masterOrder)	
	lunatest.assert_equal(attr.score, setAttr.score)
	lunatest.assert_equal(attr.insure, setAttr.insure)
	lunatest.assert_equal(attr.medal, setAttr.medal)
	lunatest.assert_equal(attr.gift, setAttr.gift)
	lunatest.assert_equal(attr.present, setAttr.present)
	lunatest.assert_equal(attr.experience, setAttr.experience)
	lunatest.assert_equal(attr.loveliness, setAttr.loveliness)
	lunatest.assert_equal(attr.winCount, setAttr.winCount)
	lunatest.assert_equal(attr.lostCount, setAttr.lostCount)
	lunatest.assert_equal(attr.drawCount, setAttr.drawCount)
	lunatest.assert_equal(attr.fleeCount, setAttr.fleeCount)
	lunatest.assert_equal(attr.contribution, setAttr.contribution)
	
	

	lunatest.assert_equal(attr.userRight, orignalAttr.userRight)
	lunatest.assert_equal(attr.masterRight, orignalAttr.masterRight)
	
	lunatest.assert_equal(attr.tableID, orignalAttr.tableID)
	lunatest.assert_equal(attr.chairID, orignalAttr.chairID)
	lunatest.assert_equal(attr.userStatus, orignalAttr.userStatus)
	lunatest.assert_equal(attr.enListStatus, orignalAttr.enListStatus)
	lunatest.assert_equal(attr.isAndroid, orignalAttr.isAndroid)
	lunatest.assert_equal(attr.agent, orignalAttr.agent)
	lunatest.assert_equal(attr.ipAddr, orignalAttr.ipAddr)
	lunatest.assert_equal(attr.machineID, orignalAttr.machineID)
	
	lunatest.assert_equal(attr.deskCount, orignalAttr.deskCount)
	lunatest.assert_equal(attr.mobileUserRule, orignalAttr.mobileUserRule)
	lunatest.assert_equal(attr.logonTime, orignalAttr.logonTime)
	lunatest.assert_equal(attr.inoutIndex, orignalAttr.inoutIndex)
	
	lunatest.assert_equal(attr.grade, orignalAttr.grade)
	lunatest.assert_equal(attr.siteDownScore, orignalAttr.siteDownScore)
	lunatest.assert_equal(attr.trusteeScore, orignalAttr.trusteeScore)
	lunatest.assert_equal(attr.frozenedScore, orignalAttr.frozenedScore)
	lunatest.assert_equal(attr.isClientReady, orignalAttr.isClientReady)
	lunatest.assert_equal(attr.deskPos, orignalAttr.deskPos)	

	ServerUserItem.destroy(userItem1)
end

function test_attribute_add()
	local userItem1 = ServerUserItem.new()
	ServerUserItem.initialize(userItem1, icp1, icp2)
	lunatest.assert_userdata(userItem1)	
	
	local orignalAttr = ServerUserItem.getAttribute(userItem1, {
		"score", "insure", "grade", "medal", "gift", "present", "experience", "loveliness", "contribution",
	})

	local addAttr = {
		score=50,
		insure=10,
		medal=1,
		gift=2,
		present=3,
		experience=4,
		loveliness=5,
		contribution=10,
	}
	
	ServerUserItem.addAttribute(userItem1, addAttr)
	local attr = ServerUserItem.getAttribute(userItem1, {
		"score", "insure", "grade", "medal", "gift", "present", "experience", "loveliness", "contribution",
	})

	
	lunatest.assert_equal(attr.score, addAttr.score+orignalAttr.score)
	lunatest.assert_equal(attr.insure, addAttr.insure+orignalAttr.insure)
	lunatest.assert_equal(attr.medal, addAttr.medal+orignalAttr.medal)
	lunatest.assert_equal(attr.gift, addAttr.gift+orignalAttr.gift)
	lunatest.assert_equal(attr.present, addAttr.present+orignalAttr.present)
	lunatest.assert_equal(attr.experience, addAttr.experience+orignalAttr.experience)
	lunatest.assert_equal(attr.loveliness, addAttr.loveliness+orignalAttr.loveliness)
	lunatest.assert_equal(attr.contribution, addAttr.contribution+orignalAttr.contribution)

	ServerUserItem.destroy(userItem1)
end

--测试userRule
function test_userRule()
	local userItem1 = ServerUserItem.new()
	ServerUserItem.initialize(userItem1, icp1, icp2)
	lunatest.assert_userdata(userItem1)	
	
	local orignalAttr = ServerUserItem.getAttribute(userItem1, {"userRule"}).userRule
	lunatest.assert_table(orignalAttr)
	local setAttr = {
		limitSameIP=true,
		limitWinRate=false,
		limitFleeRate=true,
		limitGameScore=false,

		minWinRate=1981,
		maxFleeRate=1982,
		maxGameScore=1983,
		password="你猜啊",
	}
	ServerUserItem.setAttribute(userItem1, {userRule=setAttr})	
	local attr = ServerUserItem.getAttribute(userItem1, {"userRule"}).userRule
	lunatest.assert_table(attr)

	lunatest.assert_equal(attr.limitSameIP, setAttr.limitSameIP)
	lunatest.assert_equal(attr.limitWinRate, setAttr.limitWinRate)
	lunatest.assert_equal(attr.limitFleeRate, setAttr.limitFleeRate)
	lunatest.assert_equal(attr.limitGameScore, setAttr.limitGameScore)
	lunatest.assert_equal(attr.minWinRate, setAttr.minWinRate)
	lunatest.assert_equal(attr.maxFleeRate, setAttr.maxFleeRate)
	lunatest.assert_equal(attr.maxGameScore, setAttr.maxGameScore)
	lunatest.assert_equal(attr.password, setAttr.password)
	
	lunatest.assert_equal(attr.minGameScore, orignalAttr.minGameScore)
	
	ServerUserItem.destroy(userItem1)
end

--测试variationInfo
function test_variationInfo()
	local userItem1 = ServerUserItem.new()
	ServerUserItem.initialize(userItem1, icp1, icp2)
	lunatest.assert_userdata(userItem1)		
	
	local orignalAttr = ServerUserItem.getAttribute(userItem1, {"variationInfo"}).variationInfo
	lunatest.assert_table(orignalAttr)
	
	local setAttr = {
		revenue=11,
		score=12,
		insure=13,
		grade=14,
		medal=15,
		gift=16,
		present=17,
		experience=18,
		
		playTimeCount = 19,
		winCount = 20,
		lostCount = 21,
		drawCount = 22,
		fleeCount = 23,
	}

	
	ServerUserItem.setAttribute(userItem1, {variationInfo=setAttr})	
	local attr = ServerUserItem.getAttribute(userItem1, {"variationInfo"}).variationInfo
	
	lunatest.assert_equal(attr.revenue, setAttr.revenue)
	lunatest.assert_equal(attr.score, setAttr.score)
	lunatest.assert_equal(attr.insure, setAttr.insure)
	lunatest.assert_equal(attr.grade, setAttr.grade)
	lunatest.assert_equal(attr.medal, setAttr.medal)
	lunatest.assert_equal(attr.gift, setAttr.gift)
	lunatest.assert_equal(attr.present, setAttr.present)
	lunatest.assert_equal(attr.experience, setAttr.experience)
	
	lunatest.assert_equal(attr.playTimeCount, setAttr.playTimeCount)
	lunatest.assert_equal(attr.winCount, setAttr.winCount)
	lunatest.assert_equal(attr.lostCount, setAttr.lostCount)
	lunatest.assert_equal(attr.drawCount, setAttr.drawCount)
	lunatest.assert_equal(attr.fleeCount, setAttr.fleeCount)
	
	lunatest.assert_equal(attr.loveliness, orignalAttr.loveliness)
	
	ServerUserItem.destroy(userItem1)
end

function test_distillVariation()
	local userItem1 = ServerUserItem.new()
	ServerUserItem.initialize(userItem1, icp1, icp2)
	lunatest.assert_userdata(userItem1)	
	
	local attr = ServerUserItem.distillVariation(userItem1)
	lunatest.assert_equal(attr.userID, icp1.userID)
	lunatest.assert_equal(attr.inoutIndex, icp2.inoutIndex)
	lunatest.assert_table(attr.variationInfo)
	
	lunatest.assert_number(attr.variationInfo.revenue)
	lunatest.assert_number(attr.variationInfo.score)
	lunatest.assert_number(attr.variationInfo.insure)
	lunatest.assert_number(attr.variationInfo.grade)
	lunatest.assert_number(attr.variationInfo.medal)
	lunatest.assert_number(attr.variationInfo.gift)
	lunatest.assert_number(attr.variationInfo.present)
	lunatest.assert_number(attr.variationInfo.experience)
	lunatest.assert_number(attr.variationInfo.loveliness)
	lunatest.assert_number(attr.variationInfo.playTimeCount)
	lunatest.assert_number(attr.variationInfo.winCount)
	lunatest.assert_number(attr.variationInfo.lostCount)
	lunatest.assert_number(attr.variationInfo.drawCount)
	lunatest.assert_number(attr.variationInfo.fleeCount)
	
	
	ServerUserItem.destroy(userItem1)
end

--测试initialize和reset
function test_initialize_reset()
	local userItem1 = ServerUserItem.new()
	ServerUserItem.initialize(userItem1, icp1, icp2)
	lunatest.assert_userdata(userItem1)	
	
	local licp1 = {
		userID=8888,
		gameID=6666,
		platformID=1,
		nickName="看风使舵",
		gender=0,
		faceID=1,
		memberOrder=3,
		masterOrder=1,
		userRight=16,
		masterRight=8,	
		score=8887850,
		insure=7990,
		medal=9550,
		gift=9800,
		present=8600,
		experience=8800,
		loveliness=260,
		winCount=1,
		lostCount=2,
		drawCount=3,
		fleeCount=4,
		contribution=5,
	}
	local licp2 = {
		tableID=21,
		chairID=1,
		userStatus=0x01,
		enListStatus=0x02,

		restrictScore=1000000,
		isAndroid=false,
		agent=1234,
		ipAddr="127.0.0.1",
		machineID="0cc175b9c0f1b6a831c399e269772661",
		deskCount=12,
		mobileUserRule=0x100,
		logonTime=os.time(),
		inoutIndex=1,
	}
	ServerUserItem.reset(userItem1)
	ServerUserItem.initialize(userItem1, licp1, licp2)
	
	local attr = ServerUserItem.getAttribute(userItem1, {
		"userID", "gameID", "platformID", "nickName", "gender", "faceID", "score", "insure", "grade", "medal", "gift", "present", "experience",
		"loveliness", "winCount", "lostCount", "drawCount", "fleeCount", "contribution", "siteDownScore", "memberOrder", "masterOrder",
		"userRight", "masterRight", "tableID", "chairID", "userStatus", "enListStatus", "userRule", "variationInfo", "trusteeScore", "restrictScore",
		"frozenedScore", "logonTime", "inoutIndex", "isAndroid", "isClientReady", "agent", "ipAddr", "machineID", "deskPos",
		"deskCount", "mobileUserRule",
	})	

	lunatest.assert_equal(attr.userID, licp1.userID)
	lunatest.assert_equal(attr.gameID, licp1.gameID)
	lunatest.assert_equal(attr.platformID, licp1.platformID)
	lunatest.assert_equal(attr.nickName, licp1.nickName)
	lunatest.assert_equal(attr.gender, licp1.gender)
	lunatest.assert_equal(attr.faceID, licp1.faceID)
	lunatest.assert_equal(attr.memberOrder, licp1.memberOrder)
	lunatest.assert_equal(attr.masterOrder, licp1.masterOrder)
	lunatest.assert_equal(attr.userRight, licp1.userRight)
	lunatest.assert_equal(attr.masterRight, licp1.masterRight)
	if attr.trusteeScore > 0 then
		lunatest.assert_equal(attr.score+attr.trusteeScore, licp1.score)
	else
		lunatest.assert_equal(attr.score, licp1.score)
	end
	lunatest.assert_equal(attr.insure, licp1.insure)
	lunatest.assert_equal(attr.medal, licp1.medal)
	lunatest.assert_equal(attr.gift, licp1.gift)
	lunatest.assert_equal(attr.present, licp1.present)
	lunatest.assert_equal(attr.experience, licp1.experience)
	lunatest.assert_equal(attr.loveliness, licp1.loveliness)
	lunatest.assert_equal(attr.winCount, licp1.winCount)
	lunatest.assert_equal(attr.lostCount, licp1.lostCount)
	lunatest.assert_equal(attr.drawCount, licp1.drawCount)
	lunatest.assert_equal(attr.fleeCount, licp1.fleeCount)
	lunatest.assert_equal(attr.contribution, licp1.contribution)
	
	lunatest.assert_equal(attr.tableID, licp2.tableID)
	lunatest.assert_equal(attr.chairID, licp2.chairID)
	lunatest.assert_equal(attr.userStatus, licp2.userStatus)
	lunatest.assert_equal(attr.enListStatus, licp2.enListStatus)
	lunatest.assert_equal(attr.isAndroid, licp2.isAndroid)
	lunatest.assert_equal(attr.agent, licp2.agent)
	lunatest.assert_equal(attr.ipAddr, licp2.ipAddr)
	lunatest.assert_equal(attr.machineID, licp2.machineID)
	
	lunatest.assert_equal(attr.deskCount, licp2.deskCount)
	lunatest.assert_equal(attr.mobileUserRule, licp2.mobileUserRule)
	lunatest.assert_equal(attr.logonTime, licp2.logonTime)
	lunatest.assert_equal(attr.inoutIndex, licp2.inoutIndex)
	
	lunatest.assert_equal(attr.grade, 0)
	lunatest.assert_equal(attr.siteDownScore, 0)
	if attr.score < icp1.score then
		lunatest.assert_equal(attr.trusteeScore, licp1.score-attr.score)
	else
		lunatest.assert_equal(attr.trusteeScore, 0)
	end
	lunatest.assert_equal(attr.frozenedScore, 0)
	lunatest.assert_false(attr.isClientReady)
	lunatest.assert_equal(attr.deskPos, 1)
	
	ServerUserItem.destroy(userItem1)
end

function test_freeze()
	local userItem1 = ServerUserItem.new()
	ServerUserItem.initialize(userItem1, icp1, icp2)
	lunatest.assert_userdata(userItem1)	
	
	local orignalAttr = ServerUserItem.getAttribute(userItem1, {"score", "trusteeScore", "frozenedScore"})
	local totalScore = orignalAttr.score + orignalAttr.trusteeScore + orignalAttr.frozenedScore
	for i=1, 9 do
		local freezeScore = math.floor(totalScore * i / 10);
		ServerUserItem.freezeScore(userItem1, freezeScore)
		local attr1 = ServerUserItem.getAttribute(userItem1, {"score", "trusteeScore", "frozenedScore"})
		
		lunatest.assert_equal(freezeScore, attr1.frozenedScore)
		lunatest.assert_equal(totalScore, attr1.score + attr1.trusteeScore + attr1.frozenedScore)
		
		ServerUserItem.unfreezeScore(userItem1, freezeScore)
		local attr2 = ServerUserItem.getAttribute(userItem1, {"score", "trusteeScore", "frozenedScore"})
		lunatest.assert_equal(orignalAttr.score, attr2.score)
		lunatest.assert_equal(orignalAttr.trusteeScore, attr2.trusteeScore)
		lunatest.assert_equal(orignalAttr.frozenedScore, attr2.frozenedScore)
	end
	
	lunatest.assert_error(function() ServerUserItem.unfreezeScore(userItem1, 100) end)
	ServerUserItem.reset(userItem1)
	lunatest.assert_error(function() ServerUserItem.freezeScore(userItem1, 200) end)
	
	ServerUserItem.destroy(userItem1)
end

function test_writeUserScore()
	local userItem1 = ServerUserItem.new()
	ServerUserItem.initialize(userItem1, icp1, icp2)
	lunatest.assert_userdata(userItem1)	
	
	local scoreInfo = {score=2133, grade=23, revenue=123, medal=290}
	local playTimeCount = 179
	ServerUserItem.writeUserScore(userItem1, scoreInfo, 0x01, playTimeCount)
	
	local attr = ServerUserItem.getAttribute(userItem1, {"isModified"})
	lunatest.assert_true(attr.isModified)

	local variationInfo = ServerUserItem.distillVariation(userItem1).variationInfo
	local attr1 = ServerUserItem.getAttribute(userItem1, {"variationInfo"}).variationInfo
	lunatest.assert_equal(variationInfo.score, scoreInfo.score)
	lunatest.assert_equal(variationInfo.grade, scoreInfo.grade)
	lunatest.assert_equal(variationInfo.revenue, scoreInfo.revenue)
	lunatest.assert_equal(variationInfo.medal, scoreInfo.medal)
	lunatest.assert_equal(variationInfo.playTimeCount, playTimeCount)
	lunatest.assert_equal(variationInfo.experience, math.floor((playTimeCount+59)/60))
	
	lunatest.assert_equal(variationInfo.winCount, 1)
	
	lunatest.assert_equal(attr1.score, 0)
end

--测试异常
function test_exception()
	local userItem1 = ServerUserItem.new()
	ServerUserItem.initialize(userItem1, icp1, icp2)
	lunatest.assert_userdata(userItem1)	
	
	local licp1 = {
		userID=8888,
		gameID=6666,
		platformID=1,
		nickName="看风使舵",
		gender=0,
		faceID=1,
		memberOrder=3,
		masterOrder=1,
		userRight=16,
		masterRight=8,	
		score=8887850,
		insure=7990,
		medal=9550,
		gift=9800,
		present=8600,
		experience=8800,
		loveliness=260,
		winCount=1,
		lostCount=2,
		drawCount=3,
		fleeCount=4,
		contribution=5,
	}
	local licp2 = {
		tableID=21,
		chairID=1,
		userStatus=0x01,
		enListStatus=0x02,

		restrictScore=1000000,
		isAndroid=false,
		agent=1234,
		ipAddr="127.0.0.1",
		machineID="0cc175b9c0f1b6a831c399e269772661",
		deskCount=12,
		mobileUserRule=0x100,
		logonTime=os.time(),
		inoutIndex=1,
	}
	lunatest.assert_error(function() ServerUserItem.initialize(userItem1, licp1, licp2) end)
	lunatest.assert_error(function()
		ServerUserItem.setAttribute(userItem1, {
			userID="圣诞快乐就",
			gameID=6666,
		}) 
	end)

	lunatest.assert_error(function()
		ServerUserItem.setAttribute(userItem1, {
			whatever=123,
		}) 
	end)
	
	licp1 = {
		userID=8888,
		gameID=6666,
		platformID=1,
		nickName="恭喜发财",
		gender=0,
		faceID=1,
		memberOrder=3,
		masterOrder=1,
		userRight=128,
		masterRight=64,
		score=8887850,
		insure=7990,
		medal=9550,
		gift=9800,
		present=8600,
		experience=8800,
		loveliness=260,
		winCount=1,
		lostCount=2,
		drawCount=3,
		fleeCount=4,
		contribution=5,
	}
	licp2 = {
		tableID=21,
		chairID=1,
		userStatus=0x01,
		enListStatus=0x02,

		restrictScore=1000000,
		isAndroid=false,
		agent=1234,
		ipAddr="127.0.0.1",
		machineID="0cc175b9c0f1b6a831c399e269772661",
		deskCount=12,
		mobileUserRule=0x100,
		logonTime=os.time(),
	}	
	
	lunatest.assert_error(function() 
		local ui1 = ServerUserItem.new()
		ServerUserItem.initialize(ui1, licp1, licp2)
	end)
	
	ServerUserItem.destroy(userItem1)
end
--]]
function test_propertyRepository()
	local userItem1 = ServerUserItem.new()
	ServerUserItem.initialize(userItem1, icp1, icp2)
	
	local attr = ServerUserItem.getAttribute(userItem1, {"propertyRepository"})
	--print(string.format("%s\n%s", tostring(userItem1), jsonUtil.serialise_value(attr)))
	
	lunatest.assert_equal(#(attr.propertyRepository), 0)
	
	
	
	local propertyHash = {
		[3] = 5,
		[1] = 30,
		[10] = 88,
	}
	
	local propertyRepository = {}
	for propertyID, propertyCount in pairs(propertyHash) do
		table.insert(propertyRepository, {propertyID=propertyID, propertyCount=propertyCount})
	end
	ServerUserItem.setAttribute(userItem1, {propertyRepository=propertyRepository})
	attr = ServerUserItem.getAttribute(userItem1, {"propertyRepository"})
	--print(string.format("%s\n%s", tostring(userItem1), jsonUtil.serialise_value(attr)))	
	
	for _, item in ipairs(attr.propertyRepository) do
		lunatest.assert_equal(propertyHash[item.propertyID], item.propertyCount)
	end
	
	
	ServerUserItem.addProperty(userItem1, 10, 12)
	attr = ServerUserItem.getAttribute(userItem1, {"propertyRepository"})
	for _, item in ipairs(attr.propertyRepository) do
		if item.propertyID==10 then
			lunatest.assert_equal(100, item.propertyCount)
		end
	end
	
	ServerUserItem.addProperty(userItem1, 1, -20)
	attr = ServerUserItem.getAttribute(userItem1, {"propertyRepository"})
	for _, item in ipairs(attr.propertyRepository) do
		if item.propertyID==1 then
			lunatest.assert_equal(10, item.propertyCount)
		end
	end
	
	ServerUserItem.addProperty(userItem1, 15, 99)
	attr = ServerUserItem.getAttribute(userItem1, {"propertyRepository"})
	for _, item in ipairs(attr.propertyRepository) do
		if item.propertyID==15 then
			lunatest.assert_equal(99, item.propertyCount)
		end
	end
	
	ServerUserItem.addProperty(userItem1, 3, -5)
	attr = ServerUserItem.getAttribute(userItem1, {"propertyRepository"})
	local t
	for _, item in ipairs(attr.propertyRepository) do
		if item.propertyID==3 then
			t = item
		end
	end	
	lunatest.assert_true(t==nil)
	
	lunatest.assert_error(function()
		ServerUserItem.addProperty(userItem1, 11, -5)
	end)
	--print(string.format("%s\n%s", tostring(userItem1), jsonUtil.serialise_value(attr)))	
	
	
	ServerUserItem.destroy(userItem1)
end

function test_signature()
	local userItem1 = ServerUserItem.new()
	ServerUserItem.initialize(userItem1, icp1, icp2)
	
	local attr = ServerUserItem.getAttribute(userItem1, {"signature"})
	lunatest.assert_equal(attr.signature, "")
	
	local signature = "没有中国共产党的努力，没有中国共产党人做中国人民的中流砥柱，中国的独立和解放是不可能的"
	ServerUserItem.setAttribute(userItem1, {signature=signature})
	attr = ServerUserItem.getAttribute(userItem1, {"signature"})
	lunatest.assert_equal(attr.signature, signature)
	
	signature = ""
	ServerUserItem.setAttribute(userItem1, {signature=signature})
	attr = ServerUserItem.getAttribute(userItem1, {"signature"})
	lunatest.assert_equal(attr.signature, signature)
	
	ServerUserItem.destroy(userItem1)
end

function test_platformFace()
	local userItem1 = ServerUserItem.new()
	ServerUserItem.initialize(userItem1, icp1, icp2)
	
	local attr = ServerUserItem.getAttribute(userItem1, {"platformFace"})
	lunatest.assert_equal(attr.platformFace, "")
	
	local platformFace = "223dacb503b1b7159ab4f6cb8a6a2c57"
	ServerUserItem.setAttribute(userItem1, {platformFace=platformFace})
	attr = ServerUserItem.getAttribute(userItem1, {"platformFace"})
	lunatest.assert_equal(attr.platformFace, platformFace)
	
	platformFace = ""
	ServerUserItem.setAttribute(userItem1, {platformFace=platformFace})
	attr = ServerUserItem.getAttribute(userItem1, {"platformFace"})
	lunatest.assert_equal(attr.platformFace, platformFace)
	
	ServerUserItem.destroy(userItem1)
end

function test_gsinfo()
	local userItem1 = ServerUserItem.new()
	ServerUserItem.initialize(userItem1, icp1, icp2)
	
	local attr = ServerUserItem.getAttribute(userItem1, {"kindID", "nodeID", "serverID"})
	lunatest.assert_equal(attr.kindID, 0)
	lunatest.assert_equal(attr.nodeID, 0)
	lunatest.assert_equal(attr.serverID, 0)
	

	ServerUserItem.setAttribute(userItem1, {kindID=1, nodeID=2, serverID=3})
	attr = ServerUserItem.getAttribute(userItem1, {"kindID", "nodeID", "serverID"})
	lunatest.assert_equal(attr.kindID, 1)
	lunatest.assert_equal(attr.nodeID, 2)
	lunatest.assert_equal(attr.serverID, 3)
	
	ServerUserItem.destroy(userItem1)
end

lunatest.run()
