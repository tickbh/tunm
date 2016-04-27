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

    self:init_table_entity()
end

function ROOM_CLASS:destruct()
    for _,data in pairs(dup(self.room_entity)) do
        self:entity_destruct(data)
    end
end

function ROOM_CLASS:init_table_entity()
    --创建该房间的桌子信息
    self.table_entity = {}
    local table_num = self.data["table_num"] or 100
    for i=1,table_num do
        self.table_entity[i] = clone_object(self:get_table_class(), self)
    end
end

-- 生成对象的唯一ID
function ROOM_CLASS:get_ob_id()
    return (string.format("ROOM_CLASS:%s", save_string(self:get_room_name())))
end

--定义公共接口，按照字母顺序排序

function ROOM_CLASS:time_update()
    for _,data in pairs(dup(self.room_entity)) do
        self:entity_update(data)
    end
end

function ROOM_CLASS:entity_update(entity)
    trace("entity_update = %o", entity)
    if entity.last_logout_time and (os.time() - entity.last_logout_time > 10 or not entity.is_in_game) then
        self:entity_destruct(entity.user_rid)
    end
end

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

    del_message(msg_buf)
end

--玩家进入房间
function ROOM_CLASS:entity_enter(server_id, user_rid, info)
    --将新实体加该场景
    self.room_entity[user_rid] = {
        user_rid = user_rid,
        --对像连接的服务器id
        server_id = server_id,
        --对像的登出时间
        last_logout_time = nil,
        --玩家的上次操作时间，确定是否超时
        last_op_time = os.time(),
        --是否正在游戏中
        is_in_game = false,
        data = clone_object(DBASE_CLASS, info)
    }

    INTERNAL_COMM_D.send_server_message(server_id, user_rid, {}, MSG_ROOM_MESSAGE, "success_enter_room", {rid = user_rid, room_name = self:get_room_name()})
    trace("success entity_enter %o", user_ob)
    return 0
end

--玩家离开房间
function ROOM_CLASS:entity_leave(user_rid)

    if not self.room_entity[user_rid] then
        write_log(string.format("Error:对象%s离开房间%s时找不到自己\n", user_rid, self:get_room_name()))
    end

    --设置实体的登出时间，如果实体还在游戏中则等待处理，如果实体不在游戏中，则下一秒则析构掉玩家对像
    local entity = self.room_entity[user_rid]
    entity.last_logout_time = os.time()
    return 0
end

--玩家离开房间
function ROOM_CLASS:entity_destruct(user_rid)
    trace("ROOM_CLASS:entity_destruct user_rid = %o", user_rid)
    if not self.room_entity[user_rid] then
        write_log(string.format("Error:对象%s析构时找不到自己\n", user_rid))
    end

    --将该实体从场景中删除，并发送离开场景消息
    local entity = remove_get(self.room_entity, user_rid)
    destruct_object(entity.data)
    return 0
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

-- 返回房间中的玩家信息
function ROOM_CLASS:get_data_by_rid(user_rid)
    return self.room_entity[user_rid]
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

function ROOM_CLASS:get_table_class()
    return TABLE_CLASS
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