--room.lua
--Created by wugd
--房间类

--创建类模板
ROOM_TDCLS = tdcls()
ROOM_TDCLS.name = "ROOM_TDCLS"

--构造函数
function ROOM_TDCLS:create(value)
    assert(is_table(value), "room:create para not correct")

    --记录该场景的基本信息
    self.data = value

    --创建存放该场景实体的弱表
    self.room_entity = {}

    self:init_desk_entity()
end

function ROOM_TDCLS:destruct()
    for _,data in pairs(dup(self.room_entity)) do
        self:entity_destruct(data)
    end
    for _,table in pairs(self.desk_entity) do
        destruct_object(table)
    end
end

function ROOM_TDCLS:init_desk_entity()
    --创建该房间的桌子信息
    self.desk_entity = {}
    local desk_num = self.data["desk_num"] or 100
    for i=1,desk_num do
    self.desk_entity[i] = clone_object(self:get_desk_class(), self, i)
    end
end

-- 生成对象的唯一ID
function ROOM_TDCLS:get_ob_id()
    return (string.format("ROOM_TDCLS:%s", save_string(self:get_room_name())))
end

--定义公共接口，按照字母顺序排序

function ROOM_TDCLS:time_update()
    for _,data in pairs(dup(self.room_entity)) do
        self:entity_update(data)
    end

    for _,table in pairs(self.desk_entity) do
        table:time_update()
    end
end

function ROOM_TDCLS:entity_update(entity)
    --正在游戏中的不做析构处理，等游戏先结束
    if entity.last_logout_time and os.time() - entity.last_logout_time > 10 then
        if not self:is_user_playing(entity.user_rid) then
            self:entity_destruct(entity.user_rid)
        end
    end
end

-- 广播消息
function ROOM_TDCLS:broadcast_message(msg, ...)

    local size = sizeof(self.room_entity)
    local config_amount = ROOM_D.get_msg_amount(msg)
    local find_object_by_rid = find_object_by_rid
    local is_object = is_object
    local user
    local msg_buf = pack_message(get_common_msg_type(), msg, ...)
    local send_raw_message = get_class_func(USER_TDCLS, "send_raw_message")

    if not msg_buf then
        trace("广播消息(%d)打包消息失败。", msg)
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
function ROOM_TDCLS:entity_enter(server_id, user_rid, info)
    local data = self.room_entity[user_rid]
    if data then
        data.server_id = server_id
        data.last_op_time = os.time()
        data.info = info
    else
        --将新实体加该场景
        self.room_entity[user_rid] = {
            user_rid = user_rid,
            --对像连接的服务器id
            server_id = server_id,
            --对像的登出时间
            last_logout_time = nil,
            --玩家的上次操作时间，确定是否超时
            last_op_time = os.time(),
            --进入桌子时间
            enter_desk_time = nil,
            --进入桌子编号
            enter_desk_idx = nil,

            info = info,
        }

    end

    self:send_rid_message(user_rid, {}, MSG_ROOM_MESSAGE, "success_enter_room", {rid = user_rid, room_name = self:get_room_name()})
    if data and data.enter_desk_idx then
        self:send_rid_message(user_rid, {}, MSG_ROOM_MESSAGE, "pre_desk", {rid = user_rid, enter_desk_idx = data.enter_desk_idx})
    end
    return 0
end

function ROOM_TDCLS:is_user_playing(user_rid)
    local entity = self.room_entity[user_rid]
    if not entity then
        return false
    end
    if not entity.enter_desk_idx then
        return false
    end
    local desk = self.desk_entity[entity.enter_desk_idx]
    if not desk then
        return false
    end
    return desk:is_playing(user_rid)
end

--玩家离开房间
function ROOM_TDCLS:entity_leave(user_rid)
    if not self.room_entity[user_rid] then
        LOG.err("Error:对象%s离开房间%s时找不到自己", user_rid, self:get_room_name())
    end

    --设置实体的登出时间，如果实体还在游戏中则等待处理，如果实体不在游戏中，则下一秒则析构掉玩家对像
    local entity = self.room_entity[user_rid]
    entity.last_logout_time = os.time()

    if not self:is_user_playing(user_rid) then
        if entity.enter_desk_idx then
            local desk = self.desk_entity[entity.enter_desk_idx]
            if not desk:is_playing() then
                desk:user_leave(user_rid)
            end
        end

        self:entity_destruct(user_rid)
        trace("玩家不在游戏状态，掉线时离开桌子")
        return
    end

    return 0
