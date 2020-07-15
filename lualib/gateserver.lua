local zerg = require "zerg"


local gateserver = {}
local server
local chanel ----
local client_number = 0

local CMD = {}

local channels = {}



function gateserver.close_channel(channel) 
    local c = channels[channel]
    if c then
        channels[channel] = false

    end
end


function gateserver.start(handler)

    function _channel_close(channel:object, reason:int):void

    end

    function _channel_open(channel:object, reason:int):void
    end

    assert(handler.message)
    assert(handler.connect)

    function CMD.open(source, conf) 
        assert(not server)
        local address = conf.address or "127.0.0.1"
        local port = assert(conf.port)
        maxclient = conf.maxclient or 1024
        nodelay = conf.nodelay
        server = zerg.listen({address, port}, _channel_close, _channel_open)
        if handler.open then
            return handler.open(source, conf)
        end
        return {}
    end

    
    local MSG = {}

    function MSG.open(chanel, msg) 
        if client_number >= maxclient then
            --TODO server close channel
        end

        channels[chanel] = true
        client_number = client_number + 1
        handler.connect(chanel, msg)
    end

    local function close_channel(channel) 
        local c = channels[channel]
        if c ~= nil then
            channels[channel] = nil
            client_number = client_number - 1
        end
    end

    function MSG.close(channel, reason) 
        if handler.disconnect then
            handler.disconnect(channel)
        end
        close_channel(channel)
    end

    function MSG.data(channel, data)
        if channels[channel] then
            handler.message(channel, data)
        else
            zerg.error("Drop msg from channel ", channel, data)
        end
    end

    zerg.register_protocol {
        name = "socket",
        id = zergcore.PTYPE_SOCKET,
        unpack = zerg.unpack,
        dispatch = function(session, source, type, ...)
            if type then        -- type is socket cmd type
                MSG[type](...)
            end
        end
    }

    zerg.async_init(function() 
        zerg.info("[GATESERVER] start")
        zerg.dispatch("lua", function(_, address, cmd, ...) 
            local f = CMD[cmd]
            if f then
                zerg.ret(zerg.pack(f(address, ...)))
            else
                zerg.ret(zerg.pack(handler.command(cmd, address, ...)))
            end
        end)
    end)    
end


return gateserver
