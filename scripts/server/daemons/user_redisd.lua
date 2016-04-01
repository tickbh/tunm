-- user_redisd.lua
-- create by wugd
-- 缓存数据获取，一切非自己的数据取皆为异步
module("USER_REDISD", package.seeall)

cookie_map = {}
local use_serialize = true

local function check_finish(data)
    if data["readnum"] > 0 and not data.failed then
        return
    end

    if not data["time"] or not data["upload"] then
        data.failed = true
        REDIS_D.run_command("DEL", data.rid)
    end

    local record = cookie_map[data.cookie]
    if not record then
        return
    end
    cookie_map[data.cookie] = nil
    record.callback(data, record.callback_arg)
end

local function accout_user_callback(data, result_list)
    trace("USER_REDISD::accout_user_callback() get data from redis %o\n", result_list)
    data["readnum"] = data["readnum"] - 1
    if not REDIS_D.check_string(result_list) then
        trace("get accout_user_callback failed %o\n", result_list)
        data.failed = true
    else
        merge(data, decode_json(result_list))
    end
    check_finish(data)
end

function load_data_from_db(rid, callback, callback_arg)
    assert(callback ~= nil and type(callback) == "function", "callback must not empty")
    local data = { rid = rid, cookie = new_cookie(), readnum = 1, is_redis = true }
    local record = {
        callback     = callback,
        callback_arg = callback_arg,
    }
    cookie_map[data.cookie] = record
    REDIS_D.run_command_with_call(accout_user_callback, data, "GET", rid)

    return
end

function cache_data_to_db(rid, data)
    -- trace("cache_data_to_db() rid is %o data is %o serialize data is %o \n", rid, data, serialize(data))
    -- trace("cache_data_to_db() rid is %o data is %o unserialize data is %o \n", rid, data, unserialize(serialize(data)))
    local ser = encode_json(data)
    REDIS_D.run_command("SET", rid, ser)
    REDIS_D.run_command("EXPIRE", rid, CACHE_EXPIRE_TIME_REDIS)
end