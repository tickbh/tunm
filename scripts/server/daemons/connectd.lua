--connectd.lua
--connectd 服务
CONNECT_D = {}
setmetatable(CONNECT_D, {__index = _G})
local _ENV = CONNECT_D

local connect_agent = nil
local connect_timer = nil
local ensure_timer = nil
local heartbeat_timer = nil
local timeout = 60
local gate_prefix = "{GATE:IP}"
local redis_gate_prefix = "{GATE:IP}:*"
local gate_match_string = string.format("%s:([%%w.]*):(%%d+):(%%d+)",gate_prefix)

local connecting_cache_table = {}
local connected_gate_table = {}
local all_server_table = {}


function close_connecting_info()
    if IS_OBJECT(connect_agent) then
        DESTRUCT_OBJECT(connect_agent)
        connect_agent = nil
        if IS_VALID_TIMER(connect_timer) then
            delete_timer(connect_timer)
        end
        connect_timer = -1
    end
    if IS_VALID_TIMER(heartbeat_timer) then
        delete_timer(heartbeat_timer)
    end
    heartbeat_timer = -1
    
    if IS_VALID_TIMER(ensure_timer) then
        delete_timer(ensure_timer)
    end
    ensure_timer = -1
end

local function gate_heartbeat_network()
    local agents = get_all_agents()
    local key = string.format("%s:%s:%d:%d", gate_prefix, CURRENT_IP, GATE_LOGIC_PORT, CODE_ID)
    -- TRACE("gate_heartbeat_network key %o", key)
    REDIS_D.run_command("SET", key, SIZEOF(agents))
    REDIS_D.run_command("EXPIRE", key, timeout)
end

local function logic_connect_callback(agent, arg)
    if IS_OBJECT(connect_agent) then
        DESTRUCT_OBJECT(connect_agent)
        connect_agent = nil
    end
    agent:set_server_type(SERVER_TYPE_GATE)
    connect_agent = agent

    -- for i=1,10000 do
    --     agent:send_message(LOSE_CLIENT, 0)
    -- end
    
    TRACE("logic_connect_callback success fd is %o", connect_agent)
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
    if IS_OBJECT(connect_agent) then
        return
    end

    TRACE("---------logic_check_connection---------------")
    REDIS_SCRIPTD.eval_script_by_name("gate_select", {redis_gate_prefix, gate_prefix}, callback_gate_select, {})
end

local function ensure_server_async()
    TRACE("ensure_server_async === %o", SERVER_TYPE)
    if SERVER_TYPE == SERVER_GATE and not STANDALONE then
        return
    end

    local function server_callback(data, result_list)
        local succ, list = REDIS_D.check_array(result_list)
        if not succ then
            return
        end

        for _, value in ipairs(list) do
            local cur_ip, cur_port, code_id = string.match(value, gate_match_string)
            local unique_key = cur_ip .. ":" .. cur_port
            local last_cache_time = connecting_cache_table[unique_key] or 0
            local cache_agent = connected_gate_table[unique_key]
            if not IS_OBJECT(cache_agent) and last_cache_time + 120 < os.time()  then
                connecting_cache_table[unique_key] = os.time()
                    
                local function local_logic_connect_callback(agent, arg)
                    local unique_key, code_id = arg["unique_key"], arg["code_id"]
                    if IS_OBJECT(connected_gate_table[unique_key]) then
                        DESTRUCT_OBJECT(connected_gate_table[unique_key])
                        connected_gate_table[unique_key] = nil
                    end
                    agent:set_code_type(SERVER_TYPE_GATE, code_id)
                    local password = CALC_STR_MD5(string.format("%s:%s:%s", CODE_TYPE, CODE_ID, SECRET_KEY))
                    
                    agent:send_message(CMD_AGENT_IDENTITY, CODE_TYPE, CODE_ID, password)
                    connected_gate_table[unique_key] = agent
                    
                    TRACE("!!!!!!!!logic_connect_callback success fd is %o", agent)
                end

                socket_connect(cur_ip, cur_port, 25000, local_logic_connect_callback, {["unique_key"] = unique_key, ["code_id"] = code_id})
            else
                TRACE("%o is alive ", unique_key)
            end
        end
    end

    REDIS_D.run_command_with_call(server_callback, {}, "KEYS", redis_gate_prefix)

end

local function init_network_status()
    TRACE("init server %o %o", SERVER_TYPE, STANDALONE)
    if SERVER_TYPE == SERVER_GATE or STANDALONE then
        listen_server(GATE_LOGIC_PORT)
        listen_server(GATE_CLIENT_PORT)

        TRACE("listen http server:%o", "0.0.0.0:" .. GATE_HTTP_PORT)
        TRACE("listen websocket server:%o", "0.0.0.0:" .. GATE_WEBSOCKET_PORT)
        
        listen_http("0.0.0.0:" .. GATE_HTTP_PORT)
        listen_websocket("0.0.0.0", tonumber(GATE_WEBSOCKET_PORT))
        
        CURRENT_IP = GET_LOCALIP_ADDR() or "127.0.0.1"
        gate_heartbeat_network()
        heartbeat_timer = set_timer(3000, gate_heartbeat_network, nil, true)
    end

    -- ensure_timer = set_timer(3000, ensure_server_async, nil, true)

    if SERVER_TYPE == SERVER_LOGIC or STANDALONE then
        ensure_server_async()
        ensure_timer = set_timer(10000, ensure_server_async, nil, true)
        -- logic_check_connection()
        -- connect_timer = set_timer(3000, logic_check_connection, nil, true)
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

TRACE("fuck!!!!!!")
create()
register_post_data_init(init)