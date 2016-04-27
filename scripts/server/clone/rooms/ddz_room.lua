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

--获取房间类型
function DDZ_ROOM_CLASS:get_game_type()
    return "ddz"
end

function ROOM_CLASS:get_ob_id()
    return (string.format("DDZ_ROOM_CLASS:%s", save_string(self:get_room_name())))
end

function DDZ_ROOM_CLASS:entity_update(entity)
    trace("DDZ_ROOM_CLASS:entity_update")
    local room_update = get_class_func(ROOM_CLASS, "entity_update")
    room_update(self, entity)

end