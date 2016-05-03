-- global_comm.lua
-- Created by wugd
-- 处理通信消息的派发

-- flag标志为1或0，分别代表打开所有消息和关闭所有消息
-- flag为table，则代表打开指定玩家rid的消息
-- gate logic client
local debug_flag = 1
local send_debug_flag = 1
local new_connection_callback = {}
local socket_cookie_map = {}
local msg_filter = {}
local max_online_num = 1000

-- 发起 socket 连接的回调
local function socket_connect_callback(cookie, fd, client_ip)
    local cookie_info = socket_cookie_map[cookie]
    if not cookie_info then
        -- 没有记录该 cookie 的发起连接请求
        close_fd(fd)
        return
    end

    -- 删除缓存记录
    socket_cookie_map[cookie] = nil

    -- 解除对新连接的关注
    unregister_new_connection_callback(cookie)

    local agent = fd
    if fd ~= -1 then
        agent = clone_object(AGENT_TDCLS)
        -- 设置验证
        agent:set_authed(true)
        -- 设置端口与 agent 的映射关系
        agent:set_port_no(fd)
    end

    -- 若有回调，则调用之
    local f, arg = cookie_info["callback"], cookie_info["arg"]
    if type(f) == "function" then
        f(agent, arg)
    end
end

-- 更新玩家每次操作的时间（在发送CMD消息时调用）
local function update_operation_time(agent)
    -- 判断该agent是否玩家
    if agent:is_user() then
        agent:set_temp("last_operation_time", os.time())
    end
end

-- 注册新连接的回调
function register_new_connection_callback(cookie, f)
    new_connection_callback[cookie] = f
end

-- 注销新连接的回调
function unregister_new_connection_callback(cookie)
    new_connection_callback[cookie] = nil
end

-- 连接断开的回调
function cmd_connection_lost(port_no)
    trace("断开连接(%d)\n", port_no)
    -- 取得该端口对应的 agent
    local agent = find_agent_by_port(port_no)
    if agent == nil then
        -- 不存在对应的 agent，不处理
        do return end
    end
    -- 通知 agent 连接断开
    agent:connection_lost()
end

function get_server_type(client_ip, server_port)
    if SERVER_TYPE == "logic" then
        -- for _,value in ipairs(GATE_SERVER) do
        --     if string.match(client_ip, value) then
        --         return SERVER_TYPE_GATE
        --     end

        -- end
        return SERVER_TYPE_GATE
    elseif SERVER_TYPE == "gate" and server_port == tonumber(GATE_LOGIC_PORT) then
        -- for _,value in ipairs(LOGIC_SERVER) do
        --     if string.match(client_ip, value) then
        --         return SERVER_TYPE_LOGIC
        --     end
        -- end
        return SERVER_TYPE_LOGIC
    end
    return SERVER_TYPE_CLIENT
end

-- 收到新连接
function cmd_new_connection(cookie, fd, client_ip, server_port)
    trace("收到新连接(%d)。端口(%d), 客户端地址(%s), new connect info\n", fd, server_port, client_ip)
    local f = new_connection_callback[cookie]
    if type(f) == "function" then
        -- 若该连接有回调，则调用之
        f(cookie, fd, client_ip)
        return
    end

    local agent = clone_object(AGENT_TDCLS)
    -- 设置端口与 agent 的映射关系
    agent:set_port_no(fd)
    agent:set_client_ip(client_ip)
    local server_type = get_server_type(client_ip, server_port)
    if server_type == SERVER_TYPE_GATE or server_type == SERVER_TYPE_LOGIC then
        -- 现在暂时不需要验证
        agent:set_authed(true)
        agent:set_server_type(server_type)
    else
        local server_fd = get_logic_fd()
        if SERVER_TYPE == SERVER_GATE and server_fd ~= -1 then
            agent:set_server_type(server_type)
            set_port_map(server_fd, fd)
        else
            trace("no logic server to accept so close the port")
            agent:connection_lost()
        end

        --超过最高在线
        if get_real_agent_count() > max_online_num then
            agent:connection_lost()
        end
    end
end

-- 是否输出消息trace
function debug_on(flag, rid)
    -- 开启或关闭所有消息
    if not rid or type(rid) ~= "string" then
        if not flag or flag == 0 then
            debug_flag = 0
        else
            debug_flag = 1
        end

    -- 对指定玩家开启或关闭所有消息
    else
        if not flag or flag == 0 then
            if type(debug_flag) == "table" then
                debug_flag[rid] = nil
                if sizeof(debug_flag) <= 0 then
                    debug_flag  = 0
                end
            end
        else
            if type(debug_flag) ~= "table" then
                debug_flag = {}
            end
            debug_flag[rid] = true
        end
    end
end

-- 发送消息是否输出 trace
function send_debug_on(flag, rid)
    -- 开启或关闭所有消息
    if not rid or type(rid) ~= "string" then
        if not flag or flag == 0 then
            send_debug_flag = 0
        else
            send_debug_flag = 1
        end

    -- 对指定玩家开启或关闭所有消息
    else
        if not flag or flag == 0 then
            if type(send_debug_flag) == "table" then
                send_debug_flag[rid] = nil
                if sizeof(send_debug_flag) <= 0 then
                    send_debug_flag  = 0
                end
            end
        else
            if type(send_debug_flag) ~= "table" then
                send_debug_flag = {}
            end
            send_debug_flag[rid] = true
        end
    end
end

function get_send_debug_flag()
    return send_debug_flag
end

function get_debug_flag()
    return debug_flag
