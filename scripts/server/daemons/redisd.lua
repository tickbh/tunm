-- redisd.lua
-- 声明模块名
REDIS_D = {}
setmetatable(REDIS_D, {__index = _G})
local _ENV = REDIS_D

local STATUS_SUFFIX = "::STATUS"
local ERROR_SUFFIX = "::ERROR"
local MATCH_STATUS = "(%w+)::STATUS"
local MATCH_ERROR = "(%w+)::ERROR"

local redis_subs_channel = {}

function check_status(value)
    if type(value) == "string" then
        local status = string.match(value, MATCH_STATUS)
        if status then
            return true, status
        else
            return false, nil
        end
    end
    return false, nil
end

function check_error(value)
    if type(value) == "table" then
        local err = string.match(value, MATCH_ERROR)
        if err then
            return true, err
        else
            return false, nil
        end
    end
    return false, nil
end

function check_nil(value)
    if value == nil then
        return true
    end
    return false
end

function check_array(value)
    if type(value) == "table" then
        return true, value
    end
    return false, nil
end

function check_integer(value)
    if value and type(value) == "number" then
        return true, value
    end
    return false, 0
end

function check_string(value)
    if value and type(value) == "string" then
        if string.find(value, STATUS_SUFFIX) or string.find(value, ERROR_SUFFIX) then
            return false, ""
        end
        return true, value
    end
    return false, ""
end

function get_value(value)
    if not value then
        return nil
    end
    local value_type = type(value)
    if value_type == "string" and string.find(value, STATUS_SUFFIX) then
        return string.match(value, MATCH_STATUS)
    elseif value_type == "string" and string.find(value, ERROR_SUFFIX) then
        return string.match(value, MATCH_ERROR)
    elseif value_type == "table" then
        return value
    elseif type(value) == "number" or type(value) == "string" then
        return value
    end
    return nil
end

local cookie_map = {}
-- 默认回调函数
local function default_callback(command, value)
    TRACE("command is %o, value is %o", command, value)
end

function run_command_sync(...)
    return redis_run_command_sync(...)
end

function run_command(...)
    redis_run_command(0, ...)
end

function run_publish(...)
    redis_run_command(0, "PUBLISH", ...)
end

-- 通知操作结果
function notify_operation_result(cookie, value)
    -- 若不在 cookie_map 中，则认为该通知非法
    local oper = cookie_map[cookie]
    if not oper then
        do return end
    end

    -- 从 cookie_map 中移除该操作记录
    cookie_map[cookie] = nil

    -- 取得该操作的回调函数
    local callback     = oper["callback"]
    local callback_arg = oper["callback_arg"]
    local command      = oper["command"]
    -- TRACE("callback is %o value is %o", callback, value)
    -- 若存在回调，则调用之，否则调用默认回调函数
    if type(callback) == "function" then
        -- 若有结果集
        if callback_arg then
            callback(callback_arg, value)
        else
            callback(value)
        end
    else
        default_callback(command, value)
    end
end

function run_command_with_call(callback, callback_arg, ...)
    local cookie = 0
    if callback then
        cookie = new_int_cookie()
        local record = {
                         callback     = callback,
                         callback_arg = callback_arg,
                         command      = {...},
                         begin_time   = os.time(),
        }
        -- 记录该操作
        cookie_map[cookie] = record
    end
    redis_run_command(cookie, ...)
end

function run_script(...)
    ASSERT(#{...} >= 3, "args must >= 3 args")
    redis_run_script(0, ...)
end


function run_script_with_call(callback, callback_arg, ...)
    local cookie = 0
    if callback then
        cookie = new_int_cookie()
        local record = {
                         callback     = callback,
                         callback_arg = callback_arg,
                         command      = {...},
                         begin_time   = os.time(),
        }
        -- 记录该操作
        cookie_map[cookie] = record
    end
    ASSERT(#{...} >= 3, "args must >= 3 args")
    redis_run_script(cookie, ...)
end

function subs_command_with_call(callback, callback_arg, ...)
    local cookie = 0
    if callback then
        cookie = new_int_cookie()
        local record = {
                         callback     = callback,
                         callback_arg = callback_arg,
                         command      = {...},
                         begin_time   = os.time(),
        }
        -- 记录该操作
        cookie_map[cookie] = record
    end
    redis_subs_command(cookie, ...)
end

function subs_command(...)
    redis_subs_command(0, ...)
end

function subs_get_reply()
    return redis_subs_get_reply()
end

function add_subscribe_channel(channel)
    table.insert(redis_subs_channel, channel)

end

function start_psubscribe()
    subs_command("PUNSUBSCRIBE", {})
    subs_command("PSUBSCRIBE", redis_subs_channel)
end

local function create()
    redis_subs_channel = DUP(REDIS_SUBS_REGISTER)
end

create()
register_post_init(start_psubscribe)