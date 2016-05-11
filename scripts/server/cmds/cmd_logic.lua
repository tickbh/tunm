--cmd_logic.lua

-- 登录帐号命令处理
function cmd_login(agent, map)
    LOGIN_D.login(agent, map)
end

--逻辑服收到新用户登陆消息
function new_client_init(agent, port, data, ext)
    --端口区分本地端口
    port = port + 0x10000

    --断线重连
    local old_agent = find_agent_by_port(port)
    if old_agent then
        old_agent:connection_lost(true)
    end
    local client_agent = clone_object(AGENT_TDCLS);
    -- 设置端口与 agent 的映射关系
    client_agent:set_all_port_no(port, agent:get_port_no())
    client_agent:set_client_ip(ext["client_ip"])
    client_agent:set_server_type(SERVER_TYPE_CLIENT)
    client_agent:set_authed(true)
end

--获取用户列表
function cmd_user_list(account)
    ACCOUNT_D.get_user_list(account)
end

function cmd_create_user(account, info)
    ACCOUNT_D.request_create_user(account, info)
end

function cmd_select_user(account, rid)
    ACCOUNT_D.request_select_user(account, rid)
end

function cmd_common_op(user, info)
    if info.oper == "add" then
        user:add_attrib(info.field, info.amount)
    elseif info.oper == "cost" then
        user:cost_attrib(info.field, info.amount)
    elseif info.oper == "add_item" then
        BONUS_D.do_user_bonus(user, {property = { {class_id = info.class_id, amount = info.amount} }}, BONUS_TYPE_SHOW, BONUS_TYPE_SHOW)
    end
end

function cmd_sale_object(user, info)
    local rid, amount = info.rid, info.amount
    local object = find_object_by_rid(rid)
    if not object or get_ob_rid(user) ~= object:query("owner") then
        return user:send_message(MSG_SALE_OBJECT, {ret = -1, err_msg = "物品rid有误"})
    end

    if object:query("sell_price") == 0 then
        return user:send_message(MSG_SALE_OBJECT, {ret = -1, err_msg = "该物品不可出售"})
    end

    local sale_amount = math.min(info.amount, object:query("amount"))
    user:add_attrib("gold", sale_amount * object:query("sell_price"))
    object:cost_amount(sale_amount)
    return user:send_message(MSG_SALE_OBJECT, {ret = 0})
end

function cmd_chat( user, channel, info )
    local data = {chat_channel = channel, send_rid = user:query("rid"), recv_rid = info.recv_rid, send_name = user:query("name"), chat_info = {send_content = info.send_content, send_time = os.time()}}
    if channel == CHAT_CHANNEL_WORLD then
        REDIS_D.run_command("PUBLISH", REDIS_CHAT_CHANNEL_WORLD, encode_json(data))
    end

end

function cmd_enter_room(user, info)
    local room = ROOM_D.get_detail_room(info.room_name)
    if not room then
        user:send_message(MSG_ENTER_ROOM, {ret = -1, err_msg = "房间不存在"})
        return
    end

    if user:query_temp("room_name") ~= nil then
        user:send_message(MSG_ENTER_ROOM, {ret = -2, err_msg = "您已在房间内", room_name = user:query_temp("room_name")})
        return
    end

    local function enter_room_callback(args, ext)
        if not is_object(user) then
            return
        end

        user:set_temp("room_server_id", tonumber(SERVER_ID))
        user:set_temp("room_name", info.room_name)
        user:send_message(MSG_ENTER_ROOM, {room_name = info.room_name})
    end

    --get room type, user base info, room game data
    local base_info = dup(user:query())
    base_info["server_id"] = tonumber(SERVER_ID)
    INTERNAL_COMM_D.send_room_message(info.room_name, get_ob_rid(user), {enter_room_callback, {user = user, info = info}}, CMD_ROOM_MESSAGE, "enter_room", base_info)
end

function cmd_leave_room(user, info)
    local room_name = user:query_temp("room_name")
    if not room_name then
        user:send_message(MSG_LEAVE_ROOM, {ret = -1, err_msg = "您未在房间内"})
        return
    end

    local function leave_room_callback(args, ext)
        trace("leave_room_callback!!!")
        if not is_object(user) then
            return
        end
        user:send_message(MSG_LEAVE_ROOM, {room_name = room_name})
    end

    INTERNAL_COMM_D.send_room_message(room_name, get_ob_rid(user), {leave_room_callback, {}}, CMD_ROOM_MESSAGE, "leave_room", {server_id = tonumber(SERVER_ID)})
    user:delete_temp("room_name")
end

function respone_room_message(user, oper, info)
    if oper == "reconnect_user" then
        user:send_message(MSG_ROOM_MESSAGE, "pre_room", info)
    end
end