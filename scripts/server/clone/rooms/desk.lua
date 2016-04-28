--room.lua
--Created by wugd
--桌子类

--创建类模板
DESK_CLASS = class()
DESK_CLASS.name = "DESK_CLASS"

--构造函数
function DESK_CLASS:create(room, idx)
    self.room = room
    self.idx = idx
    --rid=wheel, 玩家所在的位置
    self.users = {}
    --玩家所坐的位置
    self.wheels = {{}, {}, {}}
end

function DESK_CLASS:time_update()

end

function DESK_CLASS:is_full_user()
    return true
end

function DESK_CLASS:get_user_count()
    return sizeof(self.users)
end

function DESK_CLASS:get_empty_wheel()
    for idx,v in ipairs(self.wheels) do
        if not is_rid_vaild(v.rid) then
            return idx
        end 
    end
    return nil
end

function DESK_CLASS:is_empty()
    for idx,v in ipairs(self.wheels) do
        if is_rid_vaild(v.rid) then
            return false
        end 
    end
    return true
end

function DESK_CLASS:user_enter(user_rid)
    local idx = self:get_empty_wheel()
    if not idx then
        return -1
    end
    self.users[user_rid] = { idx = idx}
    self.wheels[idx] = {rid = user_rid, is_ready = 0}
    return 0
end

function DESK_CLASS:user_leave(user_rid)
    local user_data = self.users[user_rid]
    if not user_data then
        return -1
    end
    self.wheels[user_data.idx] = {}
    return 0
end

function DESK_CLASS:is_playing(user_rid)
    return false
end

function DESK_CLASS:get_play_num()
    return 3
end