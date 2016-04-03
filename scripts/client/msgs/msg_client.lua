
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
