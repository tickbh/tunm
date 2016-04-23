--connectd.lua
--connectd 服务
module("CONNECT_D", package.seeall)

local connect_agent = nil
local connect_timer = nil
local heartbeat_timer = nil
local timeout = 60
local gate_prefix = "{GATE:IP}"
local redis_gate_prefix = "{GATE:IP}:*"

function close_connecting_info()
    if is_object(connect_agent) then
        destruct_object(connect_agent)
        connect_agent = nil
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
    if is_object(connect_agent) then
        destruct_object(connect_agent)
        connect_agent = nil
    end
    agent:set_server_type(SERVER_TYPE_GATE)
    connect_agent = agent

    -- for i=1,10000 do
    --     agent:send_message(LOSE_CLIENT, 0);
    -- end
    
    trace("logic_connect_callback success fd is %o", connect_agent)
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
    if is_object(connect_agent) then
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
    if SERVER_TYPE == SERVER_LOGIC or STANDALONE then
        REDIS_D.add_subscribe_channel(REDIS_ACCOUNT_START_HIBERNATE)
        REDIS_D.add_subscribe_channel(REDIS_ACCOUNT_END_HIBERNATE)
    end
end

local function init()
    REDIS_SCRIPTD.load_script("gate_select", gate_prefix)
    init_network_status()
end

create()
register_post_data_init(init)