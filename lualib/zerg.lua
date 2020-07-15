local zerg = {}

--log
function zerg.info(...) 
    zergcore.log(0, ...)
end

function zerg.warning(...) 
    zergcore.log(1, ...)
end

function zerg.error(...) 
    zergcore.log(2, ...)
end

-- protocol
local proto = {}
function zerg.register_protocol(class) 
    local name = class.name
    local id = class.id
    assert(proto[name] == nil and proto[id] == nil)
    assert(type(name) == "string" and type(id) == "number" and id >= 0 and id <= 255)
    proto[name] = class
    proto[id] = class
end

-- --co data struct
local session_id_coroutine = {}                         -- 根据session找到他的co
local session_coroutine_id = {}                         -- 根据co找到他的id
local session_coroutine_address = {}                    -- 根据co找到他的属于哪一个服务
local session_response = {}								-- 表示某个session已经response了,不要再重复response

local wakeup_queue = {}									-- 缓存从sleep中中断的那些co
local sleep_session = {}                                

local dead_service = {}                                 -- 记录那些已经死掉的服务

local fork_queue = {}                                   -- 轻量线程

local watching_session = {}                             -- 记录的是我正在call的线程
local error_queue = {}                                  -- 
local watching_service = {}                             -- 记录的是我被哪些service发了消息



-- co reuse
-- local coroutine_pool = setmetatable({}, { __mode == "kv" })
local coroutine_pool = {}

local function co_create(f) 
    local co = coroutine.create(function(...) 
        f(...)

        while true do
            f = nil
            table.insert(coroutine_pool, co)
            f = coroutine.yield "EXIT"
            f(coroutine.yield())
        end
    end)
    return co
end

local function dispatch_wakeup()
    local co = table.remove(wakeup_queue)
    if co then
        local session = sleep_session[co]
        if session then
            session_id_coroutine[session] = "BREAK"
            return scheduler(co, coroutine.resume(co, false, "BREAK"))
        end
    end
end

function zerg.timeout(time, func) 
    local session = zergcore.command("TIMEOUT", time)
    local co = co_create(func)
    assert(session_id_coroutine[session] == nil)
    session_id_coroutine[session] = co
end

local function dispatch_error_queue() 
    local session = zergcore.tblremove(error_queue, 1)
    if session then
        local co = session_id_coroutine[session]
        session_id_coroutine[session] = nil
        return scheduler(co, coroutine.resume(co, false))
    end
end

local function _error_dispatch(error_session, error_source)
    if error_session == 0 then 

        -- why this is zero
        if watching_service[error_source] then
            dead_service[error_source] = true
        end

        for session, srv in pairs(watching_service) do
            if srv == error_source then
                table.insert(error_queue, session)
            end
        end
    else
        if watching_session[error_session] then
            table.insert(error_queue, watching_session[error_session])
        end
    end
end

local function release_watching(address) 
    local ref = watching_service[address]
    if ref then
        ref = ref - 1
        if ref > 0 then
            watching_service[address] = ref
        else
            watching_service[address] = nil
        end
    end
end

