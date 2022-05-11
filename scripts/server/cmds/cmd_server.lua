--cmd_server.lua

--逻辑服或者网关服接收客户端登出
function lose_client(agent, fd)
    fd = bit32.band(fd, 0xFFFF)
    if STANDALONE then
        local client_agent = find_agent_by_port(fd)
        if client_agent then
            client_agent:set_sended_close(true)
            client_agent:connection_lost()
            ASSERT(find_agent_by_port(fd) == nil, "client is must nil") 
        end

        local client_agent = find_agent_by_port(fd + 0x10000)
        if client_agent then
            client_agent:set_sended_close(true)
            client_agent:connection_lost()
            ASSERT(find_agent_by_port(fd) == nil, "client is must nil") 
        end
    else
        if SERVER_TYPE == "logic" then
            fd = fd + 0x10000
        end
        local client_agent = find_agent_by_port(fd)
        if client_agent then
            client_agent:set_sended_close(true)
            client_agent:connection_lost()
            ASSERT(find_agent_by_port(fd) == nil, "client is must nil") 
        end
    end
end

function cmd_inner_enter_server(agent, port, data, ext)
    --端口区分本地端口
    TRACE("cmd_inner_enter_server port ==== ", port, data)
    port = tonumber(port) + 0x10000
    --断线重连
    local old_agent = find_agent_by_port(port)
    if old_agent then
        old_agent:connection_lost(true)
    end
    local client_agent = CLONE_OBJECT(USER_TDCLS, data);
    -- 设置端口与 agent 的映射关系
    client_agent:set_all_port_no(port, agent:get_port_no())
    client_agent:set_client_ip(ext["client_ip"])
    if ext.is_websocket then
        client_agent:set_websocket(ext.is_websocket)
    end
    client_agent:set_code_type(SERVER_TYPE_CLIENT, 0)
    client_agent:set_authed(true)

    client_agent:send_message(MSG_ENTER_SERVER, {status="ok"})
end