SERVER_TYPE_CLIENT = 0
SERVER_TYPE_GATE = 1
SERVER_TYPE_LOGIC = 2
SERVER_TYPE_GAME = 3

SERVER_NAMES = {}
SERVER_NAMES[SERVER_TYPE_CLIENT] = "client"
SERVER_NAMES[SERVER_TYPE_GATE] = "gate"
SERVER_NAMES[SERVER_TYPE_LOGIC] = "logic"
SERVER_NAMES[SERVER_TYPE_GAME] = "game"

ALL_SERVER_TYPES = {}
for k, _ in pairs(SERVER_NAMES) do
    ALL_SERVER_TYPES[#ALL_SERVER_TYPES + 1] = k
end

CMD_INTERNAL_AUTH           = "cmd_internal_auth"
CMD_AGENT_IDENTITY          = "cmd_agent_identity"
CMD_LOGIN                   = "cmd_login"
CMD_ENTER_SERVER            = "cmd_enter_server"
CMD_INNER_ENTER_SERVER      = "cmd_inner_enter_server"
CMD_CHECK_HEART             = "cmd_check_heart"
MSG_CHECK_HEART             = "msg_check_heart"
CMD_USER_LIST               = "cmd_user_list"
MSG_USER_LIST               = "msg_user_list"
CMD_CREATE_USER             = "cmd_create_user"
MSG_CREATE_USER             = "msg_create_user"
CMD_SELECT_USER             = "cmd_select_user"
MSG_ENTER_GAME              = "msg_enter_game"
MSG_ENTER_SERVER            = "msg_enter_server"
MSG_LOGIN_NOTIFY_STATUS     = "msg_login_notify_status"
NEW_CLIENT_INIT             = "new_client_init"
LOSE_CLIENT                 = "lose_client"
CMD_COMMON_OP               = "cmd_common_op"
MSG_COMMON_OP               = "msg_common_op"
MSG_OBJECT_UPDATED          = "msg_object_updated"
MSG_PROPERTY_LOADED         = "msg_property_loaded"
MSG_BONUS                   = "msg_bonus"
CMD_SALE_OBJECT             = "cmd_sale_object"
MSG_SALE_OBJECT             = "msg_sale_object"
MSG_PROPERTY_DELETE         = "msg_property_delete"
CMD_CHAT                    = "cmd_chat"
MSG_CHAT                    = "msg_chat"
MSG_WAIT_QUEUE_NUMBER       = "msg_wait_queue_number"
CMD_ENTER_ROOM              = "cmd_enter_room"
MSG_ENTER_ROOM              = "msg_enter_room"
CMD_LEAVE_ROOM              = "cmd_leave_room"
MSG_LEAVE_ROOM              = "msg_leave_room"
CMD_ROOM_MESSAGE            = "cmd_room_message"
MSG_ROOM_MESSAGE            = "msg_room_message"
CMD_ROOM_OPER               = "cmd_room_oper"
MSG_ROOM_OPER               = "msg_room_oper"
RESPONE_ROOM_MESSAGE        = "respone_room_message"
MSG_DB_RESULT               = "msg_db_result"

MSG_DEDEAL_SERVER = {}
MSG_DEDEAL_SERVER[CMD_INTERNAL_AUTH] = {SERVER_TYPE_GATE}
MSG_DEDEAL_SERVER[CMD_AGENT_IDENTITY] = {SERVER_TYPE_GATE, SERVER_TYPE_LOGIC}
MSG_DEDEAL_SERVER[CMD_LOGIN] = {SERVER_TYPE_GATE, SERVER_TYPE_LOGIC}
MSG_DEDEAL_SERVER[CMD_CHECK_HEART] = {SERVER_TYPE_GATE}
MSG_DEDEAL_SERVER[MSG_ENTER_GAME] = {SERVER_TYPE_CLIENT}
MSG_DEDEAL_SERVER[MSG_ENTER_SERVER] = {SERVER_TYPE_CLIENT}
MSG_DEDEAL_SERVER[LOSE_CLIENT] = ALL_SERVER_TYPES
MSG_DEDEAL_SERVER[CMD_ENTER_SERVER] = {SERVER_TYPE_GATE}
MSG_DEDEAL_SERVER[CMD_INNER_ENTER_SERVER] = {SERVER_TYPE_LOGIC, SERVER_TYPE_GAME}


for name, value in pairs(MSG_DEDEAL_SERVER) do
    local new_value = {}
    for _, k in ipairs(value) do
        new_value[SERVER_NAMES[k]] = true
    end
    MSG_DEDEAL_SERVER[name] = new_value
end

function is_msg_can_deal(message)
    local info = MSG_DEDEAL_SERVER[message]
    if not info then
        return false        
    end
    return info[SERVER_TYPE] or info[CODE_TYPE]
end