local function scheduler(co, result, command, param) 
    if not result then      -- 出错误的时候会传入false
        local session = session_coroutine_id[co]
        if session then
            local addr = session_coroutine_address[co]
            if session ~= 0 then
                zergcore.send(addr, zerg.PTYPE_ERROR, session, "")
            end
            session_coroutine_id[co] = nil
            session_coroutine_address[co] = nil
        end
        -- TODO error
    end

    if command == "CALL" then
        session_id_coroutine[param] = co
    elseif command == "SLEEP" then
        session_id_coroutine[param] = co
        sleep_session[co] = param
    elseif command == "RETURN" then
        local co_session = session_coroutine_id[co]
        if co_session == 0 then
            return scheduler(co, coroutine.resume(co, false))
        end

        local co_address = session_coroutine_address[co]
        if param == nil or session_response[co] then
            -- error
        end

        session_response[co] = true
        local ret 
        if not dead_service[co_address] then
            ret = zergcore.send(co_address, zergcore.PTYPE_RESPONSE, co_session, param) ~= nil
            if not ret then
                zergcore.send(co_address, zergcore.PTYPE_ERROR, co_session, "")
            end
        end

        return scheduler(co, coroutine.resume(co, ret))
    elseif command == "RESPONSE" then
        local co_session = session_coroutine_id[co]
        local co_address = session_coroutine_address[co]
        if session_response[co] then
            -- TOD
        end
        local f = param
        local function response(ok, ...) 
            if not f then
                if f == false then
                    f = nil
                    return false
                end
                --TODO
            end
            local ret
            if co_session ~= 0 and not dead_service[co_address] then
                if ok then          -- ok coroutin.resume return value
                    ret = zergcore.send(co_address, zergcore.PTYPE_RESPONSE, co_session, f(...)) ~= nil
                    if not ret then
                        ret = zergcore.send(co_address, zergcore.PTYPE_ERROR, co_session, "") ~= nil
                    end
                else
                    ret = zergcore.send(co_address, zergcore.PTYPE_ERROR, co_session, "") ~= nil
                end
            else
                ret = false
            end

            release_watching(co_address)

            f = nil
            return ret
        end

        watching_service[co_address] = watching_service[co_address] + 1
        session_response[co] = true
        return scheduler(co, coroutine.resume(co, response))
    elseif command == "QUIT" then
        return
    elseif command == "EXIT" then
        -- coroutine exit
        local address = session_coroutine_address[co]
        release_watching(address)
        session_coroutine_id[co] = nil
        session_coroutine_address[co] = nil
    elseif command == nil then
    else
        print("Unknown command: ", command, "\n")
    end

    dispatch_wakeup()
    dispatch_error_queue()
end

function zerg.dispatch(typename, func) 
    local p = proto[typename]
    if func then
        local ret = p.dispatch
        p.dispatch = func
        return ret
    else
        return p and p.dispatch
    end
end

local function raw_dispatch_message(prototype, session, source, msg) 
    if prototype == zergcore.PTYPE_RESPONSE then                              -- means respone a msg
        -- 是一个session的回应消息
        local co = session_id_coroutine[session]        -- get the co by specify session
        if co == nil then 
            -- TODO
        else
            session_id_coroutine[session] = nil         -- destroy the associated co
            scheduler(co, coroutine.resume(co, true, msg))
        end
    else 
        -- 是一个协议消息
        local p = proto[prototype]
        if p == nil then
            if session ~= 0 then
                zergcore.send(source, zergcore.PTYPE_ERROR, session, "")
            end
            return
        end
        local f = p.dispatch
        -- print(zerg.self(), p.id, p.dispatch)
        if f then
            local ref = watching_service[source]
            if ref then
                watching_service[source] = ref + 1
            else
                watching_service[source] = 1
            end
            local co = co_create(f)
            session_coroutine_id[co] = session
            session_coroutine_address[co] = source
            scheduler(co, coroutine.resume(co, session, source, p.unpack(msg)))
        else
            -- print("proto dispatch is valid")
        end
    end
end

function zerg.dispatch_message(type:int, session:int, source:int, msg:object):void
    local succ, err = pcall(raw_dispatch_message, type, session, source, msg)
    -- dispatch fork
    while true do
        local key, co = next(fork_queue)
        if co == nil then
            break
        end

        zergcore.tblremove(fork_queue, co)
        local fork_succ, fork_err = pcall(scheduler, co, coroutine.resume(co))
        if not fork_succ then
            if succ then
                succ = false
                err = tostring(fork_err)
            else
                err = tostring(err) .. "\n" .. tostring(fork_err)
            end
        end
    end
    assert(succ, tostring(err))
end

function zerg.newservice(name, ...) 
end

---- register protocol
do local REG = zerg.register_protocol
    REG {
        name = "lua",
        id = zergcore.PTYPE_LUA,
        pack = zergcore.packlua,
        unpack = zergcore.unpacklua
    }

    REG {
        name = "response",
        id = zergcore.PTYPE_RESPONSE,
    }

    REG {
        name = "error",
        id = zergcore.PTYPE_ERROR,
        unpack = function(...) return ... end,
        dispatch = _error_dispatch,
    }
end

local function yield_call(service, session) 
    watching_session[session] = service
    local succ, msg = coroutine.yield("CALL", session)
    watching_session[session] = nil
    if not succ then
        -- error "call failed"
        zerg.error(service, " after call resume failed ", session)
    end
    return msg
