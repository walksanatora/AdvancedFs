local function GenerateVirtualFileTree()
	_G._VTree = {}
	local function recurse(dir,handler,handlerPath)
		if dir == '/' then dir = ''end
		local out = {}
		for _, obj in pairs(handler(dir,'list')) do
			if handler(dir..'/'..obj,'isDir') then
				out[obj] = recurse(dir..'/'..obj,handler,handlerPath)
			else
				out[obj] = handlerPath
			end
		end
		return out
	end
	for path,handler in pairs(_Mounts) do
		local done = ''
		for _,folder in pairs(string.split(path,'/')) do
			if not (folder == '') then
				if not load("if _VTree"..done..'.'..folder..' then return true else return false end')() then
					load("_VTree"..done..'.'..folder..' = {}')()
				end
				done = done .. "." .. folder
			end
		end
		local con = recurse(path,handler,path)
		load("_VTree"..done..'= '..textutils.serialise(con))()
	end
	return _VTree
end

local function GeneratePhysicalFileTree(OldFs)
	_G._PTree = {}
	local function recurse(OldFs,dir)
		if dir == '/' then dir = ''end
		local out = {}
		for _, obj in pairs(OldFs.list(dir)) do
			if OldFs.isDir(dir..'/'..obj) then
				out[obj] = recurse(OldFs,dir..'/'..obj)
			else
				out[obj] = 'fs'
			end
		end
		return out
	end
	_G._PTree = recurse(OldFs,'/')
end

local function reGeneratetree(OldFs)
	GenerateVirtualFileTree()
	GeneratePhysicalFileTree(OldFs)
	if not table.merge then
		error('unnable to find table.merge, did utilFunctions load correctly')
	end
	_G.FsTree = table.merge(_PTree,_VTree)
end

local o = {
	['GeneratePhysicalFileTree'] = GeneratePhysicalFileTree,
	['GenerateVirtualFileTree'] = GenerateVirtualFileTree,
	['reGeneratetree'] = reGeneratetree
}

return o