--connectd.lua
--connectd 服务
module("CONNECT_D", package.seeall)

local connect_fd = -1
local connect_timer = nil
local heartbeat_timer = nil
local timeout = 60
local gate_prefix = "{GATE:IP}"
local redis_gate_prefix = "{GATE:IP}:*"

function close_connecting_info()
    if connect_fd ~= -1 then
        close_fd(connect_fd)
        connect_fd = -1
        if is_valid_timer(connect_timer) then
            delete_timer(connect_timer)
        end
        connect_timer = -1
    else
        if is_valid_timer(heartbeat_timer) then
            delete_timer(heartbeat_timer)
        end
        heartbeat_timer = -1
    end
end

local function gate_heartbeat_network()
    local agents = get_all_agents()
    local key = string.format("%s:%s:%d", gate_prefix, CURRENT_IP, GATE_LOGIC_PORT)
    -- trace("gate_heartbeat_network key %o", key)
    REDIS_D.run_command("SET", key, sizeof(agents))
    REDIS_D.run_command("EXPIRE", key, timeout)
end

local function logic_connect_callback(agent, arg)
    if connect_fd ~= -1 then
        local obj = find_agent_by_port(connect_fd)
        if obj then
            obj:connection_lost()
        end
        connect_fd = -1
    end
    agent:set_server_type(SERVER_TYPE_GATE)
    connect_fd = agent:get_port_no()
    
    trace("logic_connect_callback success fd is %o", connect_fd)
end

local function callback_gate_select(data, result_list)
    if result_list.success == 0 then
        return
    end

    local ip, port = result_list[1], result_list[2]
    if ip and port then
        socket_connect(ip, port, 25000, logic_connect_callback)
    end
end

--找出负载最低的网关进行连接
local function logic_check_connection()
    if connect_fd ~= -1 and find_agent_by_port(connect_fd) then
        return
    end

    trace("---------logic_check_connection---------------")
    REDIS_SCRIPTD.eval_script_by_name("gate_select", {redis_gate_prefix, gate_prefix}, callback_gate_select, {})
end

local function init_network_status()
    if SERVER_TYPE == SERVER_GATE or STANDALONE then
        listen_server(GATE_LOGIC_PORT, BIND_IP)
        listen_server(GATE_CLIENT_PORT)
        listen_http("0.0.0.0:" .. GATE_HTTP_PORT)
        CURRENT_IP = CURRENT_IP or "127.0.0.1"
        gate_heartbeat_network()
        heartbeat_timer = set_timer(3000, gate_heartbeat_network, nil, true)
    end

    if SERVER_TYPE == SERVER_LOGIC or STANDALONE then
        logic_check_connection()
        connect_timer = set_timer(3000, logic_check_connection, nil, true)
    end
end

local function create()
    REDIS_SCRIPTD.load_script("gate_select", gate_prefix)
    init_network_status()
end

register_post_data_init(create)