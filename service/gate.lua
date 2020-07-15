local zerg = require "zerg"
local gateserver = require "gateserver"


local watchdog
local connection = {}
local forwarding = {}


zerg.register_protocol {
    name = "client",
    id = zergcore.PTYPE_CLIENT
}


local handler = {}

function handler.open(source, conf) 
    watchdog = conf.watchdog or source
end

function handler.connect(channel, addr)
    local c = {
        channel = channel,
        ip = addr
    }

    connection[channel] = c
    zerg.send(watchdog, "lua", "socket", "open", channel, addr)
end

local function unforward(c)
	if c.pawn then
		forwarding[c.pawn] = nil
		c.pawn = nil
		c.pawn = nil
	end
end

local function close_channel(channel) 
    local c = connection[channel]

    if c then
        connection[channel] = nil
    end
end

function handler.disconnect(channel, reason) 
    close_channel(channel)
    zerg.send(watchdog, "lua", "socket", "close", channel)
end

function handler.message(channel, msg)
    local c = connection[channel]
    if c.pawn then
        -- print("-------------------------------------------------------------------")
        -- print(c.pawn, c.client, msg)
        zerg.redirect(c.pawn, c.client, "client", msg)
    else
        zerg.send(watchdog, "lua", "socket", "data", channel, msg)
    end
end


local CMD = {}

function CMD.forward(source, channel, client, address) 
    local c = assert(connection[channel])

    unforward(c)
    c.client = client or 0
    c.pawn = address or source
    forwarding[c] = c
end

function CMD.kick(channel) 
    gateserver.close_channel(channel)
end

function handler.command(cmd, source, ...)
    local f = assert(CMD[cmd])
    return f(...)
end

gateserver.start(handler)
