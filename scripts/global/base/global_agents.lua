-- global_agents.lua
-- Created by wugd
-- 维护连接对象

-- 变量定义
local agents = {};
--{1:2} client map or {2:{1=true,3=true}} logic map
local port_map = {};
--{GateType = {1=true,3=true}, LogicType={2=true, 3=true}, ClientType={4=true}}
local type_fds = {};

-- setmetatable(agents, { __mode = "v" });

-- 定义公共接口，按照字母顺序排序

-- 取得所有的 agent
function get_all_agents()
    return agents;
end

function get_real_agent_count()
    local sum = 0
    for port,_ in ipairs(agents) do
        if port < 0xFFFF then
            sum = sum + 1
        end
    end
    return sum
end

function get_port_map()
    return port_map
end
-- 根据 port_no 找 agent　对象
function find_agent_by_port(port_no)
    return agents[port_no];
end

function reset_port_agent(port_no, agent)
    agents[port_no] = agent;
end

-- 移除 port_no　与 agent 的映射关系
function remove_port_agent(port_no)
    local agent = agents[port_no]
    if agent then
        local server_type = agent:get_server_type()
        if server_type == SERVER_TYPE_GATE then
            for _,ag in pairs(dup(agents)) do
                if ag:get_server_type() == SERVER_TYPE_CLIENT then
                    ag:connection_lost()
                end
            end
        elseif server_type == SERVER_TYPE_LOGIC then
            for port,_ in pairs(dup(port_map[port_no]) or {}) do
                agents[port]:connection_lost()
            end
        else
            local logic_agent = find_agent_by_port(get_map_port(port_no))
            if logic_agent then
                logic_agent:send_message(LOSE_CLIENT, port_no)
            end
            
            local gate_agent = find_agent_by_port(get_gate_fd())
            if gate_agent then
                gate_agent:send_message(LOSE_CLIENT, port_no)
            end
        end
        remove_port_map(port_no)
        type_fds[server_type] = type_fds[server_type] or {}
        type_fds[server_type][port_no] = nil
    end
    agents[port_no] = nil
end

-- 设置 port_no　与 agent 的映射关系
function set_port_agent(port_no, agent)
    agents[port_no] = agent;
end

function set_type_port(server_type, port_no)
    type_fds[server_type] = type_fds[server_type] or {}
    type_fds[server_type][port_no] = true
end

function remove_port_map(port_no)
    local ports = port_map[port_no]
    for no, _ in pairs(ports or {}) do
        if port_map[no] then
            port_map[no][port_no] = nil
        end
        if is_empty_table(port_map[no]) then
            port_map[no] = nil
        end
    end
    port_map[port_no] = nil
end

function set_port_map(port_no_server, port_no_client)
    port_map[port_no_server] = port_map[port_no_server] or {}
    port_map[port_no_client] = port_map[port_no_client] or {}
    port_map[port_no_server][port_no_client] = true
    port_map[port_no_client][port_no_server] = true
end

function get_map_port(port_no)
    for port,_ in pairs(port_map[port_no] or {}) do
        return port
    end
    return -1
end

function get_logic_fd()
    local logic_fds = type_fds[SERVER_TYPE_LOGIC] or {}
    local resultfd = -1
    local max = -1
    for fd,_ in pairs(logic_fds) do
        local size = sizeof(port_map[fd])
        if max < size then
            resultfd = fd
            max = size
        end
    end
    return resultfd
end

function get_gate_fd()
    for fd,_ in pairs(type_fds[SERVER_TYPE_GATE] or {}) do
        return fd
    end
    return -1
end
