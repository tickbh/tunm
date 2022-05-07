

-- 更新一个文件，强制重新载入
function update(name)
    name = string.gsub(name, ".lua", "") .. ".lua";
    local full_name = GET_FULL_PATH(name);
    require(full_name);
    TRACE("update file name = %o", name)
    -- 回收垃圾
    collectgarbage("collect");
end

update("global/base/util");
update("global/base/load_folder");
TRACE("??????????????")

local function main()
    LOAD_FOLDER("global/include");
    LOAD_FOLDER("global/base", "util");
    LOAD_FOLDER("global/inherit");
    LOAD_FOLDER("global/daemons", "importd:dbd:sqld:datad");
    LOAD_FOLDER("global/clone");
    
    LOAD_FOLDER("etc")

    local load_table={
        "user",
    }
    set_need_load_data_num(sizeof(load_table) )

    LOAD_FOLDER("share")
    
    LOAD_FOLDER("client/global")
    LOAD_FOLDER("client/clone");
    update("client/daemons/logind")
    update("client/daemons/med")
    update("client/daemons/stress_testd")
    -- LOAD_FOLDER("client/daemons", ""); --,"propertyd" 强制加载优先顺序

    -- STRESS_TEST_D.start(500, "CHAT_TESTD")

    LOAD_FOLDER("client/msgs")

    update("client/command")

    send_debug_on(0)
    debug_on(0)
    post_init()
    START_COMMAND_INPUT()
    print("------------------welcome to rust lua game client------------------")
end


local status, msg = xpcall(main, ERROR_HANDLE)
if not status then
    print(msg)
end