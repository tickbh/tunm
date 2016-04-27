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
    self.users = {}
end

function DESK_CLASS:time_update()

end

function DESK_CLASS:is_full_user()
    return true
end

function DESK_CLASS:get_user_count()
    return sizeof(self.users)
end

function DESK_CLASS:user_enter(user_rid)
    
end