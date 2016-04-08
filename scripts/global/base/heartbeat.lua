-- heartbeat.lua
-- Created by wugd
-- 心跳相关函数

-- 定义公共接口，按照字母顺序排序

local heartbeat_funcs   = {};

-- 调用心跳回调函数
function post_heartbeat(ob_class, ob)
    local func_list = heartbeat_funcs[ob_class];
    if not func_list then
        return;
    end

    -- 依次调用回调
    for _, f in ipairs(func_list) do
        if type(f) == "function" then
            f(ob);
        end
    end
end

-- 注册心跳回调函数
function register_heartbeat(ob_class, f)
    if not is_table(heartbeat_funcs[ob_class]) then
        heartbeat_funcs[ob_class] = {};
    end

    table.insert(heartbeat_funcs[ob_class], f);
end
