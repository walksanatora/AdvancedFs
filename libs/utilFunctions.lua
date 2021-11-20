local out = {}

local function BetterStringSplit(self,delim)
	local res = {}
	local from = 1
	local delim_from, delim_to = string.find(self,delim,from)
	while delim_from do
		table.insert(res,string.sub(self,from,delim_from-1))
		from = delim_to + 1
		delim_from, delim_to = string.find(self, delim, from)
	end
	table.insert(res,string.sub(self,from))
	return res
end

local function merge(t1,t2)
	for k,v in pairs(t2) do
		if type(v) == 'table' then
			if type(t1[k]or false) == 'table' then
				merge(t1[k] or {},t2[k] or {})
			else
				t1[k] = v
			end
		else
			t1[k] = v
		end
	end
	return t1
end

local function DeepCopy(obj,seen)
	--handle non-tables and previously-seen tables
	if type(obj) ~="table" then return obj end

	--make a New table; then mark as seen and then copy recursively
	local s = seen or {}
	local res = {}
	s[obj] = res
	for k, v in pairs(obj) do res[DeepCopy(k,s)] = DeepCopy(v,s)end
	return setmetatable(res,getmetatable(obj))
end

function out.LoadIntoG()
	_G.DeepCopy = DeepCopy
	_G.table.merge = merge
	_G.string.split = BetterStringSplit
end

function out.LoadIntoTable()
	local o = {}
	o.DeepCopy = DeepCopy
	o.MergeTables =  merge
	o.BetterStringSplit = BetterStringSplit
	return o
end

return out