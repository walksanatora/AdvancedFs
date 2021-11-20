-- dbprotect.lua - Protect your functions from the debug library
-- By JackMacWindows
-- Licensed under CC0, though I'd appreciate it if this notice was left in place.

-- Simply run this file in some fashion, then call `debug.protect` to protect a function.
-- It takes the function as the first argument, as well as a list of functions
-- that are still allowed to access the function's properties.
-- Once protected, access to the function's environment, locals, and upvalues is
-- blocked from all Lua functions. A function *can not* be unprotected without
-- restarting the Lua state.
-- The debug library itself is protected too, so it's not possible to remove the
-- protection layer after being installed.
-- It's also not possible to add functions to the whitelist after protecting, so
-- make sure everything that needs to access the function's properties are added.

if debug.protect then return debug.protect end

local protectedObjects
local n_getfenv, n_setfenv, d_getfenv, getlocal, getupvalue, d_setfenv, setlocal, setupvalue, upvaluejoin =
    getfenv, setfenv, debug.getfenv, debug.getlocal, debug.getupvalue, debug.setfenv, debug.setlocal, debug.setupvalue, debug.upvaluejoin

local error, getinfo, running, select, setmetatable, type = error, debug.getinfo, coroutine.running, select, setmetatable, type

local function keys(t, v, ...)
    if v then t[v] = true end
    if select("#", ...) > 0 then return keys(t, ...)
    else return t end
end

function debug.getlocal(thread, level, loc)
    if loc == nil then loc, level, thread = level, thread, running() end
    if type(level) == "function" then
        local caller = getinfo(2, "f")
        if protectedObjects[level] and not (caller and protectedObjects[level][caller.func]) then return nil end
        return getlocal(level, loc)
    elseif type(level) == "number" then
        local info = getinfo(thread, level + 1, "f")
        local caller = getinfo(2, "f")
        if info and protectedObjects[info.func] and not (caller and protectedObjects[info.func][caller.func]) then return nil end
        return getlocal(thread, level + 1, loc)
    else return getlocal(thread, level, loc) end
end

function debug.getupvalue(func, up)
    if type(func) == "function" then
        local caller = getinfo(2, "f")
        if protectedObjects[func] and not (caller and protectedObjects[func][caller.func]) then return nil end
    end
    return getupvalue(func, up)
end

function debug.setlocal(thread, level, loc, value)
    if loc == nil then loc, level, thread = level, thread, running() end
    if type(level) == "number" then
        local info = getinfo(thread, level + 1, "f")
        local caller = getinfo(2, "f")
        if info and protectedObjects[info.func] and not (caller and protectedObjects[info.func][caller.func]) then error("attempt to set local of protected function", 2) end
        return setlocal(thread, level + 1, loc, value)
    else return setlocal(thread, level, loc, value) end
end

function debug.setupvalue(func, up, value)
    if type(func) == "function" then
        local caller = getinfo(2, "f")
        if protectedObjects[func] and not (caller and protectedObjects[func][caller.func]) then error("attempt to set upvalue of protected function", 2) end
    end
    return setupvalue(func, up, value)
end

if n_getfenv then
    function _G.getfenv(f)
        if f == nil then return n_getfenv(2)
        elseif type(f) == "number" and f > 0 then
            local info = getinfo(f + 1, "f")
            local caller = getinfo(2, "f")
            if info and protectedObjects[info.func] and not (caller and protectedObjects[info.func][caller.func]) then return nil end
            return n_getfenv(f+1)
        elseif type(f) == "function" then
            local caller = getinfo(2, "f")
            if protectedObjects[f] and not (caller and protectedObjects[f][caller.func]) then return nil end
        end
        return n_getfenv(f)
    end

    function _G.setfenv(f, tab)
        if type(f) == "number" then
            local info = getinfo(f + 1, "f")
            local caller = getinfo(2, "f")
            if info and protectedObjects[info.func] and not (caller and protectedObjects[info.func][caller.func]) then error("attempt to set environment of protected function", 2) end
            return n_setfenv(f+1, tab)
        elseif type(f) == "function" then
            local caller = getinfo(2, "f")
            if protectedObjects[f] and not (caller and protectedObjects[f][caller.func]) then error("attempt to set environment of protected function", 2) end
        end
        return n_setfenv(f, tab)
    end

    function debug.getfenv(o)
        if type(o) == "function" then
            local caller = getinfo(2, "f")
            if protectedObjects[o] and not (caller and protectedObjects[o][caller.func]) then return nil end
        end
        return d_getfenv(o)
    end

    function debug.setfenv(o, tab)
        if type(o) == "function" then
            local caller = getinfo(2, "f")
            if protectedObjects[o] and not (caller and protectedObjects[o][caller.func]) then error("attempt to set environment of protected function", 2) end
        end
        return d_setfenv(o, tab)
    end
end

if upvaluejoin then
    function debug.upvaluejoin(f1, n1, f2, n2)
        if type(f1) == "function" and type(f2) == "function" then
            local caller = getinfo(2, "f")
            if protectedObjects[f1] and not (caller and protectedObjects[f1][caller.func]) then error("attempt to get upvalue of protected function", 2) end
            if protectedObjects[f2] and not (caller and protectedObjects[f2][caller.func]) then error("attempt to set upvalue of protected function", 2) end
        end
        return upvaluejoin(f1, n1, f2, n2)
    end
end

function debug.protect(func, ...)
    if type(func) ~= "function" then error("bad argument #1 (expected function, got " .. type(func) .. ")", 2) end
    protectedObjects[func] = keys(setmetatable({}, {__mode = "k"}), func, ...)
end

protectedObjects = keys(setmetatable({}, {__mode = "k"}),
    getfenv,
    setfenv,
    debug.getfenv,
    debug.getlocal,
    debug.getupvalue,
    debug.setfenv,
    debug.setlocal,
    debug.setupvalue,
    debug.upvaluejoin,
    debug.protect
)
for k,v in pairs(protectedObjects) do protectedObjects[k] = {[k] = v} end

return debug.protect
