--ddz_room.lua
--Created by wugd
--斗地主房间类

--创建类模板
DDZ_ROOM_TDCLS = tdcls(ROOM_TDCLS)
DDZ_ROOM_TDCLS.name = "DDZ_ROOM_TDCLS"

--构造函数
function DDZ_ROOM_TDCLS:create(value)
    ASSERT(IS_TABLE(value), "room:create para not correct")
end

--获取房间类型
function DDZ_ROOM_TDCLS:get_game_type()
    return "ddz"
end

function ROOM_TDCLS:get_ob_id()
    return (string.format("DDZ_ROOM_TDCLS:%s", SAVE_STRING(self:get_room_name())))
end

function DDZ_ROOM_TDCLS:entity_update(entity)
    local room_update = get_class_func(ROOM_TDCLS, "entity_update")
    room_update(self, entity)
end

function ROOM_TDCLS:get_desk_class()
    return DDZ_DESK_TDCLS
end