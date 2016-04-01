
function msg_login_notify_status( agent, info )
end

--msg_user_list
function msg_user_list(agent, list)
end

function msg_create_user(agent, info)
end

function msg_enter_game(agent, info)
    ME_D.me_updated(agent, info)
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
end

function msg_bonus(user, info, bonus_type)
end
