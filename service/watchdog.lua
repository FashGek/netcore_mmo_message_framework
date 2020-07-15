local zerg = require "zerg"

local CMD = {}
local SOCKET = {}
local gate
local pawns = {}

function SOCKET.open(channel, addr)
    pawns[channel] = zerg.spawn_service("pawn")
    zerg.call(pawns[channel], "lua", "start", { gate = gate, client = channel, watchdog = zerg.self() }) 
end

function SOCKET.close(channel) 
    local p = pawns[channel]
    pawns[channel] = nil
    if p then
        zerg.call(gate, "lua", "kick", channel)
        zerg.send(p, "lua", "disconnect")
    end
end

function SOCKET.data(channel, msg) 
end

function CMD.start(conf)
    zerg.call(gate, "lua", "open", conf)
end

zerg.async_init(function()
    zerg.info("[WATCHDOG] start")

    zerg.dispatch("lua", function(session, source, cmd, subcmd, ...) 
        if cmd == "socket" then
            local f = SOCKET[subcmd]
            f(...)
            -- socket api do not need return
        else
            -- print(typeof(cmd), cmd)
            local f = CMD[cmd]
            zerg.ret(zerg.pack(f(subcmd, ...)))
        end
    end)

    gate = zerg.spawn_service("gate")
end)