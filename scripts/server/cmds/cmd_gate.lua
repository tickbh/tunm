--cmd_gate.lua

-- 验证帐号命令处理
function cmd_internal_auth(agent, connect_type, device_id, sign_info)
    agent:set_authed(true)
    local is_websocket = agent:is_websocket() and 1 or 0
    agent:send_logic_message(NEW_CLIENT_INIT, agent:get_port_no(), {}, {client_ip=agent:get_client_ip(), is_websocket = is_websocket} )
end

function cmd_agent_identity(agent, code_type, code_id, password)
    TRACE("cmd_agent_identity == code_type = %o, code_id = %o, password = %o", code_type, code_id, password)
    
    local calc_password = CALC_STR_MD5(string.format("%s:%s:%s", code_type, code_id, SECRET_KEY))
    if calc_password ~= password then
        agent:connection_lost()
        return
    end
    agent:set_code_type(code_type)
    agent:set_code_id(code_id)
    agent:set_authed(true)
end