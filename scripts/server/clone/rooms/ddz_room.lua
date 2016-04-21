--ddz_room.lua
--Created by wugd
--斗地主房间类

--创建类模板
DDZ_ROOM_CLASS = class(ROOM_CLASS)
DDZ_ROOM_CLASS.name = "DDZ_ROOM_CLASS"

--构造函数
function DDZ_ROOM_CLASS:create(value)
    assert(is_table(value), "room:create para not correct")
end
