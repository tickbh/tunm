-- cached.lua
-- create by wugd
-- 缓存数据获取，一切非自己的数据取皆为异步
CACHE_D = {}
setmetatable(CACHE_D, {__index = _G})
local _ENV = CACHE_D

ENABLE_REDIS_CACHE = false

cache_data = {}

cookie_map = {}

timer_map = {}

local function get_cache_data(rid)
    local value = cache_data[rid]
    if not value or not value.store then
        return nil
    end
    if os.time() - value.store > CACHE_EXPIRE_TIME_MEMORY then
        cache_data[rid] = nil
        return nil
    end
    return value.data
end

function set_cache_data(rid, data)
    local need_cache = data.is_db or data.need_cache
    data.need_cache = nil
    data.is_db = nil
    
    cache_data[rid] = {store = os.time(), data=dup(data)}
    if need_cache and ENABLE_REDIS_CACHE then
        USER_REDISD.cache_data_to_db(rid, data)
    end
end

function remove_cache_data(rid)
    cache_data[rid] = nil
end

local function redis_timer(rid)
    local map_info = timer_map[rid]
    if map_info == nil then
        return
    end
    timer_map[rid] = nil
    USER_DBD.load_data_from_db(rid, map_info["callback"])
end

local function delete_redis_timer(rid)
    local map_info = timer_map[rid]
    if map_info == nil then
        return
    end
    if is_valid_timer(map_info["timer_id"]) then
        delete_timer(map_info["timer_id"])
    end
    timer_map[rid] = nil
end

local function load_user_callback(data)
    assert(data["rid"] ~= nil, "callback rid must no empty")
    if data.is_redis then
        delete_redis_timer(data["rid"])
    end
    if data.is_redis and data.failed then
        USER_DBD.load_data_from_db(data["rid"], load_user_callback)
        return
    end

    if not data.failed then
        set_cache_data(data["rid"], data)
    end

    local record = cookie_map[data["rid"]]
    if not record then
        return
    end
    cookie_map[data["rid"]] = nil
    record.callback(data, record.callback_arg)
end

function get_user_data(rid, callback, callback_arg)
    assert(callback ~= nil and type(callback) == "function", "callback must not empty")
    local cache_data = get_cache_data(rid)
    if cache_data then
        callback(deep_dup(cache_data), callback_arg)
        return
    end

    local record = {
        callback     = callback,
        callback_arg = callback_arg,
    }
    cookie_map[rid] = record
    if ENABLE_REDIS_CACHE then
        local timer_id = set_timer(1000, redis_timer, rid, false)
        timer_map[rid] = {timer_id = timer_id, callback = load_user_callback}
        USER_REDISD.load_data_from_db(rid, load_user_callback)
    else
        USER_DBD.load_data_from_db(rid, load_user_callback)
    end

    return
end