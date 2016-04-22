--room.lua
--Created by wugd
--房间类

--创建类模板
ROOM_CLASS = class()
ROOM_CLASS.name = "ROOM_CLASS"

--构造函数
function ROOM_CLASS:create(value)
    assert(is_table(value), "room:create para not correct")

    --记录该场景的基本信息
    self.data = value

    --创建存放该场景实体的弱表
    self.room_entity = {}
end

-- 生成对象的唯一ID
function ROOM_CLASS:get_ob_id()
    return (string.format("ROOM_CLASS:%s", save_string(self:get_room_name())))
end

--定义公共接口，按照字母顺序排序

-- 广播消息
function ROOM_CLASS:broadcast_message(msg, ...)

    local size = sizeof(self.room_entity)
    local config_amount = ROOM_D.get_msg_amount(msg)
    local find_object_by_rid = find_object_by_rid
    local is_object = is_object
    local user
    local msg_buf = pack_message(msg, ...)
    local send_raw_message = get_class_func(USER_CLASS, "send_raw_message")

    if not msg_buf then
        trace("广播消息(%d)打包消息失败。\n", msg)
        return
    end

    -- 遍历该房间的所有玩家对象
    for rid, info in pairs(self.room_entity) do
        if info.ob_type == OB_TYPE_USER then
            if  math.random(1, size) < config_amount then
                user = find_object_by_rid(rid)
                if is_object(user) then
                    send_raw_message(user, msg_buf)
                else
                    self.room_entity[rid] = nil
                end
            end
        end
    end
end

--玩家进入房间
function ROOM_CLASS:entity_enter(server_id, user_rid, cookie, info)
    local user_ob = find_object_by_rid(user_rid)
    if not user_ob then
        user_ob = USER_D.create_user(info)
    end
    assert(user_ob ~= nil, "ob must exist")
    user_ob:set_temp("room_server_id", server_id)

    --将新实体加该场景
    self.room_entity[user_rid] = {
        server_id = server_id,
    }

    local channel = string.format(CREATE_RESPONE_SERVER_INFO, server_id, cookie)
    REDIS_D.run_publish(channel, "")

    INTERNAL_COMM_D.send_server_message(server_id, user_rid, {}, MSG_ROOM_MESSAGE, "success_enter_room", {rid = user_rid})

    trace("success entity_enter %o", user_ob)

end

--玩家离开房间
function ROOM_CLASS:entity_leave(entity)

    local query_func = entity.query
    local entity_rid = query_func(entity, "rid")

    if not self.room_entity[entity_rid] then
        write_log(string.format("Error:对象%s离开房间%s时找不到自己(%s)\n",
                                entity_rid, self:get_room_name(), entity:query_temp("room") or "nil"))
        assert(nil)
    end

    --将该实体从场景中删除，并发送离开场景消息
    self.room_entity[entity_rid] = nil

    local send_message = get_class_func(USER_CLASS, "send_message")
    if query_func(entity, "ob_type") == OB_TYPE_USER then
        send_message(entity, MSG_LEAVE_ROOM, self:get_room_name())
    end

end

--获取房间名称
function ROOM_CLASS:get_room_name()
    return self.data["room_name"]
end

--获取房间类型
function ROOM_CLASS:get_game_type()
    return self.data["game_type"]
end

-- 返回房间中的玩家信息
function ROOM_CLASS:get_room_entity()
    return self.room_entity
end

--判断是否是vip场景
function ROOM_CLASS:is_vip()
    if self.data["is_vip"] == 1 then
        return true
    else
        return nil
    end
end

function ROOM_CLASS:get_level()
    return self.data["level"]
end

-- 判断是否为房间对象
function ROOM_CLASS:is_room()
    return true
end

--更新实体外观信息
function ROOM_CLASS:update_entity(rid, pkg_info)
    if self.room_entity[rid] and
       self.room_entity[rid]["packet"] then

        self.room_entity[rid]["packet"] = pkg_info
    end
end

function ROOM_CLASS:get_listen_channel()
    return string.format(REDIS_ROOM_MSG_CHANNEL_USER, self:get_room_name())
end

function ROOM_CLASS:get_respone_channel()
    return string.format(REDIS_RESPONE_ROOM_INFO, self:get_room_name())
end