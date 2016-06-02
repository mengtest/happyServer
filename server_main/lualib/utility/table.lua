table.deepcopy = function(original)
	assert(type(original)=="table", "argument must be a table")
	
	local ret = {}
	for k, v in pairs(original) do
		ret[k] = v
	end
	return ret
end

table.countHash = function(t)
	local i = 0
	for k, v in pairs(t) do
		i = i + 1
	end
	return i
end
