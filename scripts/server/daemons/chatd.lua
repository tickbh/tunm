-- chatd.lua
-- Created by wugd
-- 负责聊天相关的模块
CHAT_D = {}
setmetatable(CHAT_D, {__index = _G})
local _ENV = CHAT_D

--[[
{
    chat_channel = xx, send_rid = xx, recv_rid = xx, send_name = xx, chat_info = {send_content = xx, send_time = os.time()}

    CHAT_CHANNEL_WORLD = { {user_data = xx, chat_info = xx} },
    CHAT_CHANNEL_UNION = { {user_data = xx, chat_info = xx} },
    CHAT_CHANNEL_PRIVATE = { rid = { {user_data = xx, chat_info = xx} } },
}
--]]

function deal_with_new_chat(data)
    if data.chat_channel == CHAT_CHANNEL_WORLD then
        local ret_msg = pack_message(get_common_msg_type(), MSG_CHAT, data.chat_channel, data)
        local users = USER_D.get_user_list()
        for _,user in pairs(users) do
            user:send_net_msg(ret_msg)
        end
    end
end

function send_system_chat(content, ext_data)
    local data = {chat_channel = CHAT_CHANNEL_WORLD, send_rid = GLOABL_RID, send_name = "TDEngine", send_rid = GLOABL_RID, chat_info = {send_content = content, send_time = os.time()}}
    merge(data.chat_info, ext_data or {})
    REDIS_D.run_command("PUBLISH", REDIS_CHAT_CHANNEL_WORLD, encode_json(data))
end

function send_system_private_chat( rid, content, ext_data )
    local data = {chat_channel = CHAT_CHANNEL_PRIVATE, send_rid = GLOABL_RID, recv_rid = rid, send_name = "TDEngine", send_rid = GLOABL_RID, chat_info = {send_content = content, send_time = os.time()}}
    merge(data.chat_info, ext_data or {})
    REDIS_D.run_command("PUBLISH", string.format(CREATE_CHAT_CHANNEL_PRIVATE, rid), encode_json(data))
end