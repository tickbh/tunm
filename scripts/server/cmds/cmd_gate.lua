--cmd_gate.lua

-- 验证帐号命令处理
function cmd_internal_auth(agent, connect_type, device_id, sign_info)
    agent:set_authed(true)
    local is_websocket = agent:is_websocket() and 1 or 0
    agent:send_logic_message(NEW_CLIENT_INIT, agent:get_port_no(), {}, {client_ip=agent:get_client_ip(), is_websocket = is_websocket} )
end

function cmd_agent_identity(agent, code_type, code_id, password)
    code_type, code_id = tonumber(code_type), tonumber(code_id)
    TRACE("cmd_agent_identity == code_type = %o, code_id = %o, password = %o", code_type, code_id, password)
    if code_type == SERVER_TYPE_CLIENT then
        agent:set_code_type(code_type, 0)
        agent:set_authed(true)
        return
    end

    local calc_password = CALC_STR_MD5(string.format("%s:%s:%s", code_type, code_id, SECRET_KEY))
    if calc_password ~= password then
        agent:connection_lost()
        return
    end
    agent:set_code_type(code_type, code_id)
    agent:set_authed(true)
end

function cmd_check_heart(agent)
    agent:send_message(MSG_CHECK_HEART, {status= "ok"})
end

function cmd_enter_server(agent, server)
    TRACE("11111111111 cmd_enter_server ==== %o", server)
    if not IS_TABLE(server) then
        return
    end
    
    local code_type, code_id = tonumber(server["code_type"]), tonumber(server["code_id"]) 
    if not code_type or not code_id then
        return
    end

    TRACE("22222222222222222222agent ==== %o", agent)
    if not agent:is_user() then
        TRACE("非USER请求进入服务")
        return
    end

    local server_agent = find_port_by_code(code_type, code_id)
    TRACE("3333333333333333333 ==== %o server_agent = %o", server, server_agent)
    if not IS_OBJECT(server_agent) then
        return
    end

    TRACE("44444444444444444 ==== %o === %o", server, agent:get_port_no())
    server_agent:send_dest_message({code_type=code_type, code_id=code_id}, CMD_INNER_ENTER_SERVER, agent:get_port_no(), agent:query_into_server_data(), {is_websocket=agent:is_websocket()})
end