end

function zerg.call(addr, typename, ...) 
    local p = proto[typename]
    local session = zergcore.send(addr, p.id, nil, p.pack(...))
    if session == nil then
        -- error("call to invalide address")
    end
    local r = yield_call(addr, session)
    return p.unpack(r)
end

function zerg.ret(msg)
    msg = msg or ""
    return coroutine.yield("RETURN", msg)
end

function zerg.retpack(...)
    return zerg.ret(zerg.pack(...))
end

function zerg.response(pack)
    pack = pack or zergcore.packlua
    return coroutine.yield("RESPONSE", pack)
end

function zerg.wakeup(co)
    if sleep_session[co] then
        table.insert(wakeup_queue, co)
        return true
    end
end

function zerg.fork(func, ...) 
    local args = table.pack(...)
    local co = co_create(function() 
        func(table.unpack(args, 1, args.n))
    end)
    table.insert(fork_queue, co)
    return co
end

function zerg.send(addr, typename, ...) 
    local p = proto[typename]
    zergcore.send(addr, p.id, 0, p.pack(...))
end

function zerg.redirect(dest, source, typename, msg, ...) 
    -- print(dest, source, typename, ...)
    -- print(proto[typename])
    return zergcore.redirect(dest, source, proto[typename].id, msg)
end

function zerg.wait(co)
    local session = zergcore.genid()
    local ret, msg = coroutine.yield("SLEEP", session)
    co = co or coroutine.running()
    sleep_session[co] = nil
    session_id_coroutine[session] = nil
end

function zerg.sleep(ti) 
    local session = zergcore.command("TIMEOUT", ti)
    assert(session)
    local succ, ret = coroutine.yield("SLEEP", session)
    sleep_session[coroutine.running()] = nil
    if succ then
        return
    end

    if ret == "BREAK" then
        return "BREAK"
    else
        --TODO
    end
end

function zerg.yield()
    return zerg.sleep(0)
end

function zerg.exit()
    -- clear fork 
    fork_queue = {}

    -- report to the spawner 
    zerg.send("spawner", "lua", "REMOVE", zerg.self(), false)

    -- report the soure which call me i am dead
    for co, session in pairs(session_coroutine_id) do 
        local address = session_coroutine_address[co]
        if session ~= 0 and address then
            zergcore.send(address, zergcore.PTYPE_ERROR, session, "")
        end
    end

    -- report the address which i call i was dead
    local tmp = {}
    for session, address in pairs(watching_session) do
        tmp[address] = true
    end

    for address in pairs(tmp) do 
        zergcore.send(address, zergcore.PTYPE_ERROR, 0, "")
    end

    zergcore.command("EXIT")

    coroutine.yield "QUIT"
end

----


--- manager
function zerg.spawn(...) 
    return zergcore.command("SPAWN", table.concat({...}," "))
end

function zerg.name(...) 
    zergcore.command("NAME", ...)
end

function zerg.spawn_service(name, ...) 
    return zerg.call("spawner", "lua", "SPAWN", "ZgLua", name, ...)
end

local init_func = {}

local function init_all() 
    local funcs = init_func
    init_func = nil
    if funcs then
        for _, f in ipairs(funcs) do
            f()
        end
    end
end

local function ret(f, ...)
    f()
    return ...
end

local function init_service_template(sco, ...) 
    init_all()
    init_func = {}
    return sco(...)
    -- return ret(init_all, v)
end

function zerg.pcall(sco, ...)
    return xpcall(init_service_template, print, sco, ...)
end

function zerg.init_service(sco) 

	init_service_template(sco)
    -- local ok, err = zerg.pcall(sco)
    -- print("-------%", err())
    -- if not ok then
    --     -- err()
    --     zerg.send("spawner", "lua", "SPAWNFAIL")
    -- else
    --     zerg.send("spawner", "lua", "SPAWNSUCC")
    -- end--     
    zerg.send("spawner", "lua", "SPAWNSUCC")
end

function zerg.async_init(sco)
    zergcore.hook(zerg.dispatch_message)
    zerg.timeout(0, function() 
        zerg.init_service(sco)
    end)
end 

return zerg
