

-- 更新一个文件，强制重新载入
function update(name)
    name = string.gsub(name, ".lua", "") .. ".lua";
    local full_name = get_full_path(name);
    require(full_name);
    -- 回收垃圾
    collectgarbage("collect");
end

update("global/base/util");
update("global/base/load_folder");

local function main()
    load_folder("global/include");
    load_folder("global/base");
    load_folder("global/inherit");
    load_folder("global/daemons", "importd:dbd:sqld:datad");

    local load_table={
        "user",
    }
    set_need_load_data_num(sizeof(load_table) )
    
    load_folder("share")
    
    load_folder("server/clone");
    load_folder("server/daemons", "redisd:redis_queued:redis_scriptd"); --,"propertyd" 强制加载优先顺序
    load_folder("server/cmds")
    load_folder("server/msgs")

    start_command_input()
    print("------------------welcome to rust lua game server------------------")
end


local status, msg = xpcall(main, error_handle)
if not status then
    print(msg)
end