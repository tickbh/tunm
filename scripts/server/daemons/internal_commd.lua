-- internal_commd.lua
-- Created by wugd
-- 发送信息内部管理的类

-- 声明模块名
module("INTERNAL_COMM_D", package.seeall)

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

-- 对指定的server_id进行广播消息
function send_room_message(room_name, callback, arg, msg_no, ...)

    local record = {}
    local msg
    local msg_arg

    --如果存在回调函数，则第三个或第四个是消息编号
    if type(callback) == "function" then
        record["callback"] = callback

        --回调有参数，则第四个是消息编号
        if type(arg) == "table" then
            record["arg"] = arg
            msg     = msg_no
            msg_arg = {...}

        --否则是第三个参数是消息编号
        else
            msg     = arg
            msg_arg = {msg_no,...}
        end
    else
        msg     = callback
        msg_arg = {arg, msg_no, ...}
    end

    
    --如果有回调函数，则产生一个cookie，默认cookie为该消息的第一个参数
    if sizeof(record) ~= 0 then
        local cookie = new_cookie()
        record["begin_time"] = os.time()
        cookie_map[tostring(cookie)] = record
    end

    local net_msg = pack_message(msg, unpack(msg_arg))
    if not net_msg then
        return
    end

    local channel = string.format(CREATE_ROOM_MSG_CHANNEL, room_name)
    REDIS_D.run_publish(channel, net_msg:get_data())
    del_message(net_msg)
end

-- 对指定的server_id进行广播消息
function send_server_message(server_id, callback, arg, msg_no, ...)

    server_id = tonumber(server_id)
    local record = {}
    local msg
    local msg_arg

    --如果存在回调函数，则第三个或第四个是消息编号
    if type(callback) == "function" then
        record["callback"] = callback

        --回调有参数，则第四个是消息编号
        if type(arg) == "table" then
            record["arg"] = arg
            msg     = msg_no
            msg_arg = {...}

        --否则是第三个参数是消息编号
        else
            msg     = arg
            msg_arg = {msg_no,...}
        end
    else
        msg     = callback
        msg_arg = {arg, msg_no, ...}
    end

    
    --如果有回调函数，则产生一个cookie，默认cookie为该消息的第一个参数
    if sizeof(record) ~= 0 then
        local cookie = new_cookie()
        record["begin_time"] = os.time()
        cookie_map[tostring(cookie)] = record
    end

    local net_msg = pack_message(msg, unpack(msg_arg))
    if not net_msg then
        return
    end

    local channel = string.format(CREATE_SERVER_MSG, server_id)
    REDIS_D.run_publish(channel, net_msg:get_data())
    del_message(net_msg)
end

function get_cookie_map()
    return cookie_map
end

-- 模块的入口执行
function create()
    set_timer(1000, timer_handle, nil, true)
end

create()
