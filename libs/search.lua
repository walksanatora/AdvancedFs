---@diagnostic disable: lowercase-global
---filesystem search API by CoolisTheName007
local fs=fs
local string=string

--The hard work here was writing the iterators to be efficient; for instance they don't use coroutines or recursion.

----DIRECTORY TREE-LIKE SEARCH

local lib = {}

---iterator over files/dirs in directory dir and with maximum depth of search depth, default is infinite
--following refer to the iterator returned, not the iterator created.
--@treturn string path
local function iterTree(dir,depth)
	dir=dir or ''
	if dir=='/' then dir='' end
	local index={0}
	local dir_index={0}
	local ts={{dir,fs.list(dir),{}}}
	local level=1
	local t_dir
	return function()
		repeat
			index[level]=index[level]+1
			name=ts[level][2][index[level]]
			-- print(index,name)
			-- read()
			if name==nil then
				if (not ts[level][4]) and ts[level][3][1] then
					ts[level][4]=true
					ts[level][2],ts[level][3]=ts[level][3],ts[level][2]
					index[level]=0
				else
					level=level-1
					if level==0 then return end
					dir=ts[level][1]
				end
			else
				t_dir=ts[level][1]..'/'..name
				if fs.isDir(t_dir) then
					if ts[level][4] then
						if depth~=level then
							level=level+1
							dir=t_dir
							ts[level]={dir,fs.list(dir),{}}
							index[level]=0
							dir_index[level]=0
						end
					else
						dir_index[level]=dir_index[level]+1
						ts[level][3][dir_index[level]]=name
						break --send dir path
					end
				else
					break
				end
			end
		until false
		return dir..'/'..name
	end
end

lib.iterTree = iterTree

---iterator over files in directory dir and with maximum depth of search depth, default is infinite
--following refer to the iterator returned, not the iterator created.
--@treturn string path
local function iterFiles(dir,depth)
	local iter=iterTree(dir,depth)
	local path
	return function()
		repeat
			path=iter()
			if path then
				if not fs.isDir(path) then
					return path
				end
			else
				return
			end
		until false
	end
end

lib.iterFiles = iterFiles

---iterator over dirs in directory dir and with maximum depth of search depth, default is infinite
--following refer to the iterator returned, not the iterator created.
--@treturn string path
function iterDir(dir,depth)
	local iter=iterTree(dir,depth)
	local path
	return function()
		repeat
			path=iter()
			if path then
				if fs.isDir(path) then
					return path
				end
			else
				return
			end
		until false
	end
end

------GLOBS

--WARNING: for compatibility with Lua ?, ? was replaced by # in globs; taken from https://github.com/davidm/lua-glob-pattern , by davidm
--only needed for filename conversion, slashes are dealt with directly for iteration purposes.
local function globtopattern(g)

  local p = "^"  -- pattern being built
  local i = 0    -- index in g
  local c        -- char at index i in g.

  
    -- unescape glob char
  local function unescape()
    if c == '\\' then
      i = i + 1; c = string.sub(g,i,i)
      if c == '' then
        p = '[^]'
        return false
      end
    end
    return true
  end

  -- escape pattern char
  local function escape(c)
    return c:match("^%w$") and c or '%' .. c
  end
  -- Convert tokens at end of charset.
  local function charset_end()
    while 1 do
      if c == '' then
        p = '[^]'
        return false
      elseif c == ']' then
        p = p .. ']'
        break
      else
        if not unescape() then break end
        local c1 = c
        i = i + 1; c = string.sub(g,i,i)
        if c == '' then
          p = '[^]'
          return false
        elseif c == '-' then
          i = i + 1; c = string.sub(g,i,i)
          if c == '' then
            p = '[^]'
            return false
          elseif c == ']' then
            p = p .. escape(c1) .. '%-]'
            break
          else
            if not unescape() then break end
            p = p .. escape(c1) .. '-' .. escape(c)
          end
        elseif c == ']' then
          p = p .. escape(c1) .. ']'
          break
        else
          p = p .. escape(c1)
          i = i - 1 -- put back
        end
      end
      i = i + 1; c = string.sub(g,i,i)
    end
    return true
  end

  -- Convert tokens in charset.
  local function charset()
    i = i + 1; c = string.sub(g,i,i)
    if c == '' or c == ']' then
      p = '[^]'
      return false
    elseif c == '^' or c == '!' then
      i = i + 1; c = string.sub(g,i,i)
      if c == ']' then
        -- ignored
      else
        p = p .. '[^'
        if not charset_end() then return false end
      end
    else
      p = p .. '['
      if not charset_end() then return false end
    end
    return true
  end
 --Convert tokens.
  while 1 do
	i = i + 1; c = string.sub(g,i,i)
    if c == '' then
      p = p .. '$'
      break
    elseif c == '#' then --?->#
      p = p .. '.'
    elseif c == '*' then
      p = p .. '.*'
    elseif c == '[' then
      if not charset() then break end
    elseif c == '\\' then
      i = i + 1; c = string.sub(g,i,i)
      if c == '' then
        p = p .. '\\$'
        break
      end
      p = p .. escape(c)
    else
      p = p .. escape(c)
    end
  end
  return p
