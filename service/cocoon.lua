local zerg = require "zerg"

zerg.async_init(function() 
    zerg.info("[COCOON] start")
    local addr = zerg.spawn("ZgLua", "spawner")
    zerg.name(addr, "spawner")

    zerg.sleep(4200)

    -- zerg.send(addr, "lua", 23) 这里其实是有一个异步的bug的，就是此时可能launcher还没有完全初始化完就是hook还没有挂上去
    zerg.spawn_service("service_mgr")

    zerg.spawn_service(zerg.getenv "start")
    zerg.exit()
end)
