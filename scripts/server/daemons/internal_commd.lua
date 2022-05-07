-- internal_commd.lua
-- Created by wugd
-- 发送信息内部管理的类

-- 声明模块名
INTERNAL_COMM_D = {}
setmetatable(INTERNAL_COMM_D, {__index = _G})
local _ENV = INTERNAL_COMM_D

local cookie_map = {}
local TIMEOUT = 15

-- 超时处理函数
local function timer_handle()
    local cur_time = os.time()

    for k, v in pairs(cookie_map) do
        if v["begin_time"] + TIMEOUT <= cur_time then
            cookie_map[k] = nil
            local callback, arg = v["callback"], v["arg"]
            if type(callback) == "function" then
                if arg then
                    -- -2 表示超时
                    callback(arg, -2)
                else
                    callback(-2)
                end
            end
        end
    end
end

---- 公共接口

--收到其他服务器返回的消息
function notify_internal_result(cookie, ...)
    local oper = cookie_map[tostring(cookie)]
    if not oper then
        do return end
    end

    --为正数，表明未超时
    local ret = 2

    -- 从 cookie_map 中移除该操作记录
    cookie_map[tostring(cookie)] = nil

    -- 取得该操作的回调函数
    local callback     = oper["callback"]
    local callback_arg = oper["arg"]

    -- 若存在回调，则调用之，否则调用默认回调函数
    if type(callback) == "function" then

        -- 若有结果集
        if callback_arg then
            callback(callback_arg, ret, ...)
        else
            callback(ret, ...)
        end
    end
end

function send_room_raw_message(room_name, user_rid, record, net_data)
    --如果有回调函数，则产生一个cookie，默认cookie为该消息的第一个参数
    local cookie = 0
    if IS_TABLE(record) and SIZEOF(record) ~= 0 then
        cookie = new_cookie()
        local new_record = { begin_time = os.time(), callback = record[1], arg = record[2] }
        cookie_map[tostring(cookie)] = new_record
    end

    local channel = string.format(CREATE_ROOM_MSG_CHANNEL_USER, room_name, user_rid, cookie)
    REDIS_D.run_publish(channel, net_data)
end

-- 对指定的房间，指定的用户进行消息发送
function send_room_message(room_name, user_rid, record, msg, ...)
    local net_msg = pack_message(get_common_msg_type(), msg, ...)
    if not net_msg then
        return
    end

    send_room_raw_message(room_name, user_rid, record, net_msg:get_data())
    del_message(net_msg)
end

function send_server_raw_message(server_id, user_rid, record, net_data)
    --如果有回调函数，则产生一个cookie，默认cookie为该消息的第一个参数
    local cookie = 0
    if IS_TABLE(record) and SIZEOF(record) ~= 0 then
        cookie = new_cookie()
        local new_record = { begin_time = os.time(), callback = record[1], arg = record[2] }
        cookie_map[tostring(cookie)] = new_record
    end

    local channel = string.format(CREATE_SERVER_MSG_USER, server_id, user_rid, cookie)
    REDIS_D.run_publish(channel, net_data)
end


-- 对指定的server_id进行消息发送
function send_server_message(server_id, user_rid, record, msg, ...)
    server_id = tonumber(server_id)
    local net_msg = pack_message(get_common_msg_type(), msg, ...)
    if not net_msg then
        return
    end

    send_server_raw_message(server_id, user_rid, record, net_msg:get_data())
    del_message(net_msg)
end

function get_cookie_map()
    return cookie_map
end

-- 模块的入口执行
function create()
    set_timer(1000, timer_handle, nil, true)

    if SERVER_TYPE == SERVER_LOGIC or STANDALONE then
        REDIS_D.add_subscribe_channel(string.format(REDIS_SERVER_MSG_USER, SERVER_ID))
        REDIS_D.add_subscribe_channel(string.format(REDIS_RESPONE_SERVER_INFO, SERVER_ID))
    end

end

create()
