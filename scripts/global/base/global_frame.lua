-- global_frame.lua
-- Created by wugd
-- 每帧的处理函数

local callback_info = { callback =  {}, callback_count = 0 };
local callback_switch = false;
local cookie = 1;
local timer_cache = {};
setmetatable(timer_cache, { __mode = "k" });

-- 定时器的回调
local function timer_callback(evid, para)
    local callback, arg, is_repeat = para["callback"], para["arg"], para["is_repeat"];
    -- 调用真实的回调处理
    if type(callback) == "function" then
        if _DEBUG or callback_switch then
            -- 记录当前的回调函数信息
            callback_info["callback"] = debug.getinfo(callback, 'S');
        end
        xpcall(callback, error_handle, arg);
    end
end

function timer_event_dispatch(cookie) 
    cookie = tonumber(cookie)
    local timer_info = timer_cache[cookie];
    if not timer_info then
        return;
    end
    timer_callback(cookie, timer_info);
end

function get_timer_cache()
    return timer_cache;
end

-- 取得回调函数的信息
function get_callback_info()
    return callback_info["callback"]["short_src"], callback_info["callback"]["linedefined"], callback_info["callback_count"];
end

-- 设置定时器
function set_timer(timeout, callback, arg, is_repeat)

    assert(timeout > 0, "超时时间必须>0\n");
    -- 创建一个新的 timer
    local id = timer_event_set(timeout, is_repeat or false);
    if not id then
        assert(false, "设置定时器失败。\n");
    end

    local cache_arg;

    cache_arg = {
        timeout = timeout,
        arg     = arg,
        id      = id,
        callback = callback,
        is_repeat = is_repeat,
    };
    -- setmetatable(cache_arg, { __mode = "v" });
    assert(not timer_cache[id]);
    timer_cache[id] = cache_arg;
    return id;
end

-- 删除定时器
function delete_timer(time_id)
    timer_cache[time_id] = nil;
    timer_event_del(time_id);
end

function get_timer(time_id)
    return timer_cache[time_id];
end

function get_all_timer()
    return timer_cache;
end

function get_timer_count()
    return #timer_cache;
end

function callback_switch_on(switch)
    callback_switch = switch;
end
