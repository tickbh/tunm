
function msg_login_notify_status( agent, info )
    trace("msg_login_notify_status!!!!!!!!!!!!")
    if info.ret and info.ret ~= 0 then
        trace("登陆时发生错误:%s", info.err_msg)
    end
end

--msg_user_list
function msg_user_list(agent, list)
end

function msg_create_user(agent, info)
end

function msg_enter_game(agent, info)
    ME_D.me_updated(agent, info)
    enter_room()
end

function msg_common_op(user, info)
end

function msg_object_updated(user, rid, info)
    local object = find_object_by_rid(rid)
    if not is_object(object) then
        trace("物件:%s不存在", rid)
        return
    end

    for k,v in pairs(info) do
        trace("属性更新:%o->[%o]=%o", object:query("name"), k, v)
        object:set(k, v)
    end
end

function msg_property_loaded(user, rid, info_list)
    for _,v in pairs(info_list) do
        local obj = PROPERTY_D.clone_object_from(v.class_id, v)
        user:load_property(obj)
    end
end

function msg_bonus(user, info, bonus_type)
    if bonus_type == BONUS_TYPE_SHOW then
        for _,v in pairs(info.properties or {}) do
            local obj = find_basic_object_by_class_id(v.class_id)
            assert(obj, "物品不存在")
            trace("获得物品:%o，数量:%o", obj:query("name"), v.amount)
        end
    end
end

function msg_sale_object(user, info)
    if info.ret ~= 0 then
        trace("出售物品失败:%o", info.err_msg)
    else
        trace("出售物品成功")
    end
end

function msg_property_delete(user, rids)
    for _,rid in ipairs(rids) do
        local object = find_object_by_rid(rid)
        if object then
            trace("物品:%o，名称:%o消耗完毕", object:query("rid"), object:query("name"))
            user:unload_property(object)
        end
    end
end

function msg_chat( user, channel, info )
    info.chat_info = info.chat_info or {}
    if channel == CHAT_CHANNEL_WORLD then
        trace("收到来自:%s的世界聊天, 内容为:\"%s\"", info.send_name, info.chat_info.send_content)
    end
end

function msg_room_message(user, oper, info)
    trace("user = %o, oper = %o, info = %o", user, oper, info)
    if oper == "success_enter_room" then
        trace("成功进入房间:\"%s\"", info.room_name)
        user:send_message(CMD_ROOM_MESSAGE, "enter_desk", {})
    elseif oper == "success_enter_desk" then
        if info.rid == get_ob_rid(user) then
            desk_ready()
        end
        trace("%s成功进入桌子:\"%d\", 在位置:%d", info.rid, info.idx, info.wheel_idx)
    elseif oper == "pre_room" then
        if info.room_name then
            user:send_message(CMD_ENTER_ROOM, {room_name = info.room_name})            
        end
    end
end



function msg_enter_room(user, info)
    if info.ret and info.ret < 0 then
        trace("进入房间错误:\"%s\"", info.err_msg)
        return
    end
    trace("msg_enter_room info = %o", info)
    trace("成功进入房间:\"%s\"", info.room_name)
end

function msg_leave_room(user, info)    
    if info.ret and info.ret < 0 then
        trace("离开房间错误:\"%s\"", info.err_msg)
        return
    end
    trace("msg_leave_room info = %o", info)
    trace("成功离开房间:\"%s\"", info.room_name)
end