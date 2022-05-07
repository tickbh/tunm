

-- 更新一个文件，强制重新载入
function update(name)
    name = string.gsub(name, ".lua", "") .. ".lua"
    local full_name = GET_FULL_PATH(name)
    package.loaded[full_name] = false
    if TRACE then
        TRACE("update name = %o", name)
    end
    require(full_name)
    -- 回收垃圾
    collectgarbage("collect")
end

math.randomseed(os.time())
update("global/base/util")
update("global/base/load_folder")

function test_env()
    set_port_map(1, 2)
    TRACE("get_port_map %o", get_port_map())
    hotfix_file(GET_FULL_PATH("test/fix.lua") )
    set_port_map(2, 3)
    TRACE("get_port_map %o", get_port_map())
end

local function main()
    LOAD_FOLDER("global/include")
    LOAD_FOLDER("global/base", "util")
    LOAD_FOLDER("global/inherit")
    LOAD_FOLDER("global/daemons", "importd:dbd:sqld:datad")
    LOAD_FOLDER("global/clone")

    LOAD_FOLDER("etc")

    local load_table={
        "user",
    }
    set_need_load_data_num(SIZEOF(load_table) )
    
    LOAD_FOLDER("share")
    
    LOAD_FOLDER("server/clone")
    LOAD_FOLDER("server/clone/rooms", "room:desk")
    LOAD_FOLDER("server/daemons", "sqld:dbd:datad:redisd:redis_queued:redis_scriptd") --,"propertyd" 强制加载优先顺序
    LOAD_FOLDER("server/daemons/poker")
    LOAD_FOLDER("server/cmds")
    LOAD_FOLDER("server/msgs")

    --test_env()
    if not _DEBUG or _DUBUG == "false" then
        send_debug_on(0)
        debug_on(0)
    end

    post_init()
    START_COMMAND_INPUT()
    TRACE("------------------welcome to rust lua game server------------------")

    -- local msg = pack_message(MSG_TYPE_JSON, "aaaaaaaa", {a="1111", c="xxxxxxxxxx", d= {a="xxxx"}}, {b="xxxxxxxxxxx"})
    -- local name, un = msg_to_table(msg)
    -- TRACE("name = %o un = %o", name, un)
end


local status, msg = xpcall(main, ERROR_HANDLE)
if not status then
    print(msg)
end