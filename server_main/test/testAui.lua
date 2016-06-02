local AndroidUserItem = require "aui"
local jsonUtil = require "cjson.util"
local lunatest = require "lunatest"

local param1 = {
	userID=3290,
	serverID=106,
	minPlayDraw=10,
	maxPlayDraw=100,
	minTakeScore=100000,
	maxTakeScore=1000000,
	minReposeTime=30,
	maxReposeTime=60,
	serviceTime=8388544,
	serviceGender=7,
}

local param2 = {
	userID=3291,
	serverID=106,
	minPlayDraw=10,
	maxPlayDraw=100,
	minTakeScore=100000,
	maxTakeScore=1000000,
	minReposeTime=30,
	maxReposeTime=60,
	serviceTime=8388544,
	serviceGender=7,
}

--测试比较
function test_equality()
	
	local androidItem1 = AndroidUserItem.new()
	AndroidUserItem.initialize(androidItem1, param1, 100, 15)
	
	local androidItem2 = AndroidUserItem.new()
	AndroidUserItem.initialize(androidItem2, param2, 100, 15)

	lunatest.assert_equal(androidItem1, androidItem1);
	lunatest.assert_not_equal(androidItem1, androidItem2);
	
	AndroidUserItem.destroy(androidItem1)
	AndroidUserItem.destroy(androidItem2)
end

--测试获取全部数据
function test_attribute_get()
	local androidItem1 = AndroidUserItem.new()
	AndroidUserItem.initialize(androidItem1, param1, 100, 15)
	
	local attr = AndroidUserItem.getAttribute(androidItem1, {
		"androidParameter", "residualPlayDraw", "reposeTime",
	})

	print(string.format("%s\n%s", tostring(androidItem1), jsonUtil.serialise_value(attr)))
	
	lunatest.assert_equal(attr.androidParameter.userID, param1.userID)
	lunatest.assert_equal(attr.androidParameter.serverID, param1.serverID)
	lunatest.assert_equal(attr.androidParameter.minPlayDraw, param1.minPlayDraw)
	lunatest.assert_equal(attr.androidParameter.maxPlayDraw, param1.maxPlayDraw)
	lunatest.assert_equal(attr.androidParameter.minTakeScore, param1.minTakeScore)
	lunatest.assert_equal(attr.androidParameter.maxTakeScore, param1.maxTakeScore)
	lunatest.assert_equal(attr.androidParameter.minReposeTime, param1.minReposeTime)
	lunatest.assert_equal(attr.androidParameter.maxReposeTime, param1.maxReposeTime)
	lunatest.assert_equal(attr.androidParameter.serviceTime, param1.serviceTime)
	lunatest.assert_equal(attr.androidParameter.serviceGender, param1.serviceGender)
	
	lunatest.assert_equal(attr.residualPlayDraw, 100)
	lunatest.assert_equal(attr.reposeTime, 15)

	AndroidUserItem.destroy(androidItem1)
end

--测试scale value
function test_attribute_set()
	local androidItem1 = AndroidUserItem.new()
	AndroidUserItem.initialize(androidItem1, param1, 100, 15)
	
	local orignalAttr = AndroidUserItem.getAttribute(androidItem1, {
		"androidParameter", "residualPlayDraw", "reposeTime",
	})
	
	AndroidUserItem.setAttribute(androidItem1, {androidParameter=param2, residualPlayDraw=101})
	local attr = AndroidUserItem.getAttribute(androidItem1, {
		"androidParameter", "residualPlayDraw", "reposeTime",
	})

	lunatest.assert_equal(orignalAttr.androidParameter.userID, param1.userID)
	lunatest.assert_equal(orignalAttr.androidParameter.serverID, param1.serverID)
	lunatest.assert_equal(orignalAttr.androidParameter.minPlayDraw, param1.minPlayDraw)
	lunatest.assert_equal(orignalAttr.androidParameter.maxPlayDraw, param1.maxPlayDraw)
	lunatest.assert_equal(orignalAttr.androidParameter.minTakeScore, param1.minTakeScore)
	lunatest.assert_equal(orignalAttr.androidParameter.maxTakeScore, param1.maxTakeScore)
	lunatest.assert_equal(orignalAttr.androidParameter.minReposeTime, param1.minReposeTime)
	lunatest.assert_equal(orignalAttr.androidParameter.maxReposeTime, param1.maxReposeTime)
	lunatest.assert_equal(orignalAttr.androidParameter.serviceTime, param1.serviceTime)
	lunatest.assert_equal(orignalAttr.androidParameter.serviceGender, param1.serviceGender)

	lunatest.assert_equal(attr.androidParameter.userID, param2.userID)
	lunatest.assert_equal(attr.androidParameter.serverID, param2.serverID)
	lunatest.assert_equal(attr.androidParameter.minPlayDraw, param2.minPlayDraw)
	lunatest.assert_equal(attr.androidParameter.maxPlayDraw, param2.maxPlayDraw)
	lunatest.assert_equal(attr.androidParameter.minTakeScore, param2.minTakeScore)
	lunatest.assert_equal(attr.androidParameter.maxTakeScore, param2.maxTakeScore)
	lunatest.assert_equal(attr.androidParameter.minReposeTime, param2.minReposeTime)
	lunatest.assert_equal(attr.androidParameter.maxReposeTime, param2.maxReposeTime)
	lunatest.assert_equal(attr.androidParameter.serviceTime, param2.serviceTime)
	lunatest.assert_equal(attr.androidParameter.serviceGender, param2.serviceGender)
	
	lunatest.assert_equal(attr.residualPlayDraw, 101)
	lunatest.assert_equal(orignalAttr.reposeTime, 15)	
	
	AndroidUserItem.destroy(androidItem1)
end

lunatest.run()