end

--玩家离开房间
function ROOM_TDCLS:entity_destruct(user_rid)
    if not self.room_entity[user_rid] then
        LOG.err("Error:对象%s析构时找不到自己", user_rid)
    end

    --将该实体从场景中删除，并发送离开场景消息
    local entity = remove_get(self.room_entity, user_rid)
    return 0
end

--TODO优先填取桌子人多但并未满的桌子 
function ROOM_TDCLS:get_can_enter_desk()
    for idx, t in ipairs(self.desk_entity) do
        if not t:is_full_user() then
            return idx
        end
    end
    return nil
end

function ROOM_TDCLS:enter_desk(user_rid, idx, enter_method)
    local data = self.room_entity[user_rid]
    if not data then
        LOG.err("Error:%s进入桌子时找不到自己", user_rid)
        return -1
    end
    if idx and idx == data.enter_desk_idx then
        data.enter_desk_idx = nil
    elseif idx == nil then
        if data.enter_desk_idx then
            idx = data.enter_desk_idx
            data.enter_desk_idx = nil
        else
            idx = self:get_can_enter_desk()
        end
    end

    if data.enter_desk_idx then
        LOG.err("Error:%s已在%d桌，无法进入", user_rid, data.enter_desk_idx)
        return -1
    end
    if not idx then
        LOG.err("桌子已用完，无可用桌子")
        return -1
    end

    local desk = self.desk_entity[idx]
    if not desk then
        LOG.err("Error:%o桌号不存在", idx)
        return -1
    end

    desk:user_enter(user_rid)
    data.enter_desk_idx = idx
    return 0
end

function ROOM_TDCLS:send_rid_message(user_rid, record, msg, ...)
    local msg_buf = pack_message(get_common_msg_type(), msg, ...)
    if not msg_buf then
        trace("广播消息(%s)打包消息失败。", msg)
        return
    end
    self:send_rid_raw_message(user_rid, record, msg_buf)
    del_message(msg_buf)
end

function ROOM_TDCLS:send_rid_raw_message(user_rid, record, msg_buf)
    local data = self:get_data_by_rid(user_rid)
    if not data or not data.server_id then
        trace("获取用户%s数据失败", user_rid)
        return
    end
    INTERNAL_COMM_D.send_server_raw_message(data.server_id, user_rid, record or {}, msg_buf:get_data())
end

function ROOM_TDCLS:desk_op(user_rid, info)
    local data = self.room_entity[user_rid]
    if not data then
        return -1
    end
    local desk = self.desk_entity[data.enter_desk_idx or 0]
    if not desk then
        return -1
    end

    desk:op_info(user_rid, info)
end

--获取房间名称
function ROOM_TDCLS:get_room_name()
    return self.data["room_name"]
end

--获取房间类型
function ROOM_TDCLS:get_game_type()
    return self.data["game_type"]
end

-- 返回房间中的玩家信息
function ROOM_TDCLS:get_room_entity()
    return self.room_entity
end

-- 返回房间中的玩家信息
function ROOM_TDCLS:get_data_by_rid(user_rid)
    return self.room_entity[user_rid]
end

-- 返回房间中的玩家信息
function ROOM_TDCLS:get_base_info_by_rid(user_rid)
    local data = self.room_entity[user_rid]
    if not data then
        return nil
    end
    return data.info
end

--判断是否是vip场景
function ROOM_TDCLS:is_vip()
    if self.data["is_vip"] == 1 then
        return true
    else
        return nil
    end
end

function ROOM_TDCLS:get_level()
    return self.data["level"]
end

function ROOM_TDCLS:get_desk_class()
    return DESK_TDCLS
end

-- 判断是否为房间对象
function ROOM_TDCLS:is_room()
    return true
end

--更新实体外观信息
function ROOM_TDCLS:update_entity(rid, pkg_info)
    if self.room_entity[rid] and
       self.room_entity[rid]["packet"] then

        self.room_entity[rid]["packet"] = pkg_info
    end
end

function ROOM_TDCLS:get_listen_channel()
    return string.format(REDIS_ROOM_MSG_CHANNEL_USER, self:get_room_name())
end

function ROOM_TDCLS:get_respone_channel()
    return string.format(REDIS_RESPONE_ROOM_INFO, self:get_room_name())
end