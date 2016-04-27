--room.lua
--Created by wugd
--桌子类

--创建类模板
TABLE_CLASS = class()
TABLE_CLASS.name = "TABLE_CLASS"

--构造函数
function TABLE_CLASS:create(room)
    self.room = room
end

function TABLE_CLASS:time_update()

end