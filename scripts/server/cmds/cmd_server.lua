--cmd_server.lua

--逻辑服或者网关服接收客户端登出
function lose_client(agent, fd)
    fd = bit32.band(fd, 0xFFFF)
    if STANDALONE then
        local client_agent = find_agent_by_port(fd)
        if client_agent then
            client_agent:connection_lost()
            assert(find_agent_by_port(fd) == nil, "client is must nil") 
        end

        local client_agent = find_agent_by_port(fd + 0x10000)
        if client_agent then
            client_agent:connection_lost()
            assert(find_agent_by_port(fd) == nil, "client is must nil") 
        end
    else
        if SERVER_TYPE == "logic" then
            fd = fd + 0x10000
        end
        local client_agent = find_agent_by_port(fd)
        if client_agent then
            client_agent:connection_lost()
            assert(find_agent_by_port(fd) == nil, "client is must nil") 
        end
    end

end