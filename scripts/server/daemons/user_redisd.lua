-- user_redisd.lua
-- create by wugd
-- 缓存数据获取，一切非自己的数据取皆为异步
USER_REDISD = {}
setmetatable(USER_REDISD, {__index = _G})
local _ENV = USER_REDISD

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
    data["readnum"] = data["readnum"] - 1
    if not REDIS_D.check_string(result_list) then
        data.failed = true
    else
        MERGE(data, DECODE_JSON(result_list))
    end
    check_finish(data)
end

function load_data_from_db(rid, callback, callback_arg)
    ASSERT(callback ~= nil and type(callback) == "function", "callback must not empty")
    local data = { rid = rid, cookie = new_cookie(), readnum = 1, is_redis = true }
    local record = {
        callback     = callback,
        callback_arg = callback_arg,
    }
    cookie_map[data.cookie] = record
    REDIS_D.run_command_with_call(accout_user_callback, data, "GET", rid)
end

function cache_data_to_db(rid, data)
    local ser = ENCODE_JSON(data)
    REDIS_D.run_command("SET", rid, ser)
    REDIS_D.run_command("EXPIRE", rid, CACHE_EXPIRE_TIME_REDIS)
end