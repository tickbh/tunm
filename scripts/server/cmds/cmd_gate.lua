--cmd_gate.lua

-- 验证帐号命令处理
function cmd_internal_auth(agent, connect_type, device_id, sign_info)
    agent:set_authed(true)
    
    agent:send_logic_message(NEW_CLIENT_INIT, agent:get_port_no(), {}, {client_ip=agent:get_client_ip()} )
end

