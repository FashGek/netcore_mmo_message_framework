local zerg = require "zerg"
local sproto = require "sproto"
local sprotoloader = require "sprotoloader"


local REQUEST = {}

function REQUEST:handshake() 
    zerg.info("handshake")
end

function REQUEST:heartbeat()
    zerg.info("heartbeat")
end

local function request(name, args, response) 
    local f = assert(REQUEST[name])
    local r = f(args)
    if response then
    end
end

zerg.register_protocol {
    name = "server",
    id = zergcore.PTYPE_SERVER,
    unpack = function(...) 
        return host:dispatch(sprotoloader.load(1), ...)
    end,
    dispatch = function(session, source, type, ...)
        if type == "REQUEST" then
            request(...)
        end
    end
}


zerg.async_init(function() 
    zerg.info("test client start")
    zerg.spawn_service("protoloader")

    host = sprotoloader.load(2):host "package"
    local send_request = host:attach(sprotoloader.load(1))


    zerg.connect("127.0.0.1", 8889)

    zerg.fork(function() 
        while true do
            local bin = send_request("handshake")
            socketcore.clientSocketSend(bin)
            zerg.sleep(1000)
        end
    end)
end)