local skynet = require "skynet"

-- 牌
local _cards = {
	0x0C,0x2C,
	0x1B,0x3B,
	0x0A,0x1A,0x2A,0x3A,
	0x09,0x29,
	0x07,0x17,0x27,0x37,
	0x08,0x18,0x28,0x38,
	0x06,0x16,0x26,0x36,
	0x05,0x25,
	0x04,0x14,0x24,0x34,
	0x02,0x22,
	0x31,
	0x33
}
-- 牌型
local _cardsType = {}

local round = 0 -- 第几轮

--逻辑大小
local function _getCardLogicValue(cardData)
	--获取花色
	local cbColor= math.floor(cardData / 0x10)

	--获取数值
	local cbValue= cardData % 0x10

	--返回逻辑值
	if (12==cbValue and (0==cbColor or 2==cbColor)) then
		return 8
	end
	
	if (2==cbValue and (0==cbColor or 2==cbColor)) then
		return 7
	end
	
	if (8==cbValue and (0==cbColor or 2==cbColor)) then
		return 6
	end
	
	if (4==cbValue and (0==cbColor or 2==cbColor)) then
		return 5
	end

	if ((1==cbColor or 3==cbColor) and (10==cbValue or 6==cbValue or 4==cbValue)) then
		return 4
	end

	if ((0==cbColor or 2==cbColor) and (10==cbValue or 6==cbValue or 7==cbValue)) then
		return 3
	end
	if ((1==cbColor or 3==cbColor) and 11==cbValue) then
		return 3
	end

	if ((1==cbColor or 3==cbColor) and (7==cbValue or 8==cbValue)) then
		return 2
	end
	if ((0==cbColor or 2==cbColor) and (5==cbValue or 9==cbValue)) then
		return 2
	end

	if (3==cbColor and (1==cbValue or 3==cbValue)) then
		return 1
	end

	return 0
end

-- 设置每对牌值
local function _setCardType()
	local first, second, fv, sv, fc, sc
	for i=2,#_cards,2 do
		first = _cards[i-1] 
		second = _cards[i] 
		fv = first % 0x10
		sv = second % 0x10
		if fv < sv or (fv == sv and first < second) then
			--交换位置
			first, second = second, first
			fv, sv = sv, fv
		end
		fc = math.floor(first / 0x10)
		sc = math.floor(second / 0x10)
	
		--特殊牌型
		if ((3+3)==(fc+sc) and (1==fv and 3==sv or 3==fv and 1==sv)) then _cardsType[i/2] = 20
		elseif (12==fv and fv==sv) then _cardsType[i/2] = 19
		elseif ((0+2)==(fc+sc) and fv==sv and 2==fv) then _cardsType[i/2] = 18
		elseif ((0+2)==(fc+sc) and fv==sv and 8==fv) then _cardsType[i/2] = 17
		elseif ((0+2)==(fc+sc) and fv==sv and 4==fv) then _cardsType[i/2] = 16
		elseif ((1+3)==(fc+sc) and fv==sv and 10==fv) then _cardsType[i/2] = 15
		elseif ((1+3)==(fc+sc) and fv==sv and 6==fv) then _cardsType[i/2] = 15
		elseif ((1+3)==(fc+sc) and fv==sv and 4==fv) then _cardsType[i/2] = 15
		elseif ((0+2)==(fc+sc) and fv==sv and 6==fv) then _cardsType[i/2] = 14
		elseif ((0+2)==(fc+sc) and fv==sv and 7==fv) then _cardsType[i/2] = 14
		elseif ((0+2)==(fc+sc) and fv==sv and 10==fv) then _cardsType[i/2] = 14
		elseif ((1+3)==(fc+sc) and fv==sv and 11==fv) then _cardsType[i/2] = 14
		elseif ((1+3)==(fc+sc) and fv==sv and 7==fv) then _cardsType[i/2] = 13
		elseif ((1+3)==(fc+sc) and fv==sv and 8==fv) then _cardsType[i/2] = 13
		elseif ((0+2)==(fc+sc) and fv==sv and 9==fv) then _cardsType[i/2] = 13
		elseif ((0+2)==(fc+sc) and fv==sv and 5==fv) then _cardsType[i/2] = 13
		elseif (12==fv and 9==sv) then _cardsType[i/2] = 12
		elseif (12==fv and 8==sv) then _cardsType[i/2] = 11
		elseif (8==fv and 2==sv) then _cardsType[i/2] = 10
		--点数牌型
		else
			local temp = 0
			temp = ((fv==1 and 6) or fv) + ((sv==1 and 6) or sv)
			_cardsType[i/2] = temp % 10
		end
	end
end

-- 洗牌
local function shuffle()
	round = 0
	math.randomseed(skynet.self()*100 + skynet.now())
	local n = #_cards
	for i=1, n-1 do
		local j = math.random(i, n)
		local temp = _cards[i]
		_cards[i] = _cards[j]
		_cards[j] = temp
	end
	
	--计算牌型
	_setCardType()
end

-- return {card={},result={}} index=1~4表示庄家牌位置
local function getPlayingCards(index)
	if round >= 4 then
		shuffle()
	end
	local card = {}
	local result = {}
	for i=1,8 do
		table.insert(card, _cards[round*8+(index*2-3+i)%8 + 1])
	end
	local bankNum = _cardsType[round*4+index]
	local playNum
	local temp1 = _getCardLogicValue(card[1])
	local temp2 = _getCardLogicValue(card[2])
	local banker = temp1 > temp2 and temp1 or temp2 --庄家最大逻辑牌
	for i=2,4 do
		playNum = _cardsType[round*4+(index-2+i)%4 + 1]
		if bankNum < playNum then
			result[i-1] = 1
		elseif bankNum == playNum then
			temp1 = _getCardLogicValue(card[i*2-1])
			temp2 = _getCardLogicValue(card[i*2])
			local player = temp1 > temp2 and temp1 or temp2 --xian家最大逻辑牌
			if bankNum < 10 and bankNum ~= 0 and player > banker then
				result[i-1] = 1
			else
				result[i-1] = 0
			end
		else 
			result[i-1] = 0
		end
	end
	return card, result
end

local function cardEnd()
	round = round + 1
end

local function getRound()
	return round
end


return {
	getRound = getRound,
	shuffle = shuffle,
	getPlayingCards = getPlayingCards,
	cardEnd = cardEnd,
}
