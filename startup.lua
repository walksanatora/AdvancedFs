--Advanced FileSystem loader script

--loads some utils into _G
require('libs.utilFunctions').LoadIntoG()
--loads other libs into locals
local regenFSList = require('libs.folderTree').reGeneratetree
local dbProtect = require('libs.dbprotect')
local search = require('libs.search')

--mounts should be in the pattern of {"/mount/path": MountFunctionWhichTakes(path)}
_G._Mounts = {}

local OldFS = DeepCopy(fs)
local NewFS = {}
local function startup()
local utils = {}

--[[
Checks if you have permissions to perform the specified action
append requires read+write permissions
write requres write permissions
read requires read permissions
@tparam string path the path to check
@tparam string action the action to check permissions on
@treturn boolean whether or not the action is allowed
]]--
function NewFS.checkPermissions(path,action)
	local attrs = NewFS.attributes(path)
	local perm = attrs.permissions
	if string.find(action,'a') and perm.read and perm.write then
		return true
	elseif string.find(action,'w') and perm.write then
		return true
	elseif string.find(action,'r') and perm.read then
		return true
	else
		return false
	end
end

local function SlightlyModifiedFSAttr(path)
	local data = OldFS.attributes(path)
	local permissions = {}
	permissions.read = true
	permissions.write = false
	if not OldFS.isReadOnly(path) then
		permissions.write = true
	end
	data.permissions = permissions
	data.path = path
	return data
end

