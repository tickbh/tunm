

-- 更新一个文件，强制重新载入
function update(name)
    name = string.gsub(name, ".lua", "") .. ".lua"
    local full_name = get_full_path(name)
    package.loaded[full_name] = false
    require(full_name)
    -- 回收垃圾
    collectgarbage("collect")
end

update("global/base/util")
update("global/base/load_folder")

function test_env()
    set_port_map(1, 2)
    trace("get_port_map %o", get_port_map())
    hotfix_file(get_full_path("test/fix.lua") )
    set_port_map(2, 3)
    trace("get_port_map %o", get_port_map())
end

local function main()
    load_folder("global/include")
    load_folder("global/base")
    load_folder("global/inherit")
    load_folder("global/daemons", "importd:dbd:sqld:datad")
    load_folder("global/clone")

    load_folder("etc")

    local load_table={
        "user",
    }
    set_need_load_data_num(sizeof(load_table) )
    
    load_folder("share")
    
    load_folder("server/clone")
    load_folder("server/daemons", "sqld:dbd:datad:redisd:redis_queued:redis_scriptd") --,"propertyd" 强制加载优先顺序
    load_folder("server/cmds")
    load_folder("server/msgs")

    --test_env()
    send_debug_on(0)
    debug_on(0)
    post_init()
    start_command_input()
    print("------------------welcome to rust lua game server------------------")
end


local status, msg = xpcall(main, error_handle)
if not status then
    print(msg)
end