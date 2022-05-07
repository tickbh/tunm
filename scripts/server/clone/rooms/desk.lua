--room.lua
--Created by wugd
--桌子类

--创建类模板
DESK_TDCLS = tdcls()
DESK_TDCLS.name = "DESK_TDCLS"

--构造函数
function DESK_TDCLS:create(room, idx)
    self.room = room
    self.idx = idx
    --rid=wheel, 玩家所在的位置
    self.users = {}
    --玩家所坐的位置
    self.wheels = {{}, {}, {}}
end

function DESK_TDCLS:time_update()

end

function DESK_TDCLS:is_full_user()
    return true
end

function DESK_TDCLS:get_user_count()
    return sizeof(self.users)
end

function DESK_TDCLS:get_empty_wheel()
    for idx,v in ipairs(self.wheels) do
        if not is_rid_vaild(v.rid) then
            return idx
        end 
    end
    return nil
end


function DESK_TDCLS:check_user_wheel(user_rid)
    local fix_empty_idx = nil
    for idx,v in ipairs(self.wheels) do
        if v.rid == user_rid then
            return idx
        end
        if not is_rid_vaild(v.rid) and not fix_empty_idx then
            fix_empty_idx = idx
        end
    end
    if self:is_playing() then
        return nil
    end
    return fix_empty_idx
end

function DESK_TDCLS:is_empty()
    for idx,v in ipairs(self.wheels) do
        if is_rid_vaild(v.rid) then
            return false
        end 
    end
    return true
end

function DESK_TDCLS:user_enter(user_rid)
    local idx = self:check_user_wheel(user_rid)
    if not idx then
        return -1
    end
    self.users[user_rid] = { idx = idx }
    self.wheels[idx] = self.wheels[idx] or {}
    self.wheels[idx].rid = user_rid
    self.wheels[idx].is_ready = 0

    self:broadcast_message(MSG_ROOM_MESSAGE, "success_enter_desk", {rid = user_rid, wheel_idx = idx, idx = self.idx, info = self.room:get_base_info_by_rid(user_rid)})
    self:send_desk_info(user_rid)
    return 0
end

function DESK_TDCLS:send_desk_info(user_rid)

end

function DESK_TDCLS:user_leave(user_rid)
    local user_data = self.users[user_rid]
    if not user_data then
        return -1
    end
    user_data.last_logout_time = os.time()

    self:broadcast_message(MSG_ROOM_MESSAGE, "success_leave_desk", {rid = user_rid, wheel_idx = user_data.idx})
    --中途掉线，保存当前进度数据
    if self:is_playing() then
        return -1
    end
    self.users[user_rid] = nil
    self.wheels[user_data.idx] = {}
    return 0
end


-- 广播消息
function DESK_TDCLS:broadcast_message(msg, ...)

    local size = sizeof(self.users)
    local msg_buf = pack_message(get_common_msg_type(), msg, ...)

    if not msg_buf then
        TRACE("广播消息(%d)打包消息失败。", msg)
        return
    end

    -- 遍历该房间的所有玩家对象
    for rid, _ in pairs(self.users) do
        self.room:send_rid_raw_message(rid, {}, msg_buf)
    end

    del_message(msg_buf)
end

-- 广播消息
function DESK_TDCLS:send_rid_message(user_rid, msg, ...)
    local msg_buf = pack_message(get_common_msg_type(), msg, ...)
    if not msg_buf then
        TRACE("发送消息(%s:%o)打包消息失败。", msg, {...})
        return
    end

    self.room:send_rid_raw_message(user_rid, {}, msg_buf)

    del_message(msg_buf)
end

function DESK_TDCLS:op_info(user_rid, info)
    return false
end

function DESK_TDCLS:check_all_ready()
    for _,data in ipairs(self.wheels) do
        if data.is_ready ~= 1 then
            return false
        end
    end

    self:start_game()
end

function DESK_TDCLS:start_game()
    self:broadcast_message(MSG_ROOM_MESSAGE, "success_start_game", {idx = self.idx})
end

function DESK_TDCLS:is_playing(user_rid)
    return false
end

function DESK_TDCLS:get_play_num()
    return 3
end
