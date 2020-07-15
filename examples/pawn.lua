
local zerg = require "zerg"
local loader = require "sprotoloader"
local host
local CMD = {}
local pawn_channel
local watchdog

local REQUEST = {}

function REQUEST:handshake(...) 
    return {msg = "Welcom to zerg, I will send heartbet every 5 sec."}
end

local function request(name, args, response)
    local f = assert(REQUEST[name])
    local r = f(args)
    if response then
        return response(r)
    end
end

zerg.register_protocol {
    name = "client",
    id = zergcore.PTYPE_CLIENT,
    unpack = function(msg)       
        chost = loader.load(1):host "package"
        return chost:dispatch(loader.load(2), msg)
        -- chost.attach(loader.load(2))
    end,
    dispatch = function (session, source, type, ...) 
        if type == "REQUEST" then
            local ok, result = pcall(request, ...)
            if ok then
                if result then
                    -- send_package(result)
                end
            end
        end
    end
}

function CMD.start(conf)
    pawn_channel = conf.client
    watchdog = conf.watchdog

    -- socketcore.send(conf.client)

    sp = loader.load(1)
    host = sp:host "package"                                        -- equal sprpc server = sprpc.create(client_proto, "package")
    send_request = host:attach(loader.load(2))                      -- equal server.attach(server_proto)      
    -- local data = handle("heartbeat", "hello", 1, nil)            -- equal server.request("heartbeat")
    -- print(host:dispatch(loader.load(2), data))

    zerg.fork(function() 
        while true do
            if pawn_channel ~= nil then
                socketcore.send(pawn_channel, send_request "heartbeat")
            end
            zerg.sleep(1500)
        end
    end)
    zerg.call(conf.gate, "lua", "forward", zerg.self(), pawn_channel)
end

function CMD.disconnect()
    zerg.info("pawn exit")
    zerg.exit()
end

zerg.async_init(function() 

    zerg.info("[PAWN] start")
    -- print(host)

    zerg.dispatch("lua", function(_, _, command, ...) 
        local f = CMD[command]
        zerg.ret(zerg.pack(f(...)))
    end)



end)
