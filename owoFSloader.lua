if not fs.regenTree then error('Advanced Filesystem not loaded') end

local function owoOpenHandler(path,mode)
	if string.find(mode,'w') or string.find(mode,'a') then
		error('file cannot be opened in write/append mode mode')
	end
	local obj ={}
	function obj.close()
	end --does nothing lel
	function obj.readAll()
		return "owo\nweeabo"
	end
	return obj
end

local function owoAttrHandler(file)
	local data = {}
	data.created = 0
	data.isDir = false
	data.isReadOnly = true
	data.modification = 0
	data.size = 1
	local permissions = {}
	permissions.read = true
	permissions.write = false
	data.permissions = permissions
	return data
end

local function owoListHandler(path)
	local list = {}
	table.insert(list,1,'owofile')
	return list
end

local function owoIsDirHandler(path)
	return (path == '/owo')
end

local function owoNoAction(path)
	return nil
end

local function loader(path,type,opt)
	if type == 'open' then
		return owoOpenHandler(path,opt['mode'])
	elseif type == 'attributes' then
		return owoAttrHandler(path)
	elseif type == 'list' then
		return owoListHandler(path)
	elseif type == 'isDir' then
		return owoIsDirHandler(path)
	elseif type == 'move' then
		return owoNoAction() --todo: implement move handler
	elseif type == 'copy' then
		return owoNoAction() --todo: implement copy handler (or fallback to Open,Write)
	elseif type == 'delete' then
		return owoNoAction() --todo: implement delete handler
	elseif type == 'makeDir' then
		return owoNoAction() --todo: implement make dir handler
	end
end
_G._Mounts['/owo'] = loader
print('mounted OWO to /owo')
fs.regenTree()
print('regenerated filetree')