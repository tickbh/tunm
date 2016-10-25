--cmd_gate.lua

-- 验证帐号命令处理
function cmd_internal_auth(agent, connect_type, device_id, sign_info)
    agent:set_authed(true)
    local is_websocket = agent:is_websocket() and 1 or 0
    agent:send_logic_message(NEW_CLIENT_INIT, agent:get_port_no(), {}, {client_ip=agent:get_client_ip(), is_websocket = is_websocket} )
end

