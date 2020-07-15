
local zerg = require "zerg"

local command = {}
local NORET = {}
local services = {}
local instance = {}

local function spawn_service(service, ...)
    local param = table.concat({...}, " ")
    local inst = zerg.spawn(service, param);
    local response = zerg.response()
    if inst then
        services[inst] = service .. " " .. param
        instance[inst] = response
    else
        response(false)
        return
    end

    return inst
end

function command.SPAWN(_, service, ...) 
    spawn_service(service, ...)
    return NORET
end

function command.SPAWNSUCC(address) 
    local response = instance[address]
    if response then
        response(true, address)
        instance[address] = nil
    end

    return NORET
end

function command.SPAWNFAIL(address)

end

function command.REMOVE(_, handle, kill) 
    services[handle] = nil
    local response = instance[handle]

    if response then
        -- 表示的是 被移除掉的服务,还有一个服务在等着他回应,这里就不等了,马上回应它错误
        -- 这里相当于schedule(co, false),然后scheduler会发一个PTYPE_ERROR的消息,我们已经看过如何处理它了
        response(not kill)
        instance[handle] = nil
    end
    return NORET
end

zerg.dispatch("lua", function(session, address, cmd, ...)
    cmd = string.upper(cmd)
    local f = command[cmd]
    if f then
        local ret = f(address, ...)
        if ret ~= NORET then
            zerg.ret(zerg.pack(ret))
        end
    else
        zerg.ret(zerg.pack {"Unknown Command"})
    end
end)

zerg.async_init(function() 
    zerg.info("[SPAWNER] start")
end)
