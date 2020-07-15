local args = {}

for word in string.gmatch(module_param, "%S+") do
    table.insert(args, word)
end

SERVICE_NAME = args[1]
local main, pattern
local errs = {}
-- print("--------match begin-------")
for pat in string.gmatch(LUA_SERVICE, "([^;]+);*") do
	-- print(pat)
    local filename = string.gsub(pat, '%?', SERVICE_NAME)
	f, msg = loadfile(filename)
	-- print("finding.. ", f, msg)
	if not f then
	    table.insert(errs, msg)
	else
	    pattern = pat
	    main = f
	    break
	end
end
-- print("-----------match--end--------")
if not main then 
    -- zerror(table.concat(errs, "\n"))
end
-- print("---", pattern)
LUA_SERVICE = nil
package.path , LUA_PATH = LUA_PATH
-- package.cpath , LUA_CPATH = LUA_CPATH
-- print("pattern:", pattern)
local service_path = string.match(pattern, "(.*/)[^/?]+$")
-- print("service path:", service_path)
if service_path then
	service_path = string.gsub(service_path, "?", args[1])
	package.path = service_path .. "?.lua;" .. package.path
	SERVICE_PATH = service_path
else
	local p = string.match(pattern, "(.*/).+$")
	SERVICE_PATH = p
end

main(select(2, table.unpack(args)))
