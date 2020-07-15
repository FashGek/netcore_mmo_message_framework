local zerg = require "zerg"

zerg.async_init(function() 
    zerg.info("[main] start")
    zerg.spawn_service("protoloader")

    local watchdog = zerg.spawn_service("watchdog")
    zerg.call(watchdog, "lua", "start", {
        port = 8889,
        maxclient = 1000,
        nodelay = true,
        dummy = "dummy",
    })


end)