end

---turns a glob into a table structure proper for iterPatterns.
local function compact(g)
	
	local nl={}
	local s1
	local n=0
	for c in string.gmatch(g,'[\\/]*([^/\\]+)[\\/]*') do
		if c:match('^[%w%s%.]*$') then
			s1=s1 and s1..'/'..c or c
		else
			n=n+1
			nl[n]={s1,globtopattern(c)}
			s1=nil
		end
	end
	
	if s1 then
		if n==0 then
			n=n+1
			nl[n]={s1}
		else
			nl[n][3]=s1
		end
	end
	return nl
end

---iterator creator over valid paths defined by a table with the structure: {t1,...,tn}, where ti is:
--for i<n: {dir,pat} - dir is the directory where to look for names matching the pattern pat
--for i=n: {dir,pat,ending} -same but will combine the name (after successful match with pat) with the optional ending (can be nil) and check the resulting path
--e.g., g={{'APIS','*'},{nil,'A'},{'B/C','#','aq/qwerty'}} will search in all subfolders of APIS for subfolders named A, and in each of those for a folder B
--containing a folder C, and for all one-lettered folders in that folder for a folder aq containing a  folder/file named qwerty.
local function iterPatterns(l)
	local n=#l
	if n==0 then return function () end end
	if n==1 and not l[1][2] and fs.exists(l[1][1]) then
		local done=false
		return function ()
				if not done then
					done=true
					return l[1][1]
				else
					return
				end
			end
	end
	local dir=l[1][1]
	local index={0}
	local ts
	ts={{dir,fs.isDir(dir) and fs.list(dir) or {}}}
	local level=1
	local t_dir
	local _
	return function()
		repeat
			index[level]=index[level]+1
			name=ts[level][2][index[level]]
			if name==nil then
					index[level]=nil
					level=level-1
					if level==0 then return end
					dir=ts[level][1]
			else
				if string.match(name,l[level][2]) then
					t_dir=dir..'/'..name
					if level==n then
						_=l[level][3]
						if _ then
							t_dir=t_dir..'/'.._
							if fs.exists(t_dir) then
								path=t_dir
								break
							end
						else
							path=t_dir
							break
						end
					elseif fs.isDir(t_dir) then
						level=level+1
						_=l[level][1]
						if _ then
							t_dir=t_dir..'/'.._
							if fs.exists(t_dir) then
								dir=t_dir
								ts[level]={dir,fs.list(dir)}
								index[level]=0
							else
								level=level-1
							end
						else
							dir=t_dir
							ts[level]={dir,fs.list(dir)}
							index[level]=0
						end
					end
				end
			end
		until false
		return path, index
	end
end

---iterator creator, over the valid paths defined by glob @g, e.g */filenumber?to
-- see the unix part of the table at http://en.wikipedia.org/wiki/Glob_(programming) .
--@treturn string path to matching of the dir
--@usage
--for path in search.iterGlob('*/stuff?/a*') do
--	print(path)
--end
--APIS/stuff1/a.lua
--var/stuff2/a.var
local function iterGlob(g)
	return iterPatterns(compact(g))
end
lib.iterGlob = iterGlob

--iterator over glob @g with ? replaced by @s
local searchGlob = function (g,s)
	g=string.gsub(g,'%?',s)
	local iter=iterGlob(g)
	local path
	return function ()
		repeat
			path=iter()
			if path then
				if not fs.isDir(path) then	
					return path
				end
			else
				break
			end
		until false
	end
end
lib.searchGlob = searchGlob

local function getNameExpansion(s) --returns name and expansion from a filepath @s; special cases: ''->'',nil; '.'-> '','';
	--s string = filename
	--returns: name, expansion
	--Example
	--print(getNameExpansion('filename.lua.kl'))
	--filename
	--lua.kl
	local _,_,name,expa=string.find(s, '([^%./\\]*)%.(.*)$')
	return name or s,expa
end
local function getDir(s) --returns directory from filepath @s
	return string.match(s,'^(.*)/') or '/'
end
lib.getNameExpansion, lib.getDir = getNameExpansion, getDir

--iterator over directory @p searching for @p...@s, where @s is a glob.
local searchTree = function (p,s)
	if not p:match('%?') and fs.isDir(p) then
		if p=='/' then p='' end
		local iter=iterFiles(p)
		local path
		return function ()
			repeat
				path=iter()
				if path then
					if string.match(path,s..'$') and not string.match(path,'[^/]'..s..'$') then
						return path
					end
				else
					break
				end
			until false
		end
	else
		return function() end
	end
end
lib.searchTree = searchTree

return lib