--[[
Returns a function to open the file
]]--
function NewFS.resolveHandler(inpath,intype,inopt)
	local function internal(path,type,opt)
		for mPath, Function in pairs(_G._Mounts) do
			if path:find(mPath,1,#mPath) then
				return Function(path,type,opt)
			end
		end
		if type == 'open' then
			return OldFS.open(path,opt['mode'])
		elseif type == 'attributes' then
			return SlightlyModifiedFSAttr(path)
		elseif type == 'list' then
			return OldFS.list(path)
		elseif type == 'isDir' then
			return OldFS.isDir(path)
		elseif type == 'copy' then
			return OldFS.copy(path,opt['dest'])
		elseif type == 'delete' then
			return OldFS.delete(path)
		elseif type == 'move' then
			return OldFS.move(path,opt['dest'])
		elseif type == 'makeDir' then
			return OldFS.makeDir(path)
		else
			print('unable to resolve type',type)
			print('traceback:\n',debug.traceback())
		end
	end
	return internal(inpath,intype,inopt or {})
end

--[[
Creates a file manager for either a real or custom file
@tparam path the path of the file
@tparam string mode the mode of the file to open into
@treturn fileHandler for the file
]]--
local function createFileManager(path,mode)
	if not NewFS.checkPermissions(path,mode) then
		error('unable to use file, permission denied')
	end
	local fileManager = {}
	local buffer = ''
	local closed = false
	local Binary = mode:find('b')

	--create handler functions
	if mode:find('a') or mode:find('w') then
		if mode:find('a') then
			if not Binary then
				local f = NewFS.resolveHandler(path,'open',{['mode'] = 'r'})
				buffer = f.readAll()
				f.close()
				f=nil
			else
				local f = NewFS.resolveHandler(path,'open',{['mode'] = 'rb'})
				buffer = f.readAll()
				f.close()
				f=nil
			end
		end
		function fileManager.close()
			if closed then error('file handler closed') end
			local f = NewFS.resolveHandler(path,'open',{['mode'] = mode})
			f.write(buffer)
			f.close()
			closed = true
			f=nil
		end
		function fileManager.flush()
			if closed then error('file handler closed') end
			local f
			if not Binary then
				f = NewFS.resolveHandler(path,'open',{['mode'] = 'w'})
			else
				f=NewFS.resolveHandler(path,'open',{['mode'] = 'wb'})
			end
			f.write(buffer)
			f.close()
			f=nil
		end
		function fileManager.write(content)
			buffer = buffer .. content
		end
		function fileManager.writeLine(content)
			buffer = buffer .. content .. '\n'
		end
	else
		local f = NewFS.resolveHandler(path,'open',{['mode'] = 'r'})
		buffer = f.readAll()
		f.close()
		f=nil
		function fileManager.close()
			closed = true
			buffer = ""
		end
		function fileManager.readAll()
			if closed then error('file handler closed') end
			if buffer == '' then return nil end
			local bc = buffer
			buffer = ''
			return bc
		end
		function fileManager.read(bytes)
			if closed then error('file handler closed') end
			local data
			data,buffer = buffer:sub(1,bytes),buffer:sub(bytes+1)
			return data
		end
		function fileManager.readLine()
			if closed then error('file handler closed') end
			local retval
			retval,buffer =buffer:match("([^\n]*)\n(.*)")
			buffer = buffer or ""
			return retval
		end
	end

	return fileManager
end

function NewFS.isDriveRoot(path)
	return OldFS.isDriveRoot(path)
end

function NewFS.complete(path,location,...)
	return OldFS.complete(path,location,...)
end

--[[
ReGenerates the Filesystem tree which allows list to work
]]--
function NewFS.regenTree()
	regenFSList(OldFS)
end

function NewFS.list(path)
	if not FsTree then
		regenFSList(OldFS)
	end
	local f = OldFS.open('/list.txt','a')
	local spth = string.split(path,'/')
	f.write(textutils.serialiseJSON(spth))
	f.flush()
	local tree = DeepCopy(FsTree)
	for k, v in pairs(spth) do
		if not (v == '') then
			if tree[v] then
				tree = tree[v]
			else
				break
			end
		end
	end
	local out = {}
	if type(tree) == "table" then
		for k,v in pairs(tree) do
			table.insert(out,#out+1,k)
		end
	end
	f.write(textutils.serialiseJSON(out)..'\n\n')
	f.close();f=nil
	return out
end

function NewFS.combine(path, ...)
	return OldFS.combine(path, ...)
end

function NewFS.getName(path)
	local name = string.split(path,'/')
	local fname = name[#name]
	return fname
end

function NewFS.getDir(path)
	local dir = string.split(path,'/')
	table.remove(dir,#dir)
	return table.concat(dir,'/')
end

function NewFS.getSize(path)
	return NewFS.attributes(path).size
end

function NewFS.exists(path)
	local st = path:sub(1,1)
	if (st ~= '/') or (path:sub(1,2) == './') then
		path = shell.dir()..'/'..path
	end
	for mPath, _ in pairs(_G._Mounts) do
		if path:find(mPath or '/',1,(#mPath or 1) ) then
			return true
		end
	end
	return OldFS.exists(path)
end

function NewFS.isDir(path)
	if not FsTree then
		regenFSList(OldFS)
	end
	local spth = string.split(path,'/')
	local tree = DeepCopy(FsTree)
	for k, v in pairs(spth) do
		if not ((v or '') == '') then
			if tree[v] then
				tree = tree[v]
			else
				tree = tree
			end
		end
	end
	return((type(tree)=="table"))
end

function NewFS.isVirtualDir(path)
	local st = path:sub(1,1)
	if (st ~= '/') or (path:sub(1,2) == './') then
		path = shell.dir()..'/'..path
	end
	for mPath, _ in pairs(_G._Mounts) do
		if path:find(mPath,1,#mPath) then
			return true
		end
	end
	return false
end

function NewFS.isPhysicalDir(path)
	return not NewFS.isVirtualDir(path)
end

function NewFS.isReadOnly(path)
	return not NewFS.attributes(path,'attributes').permissions.write
end

function NewFS.makeDir(path)
	return NewFS.resolveHandler(path,'makeDir')
end

function NewFS.move(path,dest)
	return NewFS.resolveHandler(path,'move',{['dest']=dest})
end

function NewFS.copy(path,dest)
	return NewFS.resolveHandler(path,'copy',{['dest']=dest})
end

function NewFS.delete(path)
	return NewFS.resolveHandler(path,'delete')
end

function NewFS.open(file,mode)
	return createFileManager(file,mode)
end

function NewFS.getDrive(path)
	return OldFS.getDrive(path)
end

function NewFS.getFreeSpace(path)
	return OldFS.getFreeSpace(path)
end

function NewFS.find(path)
	local out = {}
	for fpath in search.iterGlob(path) do
		table.insert(out,#out+1,fpath)
	end
	return out
end

function NewFS.getCapacity(path)
	return OldFS.getCapacity(path)
end

function NewFS.attributes(path)
	return NewFS.resolveHandler(path,'attributes')
end

local unlockKey = math.random(1,100000)
local tmpfs = OldFS.open('.lock','w')
tmpfs.write(unlockKey)
tmpfs.close()
tmpfs = nil
function NewFS.restoreOldFS(key)
	if key == unlockKey then
		print('restoring fs')
		_G.Nfs = DeepCopy(fs)
		_G.fs = OldFS
	end
	print('done')
end

for _,v in pairs(NewFS) do debug.protect(v) end

_G.fs = NewFS
--_G.NFS=NewFS
end

if settings.get('enableNewFs') then

local fail, res = xpcall(startup,debug.traceback)
if not fail then 
	print('error loading fs')
	local tb = debug.traceback()
	_G.fs = OldFS
	local file = fs.open('/.traceback.txt','a')
	file.write(tb..'\n\n')
	file.close()
	print('restored old fs, traceback writton to .traceback.txt')
	print(tb)
end
else
	print('not loading newFS')
end