end

function get_message_manage_type(message, server_type)
    local msg_type = get_message_type(message)
    if msg_type == "" then
        return MESSAGE_DISCARD
    end
    if SERVER_TYPE == SERVER_CLIENT then
        return MESSAGE_MANAGE
    end

    if server_type == SERVER_TYPE_CLIENT then
        if msg_type == MESSAGE_GATE or msg_type == MESSAGE_SERVER then
            return MESSAGE_MANAGE
        else
            return MESSAGE_FORWARD
        end
    elseif server_type == SERVER_TYPE_GATE then
        return MESSAGE_MANAGE
    elseif server_type == SERVER_TYPE_LOGIC then
        if msg_type == MESSAGE_LOGIC or msg_type == MESSAGE_SERVER then
            return MESSAGE_MANAGE
        else
            return MESSAGE_FORWARD
        end
    else
        assert(false, "unknow message type")
    end
end

function oper_message(agent, message, msg_buf)
    local name, args = msg_buf:msg_to_table()
    assert(name == message)
    local flag = get_debug_flag()
    if (type(flag) == "number" and flag == 1) or
           (type(flag) == "table" and self:is_user() and flag[self:get_rid()]) then
        trace("------------- msg : %s -------------\n%o\n", message, args)
    end
    
    local message_handler = _G[message]
    if not message_handler then
        trace("global_dispatch_command message_handler : %o 未定义消息处理函数!\n", message)
        return
    end

    -- 为客户端，直接执行消息处理函数
    message_handler(agent, unpack(args or {}))
end

-- 派发消息的入口函数
function global_dispatch_command(port_no, message, buffer)
    

    -- 判断是否已存在对应的 agent
    local agent = find_agent_by_port(port_no)
    -- trace("------- my agent = %o ---------", agent)
    if not agent or
       (not agent:is_authed() and message ~= "cmd_internal_auth") then
        -- 若找不到 agent，且该消息不为验证消息，则认为是非法连接，不处理
        trace("非法连接(%d)\n 消息为(%o)", port_no, message)
        if not agent then
            trace("端口绑定的对象不存在")
        end
        if is_object(agent) then
            agent:print_fd_info()
            destruct_object(agent)
        else 
            close_fd(port_no)
        end
        do return end
    end


    local mm_type = get_message_manage_type(message, agent:get_server_type())
    if mm_type == MESSAGE_DISCARD then
        trace("------------- discard port_no is %o, cmd : %s -------------\n", port_no, message)
        del_message(buffer)
        return 
    end

    if agent:get_server_type() == SERVER_TYPE_CLIENT and CHECK_PACK and not agent:check_next_client(buffer:get_seq_fd()) then
        trace("package check failed %o kick the socket", agent:get_ob_id())
        trace("agent:get_server_type() = %o ", agent:get_server_type())
        agent:connection_lost()
        del_message(buffer)
        return
    end
    if mm_type == MESSAGE_FORWARD then
        if agent:get_server_type() == SERVER_TYPE_LOGIC then
            local clientAgent = find_agent_by_port(buffer:get_seq_fd())
            if clientAgent then
               clientAgent:forward_message(buffer) 
            end
        else
            agent:forward_logic_message(buffer)
        end
        del_message(buffer)
        return
    elseif agent:get_server_type() == SERVER_TYPE_GATE then
        local logic_agent = find_agent_by_port(buffer:get_seq_fd() + 0x10000)
        if logic_agent then
            agent = logic_agent
        end
    end

    if is_function(msg_filter[message]) then
        msg_filter[message](agent, buffer)
        del_message(buffer)
        return
    end

    oper_message(agent, message, buffer)
    del_message(buffer)

    if agent:is_user() then
        update_operation_time(agent)
        if PACKAGE_STATD then
            PACKAGE_STATD.on_user_recv_package(agent)
        end
    end
end

-- 取得DB的返回值
function msg_db_result(cookie, ret, result_list)
    -- 通知 DB_D 收到结果
    if type(result_list) == "table" then
        DB_D.notify_operation_result(cookie, ret, unpack(result_list))
    else
        DB_D.notify_operation_result(cookie, ret, result_list)
    end
end

-- 取得Redis的返回值
function msg_redis_result(cookie, value)
    REDIS_D.notify_operation_result(cookie, value)
end


-- 注册消息的过滤器
function register_msg_filter(msg, f)
    msg_filter[msg] = f
end

-- 发起一个连接
-- 异常操作
function socket_connect(ip, port, timeout, callback, arg)
    local cookie = new_cookie()

    -- 缓存该连接对象的 cookie
    socket_cookie_map[cookie] = {
        ip       = ip,
        port     = port,
        timeout  = timeout,
        callback = callback,
        arg      = arg,
    }

    -- 注册关注该 cookie 的新连接创建
    register_new_connection_callback(cookie, socket_connect_callback)

    -- 发起连接创建的请求
    return (new_connect(ip, port, timeout, cookie))
end

--query is get data, body is post data
function http_server_msg_recv(cookie, url, body, remote_host)
    cookie = tonumber(cookie)
    trace("http_server_msg_recv args is %o", {cookie, route, query, body, remote_host})
    http_server_respone(cookie, "hello world from lua")
end

function http_client_msg_respone(cookie, success, body)
    cookie = tonumber(cookie)
    success = success == "true" or success == "1"
    trace("http_client_msg_respone args is %o", {cookie, success, body})
end

function set_max_online_num(num)
    max_online_num = num
end

function get_max_online_num()
    return max_online_num
end