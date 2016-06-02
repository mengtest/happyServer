package.path = package.path .. ";../lualib/?.lua"
package.cpath = package.cpath .. ";../luaclib/?.so"
local wordFilterUtility = require "wordfilter"

local filterObj1 = wordFilterUtility.new()

local wordList = {"出售美女", "出售妹妹", "出售枪支", "出售手枪", "雏妓", "处男出售", "处女", "处女出售", "处女地", "处女膜", "处女穴", "处女终结者", "處女", "處女膜", "川島和津實", "传奇SF", "传奇sfQQ", "传奇SF发布", "传奇SF怀旧", "传奇sf开服", "传奇SF开区", "传奇sf制作", "传奇sf制作开区", "传奇私服", "传奇销售", "传奇一条龙", "传奇一条龙都包括", "传奇游戏一条龙", "传世SF", "传世私服", "床上猛男"}

for _, word in ipairs(wordList) do
	wordFilterUtility.addWord(filterObj1, word)
end

local filterObj2 = wordFilterUtility.copy(filterObj1)

print(filterObj1, filterObj2)


local sentenceList = {
	"萨拉独处女家开发萨处男出售的路口附近处女为空",
	"舍得离开了传世SF现场joi请我克里斯房床上猛男间里的三大类似的",
	"深度下挫传奇SF怀旧空间里看见了为期雏妓可谓经历快速的",
	"sad西侧紧邻空處女间颇为i厄泼處女膜i苏东坡iuxcioxciu",
}

for _, str in ipairs(sentenceList) do
	print(wordFilterUtility.doFiltering(filterObj1, str), wordFilterUtility.hasMatch(filterObj1, str))
end

print("============================================")
wordFilterUtility.destroy(filterObj1)
filterObj1 = nil

for _, str in ipairs(sentenceList) do
	print(wordFilterUtility.doFiltering(filterObj2, str), wordFilterUtility.hasMatch(filterObj2, str))
end

wordFilterUtility.destroy(filterObj2)
